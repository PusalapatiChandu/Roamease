# RoamEase – Smart Mobile Roaming & Location Management System

**RoamEase** is a modern, responsive, high-performance mobile telecommunications application built with Flutter, Dart, Firebase, and Android Native Telephony APIs. It empowers mobile subscribers to register their SIM and terminal device, monitor live 5G/4G network performance, and manage geographical location and roaming routes transparently while travelling.

---

## 📱 System Modules & Architecture

```
                                  +------------------------------------+
                                  |         RoamEase Application       |
                                  +------------------------------------+
                                                    |
       +--------------------------------------------+--------------------------------------------+
       |                                            |                                            |
+---------------+                           +----------------+                           +----------------+
|   Module 1:   |                           |   Module 2:    |                           |   Module 3:    |
|  Subscriber   |                           |   5G Network   |                           |   Subscriber   |
| Registration  |                           |   Management   |                           |    Location    |
+---------------+                           +----------------+                           +----------------+
| - Legal Name  |                           | - 5G/4G Detect |                           | - GPS Fix      |
| - Mobile Num  |                           | - dBm Meter    |                           | - Google Maps  |
| - Carrier Op  |                           | - Speed Test   |                           | - Geo Reverse  |
| - 4G/5G SIM   |                           | - 5G vs 4G     |                           | - Track Toggle |
| - Device ID   |                           | - fl_chart     |                           | - Waypoints    |
| - GPS Consent |                           | - Weak Alert   |                           | - Cell Towers  |
+---------------+                           +----------------+                           +----------------+
       |                                            |                                            |
       +--------------------------------------------+--------------------------------------------+
                                                    |
                                    +-------------------------------+
                                    |    Cloud Firestore & Auth     |
                                    +-------------------------------+
                                    | - subscribers                 |
                                    | - location_history            |
                                    | - network_history             |
                                    | - user_settings               |
                                    +-------------------------------+
```

---

## 🚀 Key Features

### 1. Subscriber Registration Module
- **Comprehensive Profile Setup:** Full Legal Name, Mobile Number, Email Address, Password with verification.
- **Carrier & SIM Detection:** Mobile network operator dropdown (Reliance Jio, Bharti Airtel, Vi, AT&T, Verizon, T-Mobile, etc.) and SIM generation selection (5G NR / 4G LTE).
- **Auto Device Discovery:** Auto-detects device hardware model via native device telemetry (`device_info_plus`).
- **Transparent GPS Consent:** Strict consent terms checkbox to ensure location tracking is 100% consent-based and transparent.
- **Account Lifecycle:** Secure Login, Password Reset, Profile Editing, and Account Deletion with complete Firestore record purge.

### 2. 5G Network Management Module
- **Verified Telephony Telemetry:** Native Android `TelephonyManager` MethodChannel queries real radio cell status without mock data.
- **Signal Quality Gauge:** Real-time dBm signal power, ASU level, and 4-bar indicator categorized as Excellent, Good, Fair, or Poor.
- **Edge Speed Test Engine:** Real download and upload speed measurement powered by high-capacity CDN test nodes with live ping latency and jitter analysis.
- **4G vs 5G Performance Matrix:** Side-by-side benchmark comparison covering throughput, latency, jitter, massive MIMO, and frequency spectrum.
- **Interactive Analytics:** Real-time performance trend curves built with `fl_chart`.
- **Poor Signal Alerts:** Local and push notification triggers when signal drops below -110 dBm.

### 3. Subscriber Location Management Module
- **Real-Time GPS Coordinates:** High-accuracy latitude, longitude, altitude, bearing, and travel speed.
- **Reverse Geocoding:** Live street address, city, sub-locality, and country resolution.
- **Interactive Google Maps View:** Subscriber location pin, accuracy radius circle, normal/satellite toggle, and camera re-centering.
- **Start/Stop Tracking Controls:** Transparent tracking switch allowing subscribers to start and halt background location logging anytime.
- **Nearby Mobile Towers:** Triangulates nearby LTE eNodeB and 5G gNodeB base transceiver stations via Android `allCellInfo`.
- **Location History:** Persistent travel waypoints stored in Cloud Firestore and cached locally.

---

## 🎨 UI/UX Design Palette
- **Primary Navy / Dark Slate:** `#0F172A`, `#1E293B`, `#1E3A8A`
- **Electric Blue & 5G Cyan:** `#2563EB`, `#06B6D4`, `#38BDF8`
- **Signal Status Colors:**
  - Excellent: `#10B981` (Emerald)
  - Good: `#3B82F6` (Royal Blue)
  - Fair: `#F59E0B` (Amber)
  - Poor / Weak: `#EF4444` (Crimson)
  - Roaming Warning: `#F97316` (Orange)
- **Theme Support:** Full Light and Dark mode toggle with persistent preferences.

---

## 🔒 Firebase Security Rules (`firestore.rules`)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(userId) {
      return request.auth != null && request.auth.uid == userId;
    }
    match /subscribers/{subscriberId} {
      allow read, update, delete: if isOwner(subscriberId);
      allow create: if request.auth != null && request.auth.uid == subscriberId;
    }
    match /location_history/{historyId} {
      allow read, delete, update: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
    match /network_history/{networkId} {
      allow read, delete, update: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
    match /user_settings/{userId} {
      allow read, write: if isOwner(userId);
    }
  }
}
```

---

## 🛠️ Step-by-Step Setup & Build Instructions

### Prerequisites
1. **Flutter SDK:** Flutter 3.24+ (Dart 3.5+)
2. **Android SDK:** API Level 34 / 35 (Android 14 / 15) with Build Tools 34.0.0+
3. **Java Development Kit:** JDK 17 or JDK 21

### Step 1: Clone and Install Dependencies
```bash
cd D:\roamease
flutter pub get
```

### Step 2: Run Unit Tests
```bash
flutter test
```
All unit and model tests will execute and verify serialization, formatters, and telemetry calculations.

### Step 3: Firebase Configuration (Optional for Cloud Sync)
1. Create a Firebase project in [Firebase Console](https://console.firebase.google.com/).
2. Enable **Authentication** (Email/Password) and **Cloud Firestore**.
3. Download your `google-services.json` and place it at:
   `android/app/google-services.json`
4. Deploy security rules:
   ```bash
   firebase deploy --only firestore:rules
   ```
*(Note: If `google-services.json` is not provided, RoamEase automatically operates in local offline fallback mode, caching all subscriber data, location waypoints, and speed history in encrypted local storage).*

### Step 4: Google Maps API Key Configuration
In `android/app/src/main/AndroidManifest.xml`, replace the placeholder key:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_GOOGLE_MAPS_API_KEY" />
```

---

## 📦 Android APK Build Procedure

### Build Debug APK (For Testing on Real Smartphone):
```bash
flutter build apk --debug
```
Output path:
`build/app/outputs/flutter-apk/app-debug.apk`

### Install onto Real Android Smartphone via USB Debugging:
1. Enable **Developer Options** and **USB Debugging** on your Android smartphone.
2. Connect device via USB cable and verify connection:
   ```bash
   flutter devices
   ```
3. Run directly on device:
   ```bash
   flutter run
   ```
   Or install the built APK directly:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

### Build Production Release APK:
```bash
flutter build apk --release
```
Output path:
`build/app/outputs/flutter-apk/app-release.apk`
#   R o a m e a s e  
 