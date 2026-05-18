# Stack Bundle: Expo + React Native

## Overview
Expo provides a managed layer on top of React Native that removes the need to maintain native build tooling
locally. Understanding when to stay in the managed workflow versus ejecting to bare workflow determines
build complexity and native module availability.

## Implementation

### Managed vs Bare Workflow
```
Managed workflow: Expo handles all native code. You write JS/TS only.
  → Use when: no custom native modules, Expo SDK covers all needs
  → Limits: only Expo-approved native modules

Bare workflow: You own ios/ and android/ directories.
  → Use when: custom native SDK (e.g., proprietary hardware), or npm package with native code
  → Cost: must install Xcode + Android Studio, manage native build config
```

### EAS Build (CI/CD)
```json
// eas.json
{
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal",
      "ios": { "simulator": true }
    },
    "production": {
      "autoIncrement": true
    }
  }
}
```
```bash
eas build --platform ios --profile production   # triggers cloud build, no Xcode needed
eas build --platform android --profile preview  # APK for internal testing
eas submit --platform ios                       # submit to App Store after build
```

### OTA Updates (expo-updates)
```ts
// app.json — configure update URL
{
  "expo": {
    "updates": {
      "url": "https://u.expo.dev/<project-id>",
      "checkAutomatically": "ON_LOAD",      // check on every app open
      "fallbackToCacheTimeout": 3000        // ms to wait before using cached bundle
    },
    "runtimeVersion": {
      "policy": "appVersion"                // OTA won't apply across native ABI changes
    }
  }
}
```
```ts
// Manual update check
import * as Updates from 'expo-updates';

async function checkForUpdate() {
  if (!__DEV__) {
    const update = await Updates.checkForUpdateAsync();
    if (update.isAvailable) {
      await Updates.fetchUpdateAsync();
      await Updates.reloadAsync();  // restart to apply
    }
  }
}
```
OTA updates only work for JS bundle changes. Any change touching native code (new native module,
Expo SDK version bump that changes native) requires a new binary build.

### Shared Code with Next.js via Monorepo
```
packages/
  ui/          # shared React components (must avoid DOM-only APIs)
  utils/       # shared business logic
  config/      # shared TypeScript config, ESLint, Tailwind

apps/
  web/         # Next.js
  mobile/      # Expo React Native
```
```json
// packages/ui/package.json — mark as ESM + RN compatible
{
  "main": "./src/index.ts",
  "exports": {
    ".": "./src/index.ts"
  }
}
```
Components shared between web and mobile cannot use `window`, `document`, `localStorage`,
or any web-only API. Conditionally import platform-specific implementations via `.native.ts` / `.web.ts`
file extensions — Metro (RN bundler) resolves `.native.ts` first on mobile, Webpack/Vite resolves `.web.ts`.

### Native Module Installation
```bash
npx expo install expo-camera        # use `expo install`, NOT `npm install`
# expo install picks the SDK-compatible version automatically
```
After adding any native module in bare workflow:
```bash
cd ios && pod install   # CocoaPods for iOS
# Android: automatic via Gradle
npx expo prebuild      # regenerates ios/ android/ from app.json (destructive if customized)
```

### Expo Go vs Production Build Differences
```
Expo Go:
  - Runs your JS bundle inside the Expo Go shell (pre-installed on device)
  - Supports only modules included in the Expo SDK
  - Cannot test push notifications, app icon, splash screen
  - Instant iteration — no build step

Development Build (via EAS):
  - Custom binary with your specific native modules
  - Behaves like production binary except with dev menu enabled
  - Required for: custom native modules, push notifications, in-app purchases

Production Build:
  - Optimized JS bundle (Hermes engine by default)
  - No dev menu, no hot reload
  - Signed binary ready for store submission
```

## Key Rules
- Always use `npx expo install` instead of `npm install` for Expo packages — version mismatches cause runtime crashes
- Set `runtimeVersion` policy to `appVersion` or `nativeVersion` to prevent OTA updates from landing on incompatible native binaries
- Test on physical devices before submitting — iOS simulator does not accurately reflect performance or camera/GPS behavior
- OTA rollback: always keep previous publish in EAS; use `eas update:rollback` on bad deploy
- Bare workflow: commit `ios/` and `android/` directories to git — they are the source of truth for native config
- Development clients must be rebuilt when adding any native module even in managed workflow
- Use `expo-dev-client` package for development builds; it adds the Expo dev menu to your custom binary
