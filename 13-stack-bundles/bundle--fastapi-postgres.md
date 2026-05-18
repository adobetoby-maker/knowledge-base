# Stack Bundle: FastAPI + PostgreSQL

## Overview
FastAPI's async-first design pairs naturally with asyncpg for non-blocking PostgreSQL access.
The full async stack (FastAPI + SQLAlchemy async + asyncpg) means a single process can handle
many concurrent requests without threading overhead — but only if every I/O operation in the
request path is actually awaited.

## Implementation

### Async SQLAlchemy + asyncpg Setup
```python
# database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

DATABASE_URL = "postgresql+asyncpg://user:pass@localhost/dbname"

engine = create_async_engine(
    DATABASE_URL,
    pool_size=10,
    max_overflow=20,
    echo=False,           # set True for SQL logging in dev
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    expire_on_commit=False,   # prevent lazy loading errors after commit
    class_=AsyncSession,
)

class Base(DeclarativeBase):
    pass
```

### Dependency Injection for DB Sessions
```python
# deps.py
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from .database import AsyncSessionLocal

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise

# In route:
from fastapi import Depends
from sqlalchemy import select
from .models import User

@app.get("/users/{user_id}")
async def get_user(user_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404)
    return user
```

### Alembic Migrations
```python
# alembic/env.py — configure async migration runner
from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine
import asyncio

def run_migrations_online():
    connectable = create_async_engine(config.get_main_option("sqlalchemy.url"))

    async def do_run():
        async with connectable.connect() as connection:
            await connection.run_sync(
                context.configure,
                connection=connection,
                target_metadata=target_metadata,
                compare_type=True,       # detect column type changes
                compare_server_default=True,
            )
            async with context.begin_transaction():
                await connection.run_sync(context.run_migrations)

    asyncio.run(do_run())
```
```bash
alembic revision --autogenerate -m "add_users_table"   # generates migration from model diff
alembic upgrade head                                    # apply migrations
alembic downgrade -1                                    # roll back one
```
Never edit a migration that has already been applied to production. Create a new migration instead.

### Pydantic v2 Validation
```python
from pydantic import BaseModel, field_validator, model_validator
from typing import Annotated
from pydantic import Field

class UserCreate(BaseModel):
    email: Annotated[str, Field(min_length=1, max_length=255)]
    password: Annotated[str, Field(min_length=8)]
    age: int | None = None

    @field_validator('email')
    @classmethod
    def email_lowercase(cls, v: str) -> str:
        return v.lower().strip()

    @model_validator(mode='after')
    def check_age(self) -> 'UserCreate':
        if self.age is not None and self.age < 0:
            raise ValueError('age cannot be negative')
        return self
```
Pydantic v2 (used by FastAPI 0.100+) uses `model_validator` and `field_validator` — the v1
`validator` decorator is deprecated.

### Background Tasks vs Celery
```python
# FastAPI BackgroundTasks — for lightweight, fire-and-forget work
@app.post("/send-email")
async def trigger_email(
    background_tasks: BackgroundTasks,
    payload: EmailPayload,
):
    background_tasks.add_task(send_email, payload.to, payload.subject, payload.body)
    return {"status": "queued"}
    # BackgroundTasks runs AFTER the response is sent, in the same process
    # If the process dies, the task is lost — no retry, no persistence
```
Use Celery (+ Redis/RabbitMQ) when:
- Tasks need retry logic
- Tasks need to be distributed across workers
- Tasks run longer than a request timeout allows
- Task failure should be visible in a queue dashboard

### Lifespan Events (startup/shutdown)
```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialize connection pools, load models
    await engine.begin()
    yield
    # Shutdown: close cleanly
    await engine.dispose()

app = FastAPI(lifespan=lifespan)
# Replaces deprecated @app.on_event("startup") / @app.on_event("shutdown")
```

## Key Rules
- Never use synchronous SQLAlchemy queries inside async routes — they block the event loop
- Set `expire_on_commit=False` on async sessions to prevent lazy loading AttributeErrors post-commit
- Always use `asyncpg` driver (not `psycopg2`) for async SQLAlchemy — the URL prefix is `postgresql+asyncpg://`
- Alembic autogenerate does not detect all changes (indexes, CHECK constraints) — always review generated migrations
- BackgroundTasks is not a job queue — use Celery for any work that must survive process restart
- Use the `lifespan` context manager instead of deprecated event decorators
- Database connection pools size: `pool_size + max_overflow` should not exceed PostgreSQL's `max_connections`
