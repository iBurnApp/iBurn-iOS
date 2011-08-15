//
//  GaiaMarker.h
//  TrailTracker
//
//  Created by Andrew Johnson on 5/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMMarker.h"

@interface GaiaMarker : RMMarker {
  // the zoom level to show the marker, used by Markermanager
	int zoom;
	// optional, used to determine unqiueness of nodes
	// if WaypointID is not specified, then MarkerManager will show a marker
	// twice if it is added twice
  NSString *waypointID;	
  BOOL userCreated;
}

@property(nonatomic, assign) BOOL userCreated;
@property(nonatomic, assign) int zoom;
@property(nonatomic,retain) NSString *waypointID;


- (id) initWithUIImage: (UIImage*) image withZoom:(int)z withID:(NSString*)wptID;
/// changes the labelView to a UILabel with supplied #text and default marker font, using existing text foreground/background color.


@end
