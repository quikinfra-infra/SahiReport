# SahiReport — Android & iOS Native Platform Updates Documentation

This document provides a comprehensive, step-by-step record of all changes made to the native **Android** and **iOS** codebases for the SahiReport mobile application. These updates address app store compliance (Google Play & Apple App Store review guidelines), security hardening, production crash prevention, and deep linking infrastructure.

---

## Part 1: Android Platform Updates

### 1. `android/app/src/main/AndroidManifest.xml`

#### A. Removal of Background Location Permission
* **File:** `android/app/src/main/AndroidManifest.xml`
* **Change:** Removed `<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>`.
* **Rationale:** 
  - Google Play policy strictly mandates that any application declaring `ACCESS_BACKGROUND_LOCATION` must submit video proof and extensive declaration forms justifying why the app needs continuous location access when closed or minimized.
  - SahiReport only captures GPS coordinates when a field engineer explicitly submits a Daily Progress Report (foreground execution).
  - Retaining this permission without continuous background tracking guarantees immediate app rejection or suspension during Google Play Store review.
* **Resulting Permissions:**
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
  <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  ```

#### B. Firebase Cloud Messaging (FCM) Default Notification Channel & Icon
* **Change:** Added default notification channel and icon metadata under `<application>`.
* **Code Added:**
  ```xml
  <!-- Default notification channel for Firebase Cloud Messaging -->
  <meta-data
      android:name="com.google.firebase.messaging.default_notification_channel_id"
      android:value="sahi_report_submissions" />
  <meta-data
      android:name="com.google.firebase.messaging.default_notification_icon"
      android:resource="@mipmap/ic_launcher" />
  ```
* **Rationale:**
  - Android 8.0+ (API 26+) requires all push notifications to be assigned to a valid `NotificationChannel`.
  - When the app is in the background or killed, the Android system handles FCM notifications using these metadata keys.
  - The channel ID `sahi_report_submissions` matches the channel created in `NotificationService.dart` and dispatched by the `send-notification` Supabase Edge Function.

#### C. Deep Linking Intent Filters (URL Schemes)
* **Change:** Added intent filters for custom schemes `fieldtrack://` and `sahireport://` under `<activity android:name=".MainActivity">`.
* **Code Added:**
  ```xml
  <!-- Deep Linking for Authentication, Email Confirmation & Passwords -->
  <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="fieldtrack" />
  </intent-filter>
  <intent-filter android:autoVerify="true">
      <action android:name="android.intent.action.VIEW" />
      <category android:name="android.intent.category.DEFAULT" />
      <category android:name="android.intent.category.BROWSABLE" />
      <data android:scheme="sahireport" />
  </intent-filter>
  ```
* **Rationale:**
  - Allows Supabase Auth confirmation links, OTP verification callbacks, and password reset redirects (`fieldtrack://reset-password` and `sahireport://confirm-email`) to seamlessly re-open the app on Android devices.

#### D. Android 11+ (API 30+) Package Visibility Queries
* **Change:** Added explicit `<queries>` intent filters for URLs, emails, and phone calls.
* **Code Added:**
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.PROCESS_TEXT"/>
          <data android:mimeType="text/plain"/>
      </intent>
      <!-- Required for image picker camera capture -->
      <intent>
          <action android:name="android.media.action.IMAGE_CAPTURE"/>
      </intent>
      <!-- Required for url_launcher (web links, emails, phone calls) on Android 11+ -->
      <intent>
          <action android:name="android.intent.action.VIEW"/>
          <data android:scheme="https"/>
      </intent>
      <intent>
          <action android:name="android.intent.action.SENDTO"/>
          <data android:scheme="mailto"/>
      </intent>
      <intent>
          <action android:name="android.intent.action.DIAL"/>
          <data android:scheme="tel"/>
      </intent>
  </queries>
  ```
* **Rationale:**
  - On Android 11 and later, apps cannot query external applications by default.
  - Without these declarations, calls to `launchUrl()` for privacy policy pages, support emails (`mailto:support@fieldtrack.in`), and owner support calls (`tel:...`) will silently fail with `ActivityNotFoundException`.

---

### 2. `android/app/build.gradle.kts`

* **File:** `android/app/build.gradle.kts`
* **Change:** Configured ProGuard/R8 code shrinking rules for release builds.
* **Code Diff:**
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("debug")
          proguardFiles(
              getDefaultProguardFile("proguard-android-optimize.txt"),
              "proguard-rules.pro"
          )
      }
  }
  ```
* **Rationale:**
  - Ensures release builds (`flutter build apk --release` / `flutter build appbundle --release`) link the custom rules file preventing runtime crashes caused by reflection stripping.

---

### 3. `android/app/proguard-rules.pro`

* **File:** `android/app/proguard-rules.pro` *(New File)*
* **Contents:**
  ```proguard
  # ── SahiReport: ProGuard & R8 Configuration ───────────────────

  # Flutter Wrapper
  -keep class io.flutter.app.** { *; }
  -keep class io.flutter.plugin.**  { *; }
  -keep class io.flutter.util.**  { *; }
  -keep class io.flutter.view.**  { *; }
  -keep class io.flutter.** { *; }
  -keep class io.flutter.plugins.**  { *; }

  # Razorpay Flutter SDK
  -keepattributes *Annotation*
  -dontwarn com.razorpay.**
  -keep class com.razorpay.** {*;}
  -optimizations !method/inlining/
  -keepclasseswithmembers class * {
    public void onPayment*(...);
  }
  -keepclassmembers class * {
      @android.webkit.JavascriptInterface <methods>;
  }

  # Google Mobile Ads (AdMob)
  -keep public class com.google.android.gms.ads.** {
     public *;
  }
  -keep public class com.google.ads.** {
     public *;
  }

  # Firebase & Google Play Services
  -keep class com.google.firebase.** { *; }
  -dontwarn com.google.firebase.**

  # SQLite / SQLCipher
  -keep class sqlcipher.** { *; }
  -dontwarn sqlcipher.**
  ```
* **Rationale:**
  - Razorpay uses Android WebViews with JavaScript interfaces (`@JavascriptInterface`). If obfuscated or stripped by R8, payment sheets crash immediately upon launch or fail to fire success/failure callbacks.
  - AdMob and Firebase require reflection on internal descriptors which must be preserved in release builds.

---

## Part 2: iOS Platform Updates

### 1. `ios/Runner/Info.plist`

#### A. Removal of `NSLocationAlwaysAndWhenInUseUsageDescription`
* **File:** `ios/Runner/Info.plist`
* **Change:** Removed the `NSLocationAlwaysAndWhenInUseUsageDescription` key-value block.
* **Rationale:**
  - Under Apple App Store Review Guideline 5.1.5, requesting background location access ("Always") without a continuous background location entitlement (e.g., GPS turn-by-turn navigation, fitness tracking) leads to automated App Store rejection.
  - SahiReport only stamps GPS coordinates at the moment a report photo is captured.
  - Retained `NSLocationWhenInUseUsageDescription` which accurately describes foreground location usage.

#### B. Application Name Alignment
* **Change:** Updated `CFBundleName` from placeholder `dpr_version_1` to `SahiReport`.
* **Rationale:**
  - Eliminates inconsistencies between internal bundle name and the display title (`CFBundleDisplayName`), ensuring proper naming in system dialogs, Spotlight, and permission prompts.

#### C. Custom URL Schemes (`CFBundleURLTypes`)
* **Change:** Added `CFBundleURLTypes` array for `fieldtrack` and `sahireport`.
* **Code Added:**
  ```xml
  <!-- ── DEEP LINKING URL SCHEMES ── -->
  <key>CFBundleURLTypes</key>
  <array>
      <dict>
          <key>CFBundleTypeRole</key>
          <string>Editor</string>
          <key>CFBundleURLName</key>
          <string>com.sahireport.app</string>
          <key>CFBundleURLSchemes</key>
          <array>
              <string>fieldtrack</string>
              <string>sahireport</string>
          </array>
      </dict>
  </array>
  ```
* **Rationale:**
  - Registers the app as the handler for `fieldtrack://` and `sahireport://` URLs on iOS devices.
  - When a user taps a Supabase email confirmation link or password reset link on Safari/Mail, iOS routes the event directly into `AppRouter.dart`.

#### D. Google AdMob SKAdNetwork Identifiers
* **Change:** Expanded `SKAdNetworkItems` with Google's recommended ad network identifiers.
* **Identifiers Added:**
  - `cstr6suwn9.skadnetwork` (Google)
  - `4fzdc2evr5.skadnetwork`
  - `2fnua5tdw4.skadnetwork`
  - `ydx93a7ass.skadnetwork`
  - `p78axxw29g.skadnetwork`
  - `v72qych544.skadnetwork`
  - `ludvb6z3bs.skadnetwork`
  - `cp8zw746q7.skadnetwork`
  - `c6k4g5qg8m.skadnetwork`
  - `s39g8k73mm.skadnetwork`
  - `3qy4746246.skadnetwork`
  - `3sh42y64q3.skadnetwork`
  - `f38h382jwy.skadnetwork`
  - `mlmmfzh3r3.skadnetwork`
  - `wg4vffrq83.skadnetwork`
  - `gta9lk7p23.skadnetwork`
  - `w9fl98au8r.skadnetwork`
* **Rationale:**
  - Required by Apple's App Tracking Transparency (ATT) framework on iOS 14.5+.
  - Enables conversion tracking and revenue monetization for AdMob banner ads on free-tier accounts.

---

### 2. `ios/Podfile`

* **File:** `ios/Podfile`
* **Change:** Fixed typo in CocoaPods build settings from `GCC_PREPROCESSOR_definitions` to `GCC_PREPROCESSOR_DEFINITIONS` (uppercase).
* **Code Diff:**
  ```ruby
  post_install do |installer|
    installer.pods_project.targets.each do |target|
      flutter_additional_ios_build_settings(target)

      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'

        # Enable required permissions for permission_handler on iOS
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
          '$(inherited)',
          'PERMISSION_CAMERA=1',
          'PERMISSION_PHOTOS=1',
          'PERMISSION_LOCATION=1',
          'PERMISSION_NOTIFICATIONS=1',
        ]
      end
    end
  end
  ```
* **Rationale:**
  - Xcode requires uppercase for `GCC_PREPROCESSOR_DEFINITIONS`.
  - When lowercase `definitions` was used, Xcode ignored the macro definitions, causing `permission_handler` to disable camera and location permission handling at compile-time on iOS.

---

## Part 3: Verification & Build Instructions

### For Android:
1. Clean and fetch dependencies:
   ```bash
   flutter clean
   flutter pub get
   ```
2. Build debug APK to verify compilation:
   ```bash
   flutter build apk --debug
   ```
3. Build production Android App Bundle (AAB) for Google Play Store upload:
   ```bash
   flutter build appbundle --release
   ```

### For iOS:
1. Install CocoaPods:
   ```bash
   cd ios
   pod install --repo-update
   cd ..
   ```
2. Build iOS release IPA / archive:
   ```bash
   flutter build ipa --release
   ```
