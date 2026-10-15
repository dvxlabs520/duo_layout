#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint duo_layout.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'duo_layout'
  s.version          = '0.1.0'
  s.summary          = 'Lays out Flutter apps for iPhone Duo from UIKit reserved regions and UIHinge.'
  s.description      = <<-DESC
Streams UIKit's reserved regions, side bar regions and hinge state (iOS 27.1 SDK) to Flutter.
                       DESC
  s.homepage         = 'https://github.com/david2701/duo_layout'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = 'DvxLabs'
  s.source           = { :path => '.' }
  s.source_files = 'duo_layout/Sources/duo_layout/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'duo_layout_privacy' => ['duo_layout/Sources/duo_layout/PrivacyInfo.xcprivacy']}
end
