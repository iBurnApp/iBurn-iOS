//
//  User.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-17.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLitePersistentObject.h"

@interface User : SQLitePersistentObject {
    NSString *username;
    NSString *name;
	NSString *emailAddress;
}

@property (nonatomic,readwrite,retain) NSString *username;
@property (nonatomic,readwrite,retain) NSString *name;
@property (nonatomic,readwrite,retain) NSString *emailAddress;

@end
