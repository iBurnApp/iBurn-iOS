//
//  BRCDetailCellInfo.m
//  iBurn
//
//  Created by David Chiles on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDetailCellInfo.h"
#import "BRCRelationshipDetailInfoCell.h"
#import "BRCCampObject.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCDatabaseManager.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCEmbargo.h"
#import "BRCAppDelegate.h"
#import "BRCDataObject+Relationships.h"
#import "BRCEventRelationshipDetailInfoCell.h"
#import "iBurn-Swift.h"

@interface BRCDetailCellInfo ()

@property (nonatomic, strong, readwrite) NSString *displayName;
@property (nonatomic, strong, readwrite) id value;
@property (nonatomic, readwrite) BRCDetailCellInfoType cellType;
@property (nonatomic, strong, readwrite) NSString *key;

@end

@implementation BRCDetailCellInfo



- (instancetype)initWithKey:(NSString *)key displayName:(NSString *)displayName cellType:(BRCDetailCellInfoType)cellType
{
    if (self = [super init]) {
        _key = key;
        _displayName = displayName;
        _cellType = cellType;
    }
    return self;
}

+ (NSArray<BRCDetailCellInfo*> *)defaultInfoArray
{
    NSMutableArray<BRCDetailCellInfo*> *defaultArray = [NSMutableArray new];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(localThumbnailURL)) displayName:@"Image" cellType:BRCDetailCellInfoTypeImage]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(audioURL)) displayName:@"Audio Guide" cellType:BRCDetailCellInfoTypeAudio]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(detailDescription)) displayName:@"Description" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(playaLocation)) displayName:@"Official Location" cellType:BRCDetailCellInfoTypePlayaAddress]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(burnerMapLocationString)) displayName:@"BurnerMap.com Location" cellType:BRCDetailCellInfoTypePlayaAddress]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(otherLocation)) displayName:@"Other Location" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(distanceFromLocation:)) displayName:@"Distance" cellType:BRCDetailCellInfoTypeDistanceFromCurrentLocation]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(title)) displayName:@"Title" cellType:BRCDetailCellInfoTypeText]];

    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(landmark)) displayName:@"Landmark" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(artistName)) displayName:@"Artist Name" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(artistLocation)) displayName:@"Artist Location" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(email)) displayName:@"Email" cellType:BRCDetailCellInfoTypeEmail]];
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(url)) displayName:@"Homepage" cellType:BRCDetailCellInfoTypeURL]];
    
    
    [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(hometown)) displayName:@"Hometown" cellType:BRCDetailCellInfoTypeText]];
    
    
    if ([BRCEmbargo allowEmbargoedData]) {
        [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(location)) displayName:@"GPS Coordinates" cellType:BRCDetailCellInfoTypeCoordinates]];
        
        [defaultArray addObject:[[BRCDetailCellInfo alloc] initWithKey:NSStringFromSelector(@selector(frontage)) displayName:@"Frontage" cellType:BRCDetailCellInfoTypeText]];
    }
    
    return defaultArray;
}

+ (NSArray<BRCDetailCellInfo*> *)infoArrayForObject:(BRCDataObject *)object metadata:(BRCObjectMetadata*)metadata
{
    NSArray<BRCDetailCellInfo*> *defaultArray = [self defaultInfoArray];
    NSMutableArray<BRCDetailCellInfo*> *finalCellInfoArray = [NSMutableArray new];
    [defaultArray enumerateObjectsUsingBlock:^(BRCDetailCellInfo *cellInfo, NSUInteger idx, BOOL *stop) {
        if ([object respondsToSelector:NSSelectorFromString(cellInfo.key)]) {
            id cellValue = nil;
            // Distance is a 'special' case
            if ([cellInfo.key isEqualToString:NSStringFromSelector(@selector(distanceFromLocation:))]) {
                CLLocation *userLocation = BRCAppDelegate.shared.locationManager.location;
                CLLocationDistance distance = [object distanceFromLocation:userLocation];
                cellValue = @(distance);
            } else {
                cellValue = [object valueForKey:cellInfo.key];
            }
            // Stupid Embargo
            if ([cellInfo.key isEqualToString:NSStringFromSelector(@selector(playaLocation))]) {
                NSString *playaAddress = object.playaLocation;
                if (![BRCEmbargo canShowLocationForObject:object]) {
                    cellValue = @"Restricted";
                } else if (!playaAddress.length) {
                    cellValue = @"Unknown";
                } else {
                    cellValue = playaAddress;
                }
                // We don't want to show locations for art because it's kind of meaningless
                if ([object isKindOfClass:BRCArtObject.class]) {
                    cellValue = nil;
                }
            }
            
            if (cellValue != nil && ![cellValue isEqual:[NSNull null]]) {
                //if value is a string check that it has an length
                if ([cellValue isKindOfClass:[NSString class]]) {
                    NSString *valueString = cellValue;
                    if (![valueString length]) {
                        return;
                    }
                } else if ([cellValue isKindOfClass:[NSURL class]]) {
                    NSURL *valueURL = cellValue;
                    if (![[valueURL absoluteString] length]) {
                        return;
                    }
                } else if ([cellValue isKindOfClass:[NSNumber class]]) {
                    if ([cellInfo.key isEqualToString:NSStringFromSelector(@selector(distanceFromLocation:))]) {
                        NSNumber *numberValue = cellValue;
                        double doubleValue = numberValue.doubleValue;
                        if (doubleValue == CLLocationDistanceMax || doubleValue == 0) {
                            return;
                        }
                    }
                }
                cellInfo.value = cellValue;
                
                //add value and dispaly name to array
                [finalCellInfoArray addObject:cellInfo];
            }
        }
        
    }];
    
    // Add link to full event schedule for Camp and Art objects
    if ([object isKindOfClass:[BRCCampObject class]] ||
        [object isKindOfClass:[BRCArtObject class]]) {
        __block NSArray *events = @[];
        [BRCDatabaseManager.shared.uiConnection readWithBlock:^(YapDatabaseReadTransaction * transaction) {
            events = [object eventsWithTransaction:transaction];
        }];
        if (events.count > 0) {
            BRCEventRelationshipDetailInfoCell *eventsListCell = [[BRCEventRelationshipDetailInfoCell alloc] init];
            eventsListCell.dataObject = object;
            eventsListCell.displayName = @"Events";
            [finalCellInfoArray insertObject:eventsListCell atIndex:1];
        }
    }
    
    
    
    // Special cases for Schedule and Camp for events
    if ([object isKindOfClass:[BRCEventObject class]]) {
        BRCEventObject *event = (BRCEventObject *)object;
        
        
        //Date string
        NSMutableAttributedString *fullScheduleString = nil;
        NSString *timeString = nil;
        if (event.isAllDay) {
            NSString *dayOfWeekLetter = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:event.startDate];
            if (dayOfWeekLetter.length >= 3) {
                NSString *firstLetter = [dayOfWeekLetter substringToIndex:3];
                timeString = [NSString stringWithFormat:@"%@ (All Day)", firstLetter];
            }
        }
        else {
            timeString = event.startAndEndString;
        }
        NSDateFormatter *dayOfWeekDateFormatter = [NSDateFormatter brc_dayOfWeekDateFormatter];
        NSDateFormatter *shortDateFormatter = [NSDateFormatter brc_shortDateFormatter];
        NSString *dayOfWeekString = [dayOfWeekDateFormatter stringFromDate:event.startDate];
        NSString *shortDateString = [shortDateFormatter stringFromDate:event.startDate];
        NSString *dateString = [NSString stringWithFormat:@"%@ %@", dayOfWeekString, shortDateString];
        NSString *fullString = [NSString stringWithFormat:@"%@\n%@", dateString, timeString];
        fullScheduleString = [[NSMutableAttributedString alloc] initWithString:fullString];
        UIColor *timeColor = [event colorForEventStatus:[NSDate present]];
        NSRange timeRange = NSMakeRange(dateString.length+1, timeString.length);
        [fullScheduleString setAttributes:@{NSForegroundColorAttributeName: timeColor}
                                    range:timeRange];
        
        //Camp relationship
        BRCRelationshipDetailInfoCell *relationshipDetailInfoCell = nil;
        NSString *relationshipUniqueID = nil;
        NSString *relationshipCollection = nil;
        if ([event.hostedByCampUniqueID length]) {
            relationshipDetailInfoCell = [[BRCRelationshipDetailInfoCell alloc] init];
            relationshipDetailInfoCell.displayName = @"Hosted By Camp";
            relationshipUniqueID = event.hostedByCampUniqueID;
            relationshipCollection = BRCCampObject.yapCollection;
        }
        else if ([event.hostedByArtUniqueID length]) {
            relationshipDetailInfoCell = [[BRCRelationshipDetailInfoCell alloc] init];
            relationshipDetailInfoCell.displayName = @"Hosted At Art";
            relationshipUniqueID = event.hostedByArtUniqueID;
            relationshipCollection = BRCArtObject.yapCollection;
        }
        
        if ([relationshipUniqueID length] && [relationshipCollection length]) {
            [BRCDatabaseManager.shared.uiConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                relationshipDetailInfoCell.dataObject = [transaction objectForKey:relationshipUniqueID inCollection:relationshipCollection];
            }];
        }
        
        
        NSUInteger index = 1;
        
        if (relationshipDetailInfoCell) {
            [finalCellInfoArray insertObject:relationshipDetailInfoCell atIndex:index];
        }
        
        if (fullScheduleString) {
            BRCDetailCellInfo *scheduleCellInfo = [[self alloc] init];
            scheduleCellInfo.displayName = @"Schedule";
            scheduleCellInfo.value = fullScheduleString;
            scheduleCellInfo.cellType = BRCDetailCellInfoTypeSchedule;
            [finalCellInfoArray insertObject:scheduleCellInfo atIndex:index];
        }
    }
    
    BRCDetailCellInfo *cellInfo = [[self alloc] init];
    cellInfo.displayName = @"User Notes";
    cellInfo.value = metadata.userNotes;
    cellInfo.cellType = BRCDetailCellInfoTypeUserNotes;
    [finalCellInfoArray addObject:cellInfo];
    
    // last update from API
#if DEBUG
    if (metadata.lastUpdated) {
        BRCDetailCellInfo *lastUpdated = [[BRCDetailCellInfo alloc] init];
        lastUpdated.value = metadata.lastUpdated; 
        lastUpdated.displayName = @"Last Updated";
        lastUpdated.cellType = BRCDetailCellInfoTypeDate;
        [finalCellInfoArray addObject:lastUpdated];
    }
#endif
    
    return finalCellInfoArray;
}

@end
