source 'https://cdn.cocoapods.org/'

platform :ios, '14.0'
inhibit_all_warnings!
use_modular_headers!

target 'PlayaKitTests' do
	pod 'CocoaLumberjack/Swift'
	pod 'YapDatabase'
end 

target 'iBurn' do
	target 'iBurnTests'

	pod 'Anchorage'

	pod 'YapDatabase'

	pod 'CocoaLumberjack/Swift'
	pod 'Mantle', '~> 2.0'
	pod 'FormatterKit/LocationFormatter', '~> 1.8'
	pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8'
	pod 'PureLayout', '~> 3.0'
	pod 'BButton', '~> 4.0'
	pod 'LicensePlist', '~> 3.24'
	pod 'TTTAttributedLabel', '~> 2.0'
	pod 'Appirater', '~> 2.0'
	pod 'CupertinoYankee', '~> 1.0'
	pod 'DOFavoriteButton', :path => 'Submodules/DOFavoriteButton/DOFavoriteButton.podspec'
	pod 'TUSafariActivity', '~> 1.0'
	pod 'ASDayPicker', :path => 'Submodules/ASDayPicker/ASDayPicker.podspec'
	pod 'KVOController', '~> 1.0'
	pod 'Onboard', '~> 2.1'
	pod 'PermissionScope', :path => 'Submodules/PermissionScope/PermissionScope.podspec'
	pod 'JTSImageViewController'
	# pod 'UIImageColors', '~> 2.1'
	pod 'UIImageColors', :git => 'https://github.com/jathu/UIImageColors.git', :tag => '2.2.0'
	pod 'GRDB.swift'
end

# https://github.com/CocoaPods/CocoaPods/issues/8069#issuecomment-420044112
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 12.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      end
    end
  end
end
