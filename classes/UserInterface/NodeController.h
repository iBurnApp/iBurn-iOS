//
//  NodeController.h
//  TrailTracker
//
//  Created by Andrew Johnson on 7/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "BurnDataObject.h"
@class ASIHTTPRequest;

@protocol NodeFetchDelegate<NSObject>
- (void) requestDone;
@end


@interface NodeController : NSObject  {
  id<NodeFetchDelegate> __unsafe_unretained delegate;
}

- (id) init;
- (void) getNodes;
- (void) getNodes:(NSString*) url;
- (void) getNodesFromJson:(NSObject*) jsonNodes;
- (void) requestDone:(ASIHTTPRequest *)request;
- (void) requestWentWrong:(ASIHTTPRequest *)request;
- (NSString*) nullStringOrString:(NSString*)str;
- (NSArray*) getNamesFromDicts:(NSArray*)dicts;
- (NSArray*)getObjectsForType:(NSString*)type 
                        names:(NSArray*)names
                    upperLeft:(CLLocationCoordinate2D)upperLeft 
                   lowerRight:(CLLocationCoordinate2D)lowerRight;

- (NSObject*) nullOrObject:(NSObject*)str;
- (NSDictionary*) getLocationDictionary:(NSDictionary*) dict;
- (void) saveObjects:(NSArray*)objects;
- (void) updateObject:(id)object withDict:(NSDictionary*)dict;
- (void) importDataFromFile:(NSString*)filename;
- (void) createObjectFromDict:(NSDictionary*)dict;
- (void) createAndUpdate:(NSArray*)objects;

@property (nonatomic, strong) NSArray *nodes;
@property (nonatomic, unsafe_unretained) id<NodeFetchDelegate> delegate;

@end
