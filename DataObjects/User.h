//
//  User.h
//  iBurn
//
//  Created by Andrew Johnson on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CoreData/CoreData.h>


@interface User :  NSManagedObject  
{
}

@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * emailAddress;

@end



