require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.cocoapods_version   = '>= 1.10.0'
  s.name                = 'RNBackgroundLocation'
  s.version             = package['version']
  s.summary             = package['description']
  s.description         = <<-DESC
    Cross-platform background location tracking for React Native.
    Transistorsoft-style implementation with LOCKING, batch sync, and autoSync.
  DESC
  s.homepage            = package['homepage'] || 'https://github.com/yourname/react-native-background-location'
  s.license             = package['license']
  s.authors             = { 'Your Name' => 'your.email@example.com' }
  s.source              = { :git => 'https://github.com/yourname/react-native-background-location.git', :tag => s.version }
  s.platform            = :ios, '11.0'

  s.dependency 'React-Core'
  s.static_framework = true
  
  # Objective-C + Swift dosyaları (iOS 17+ batarya optimizasyonu için)
  s.source_files        = 'ios/**/*.{h,m,swift}'
  s.public_header_files = 'ios/**/*.h'
  
  # Swift header'ının generate edilmesi için gerekli ayarlar
  # iOS 17+ batarya optimizasyonu için CLLocationUpdate.liveUpdates() kullanılıyor
  s.swift_version = '5.0'
  s.pod_target_xcconfig = {
    'SWIFT_VERSION' => '5.0',
    'DEFINES_MODULE' => 'YES',
    'SWIFT_OBJC_INTERFACE_HEADER_NAME' => 'RNBackgroundLocation-Swift.h',
    'SWIFT_OBJC_BRIDGING_HEADER' => '',
    'CLANG_ENABLE_MODULES' => 'YES'
  }
  
  s.libraries           = 'sqlite3', 'z'
  s.frameworks          = 'CoreLocation', 'CoreMotion', 'SystemConfiguration', 'UIKit', 'UserNotifications'
  
  s.requires_arc = true
end

