//
//  ThemeCamp.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-17.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLitePersistentObject.h"

@interface ThemeCamp : SQLitePersistentObject {
    NSString *name;
	NSNumber *year;
	NSString *description;
    NSString *url;
	NSString *contactEmail;
	NSString *hometown;
	NSString *location;
	NSNumber *circularStreet;
	NSString *timeAddress;
	NSNumber *latitude;
	NSNumber *longitude;	
}

@property (nonatomic,readwrite,retain) NSString *name;
@property (nonatomic,readwrite, retain) NSNumber *year;
@property (nonatomic,readwrite,retain) NSString *description;
@property (nonatomic,readwrite,retain) NSString *url;
@property (nonatomic,readwrite,retain) NSString *contactEmail;
@property (nonatomic,readwrite,retain) NSString *hometown;
@property (nonatomic,readwrite,retain) NSString *location;
@property (nonatomic,readwrite,retain) NSNumber *circularStreet;
@property (nonatomic,readwrite,retain) NSString *timeAddress;
@property (nonatomic,readwrite,retain) NSNumber *latitude;
@property (nonatomic,readwrite,retain) NSNumber *longitude;

@end
