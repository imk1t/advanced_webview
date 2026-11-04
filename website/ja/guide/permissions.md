# 権限

ページはカメラ、マイク、位置情報を要求できます。WebView が自動で許可することはないので、
`onPermissionRequest` で判断します。

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

コールバックは `async` にもできます。同時に要求されたリソース（たとえば 1 回の `getUserMedia` でのカメラとマイク）は、
まとめて許可または拒否されます。コールバックがない場合や例外を投げた場合は、両 OS ですべて拒否します。

## アプリ側の権限

許可しても、ページが使えるのはアプリ自身が使える範囲だけです。アプリ側での宣言も必要です。

**Android.** `android/app/src/main/AndroidManifest.xml` に、ページが必要とする権限を宣言します。

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

コールバックが許可した後、アプリがまだ権限を持っていなければ、プラグインが Android の実行時権限をユーザーに要求します。
ユーザーが拒否した場合、ページの要求も拒否されます。保護メディアと MIDI の要求は常に拒否されます。

**iOS.** `ios/Runner/Info.plist` に利用目的の説明を追加します。
`NSCameraUsageDescription`、`NSMicrophoneUsageDescription`、位置情報なら `NSLocationWhenInUseUsageDescription` です。
システムのダイアログは WebKit が表示します。

## 位置情報

`PermissionResource.geolocation` が通知されるのは **Android のみ**です。WebKit には `navigator.geolocation` 用の
デリゲートがなく、iOS ではアプリの位置情報権限をもとに WebKit 自身がユーザーに確認するため、
`onPermissionRequest` は呼ばれません。

## 信頼境界

`origin` は要求したフレームについて WebView が報告する値なので、iframe の origin が許可対象になることがあります。
origin ごとに判断し、信頼できないコンテンツを読み込む WebView で広く許可しないでください。
