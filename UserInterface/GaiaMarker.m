//
//  GaiaMarker.m
//  TrailTracker
//
//  Created by Andrew Johnson on 5/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GaiaMarker.h"


@implementation GaiaMarker
@synthesize zoom, waypointID, userCreated;

- (void) dealloc {
  self.waypointID = nil;
	[super dealloc];
}

#define defaultMarkerAnchorPoint CGPointMake(0.5, 0.5)
- (id) initWithUIImage: (UIImage*) image withZoom:(int)z withID:(NSString*)wptID {
	self = [super initWithUIImage:image anchorPoint: defaultMarkerAnchorPoint];
	self.zoom = z;
	self.waypointID = wptID;
	return self;
}


- (void) setLabel:(UIView*)aView {
	if (label == aView) return;
	if (label) {
		[[label layer] removeFromSuperlayer];
		[label release];
		label = nil;
	}
	if (aView) {
		label = [aView retain];
		//[self addSublayer:[label layer]];
	}
}

- (void) changeLabelUsingText: (NSString*)text 
                     position:(CGPoint)position 
                         font:(UIFont*)font 
              foregroundColor:(UIColor*)textColor 
              backgroundColor:(UIColor*)backgroundColor {
	[super changeLabelUsingText:text 
                     position:position 
                         font:font 
              foregroundColor:textColor 
              backgroundColor:backgroundColor];
  [self.label setHidden:YES];
}



@end
