# Skill: Deep Linking for Web + Mobile

## Overview
Deep links allow external URLs to open specific content inside a native app instead of (or in addition to) a web browser. When the app is not installed, the link should fall back to the web. Two technologies handle this: Universal Links (iOS) and App Links (Android) intercept standard HTTPS URLs at the OS level. Custom URL schemes (`myapp://`) are the legacy approach — simpler but cannot fall back to web and are blocked in some email clients. For most products, Universal Links / App Links are the right choice.

## Implementation

### Architecture Decision: Universal Links vs Custom Scheme
| Feature | Universal Links / App Links | Custom URL Scheme |
|---|---|---|
| URL format | `https://yourapp.com/products/123` | `yourapp://products/123` |
| App not installed | Opens web browser (fallback works) | Error — no app to handle it |
| Works in email/SMS | Yes | Blocked by many clients |
| Configuration | Domain verification file required | Just plist/manifest entry |

### Universal Links (iOS)

**Step 1: Host the association file at `https://yourdomain.com/.well-known/apple-app-site-association`**
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourcompany.yourapp",
        "paths": [
          "/products/*",
          "/orders/*",
          "/profile/*",
          "NOT /blog/*",
          "NOT /public/*"
        ]
      }
    ]
  }
}
```

The file must:
- Be served over HTTPS (no redirect)
- Have `Content-Type: application/json`
- NOT be gzip-encoded
- Be accessible without authentication

**Step 2: iOS App Configuration**
In `Info.plist`, add your domain to `com.apple.developer.associated-domains`:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:yourapp.com</string>
  <string>applinks:www.yourapp.com</string>
</array>
```

**Step 3: Handle in AppDelegate (Swift)**
```swift
func application(
  _ application: UIApplication,
  continue userActivity: NSUserActivity,
  restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
) -> Bool {
  guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
        let url = userActivity.webpageURL else { return false }

  // Parse and navigate to the content
  return handleDeepLink(url: url)
}

func handleDeepLink(url: URL) -> Bool {
  let path = url.path
  if path.hasPrefix("/products/") {
    let productId = String(path.dropFirst("/products/".count))
    navigateToProduct(productId)
    return true
  }
  return false
}
```

### App Links (Android)

**Step 1: Host at `https://yourdomain.com/.well-known/assetlinks.json`**
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.yourcompany.yourapp",
    "sha256_cert_fingerprints": ["AA:BB:CC:DD:..."]
  }
}]
```

Get SHA256 fingerprint: `keytool -list -v -keystore release.keystore -alias your-alias`

**Step 2: AndroidManifest.xml**
```xml
<activity android:name=".MainActivity">
  <intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="yourapp.com" />
  </intent-filter>
</activity>
```

### Testing

**iOS:** Simulator doesn't verify Universal Links. Test on device:
```bash
xcrun simctl openurl booted "https://yourapp.com/products/123"
# On device, use Safari to open the URL (not by typing in notes/messages)
```

**Android:**
```bash
adb shell am start -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d "https://yourapp.com/products/123"
```

### Web Fallback (App Not Installed)
The URL `https://yourapp.com/products/123` must work as a normal web page. If the app is installed, iOS/Android intercepts it. If not, the browser handles it normally. This is the key advantage of Universal Links.

### Generating Deep Links for Sharing
```ts
export function generateDeepLink(resource: string, id: string): string {
  // Same URL works for web and app
  return `https://yourapp.com/${resource}/${id}`;
}

// For custom scheme (legacy, use sparingly)
export function generateCustomSchemeLink(resource: string, id: string): string {
  return `myapp://${resource}/${id}`;
}
```

## Key Rules
- Host the association files at `/.well-known/` — iOS/Android fetch these during app installation, not at link-open time.
- The association file must not redirect — a redirect to HTTPS fails the verification on iOS.
- Include only the paths your app handles in the association file — don't use `"paths": ["*"]` if your app only handles specific deep routes.
- Test Universal Links on a physical device — simulators don't perform the domain verification.
- `assetlinks.json` SHA256 fingerprints must match the signing key of the production release APK — debug fingerprints won't work in the Play Store build.
- Always provide a web fallback — if the app isn't installed, the user should still see the content.
- Custom URL schemes (`myapp://`) are suitable only for app-to-app communication (OAuth callbacks, third-party integrations) — not for user-shared links.
