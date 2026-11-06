# Car Detector

Take or pick a photo of a car and an AI vision model tells you its **make, model, colour**, body type, approximate year range and a confidence level.

## Setup

1. Install Flutter and make sure `flutter doctor` is happy.
2. In an empty folder, create the platform scaffolding, then copy these files over it:
   ```
   flutter create car_detector
   ```
   Replace `car_detector/pubspec.yaml` and `car_detector/lib/` (`main.dart`, `car_service.dart`) with the ones from this project.
3. Install packages:
   ```
   flutter pub get
   ```
4. Get an API key from https://console.anthropic.com and run:
   ```
   flutter run --dart-define=ANTHROPIC_API_KEY=your_key_here
   ```

## Platform permissions

**Android** - add to `android/app/src/main/AndroidManifest.xml`, above `<application>`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```
(Do not add the CAMERA permission. `image_picker` opens the system camera app, and declaring CAMERA without granting it can make the camera button crash.)

## Build with GitHub (no Flutter install needed)

1. Create a **private** GitHub repository and push this folder to the `main` branch.
2. In the repo go to Settings > Secrets and variables > Actions > New repository secret. Name it `ANTHROPIC_API_KEY` and paste your key.
3. Open the Actions tab, pick "Build Android APK" and click Run workflow (it also runs on every push to `main`).
4. When the run turns green, open it and download `car-detector-apk` from the Artifacts section. Unzip it and install `app-release.apk` on your phone.

Keep the repo private: the key is baked into the APK, so never publish that APK in a public release.

**iOS** - add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to photograph cars for identification.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to pick car photos for identification.</string>
```

## Build an APK to share

```
flutter build apk --release --dart-define=ANTHROPIC_API_KEY=your_key_here
```

## Important: protect your API key

`--dart-define` keeps the key out of your source code, but it is still inside the built app and can be extracted. That is fine while you test on your own phone. Before you share the app publicly:

1. Put a small backend between the app and the AI (a Cloudflare Worker, Render web service, Firebase Function, etc.) that holds the key and forwards the request.
2. Run the app with `--dart-define=API_ENDPOINT=https://your-backend.example.com/identify`.

## How it works

1. `image_picker` captures or selects a photo (resized to 1280px to keep uploads fast).
2. `CarService` base64-encodes it and sends it, with a strict JSON-only prompt, to the vision model.
3. The reply is parsed into a `CarResult` and shown in a card.

## Ideas to extend

- Save a history of scanned cars locally (sqflite / Hive).
- Add number-plate reading and an RTO state lookup.
- Show price range and specs for the detected model.
- Real-time camera mode that scans every few seconds.

## Accuracy tips

Side-on or three-quarter views in daylight work best. Rare, heavily modified or partly hidden cars may come back with low confidence, and the model can confuse near-identical variants (for example, facelifts), so treat results as a strong guess rather than a certainty.
