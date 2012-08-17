//
//  GaiaMarkerManager.m
//  TrailTracker
//
//  Created by Andrew Johnson on 5/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GaiaMarkerManager.h"
#import "GaiaMarker.h"
#import "RMMapContents.h"
#import "RMLayerCollection.h"

#define MAX_LABELS_TO_SHOW ([[UIScreen mainScreen] applicationFrame].size.height * [[UIScreen mainScreen] applicationFrame].size.width)/15000


@implementation GaiaMarkerManager


@synthesize markerList, markerIdSet, markersOnScreen, hideMarkers, hideUserMarkers, showLabels;


///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark 
#pragma mark Adding / Removing / Displaying Markers


- (void)dealloc {
	self.markerList = nil;
	self.markersOnScreen = nil;
	self.markerIdSet = nil;
	[super dealloc];
}


- (id)initWithContents:(RMMapContents *)mapContents {
	if (self = [super initWithContents:mapContents]) {
    self.markerList = [[[NSMutableArray alloc] init]autorelease];
    self.markersOnScreen = [[[NSMutableArray alloc] init]autorelease]; 	
    self.markerIdSet = [[[NSMutableSet alloc] init]autorelease];
    self.showLabels = YES;
    self.hideMarkers = NO;
    self.hideUserMarkers = NO;
  }
	return self;
}


- (NSArray *)markers {
	return self.markerList;
}


// clears the marker list and remove all markers from the map
- (void) removeMarkers {
  for (GaiaMarker* marker in markerList) {
    [marker hideLabel];
  }
	[[contents overlay] removeSublayers:self.markerList]; 	
	[self.markerIdSet removeAllObjects];
  [self.markerList removeAllObjects];
}


// removes a list of markers from the marker list and removes the markers from the map
- (void) removeMarkers:(NSArray *)markers {
	[[self.contents overlay] removeSublayers: markers];
	for (GaiaMarker* marker in markers) {
    [marker hideLabel];
	  [self.markerIdSet removeObject: marker.waypointID];
  }
  [self.markerList removeObjectsInArray:markers];	
}


// remove a marker from the marker list and remove it from the map
- (void) removeMarker:(GaiaMarker *)marker {
  if (!marker) return;
  [marker hideLabel];
	[[self.contents overlay] removeSublayer: marker];
  if (marker.waypointID) {
    [self.markerIdSet removeObject:marker.waypointID];
  }
	[self.markerList removeObject:marker];
}
  

// checks if a marker is on the screen, and appropriate zoom to display
- (BOOL) isMarkerWithinScreenBounds:(GaiaMarker*)marker {
	CGPoint markerCoord = [self screenCoordinatesForMarker:marker];	
	CGRect rect;
	rect = [[contents mercatorToScreenProjection] screenBounds];
  
	return CGRectContainsPoint(rect, markerCoord) && (float)marker.zoom <= (float) contents.zoom;
}


// displays the markers within the screen bounds, with zoom < current zoom
// \bug should key markers to tiles so we don't have to loop through all markers here
// this will choke on thousands of markers
- (void) showMarkersOnScreen {
  //NSDate* start = [NSDate date];
  [[contents overlay] removeSublayers:self.markersOnScreen]; 	  	
  [self.markersOnScreen removeAllObjects];
  for (GaiaMarker* marker in self.markerList) {		
    if ([self isMarkerWithinScreenBounds: marker]) {
      if ([marker userCreated] && !self.hideUserMarkers) 
        [self.markersOnScreen addObject:marker];
      if (![marker userCreated] && !self.hideMarkers) 
        [self.markersOnScreen addObject:marker];
    }
  }    
	for (GaiaMarker *marker in self.markersOnScreen) {
		if (!self.showLabels || [self.markersOnScreen count] >= MAX_LABELS_TO_SHOW) {
		  [marker hideLabel]; 
		} else {
		  [marker showLabel]; 
    }			
		[[contents overlay] addSublayer:marker];
	}		
  //NSLog(@"time to showmarkers on screen %f", -[start timeIntervalSinceNow]);
}


// adds a marker to the marker list if it doesn't already exist
- (void) addMarker: (GaiaMarker*)marker AtLatLong:(CLLocationCoordinate2D)point {
  [super addMarker:marker AtLatLong:point];
  marker.enableRotation = YES;
	if (marker.waypointID) {
		if (![self.markerIdSet member: marker.waypointID]) { 	
		  [self.markerIdSet addObject: marker.waypointID];		
		  [self.markerList addObject:marker];
	  }
	} else {
		[self.markerList addObject:marker];
	}
}


@end
