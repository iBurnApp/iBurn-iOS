//
//  GaiaMarkerManager.h
//  TrailTracker
//
//  Created by Andrew Johnson on 5/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMMarkerManager.h"
#import "GaiaMarker.h"

@interface GaiaMarkerManager : RMMarkerManager {
	NSMutableArray *markerList, *markersOnScreen;
	NSMutableSet *markerIdSet;
	BOOL hideMarkers, showLabels, hideUserMarkers;
}

@property (nonatomic, retain) NSMutableArray *markerList, *markersOnScreen;
@property (nonatomic, assign) BOOL hideMarkers, showLabels, hideUserMarkers;
@property (nonatomic, retain) NSMutableSet *markerIdSet;

- (void) showMarkersOnScreen;
- (void) addMarker: (GaiaMarker*)marker AtLatLong:(CLLocationCoordinate2D)point;


@end
