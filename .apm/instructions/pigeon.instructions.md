---
description: Rules for editing the Pigeon platform contract and its generated code
applyTo: "{pigeons/**,**/*.g.dart,**/Messages.g.kt,**/Messages.g.swift}"
---
- `pigeons/messages.dart` is the only definition of the Dart <-> native contract.
- Never hand-edit `messages.g.dart`, `Messages.g.kt` or `Messages.g.swift`.
  After changing `pigeons/messages.dart`, run `dart run pigeon --input pigeons/messages.dart`
  and commit the regenerated files in the same change.
- Every API takes `webViewId` as its first argument; keep a single HostApi / FlutterApi pair.
- Mark host methods `@async` when the native side must await (Kotlin `suspend`, Swift `async`).
- Do not use field names that clash with `NSObject` in Swift (e.g. `description`, `hash`).
- After regenerating, update both `WebViewHostApiImpl.kt` and `WebViewHostApiImpl.swift`
  and the Dart controller, then extend `test/fake_host_api.dart`.
