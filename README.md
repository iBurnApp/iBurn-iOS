# [iBurn-iOS](https://github.com/Burning-Man-Earth/iBurn-iOS)

[![Build Status](https://travis-ci.org/Burning-Man-Earth/iBurn-iOS.svg?branch=master)](https://travis-ci.org/Burning-Man-Earth/iBurn-iOS)

iBurn is an offline map and guide for the [Burning Man](http://www.burningman.com) art festival. For the 2014 release it has been rewritten from scratch for iOS 7 on top of some really awesome open source software. We decided to use [YapDatabase](https://github.com/yaptv/YapDatabase)+[Mantle](https://github.com/Mantle/Mantle) instead of Core Data, and [Mapbox](https://github.com/mapbox/mapbox-ios-sdk) instead of MapKit for our [offline map tiles](https://github.com/Burning-Man-Earth/iBurn-Maps). For a more complete list check out our `Podfile`. For users of Android devices, we also develop a version of [iBurn for Android](https://github.com/Burning-Man-Earth/iBurn-Android).

[![iBurn App Store Link](https://developer.apple.com/app-store/marketing/guidelines/images/badge-download-on-the-app-store.svg)](https://itunes.apple.com/us/app/iburn-2013-burning-man-map/id388169740?mt=8)

## Installation

* Install [Cocoapods](http://cocoapods.org) and the most recent version of Xcode.
* `$ git submodule update --init`
* `$ pod install`
* open `iBurn.xcworkspace` (**not** the .xcodeproj file!)
* Create `BRCSecrets.m` and fill it with the following contents:

	```obj-c
	NSString * const kBRCHockeyBetaIdentifier = @"";
	NSString * const kBRCHockeyLiveIdentifier = @"";

* Compile and Run!

**Note**: Camp, Art and Event location data (`camps.json`, `art.json`, `events.json`) are embargoed by BMorg until the gates open each year. There isn't anything we can do about this until BMorg changes their policy. Sorry!

Fortunately, you can still run and test the app with the previous year's data.

## TODO

* load `image_url` for art when internet is available
* Open in Safari pop up when clicking links
* Add UILocationNotification on favoriting event
* Add filtering for event types and date proximity (work in progress...)
* Onboarding
* About page / attributions
* Show data from previous years
* Retina mbtiles support
* Optimizations
* Data Embargo :(

## Contributing

Thank you for your interest in contributing to iBurn! Please open up an issue on our tracker before starting work on major interface or functionality changes. Otherwise, feel free to run wild!

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

## License

© 2014 [Chris Ballinger](https://github.com/chrisballinger), [David Chiles](https://github.com/davidchiles)

Code: [MPL 2.0](https://www.mozilla.org/MPL/2.0/) (similar to the LGPL in terms of [copyleft](https://en.wikipedia.org/wiki/Copyleft) but more compatible with the App Store)

Data: [CC BY-SA 4.0](http://creativecommons.org/licenses/by-sa/4.0/)