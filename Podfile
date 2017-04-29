platform :ios, '8.0'

inhibit_all_warnings!
use_frameworks!

abstract_target 'iBurnAbstract' do
	target 'iBurn'
	target 'iBurnTests'

	# Debugging
	pod 'Swizzlean'

	# Gotta use fork now because it's deprecated
	pod 'Mapbox-iOS-SDK', :path => 'Submodules/mapbox-ios-sdk/Mapbox-iOS-SDK.podspec'
	# pod 'YapDatabase', '~> 2.6'
	pod 'CocoaLumberjack/Swift', '~> 3.1.0'
	pod 'YapDatabase', :git => 'https://github.com/ChatSecure/YapDatabase.git', :branch => 'cocoalumberjack3'
	pod 'Mantle', '~> 2.0'
	pod 'FormatterKit/LocationFormatter', '~> 1.8'
	pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8'
	pod 'HockeySDK-Source', '~> 4.1.4'
	pod 'PureLayout', '~> 3.0'
	pod 'DAKeyboardControl', '~> 2.4'
	pod 'BButton', '~> 4.0'
	pod 'VTAcknowledgementsViewController', '~> 1.0'
	pod 'TTTAttributedLabel', '~> 2.0'
	pod 'Appirater', '~> 2.0'
	pod 'CupertinoYankee', '~> 1.0'
	pod 'pop', '~> 1.0'
	pod 'Parse', '~> 1.0'
	pod 'DOFavoriteButton', :git => 'https://github.com/okmr-d/DOFavoriteButton.git'
	pod 'JSQWebViewController', '~> 5.0'
	pod 'TUSafariActivity', '~> 1.0'
	pod 'ASDayPicker', :path => 'Submodules/ASDayPicker/ASDayPicker.podspec'
	pod 'KVOController', '~> 1.0'
	pod 'Onboard', '~> 2.1'
	pod 'PermissionScope', '~> 1.0'
	pod 'JTSImageViewController'
	pod 'proj4', :podspec => 'https://raw.githubusercontent.com/Burning-Man-Earth/proj4.podspec/master/proj4.podspec'

end