#
# please run `pod_check.sh` to ensure this is a valid spec before submitting.
# ensure built xcframework, this podspec and corresponding tag are pushed ti orig
# submitting 'pod_push.sh'
#
Pod::Spec.new do |s|
  s.name             = 'YbridPlayerSDK'
  s.version          = '0.6.2'
  s.summary          = 'Audio player SDK for iOS and macOS.'
  s.description      = <<-DESC
Audio player SDK written in Swift supports audio codecs mp3, acc and opus.
This XCFramework runs on iOS devices and simulators (version 9 to 14) and
on macOS (versions 10.10 to 11.2).
                       DESC
  s.homepage         = 'https://github.com/ybrid/player-sdk-swift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Florian Nowotny' => 'Florian.Nowotny@nacamar.de' }
  s.source           = { :git => 'git@github.com:ybrid/player-sdk-swift.git', :tag => s.version.to_s }

  s.swift_version = '4.0'
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.10'
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

  ## helpful for development pods, but submitting fails
  s.source_files = 'player-sdk-swift/**/*.{swift}'
  s.module_name = 'YbridPlayerSDK'

  # s.framework    = 'YbridPlayerSDK'
  # s.vendored_frameworks = 'YbridPlayerSDK.xcframework'

  s.dependency 'YbridOgg'#, '0.7.2'
  s.dependency 'YbridOpus'#, '0.7.0'
end
