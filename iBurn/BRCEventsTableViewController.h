//
//  BRCEventsTableViewController.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"

@interface BRCEventsTableViewController : BRCFilteredTableViewController

@property (atomic, strong, readonly) NSDate *selectedDay;
@property (nonatomic, strong, readonly) NSString *filteredByDayViewName;
@property (nonatomic, strong, readonly) NSString *filteredByDayExpirationAndTypeViewName;

- (instancetype) initWithViewClass:(Class)viewClass
                          viewName:(NSString*)viewName
                           ftsName:(NSString*)ftsName
             filteredByDayViewName:(NSString*)filteredByDayViewName
filteredByDayExpirationAndTypeViewName:(NSString*)filteredByDayExpirationAndTypeViewName;


@end
