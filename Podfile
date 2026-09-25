source 'https://cdn.cocoapods.org/'

platform :ios, '18.0'
inhibit_all_warnings!
use_modular_headers!

target 'iBurn' do
	# The tests run inside the app (TEST_HOST), which already links every pod. Linking them
	# into the test bundle a second time duplicated each class ("Class X is implemented in
	# both iBurn.debug.dylib and the test bundle"); search paths are all the tests need.
	target 'iBurnTests' do
		inherit! :search_paths
	end

	pod 'Anchorage'

	pod 'CocoaLumberjack/Swift', '~> 3.10'
	pod 'FormatterKit/LocationFormatter', '~> 1.8'
	pod 'FormatterKit/TimeIntervalFormatter', '~> 1.8'
	pod 'PureLayout', '~> 3.0'
	pod 'BButton', '~> 4.0'
	pod 'LicensePlist', '~> 3.28'
	pod 'TTTAttributedLabel', '~> 2.0'
	pod 'Appirater', '~> 2.0'
	pod 'CupertinoYankee', '~> 1.0'
	pod 'DOFavoriteButton', :path => 'Submodules/DOFavoriteButton/DOFavoriteButton.podspec'
	pod 'TUSafariActivity', '~> 1.0'
	pod 'KVOController', '~> 1.0'
	pod 'Onboard', '~> 2.1'
	pod 'PermissionScope', :path => 'Submodules/PermissionScope/PermissionScope.podspec'
	pod 'JTSImageViewController'
	# UIImageColors was replaced by Packages/PlayaColors, a CoreGraphics port shared
	# with the playa-seed tool so baked and runtime colours match.
end

# https://github.com/CocoaPods/CocoaPods/issues/8069#issuecomment-420044112
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 18.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.0'
      end
    end
  end
end
