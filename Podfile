platform :ios, '9.0'

inhibit_all_warnings!
use_frameworks!

abstract_target 'PlayaKitAbstract' do
	target 'PlayaKit'
	target 'PlayaKitTests'
	pod 'CocoaLumberjack/Swift', '~> 3.4.1'
	pod 'YapDatabase', '~> 3.0'
end 

abstract_target 'iBurnAbstract' do
	target 'iBurn'
	target 'iBurnTests'

	# Debugging
	pod 'Swizzlean', :configurations => ['Debug']

	pod 'Mapbox-iOS-SDK', '~> 4.0'
	pod 'YapDatabase', '~> 3.0'
	pod 'CocoaLumberjack/Swift', '~> 3.4.1'
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
	pod 'UIImageColors', '~> 2.0.0'
end
