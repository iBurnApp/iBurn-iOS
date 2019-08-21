source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
inhibit_all_warnings!

target 'PlayaKitTests' do
	pod 'CocoaLumberjack/Swift'
	pod 'YapDatabase', :modular_headers => true
end 

target 'iBurn' do
	target 'iBurnTests'

	pod 'Anchorage'

	pod 'Mapbox-iOS-SDK', '~> 5.0'
	pod 'YapDatabase', :modular_headers => true

	pod 'CocoaLumberjack/Swift'
	pod 'Mantle', '~> 2.0', :modular_headers => true
	pod 'FormatterKit/LocationFormatter', '~> 1.8', :modular_headers => true
	pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8', :modular_headers => true
	pod 'PureLayout', '~> 3.0', :modular_headers => true
	pod 'DAKeyboardControl', '~> 2.4'
	pod 'BButton', '~> 4.0', :modular_headers => true
	pod 'VTAcknowledgementsViewController', '~> 1.0', :modular_headers => true
	pod 'TTTAttributedLabel', '~> 2.0', :modular_headers => true
	pod 'Appirater', '~> 2.0'
	pod 'CupertinoYankee', '~> 1.0'
	pod 'DOFavoriteButton', :path => 'Submodules/DOFavoriteButton/DOFavoriteButton.podspec'
	pod 'TUSafariActivity', '~> 1.0'
	pod 'ASDayPicker', :path => 'Submodules/ASDayPicker/ASDayPicker.podspec', :modular_headers => true
	pod 'KVOController', '~> 1.0'
	pod 'Onboard', '~> 2.1', :modular_headers => true
	pod 'PermissionScope', :path => 'Submodules/PermissionScope/PermissionScope.podspec'
	pod 'JTSImageViewController', :modular_headers => true
	pod 'UIImageColors', '~> 2.1'
	pod 'Fabric'
	pod 'Crashlytics'
	pod 'GRDB.swift'
end

# https://github.com/CocoaPods/CocoaPods/issues/8069#issuecomment-420044112
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 8.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '8.0'
      end
    end
  end
end
