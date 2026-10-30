#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint advanced_webview.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'advanced_webview'
  s.version          = '0.0.1'
  s.summary          = 'A lean, type-safe WebView plugin for Android and iOS.'
  s.description      = <<-DESC
A lean, type-safe WebView plugin for Android and iOS.
                       DESC
  s.homepage         = 'https://github.com/imk1t/advanced_webview'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'imk1t' => 'https://github.com/imk1t' }
  s.source           = { :path => '.' }
  # CocoaPods and Swift Package Manager (advanced_webview/Package.swift)
  # build the same sources; keep the platform version, sources and resources of
  # the two in sync.
  s.source_files = 'advanced_webview/Sources/advanced_webview/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '18.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.resource_bundles = {
    'advanced_webview_privacy' => ['advanced_webview/Sources/advanced_webview/Resources/PrivacyInfo.xcprivacy']
  }
end
