# Permissions

Pages can ask for the camera, the microphone and the user's location. The WebView never allows
this on its own: decide in `onPermissionRequest`.

```dart
final controller = AdvancedWebViewController(
  onPermissionRequest: (request) {
    // request.origin: 'https://example.com'
    // request.resources: [PermissionResource.camera, PermissionResource.microphone]
    final trusted = request.origin == 'https://example.com';
    return trusted ? PermissionDecision.grant : PermissionDecision.deny;
  },
);
```

The callback may be `async`. Resources asked for together (for example camera and microphone in one
`getUserMedia` call) are granted or denied together. Without a callback, and when the callback
throws, every request is denied on both platforms.

## App-level permissions

Granting only lets the page use what the app itself may use. You still declare the permission in
the app.

**Android.** Declare what the page may need in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

After your callback grants a request, the plugin asks the user for the matching Android runtime
permission if the app does not hold it yet. If the user refuses, the page's request is denied.
Protected media and MIDI requests are always denied.

**iOS.** Add the usage descriptions to `ios/Runner/Info.plist`:
`NSCameraUsageDescription`, `NSMicrophoneUsageDescription` and, for location,
`NSLocationWhenInUseUsageDescription`. WebKit shows the system prompt itself.

## Geolocation

`PermissionResource.geolocation` is reported on **Android only**. WebKit has no delegate for
`navigator.geolocation`; on iOS it asks the user itself, based on the app's location permission, and
`onPermissionRequest` is not called.

## Trust boundary

`origin` is reported by the WebView for the frame that asked, so a granted origin may be an iframe.
Decide per origin, and do not grant broadly in a WebView that loads untrusted content.
