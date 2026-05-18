# plugin--capacitor

Capacitor is a cross-platform native runtime that wraps web apps (React, Vue, plain HTML) in native iOS and Android shells. The web app runs in a `WKWebView` (iOS) or `WebView` (Android) and calls native device APIs through a JavaScript bridge.

## Core Concept: The Bridge

Every Capacitor plugin call is asynchronous — the JS side sends a message across the bridge to the native layer and awaits a response. This means even simple calls like reading a file return Promises. Never expect synchronous results from any `@capacitor/*` plugin.

## Plugin Registration

```ts
// Install
// npm install @capacitor/camera @capacitor/filesystem @capacitor/push-notifications

// Use in your web app
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';

const photo = await Camera.getPhoto({
  resultType: CameraResultType.Uri,  // Uri = safest; Base64 for upload
  source: CameraSource.Camera,
  quality: 80,
});
// photo.webPath is a local file path usable in <img src>
```

`@capacitor/core` is the bridge — it's a dependency of every plugin, not called directly. Import from specific plugin packages.

## Camera / Filesystem / Notifications Patterns

**Camera:**
- `CameraResultType.Uri` — returns a local path; display with `<img>`. Avoid `Base64` for large images (memory pressure).
- `CameraSource.Photos` — gallery picker; `CameraSource.Camera` — live camera. `CameraSource.Prompt` — lets the user choose.

**Filesystem:**
```ts
import { Filesystem, Directory, Encoding } from '@capacitor/filesystem';

await Filesystem.writeFile({
  path: 'data.json',
  data: JSON.stringify(payload),
  directory: Directory.Data,         // app-private, not visible in Files app
  encoding: Encoding.UTF8,
});
const file = await Filesystem.readFile({ path: 'data.json', directory: Directory.Data, encoding: Encoding.UTF8 });
```
`Directory.Data` is app-private. `Directory.Documents` is user-visible on iOS. Never hardcode absolute paths — they change across OS versions.

**Push Notifications:**
```ts
import { PushNotifications } from '@capacitor/push-notifications';
await PushNotifications.requestPermissions();
await PushNotifications.register();
PushNotifications.addListener('registration', ({ value }) => {
  // value is the FCM/APNs device token — send to your backend
});
```

## npx cap sync — The Critical Step

After every web build that adds or updates Capacitor plugins, run:

```bash
npm run build        # build your web app first
npx cap sync         # copies web assets to native projects + updates native plugin registrations
```

`cap sync` does two things: copies `dist/` into `ios/App/public` and `android/app/src/main/assets/public`, AND reconciles native plugin pod/gradle dependencies. Skipping it after adding a new plugin results in "Plugin not implemented" errors at runtime, even though JS imports work fine. The error is not a JS error — it's the native side that's missing.

## iOS Info.plist Permission Descriptions

Apple requires usage description strings for every API that accesses sensitive hardware. Missing descriptions cause App Store rejection, and the app crashes on iOS 14+ when the key is absent.

Add to `ios/App/App/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan QR codes and capture photos.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Used to select images from your library.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to show nearby locations.</string>
```

The string shown to the user must be honest about the purpose — vague descriptions like "Required for app functionality" are rejected during App Review. Every permission in Info.plist must map to a feature actually used.

## Live Reload Setup

For development, run the web dev server and point Capacitor at it instead of the built assets:

```bash
npx cap run ios --livereload --external
```

Or set in `capacitor.config.ts`:
```ts
const config: CapacitorConfig = {
  server: {
    url: 'http://192.168.1.50:5173', // your dev machine's LAN IP
    cleartext: true,                  // allows HTTP on Android
  },
};
```

Use the LAN IP (not `localhost`) — the device/simulator sees the host machine's network interface, not loopback. Remove the `server` block before building for production; leaving it in means production users hit your dev server.

## Key Rules

- **`npx cap sync` after every build** that adds or modifies plugins — never skip it
- **All plugin calls are async** — always `await`; no synchronous native API access
- **Info.plist descriptions are mandatory** — every capability needs a non-vague usage string
- **Live reload uses LAN IP** — `localhost` won't work from a physical device
- **`Directory.Data` for private files** — never hardcode absolute paths
- Remove `server.url` from `capacitor.config.ts` before production builds
