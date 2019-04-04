platform :ios, '9.0'

inhibit_all_warnings!
use_frameworks!

target 'PlayaKit' do
	pod 'CocoaLumberjack/Swift'
	# pod 'YapDatabase', '3.1.1'
	pod 'YapDatabase', :git => 'https://github.com/yapstudios/YapDatabase.git', :branch => 'master'
	target 'PlayaKitTests'
end 

target 'iBurn' do
	target 'iBurnTests'

	pod 'Anchorage'

	# Debugging
	pod 'Swizzlean', :configurations => ['Debug']

	pod 'Mapbox-iOS-SDK', '~> 4.0'
	# pod 'Mapbox-iOS-SDK-symbols', :path => 'Submodules/Mapbox-Pod/dynamic/Mapbox-iOS-SDK-symbols.podspec'
	# pod 'Mapbox-iOS-SDK', :podspec => "https://raw.githubusercontent.com/mapbox/mapbox-gl-native/ios-v4.3.0-beta.1/platform/ios/Mapbox-iOS-SDK.podspec"
	#pod 'YapDatabase', '3.1.1'
	pod 'YapDatabase', :git => 'https://github.com/yapstudios/YapDatabase.git', :branch => 'master'

	pod 'CocoaLumberjack/Swift'
	pod 'Mantle', '~> 2.0'
	pod 'FormatterKit/LocationFormatter', '~> 1.8'
	pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8'
	pod 'PureLayout', '~> 3.0'
	pod 'DAKeyboardControl', '~> 2.4'
	pod 'BButton', '~> 4.0'
	pod 'VTAcknowledgementsViewController', '~> 1.0'
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
	pod 'UIImageColors', '~> 2.1'
	pod 'Fabric'
	pod 'Crashlytics'
end
