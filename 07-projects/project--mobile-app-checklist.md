# Project: Mobile App Launch Checklist

## Overview
Mobile app launches are high-stakes and hard to iterate on quickly — app store reviews take days, and a bad initial review score is permanent. The checklist prioritizes the items that prevent poor ratings: crash-free sessions, offline graceful degradation, and not asking for the review at the wrong moment. App store metadata (screenshots, description, keywords) determines discoverability and is often treated as an afterthought.

## Authentication

- [ ] Email + password sign up / sign in
- [ ] OAuth (Sign in with Apple is required on iOS if any other social login exists — App Store policy)
- [ ] Biometric authentication (Face ID / Touch ID / fingerprint) for returning sessions
- [ ] Secure token storage (iOS Keychain, Android Keystore — not AsyncStorage/localStorage)
- [ ] Auto-refresh of auth tokens in the background
- [ ] Session revocation (logout clears all local auth state)

## Offline Support

- [ ] Core read functionality works offline (cached data displayed)
- [ ] Graceful error state when offline and cache is empty (not a blank screen)
- [ ] Write operations queue when offline and sync when reconnected
- [ ] Network status indicator when operating in degraded state
- [ ] Sync conflict resolution strategy defined (last-write-wins vs manual merge)

## Push Notifications

- [ ] Push notification permission request triggered by user action (not on launch — permission request on app open gets denied most of the time)
- [ ] Permission request preceded by rationale ("Enable notifications to get reminders about X")
- [ ] Notification payload handling when app is in foreground / background / killed
- [ ] Deep link from notification to relevant in-app screen
- [ ] Notification preferences screen (allow user to control what they receive)
- [ ] Unsubscribe path that actually works

## Crash Reporting

- [ ] Crash reporting SDK installed (Sentry, Firebase Crashlytics, etc.)
- [ ] Session recording or breadcrumbs (what the user did before the crash)
- [ ] Non-fatal error logging (not just crashes — network failures, API errors)
- [ ] Alert on crash rate exceeding threshold

## Analytics

- [ ] Screen view tracking (which screens are used)
- [ ] Key event tracking (sign up, purchase, feature activated)
- [ ] Funnel analysis for onboarding (where users drop off)
- [ ] Crash-free session rate (target: > 99.5%)
- [ ] Retention (D1, D7, D30)

## Deep Linking

- [ ] Universal Links (iOS) / App Links (Android) configured
- [ ] All deep link routes handled (including app not installed → App Store)
- [ ] Email links open in-app (not mobile browser)

## In-App Review Prompt

- [ ] Prompt triggered after a positive user action (task completed, level passed, successful purchase) — not on app open or at arbitrary time
- [ ] Never prompt if the user has already reviewed the app
- [ ] Native review API used (not a custom dialog that routes to App Store — violates guidelines)

## App Store Assets

- [ ] App icon (all required sizes, no text in icon per Apple guidelines)
- [ ] Screenshots: 6.5" iPhone, 5.5" iPhone, 12.9" iPad (iOS); various Android sizes
- [ ] Screenshots show the actual product, not generic marketing graphics
- [ ] App Store description: lead with key value proposition, mention core features, include keywords
- [ ] Keywords field (iOS App Store): 100 chars, comma-separated, no spaces after commas
- [ ] What's New section prepared for v1.0 release

## TestFlight / Play Console Beta

- [ ] Internal testing build before external beta
- [ ] External beta with at least 20 real users before App Store submission
- [ ] Beta feedback loop established (how do testers report issues?)

## Performance

- [ ] App launch time < 2s on mid-range device
- [ ] Scroll performance 60fps on list views (no jank)
- [ ] Images cached and lazy loaded
- [ ] No memory leaks on repeated navigation (verify with Instruments / Android Profiler)

## Key Rules

- Sign in with Apple is required if any social login is offered on iOS — App Store rejection otherwise
- Biometric auth stores the token in Keychain/Keystore — not AsyncStorage
- Push permission should never be requested on first app launch — rejection rate > 70%
- In-app review prompt must use the native API (not a custom dialog linking to the store)
- Crash-free rate should be monitored from day one — a crash-rate spike in the first week can tank reviews
