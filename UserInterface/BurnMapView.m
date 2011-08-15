//
//  BurnMapView.m
//  Created by Anna Hentzel on 8/14/09.
//  Derived from TrailTrackerMapView from Gaia GPS
//


#import "BurnMapView.h"
#import "GaiaMarkerManager.h"
#import "RMMapContents.h"

@implementation BurnMapView 


- (RMMapContents *)contents {
  if (![self isContentsSet]) {
    [super contents];
    contents.markerManager = [[GaiaMarkerManager alloc] initWithContents:contents];
    [(GaiaMarkerManager*)contents.markerManager setShowLabels:NO];
    [(GaiaMarkerManager*)contents.markerManager setHideUserMarkers:YES];
 	}
	return contents; 
}


@end
