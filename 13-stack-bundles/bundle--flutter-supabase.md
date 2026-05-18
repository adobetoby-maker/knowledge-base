# Stack Bundle: Flutter + Supabase

## Overview
The `supabase_flutter` package wraps the Supabase JS client semantics in a Dart-idiomatic API.
Because Flutter apps run on the client device, all database access goes through RLS policies —
there is no server layer to enforce authorization separately. This makes RLS not optional but
mandatory: any policy gap directly exposes user data.

## Implementation

### Initialization in main()
```dart
// main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    // authOptions for deep link handling
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,  // PKCE is more secure than implicit for mobile
    ),
  );

  runApp(const MyApp());
}

// Convenience getter — use throughout the app
final supabase = Supabase.instance.client;
```
Pass env vars via `--dart-define` at build time, not hardcoded in source:
```bash
flutter build apk --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

### SupabaseStreamBuilder for Real-Time
```dart
// Reacts to database changes in real time
class PostsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: supabase
          .from('posts')
          .stream(primaryKey: ['id'])   // subscribe to real-time changes
          .order('created_at', ascending: false)
          .limit(50),
      builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final posts = snapshot.data!;
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, i) => PostCard(post: posts[i]),
        );
      },
    );
  }
}
```
`.stream()` opens a Postgres replication subscription. Each stream call = one realtime channel.
Dispose streams when the widget is removed to avoid memory and connection leaks.

### Authentication Patterns
```dart
// Sign up
Future<void> signUp(String email, String password) async {
  final response = await supabase.auth.signUp(
    email: email,
    password: password,
    emailRedirectTo: 'io.supabase.myapp://login-callback/',  // deep link
  );
  // response.user is null until email is confirmed (if email confirmation enabled)
}

// Sign in
await supabase.auth.signInWithPassword(email: email, password: password);

// OAuth (Google, Apple, GitHub)
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'io.supabase.myapp://login-callback/',
);

// Listen to auth state changes
supabase.auth.onAuthStateChange.listen((data) {
  final session = data.session;
  if (session != null) {
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    Navigator.pushReplacementNamed(context, '/login');
  }
});
```

### Row-Level Security Enforced from Flutter
```sql
-- Without RLS, any authenticated user can read all rows
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- User can only see their own posts
CREATE POLICY "Users see own posts" ON posts
  FOR SELECT USING (auth.uid() = user_id);

-- User can only insert as themselves
CREATE POLICY "Users insert own posts" ON posts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- No admin bypass — Flutter connects with anon key, not service key
```
```dart
// This query respects RLS — returns only rows where user_id = auth.uid()
final posts = await supabase.from('posts').select();
```
The Flutter app uses the anon key. There is no service role key in mobile apps.
If you need admin operations, implement them as Edge Functions called by the app.

### Image Storage in Buckets
```dart
// Upload
Future<String> uploadAvatar(File imageFile, String userId) async {
  final path = '$userId/avatar.jpg';
  await supabase.storage.from('avatars').upload(
    path,
    imageFile,
    fileOptions: const FileOptions(upsert: true),  // overwrite if exists
  );
  return supabase.storage.from('avatars').getPublicUrl(path);
}

// Display
Image.network(
  supabase.storage.from('avatars').getPublicUrl('$userId/avatar.jpg'),
)
```
```sql
-- Bucket policy: users can only access their own files
CREATE POLICY "Users access own files" ON storage.objects
  FOR ALL USING (auth.uid()::text = (storage.foldername(name))[1]);
```

### Deep Linking for Auth Callbacks
```dart
// android/app/src/main/AndroidManifest.xml
// <intent-filter android:autoVerify="true">
//   <action android:name="android.intent.action.VIEW" />
//   <data android:scheme="io.supabase.myapp" android:host="login-callback" />
// </intent-filter>

// ios/Runner/Info.plist
// <key>CFBundleURLSchemes</key><array><string>io.supabase.myapp</string></array>

// main.dart — handle incoming deep links
import 'package:app_links/app_links.dart';

final appLinks = AppLinks();
appLinks.uriLinkStream.listen((uri) {
  supabase.auth.getSessionFromUrl(uri);  // completes OAuth/magic link flow
});
```

## Key Rules
- Never include the Supabase service role key in a Flutter app — it bypasses all RLS and is readable by anyone who decompiles the APK
- Enable RLS on every table before adding a Flutter client — unprotected tables are accessible to any authenticated user
- Dispose `StreamBuilder` streams via `StatefulWidget.dispose()` to prevent subscription leaks
- Use PKCE auth flow for mobile (`AuthFlowType.pkce`) — it is more secure than implicit flow for native apps
- Deep link scheme must match exactly between AndroidManifest.xml, Info.plist, and the `redirectTo` URL in auth calls
- Store the Supabase anon key in build-time `--dart-define` variables, not as string literals in source code
- Realtime subscriptions count against Supabase concurrent connection limits — clean up subscriptions in `dispose()`
