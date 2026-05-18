# Stack Bundle: Ionic + Capacitor

## Overview
Ionic provides a component library that mimics native mobile UI patterns using web technologies.
Capacitor acts as the bridge between the web runtime and native device APIs. The crucial mental
model: your app runs in a WebView — Capacitor plugins expose native functionality, but the
execution happens in the web context first, falling through to native implementation as needed.

## Implementation

### Capacitor Plugin System
```ts
// Always import from the Capacitor plugin package, not a polyfill
import { Camera, CameraResultType, CameraSource } from '@capacitor/camera';
import { Filesystem, Directory, Encoding } from '@capacitor/filesystem';
import { Geolocation } from '@capacitor/geolocation';

// Camera — returns base64 or URI
async function takePhoto() {
  const photo = await Camera.getPhoto({
    quality: 90,
    allowEditing: false,
    resultType: CameraResultType.Uri,   // or .Base64 / .DataUrl
    source: CameraSource.Camera,        // or .Photos / .Prompt
  });
  return photo.webPath;  // use webPath for display in <img src>, not path
}

// Filesystem — cross-platform file read/write
async function saveFile(content: string, filename: string) {
  await Filesystem.writeFile({
    path: filename,
    data: content,
    directory: Directory.Documents,
    encoding: Encoding.UTF8,
  });
}

// Geolocation
async function getPosition() {
  const coords = await Geolocation.getCurrentPosition({
    enableHighAccuracy: true,
    timeout: 10000,
  });
  return { lat: coords.coords.latitude, lng: coords.coords.longitude };
}
```

### @capacitor/core + Web APIs First
Capacitor uses a fallback strategy: the same code works on web, iOS, and Android.
On web: the plugin uses the Web API (e.g., `navigator.geolocation`).
On iOS/Android: the plugin calls the native implementation.
```ts
// This code works identically on all platforms:
const position = await Geolocation.getCurrentPosition();
// Web: uses navigator.geolocation
// iOS: uses CoreLocation
// Android: uses FusedLocationProviderClient
```
Some plugins have no web fallback (e.g., NFC, Haptics on desktop). Use `Capacitor.isNativePlatform()`
to conditionally show features.

### Permissions in Native Projects
```ts
// Request permission before using it
import { Camera } from '@capacitor/camera';

const status = await Camera.checkPermissions();
if (status.camera !== 'granted') {
  const request = await Camera.requestPermissions({ permissions: ['camera'] });
  if (request.camera !== 'granted') {
    // Show explanation UI — can't force permission after denial
    return;
  }
}
```
```xml
<!-- ios/App/App/Info.plist — required for iOS -->
<key>NSCameraUsageDescription</key>
<string>We need camera access to take photos.</string>

<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
```

### Splash Screen + App Icon Setup
```ts
// capacitor.config.ts
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.example.app',
  appName: 'My App',
  webDir: 'dist',      // or 'build' — wherever your web build outputs
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: '#ffffff',
      androidSplashResourceName: 'splash',
      showSpinner: false,
    },
  },
};
```
```bash
npx @capacitor/assets generate   # generates all icon/splash sizes from a single source image
# Requires: assets/icon.png (1024x1024) and assets/splash.png (2732x2732)
```

### Push Notifications via FCM/APNs
```ts
import { PushNotifications } from '@capacitor/push-notifications';

async function registerPush() {
  const permission = await PushNotifications.requestPermissions();
  if (permission.receive !== 'granted') return;

  await PushNotifications.register();

  PushNotifications.addListener('registration', (token) => {
    // Send token.value to your server — this is the device token for FCM/APNs
    api.savePushToken(token.value);
  });

  PushNotifications.addListener('pushNotificationReceived', (notification) => {
    // Foreground notification — app is open
    showInAppNotification(notification.title, notification.body);
  });

  PushNotifications.addListener('pushNotificationActionPerformed', (action) => {
    // User tapped on notification
    router.push(action.notification.data.route);
  });
}
```

### Syncing Native Projects After Changes
```bash
# After installing a new Capacitor plugin:
npm install @capacitor/plugin-name
npx cap sync                     # copies web build + plugins to ios/ and android/

# After changing capacitor.config.ts:
npx cap sync

# After changing web code only:
npm run build && npx cap sync    # or npx cap copy (faster — skips dependency sync)
```

## Key Rules
- Run `npx cap sync` after every npm install that adds a Capacitor plugin — skipping this causes runtime errors
- Use `photo.webPath` (not `photo.path`) when displaying Capacitor Camera results in `<img>` tags
- Check and request permissions before using any sensitive API — iOS denies silently without permission strings in Info.plist
- Always add `@capacitor/assets generate` to the build pipeline for consistent icon/splash generation
- Push notification tokens expire — store with timestamp, refresh on each app open, handle invalid token errors from FCM/APNs
- `npx cap open ios` and `npx cap open android` open the native IDEs when native troubleshooting is needed
- Test on physical devices for Camera, GPS, haptics — simulators do not accurately reflect native behavior
