// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Swift Package Manager manifest. CocoaPods builds the same sources through
// ../flutter_mobile_webview.podspec; keep the platform version, sources and
// resources of the two in sync.

import PackageDescription

let package = Package(
  name: "flutter_mobile_webview",
  platforms: [
    .iOS("18.0")
  ],
  products: [
    .library(name: "flutter-mobile-webview", targets: ["flutter_mobile_webview"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "flutter_mobile_webview",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      resources: [
        // Keep in sync with `resource_bundles` in ../flutter_mobile_webview.podspec.
        .process("Resources")
      ]
    )
  ]
)
