//
//  EventInfoViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-09-22.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "EventInfoViewController.h"
#import "Event.h"
#import "Favorite.h"
#import "EventTableViewController.h"
#import "iBurnAppDelegate.h"
#import "ThemeCamp.h"
#import "CampInfoViewController.h"

@implementation EventInfoViewController

@synthesize event;


- (NSString*) stringFromDate:(NSDate*)date {
  static NSDateFormatter *formatter = nil;
  if (!formatter) {
    formatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale;
    enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:enUSPOSIXLocale];
    [formatter setDateFormat:@"MMM dd, hh:mm a"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"MDT"]];
  }  
  return [formatter stringFromDate:date];
}

- (NSString*) dayStringFromDate:(NSDate*)date {
  static NSDateFormatter *formatter = nil;
  if (!formatter) {
    formatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale;
    enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [formatter setLocale:enUSPOSIXLocale];
    [formatter setDateFormat:@"cccc, MMM dd"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"MDT"]];
  }  
  return [formatter stringFromDate:date];
}



- (ThemeCamp*) getCampForEvent:(Event*)evt {
  return evt.camp;
}  


- (void) showCamp {  
  ThemeCamp *camp = [self getCampForEvent:event];
  CampInfoViewController *civp = [[CampInfoViewController alloc]initWithCamp:camp];
  [self.navigationController pushViewController:civp animated:YES];
}



- (void) setupViewInfo {
  //headerTitles = [[NSArray arrayWithObjects:@"Name", @"Start Time", @"End Time",@"Type",  @"URL", @"Contact Email", @"Hometown",  @"Coordinates", @"Description",nil]retain];
  NSMutableArray *tempTitles = [[NSMutableArray alloc]init];
  NSMutableArray *tempTexts = [[NSMutableArray alloc]init];
  if (event.name && ![event.name isEqualToString:@""]) {
    [tempTitles addObject:@"Name"];
    [tempTexts addObject:event.name];
  }
  ThemeCamp *camp = [self getCampForEvent:event];
  if (camp) {
    [tempTitles addObject:@"Camp"];
    [tempTexts addObject:camp.name];
  }
  NSString *startTime = event.startTime ? [self stringFromDate:event.startTime] : @"Unknown.";
  NSString *endTime = event.endTime ? [self stringFromDate:event.endTime] : @"Unknown";
  NSString *schedule = [NSString stringWithFormat:@"%@ - %@", startTime, endTime];

  if ([event.allDay boolValue]) {
    schedule = [NSString stringWithFormat:@"%@ - ALL DAY", [self dayStringFromDate:event.startTime]];
  }
  
  [tempTitles addObject:@"Schedule"];
  [tempTexts addObject:schedule];
  if (event.url && ![event.url isEqualToString:@""]) {
    [tempTitles addObject:@"URL"];
    if ([event.url rangeOfString:@"http://"].location == NSNotFound) {
      event.url = [@"http://" stringByAppendingString:event.url]; 
    }
    [tempTexts addObject:event.url];
  }
  if (event.desc && ![event.desc isEqualToString:@""] ) {
    [tempTitles addObject:@"Description"];
    [tempTexts addObject:event.desc];
  }  
  cellTexts = tempTexts;
  headerTitles = tempTitles;
}


- (id)initWithEvent:(Event*)evt {
	self = [super initWithTitle:evt.name];
	event = evt;
  [self setupViewInfo];
  return self;
}


- (CGFloat)tableView:(UITableView *)tb heightForRowAtIndexPath:(NSIndexPath *) indexPath {
  return [super tableView:tb heightForRowAtIndexPath:indexPath object:event];  
}


- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath  {
  UITableViewCell *cell = [super tableView:tv cellForRowAtIndexPath:indexPath];
  if ([[headerTitles objectAtIndex:indexPath.section]isEqualToString:@"Camp"]
      && [cell.textLabel.text rangeOfString:@"No camp listed"].location == NSNotFound) {
    cell.textLabel.textColor = [UIColor blueColor];
  }
  return cell;
}


- (void) addToFavorites: (id) sender {
  [Favorite addFavorite:@"Event" id:event.bm_id];

}




@end