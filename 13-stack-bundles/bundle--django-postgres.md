# Stack Bundle: Django + PostgreSQL

## Overview
Django's batteries-included philosophy means the right packages exist for nearly every concern.
The key is knowing which batteries to reach for: `django-environ` for 12-factor config,
`django-rest-framework` for APIs, Celery for async work, and `whitenoise` for static file serving
without a separate nginx process.

## Implementation

### django-environ for 12-Factor Config
```python
# settings.py
import environ

env = environ.Env(
    DEBUG=(bool, False),          # type cast + default
    DATABASE_URL=(str, 'postgres://localhost/myapp'),
)

# Read .env file (only in development; production uses real env vars)
environ.Env.read_env(BASE_DIR / '.env')

DEBUG = env('DEBUG')
SECRET_KEY = env('SECRET_KEY')   # no default — crash if missing
DATABASES = {'default': env.db()}  # parses DATABASE_URL automatically
```
```
DATABASE_URL=postgres://user:pass@localhost:5432/myapp
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=your-secret-key-here
DEBUG=True
```

### Django REST Framework API
```python
# serializers.py
from rest_framework import serializers
from .models import Post

class PostSerializer(serializers.ModelSerializer):
    author_email = serializers.EmailField(source='author.email', read_only=True)

    class Meta:
        model = Post
        fields = ['id', 'title', 'body', 'author_email', 'created_at']
        read_only_fields = ['id', 'created_at']

# views.py
from rest_framework.viewsets import ModelViewSet
from rest_framework.permissions import IsAuthenticatedOrReadOnly

class PostViewSet(ModelViewSet):
    queryset = Post.objects.select_related('author').order_by('-created_at')
    serializer_class = PostSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)
```
```python
# urls.py
from rest_framework.routers import DefaultRouter

router = DefaultRouter()
router.register('posts', PostViewSet)
urlpatterns = [path('api/', include(router.urls))]
```

### Celery for Background Jobs
```python
# celery.py
from celery import Celery

app = Celery('myproject')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks()

# settings.py additions
CELERY_BROKER_URL = env('REDIS_URL')
CELERY_RESULT_BACKEND = env('REDIS_URL')
CELERY_TASK_ALWAYS_EAGER = env('CELERY_ALWAYS_EAGER', default=False)  # run sync in tests

# tasks.py
from celery import shared_task
from django.core.mail import send_mail

@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_welcome_email(self, user_id: int):
    try:
        user = User.objects.get(pk=user_id)
        send_mail('Welcome!', 'Hello', 'noreply@example.com', [user.email])
    except Exception as exc:
        raise self.retry(exc=exc)
```
```bash
celery -A myproject worker --loglevel=info   # start worker process
celery -A myproject beat                     # start scheduler for periodic tasks
```

### django-storages for S3
```python
# settings.py
STORAGES = {
    "default": {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {
            "bucket_name": env("AWS_STORAGE_BUCKET_NAME"),
            "region_name": env("AWS_S3_REGION_NAME"),
            "custom_domain": f"{env('AWS_STORAGE_BUCKET_NAME')}.s3.amazonaws.com",
        },
    },
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}
```

### whitenoise for Static Files
```python
# settings.py
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # immediately after SecurityMiddleware
    # ...rest of middleware
]

STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
```
```bash
python manage.py collectstatic --noinput   # run in Docker build step, not at runtime
```

### Migrations Strategy
```bash
# Development
python manage.py makemigrations   # generate migration from model changes
python manage.py migrate          # apply

# CI/CD — never run makemigrations in CI
# migrations are committed to git; only `migrate` runs in CI/CD
python manage.py migrate --run-syncdb  # for test DB (creates tables without migrations)
```
Never run `makemigrations` in production or CI. Migration files are source code.
Running `makemigrations` on the server means the DB schema is not reproducible from git.

## Key Rules
- `django-environ`'s `env('KEY')` with no default crashes on missing key — use this for required secrets
- Always use `select_related()` and `prefetch_related()` to prevent N+1 queries in DRF viewsets
- `CELERY_TASK_ALWAYS_EAGER=True` in test settings runs tasks synchronously — prevents async test complexity
- Run `collectstatic` in the Docker build step, not at container startup
- Never run `makemigrations` in CI or production — only `migrate`
- Celery workers and the Django app must share the same codebase and environment
- Use `CompressedManifestStaticFilesStorage` for production — it appends content hash to filenames for cache-busting
