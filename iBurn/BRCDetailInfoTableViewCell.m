//
//  BRCDetailInfoTableViewself.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDetailInfoTableViewCell.h"
#import "BRCDetailCellInfo.h"
#import "BRCRelationshipDetailInfoCell.h"
#import "BRCDataObject.h"
#import "BRCLocationManager.h"
#import "TTTLocationFormatter.h"
#import "TTTTimeIntervalFormatter+iBurn.h"
#import "TTTLocationFormatter+iBurn.h"

@implementation BRCDetailInfoTableViewCell

- (void) setSelectableAppearance {
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.textLabel.textColor = [UIColor blueColor];
}

- (void) setPlainTextApperance {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.textLabel.textColor = [UIColor darkTextColor];
}

- (void) setDetailCellInfo:(BRCDetailCellInfo *)cellInfo {
    if (!cellInfo) {
        return;
    }
    switch (cellInfo.cellType) {
        case BRCDetailCellInfoTypeDistanceFromHomeCamp:
        case BRCDetailCellInfoTypeDistanceFromCurrentLocation: {
            NSNumber *distanceNumber = cellInfo.value;
            CLLocationDistance distance = distanceNumber.doubleValue;
            if (distance > 0) {
                NSAttributedString *text = [TTTLocationFormatter brc_humanizedStringForDistance:distance];
                self.textLabel.textColor = [UIColor darkTextColor];
                self.textLabel.attributedText = text;
            } else {
                self.textLabel.text = nil;
            }
            self.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        }
        case BRCDetailCellInfoTypeText: {
            self.textLabel.text = cellInfo.value;
            [self setPlainTextApperance];
            self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            self.textLabel.numberOfLines = 0;
            break;
        }
        case BRCDetailCellInfoTypeEmail: {
            [self setSelectableAppearance];
            self.textLabel.text = cellInfo.value;
            break;
        }
        case BRCDetailCellInfoTypeURL: {
            [self setSelectableAppearance];
            NSURL *url = cellInfo.value;
            self.textLabel.text = [url absoluteString];
            break;
        }
        case BRCDetailCellInfoTypeCoordinates: {
            CLLocation *location = cellInfo.value;
            self.textLabel.text = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
            self.textLabel.textColor = [UIColor darkTextColor];
            self.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        case BRCDetailCellInfoTypeSchedule: {
            NSAttributedString *attributedString = cellInfo.value;
            self.textLabel.numberOfLines = 0;
            [self setPlainTextApperance];
            self.textLabel.attributedText = attributedString;
            break;
        }
        case BRCDetailCellInfoTypeRelationship: {
            BRCRelationshipDetailInfoCell *relationshipCellInfo = (BRCRelationshipDetailInfoCell *)cellInfo;
            NSMutableString *textString = [relationshipCellInfo.dataObject.title mutableCopy];
            if ([relationshipCellInfo.dataObject.playaLocation length]) {
                [textString appendFormat:@"\n%@",relationshipCellInfo.dataObject.playaLocation];
            }
            self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            self.textLabel.numberOfLines = 0;
            self.textLabel.text = textString;
            [self setSelectableAppearance];
            break;
        }
    }
}

+ (NSString*) cellIdentifier {
    return NSStringFromClass([self class]);
}

@end
