# [iBurn-iOS](https://github.com/iBurnApp/iBurn-iOS)

[![Build Status](https://travis-ci.org/iBurnApp/iBurn-iOS.svg?branch=master)](https://travis-ci.org/iBurnApp/iBurn-iOS)

iBurn is an offline map and guide for the [Burning Man](http://www.burningman.com) art festival. Following the 2014 rewrite, the 2015 release has been updated for iOS 8 and we're starting to write new code in Swift. We decided to use [YapDatabase](https://github.com/yaptv/YapDatabase)+[Mantle](https://github.com/Mantle/Mantle) instead of Core Data, and [Mapbox](https://github.com/mapbox/mapbox-ios-sdk) instead of MapKit for our [offline map tiles](https://github.com/iBurnApp/iBurn-Maps). For a more complete list check out our `Podfile`. For users of Android devices, we also develop a version of [iBurn for Android](https://github.com/iBurnApp/iBurn-Android).

[![iBurn App Store Link](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://itunes.apple.com/us/app/iburn-2013-burning-man-map/id388169740?mt=8) [![iBurn Google Play Store Link](http://developer.android.com/images/brand/en_generic_rgb_wo_45.png)](https://play.google.com/store/apps/details?id=com.gaiagps.iburn&hl=en)

## Screenshots

![Screenshot 1](http://i.imgur.com/wmHHgiYl.jpg) ![Screenshot 2](http://i.imgur.com/39IHGN0l.jpg)

## Installation

* Install [Cocoapods](http://cocoapods.org) and the most recent version of Xcode.
* Fetch submodules and install Pods.

```
$ git clone https://github.com/iBurnApp/iBurn-iOS.git
$ cd iBurn-iOS/
$ git submodule update --init
$ pod install
```
    
* Download camp data from PlayaEvents (we can't ship ours due to BMorg's location data embargo)

```
$ curl -o ./Submodules/iBurn-Data/data/2015/2015/camps.json.js http://playaevents.burningman.org/api/0.2/2015/camp/
```

* open `iBurn.xcworkspace` (**not** the .xcodeproj file!)
* Create `BRCSecrets.m` and fill it with the following contents:

	```obj-c
	NSString * const kBRCHockeyBetaIdentifier = @"";
	NSString * const kBRCHockeyLiveIdentifier = @"";
	// To generate new passcode (without salt):
	// $ echo -n passcode | sha256sum
	NSString * const kBRCEmbargoPasscodeSHA256Hash = @"";
	NSString * const kBRCUpdatesURLString = @"";
	NSString * const kBRCMapBoxStyleURL = @"https://example.com";
	NSString * const kBRCMapBoxAccessToken = @"";

	```
	
* Create `InfoPlistSecrets.h` and add

```obj-c
#define MAPBOX_ACCESS_TOKEN test
#define CRASHLYTICS_API_TOKEN test
```
	
or run these commands:

```
$ echo -e "NSString * const kBRCHockeyBetaIdentifier = @\"\";\nNSString * const kBRCHockeyLiveIdentifier = @\"\";\nNSString * const kBRCEmbargoPasscodeSHA256Hash = @\"\";\nNSString * const kBRCUpdatesURLString = @\"\";\n NSString * const kBRCMapBoxStyleURL = @\"https://example.com\";\nNSString * const kBRCMapBoxAccessToken = @\"\";\n" > ./iBurn/BRCSecrets.m
$ echo -e "#define MAPBOX_ACCESS_TOKEN test\n#define CRASHLYTICS_API_TOKEN test\n" > ./iBurn/InfoPlistSecrets.h
```


* Create `.env` file: (optional)

```
CRASHLYTICS_API_TOKEN=""
```

* Create `iBurn/crashlytics.sh` file: (optional)

```
"${PODS_ROOT}/Fabric/run" $CRASHLYTICS_API_TOKEN $CRASHLYTICS_BUILD_SECRET
```


* Compile and Run!

**Note**: Camp, Art and Event location data are embargoed by BMorg until the gates open each year. There isn't anything we can do about this until BMorg changes their policy. Sorry!

Fortunately, you can still run and test the app without it.

## Contributing

Thank you for your interest in contributing to iBurn! Please open up an issue on our tracker before starting work on major interface or functionality changes. The easiest place to start is the list of bugs on the [issue tracker](https://github.com/iBurnApp/iBurn-iOS/issues). Otherwise, feel free to run wild!

1. Fork the project and do your work in a feature branch.
2. Make sure everything compiles and existing functionality is not broken.
3. Open a pull request.
4. Thank you! :)

Your contributions will need to be licensed to us under the [MPL 2.0](https://www.mozilla.org/MPL/2.0/) and will be distributed under the terms of the MPL 2.0.

## Authors

* [Chris Ballinger](https://github.com/chrisballinger) - iOS Development, Map Warping
* [David Chiles](https://github.com/davidchiles) - iOS Development, Map Styling
* [David Brodsky](https://github.com/onlyinamerica) - Android Development, Map Data
* [Savannah Henderson](https://github.com/savannahjune) - Map Styling

## Attribution

* [Andrew Johnstone](http://architecturalartsguild.com/about/) - Map Data (thank you!!)
* [Andrew Johnson](http://gaiagps.appspot.com/contact) - iBurn 2009-2013
* [Icons8](http://icons8.com) - Various icons used throughout the app.
* [William Keller](http://www.wkeller.net/BRC-GPS/) - Last minute 2014 Map fixes

## License

© 2015 [Chris Ballinger](https://github.com/chrisballinger), [David Chiles](https://github.com/davidchiles)

Code: [MPL 2.0](https://www.mozilla.org/MPL/2.0/) (similar to the LGPL in terms of [copyleft](https://en.wikipedia.org/wiki/Copyleft) but more compatible with the App Store)

Data: [CC BY-SA 4.0](http://creativecommons.org/licenses/by-sa/4.0/)
