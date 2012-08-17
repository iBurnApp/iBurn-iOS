//
//  EventDayTable.h
//  iBurn
//
//  Created by Andrew Johnson on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XMLTableViewController.h"
#import "NodeController.h"

#define kDay1String @"MONDAY - Gates open"
#define kDay2String @"TUESDAY"
#define kDay3String @"WEDNESDAY"
#define kDay4String @"THURSDAY - Core Burn"
#define kDay5String @"FRIDAY - Satellite fly-by 11:45:40 am"
#define kDay6String @"SATURDAY - Man Burn"
#define kDay7String @"SUNDAY - Temple Burn"
#define kDay8String @"MONDAY - Exodus"

@interface EventDayTable : XMLTableViewController <NodeFetchDelegate> {
  NSArray *events;  
}

@property(nonatomic,retain) NSArray *events;

- (id)initWithTitle:(NSString*)ttl;

+ (NSString*) subtitleString:(NSString*)ttl;

@end
