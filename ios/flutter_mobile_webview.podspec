#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_mobile_webview.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_mobile_webview'
  s.version          = '0.0.1'
  s.summary          = 'A lean, type-safe WebView plugin for Android and iOS.'
  s.description      = <<-DESC
A lean, type-safe WebView plugin for Android and iOS.
                       DESC
  s.homepage         = 'https://github.com/imk1t/flutter_mobile_webview'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'imk1t' => 'https://github.com/imk1t' }
  s.source           = { :path => '.' }
  # CocoaPods and Swift Package Manager (flutter_mobile_webview/Package.swift)
  # build the same sources; keep the platform version, sources and resources of
  # the two in sync.
  s.source_files = 'flutter_mobile_webview/Sources/flutter_mobile_webview/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '18.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'flutter_mobile_webview_privacy' => ['flutter_mobile_webview/Sources/flutter_mobile_webview/Resources/PrivacyInfo.xcprivacy']
  }
end
