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

@interface BRCDetailCellInfo ()

@property (nonatomic, strong) NSString *key;

@end

@implementation BRCDetailCellInfo


+ (instancetype)detailCellInfoWithKey:(NSString *)key displayName:(NSString *)displayName cellType:(BRCDetailCellInfoType)cellType
{
    BRCDetailCellInfo *cellInfo = [[self alloc] init];
    cellInfo.key = key;
    cellInfo.displayName = displayName;
    cellInfo.cellType = cellType;
    
    return cellInfo;
}

+ (NSArray *)defaultInfoArray
{
    NSMutableArray *defaultArray = [NSMutableArray new];
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(title)) displayName:@"Title" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(artistName)) displayName:@"Artist Name" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(artistLocation)) displayName:@"Artist Location" cellType:BRCDetailCellInfoTypeText]];
    
    /*
     For when we support images
     
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(imageURL)) displayName:@"Image" cellType:BRCDetailCellInfoTypeText]];
    */
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(email)) displayName:@"Email" cellType:BRCDetailCellInfoTypeEmail]];
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(url)) displayName:@"URL" cellType:BRCDetailCellInfoTypeURL]];
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(coordinate)) displayName:@"Location" cellType:BRCDetailCellInfoTypeCoordinates]];
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(otherLocation)) displayName:@"Other Location" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(hometown)) displayName:@"Hometown" cellType:BRCDetailCellInfoTypeText]];
    
    [defaultArray addObject:[self detailCellInfoWithKey:NSStringFromSelector(@selector(detailDescription)) displayName:@"Description" cellType:BRCDetailCellInfoTypeText]];
    return defaultArray;
}

+ (instancetype)detailCellInfoWitDisplayName:(NSString *)displayName value:(NSString *)value
{
    BRCDetailCellInfo *cellInfo = [[self alloc] init];
    cellInfo.displayName = displayName;
    cellInfo.value = value;
    return cellInfo;
}

+ (NSArray *)infoArrayForObject:(BRCDataObject *)object
{
    NSArray *defaultArray = [self defaultInfoArray];
    NSMutableArray *finalCellInfoArray = [NSMutableArray new];
    [defaultArray enumerateObjectsUsingBlock:^(BRCDetailCellInfo *cellInfo, NSUInteger idx, BOOL *stop) {
        //check if value exists
        
        if ([object respondsToSelector:NSSelectorFromString(cellInfo.key)]) {
            if ([object valueForKey:cellInfo.key] != nil && ![[object valueForKey:cellInfo.key] isEqual:[NSNull null]]) {
                
                //if value is a string check that it has an length
                if ([[object valueForKey:cellInfo.key] isKindOfClass:[NSString class]]) {
                    NSString *valueString = [object valueForKey:cellInfo.key];
                    if (![valueString length]) {
                        return;
                    }
                }
                if ([[object valueForKey:cellInfo.key] isKindOfClass:[NSURL class]]) {
                    NSURL *valueURL = [object valueForKey:cellInfo.key];
                    if (![[valueURL absoluteString] length]) {
                        return;
                    }
                }
                
                //add value and dispaly name to array
                cellInfo.value = [object valueForKey:cellInfo.key];
                [finalCellInfoArray addObject:cellInfo];
            }
        }
        
    }];
    
    // Special cases for Schedule and Camp for events
    if ([object isKindOfClass:[BRCEventObject class]]) {
        BRCEventObject *event = (BRCEventObject *)object;
        
        
        //Date string
        NSString *dateString = nil;
        if (event.isAllDay) {
            dateString = [NSString stringWithFormat:@"All Day"];
        }
        else {
            dateString = [NSString stringWithFormat:@"Some date goes here"];
        }
        
        //Camp relationship
        BRCRelationshipDetailInfoCell *relationshipDetailInfoCell = nil;
        if ([event.hostedByCampUniqueID length]) {
            relationshipDetailInfoCell = [[BRCRelationshipDetailInfoCell alloc] init];
            relationshipDetailInfoCell.displayName = @"Camp";
            [[BRCDatabaseManager sharedInstance].readWriteDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                relationshipDetailInfoCell.dataObject = [transaction objectForKey:event.hostedByCampUniqueID inCollection:[BRCCampObject collection]];
            }];
        }
        
        NSUInteger index = 0;
        
        //add items to second and third position
        if ([finalCellInfoArray count]) {
            index = 1;
        }
        
        if (dateString) {
            [finalCellInfoArray insertObject:[self detailCellInfoWitDisplayName:@"Schedule" value:dateString] atIndex:index];
        }
        
        if (relationshipDetailInfoCell) {
            [finalCellInfoArray insertObject:relationshipDetailInfoCell atIndex:index];
        }
    }
    
    
    return finalCellInfoArray;
}

@end
