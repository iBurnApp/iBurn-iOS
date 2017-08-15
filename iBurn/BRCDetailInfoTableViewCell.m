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
#import "TTTLocationFormatter.h"
#import "TTTTimeIntervalFormatter+iBurn.h"
#import "TTTLocationFormatter+iBurn.h"
#import "BRCEmbargo.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCEventRelationshipDetailInfoCell.h"
#import <PureLayout/PureLayout.h>

@interface BRCDetailInfoTableViewCell()
@property (nonatomic, strong) NSLayoutConstraint *aspectConstraint;
@end

@implementation BRCDetailInfoTableViewCell

- (instancetype) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        _artImageView = [[UIImageView alloc] init];
        self.artImageView.contentMode = UIViewContentModeScaleAspectFill;
        [self.contentView addSubview:self.artImageView];
        [self.artImageView autoPinEdgesToSuperviewEdges];
    }
    return self;
}

- (void) setSelectableAppearance:(BRCImageColors*)colors {
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.textLabel.textColor = colors.secondaryColor;
}

- (void) setPlainTextApperance:(BRCImageColors*)colors {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.textLabel.textColor = colors.primaryColor;
}

- (void) prepareForReuse {
    [super prepareForReuse];
    self.artImageView.image = nil;
    self.textLabel.text = nil;
    self.backgroundColor = [UIColor whiteColor];
    self.aspectConstraint = nil;
}

- (void) setAspectConstraint:(NSLayoutConstraint *)aspectConstraint {
    if (_aspectConstraint) {
        [self.artImageView removeConstraint:_aspectConstraint];
    }
    _aspectConstraint = aspectConstraint;
    if (_aspectConstraint) {
        [self.artImageView addConstraint:_aspectConstraint];
    }
}

- (void) setDetailCellInfo:(BRCDetailCellInfo *)cellInfo colors:(BRCImageColors*)colors {
    if (!cellInfo) {
        return;
    }
    self.backgroundColor = colors.backgroundColor;
    self.artImageView.image = nil;
    self.artImageView.hidden = YES;
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
            [self setPlainTextApperance:colors];
            self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            self.textLabel.numberOfLines = 0;
            break;
        }
        case BRCDetailCellInfoTypeEmail: {
            [self setSelectableAppearance:colors];
            self.textLabel.text = cellInfo.value;
            break;
        }
        case BRCDetailCellInfoTypeURL: {
            [self setSelectableAppearance:colors];
            NSURL *url = cellInfo.value;
            self.textLabel.text = [url absoluteString];
            break;
        }
        case BRCDetailCellInfoTypeCoordinates: {
            CLLocation *location = cellInfo.value;
            self.textLabel.text = [NSString stringWithFormat:@"%f, %f", location.coordinate.latitude, location.coordinate.longitude];
            [self setPlainTextApperance:colors];
            self.textLabel.textColor = colors.primaryColor;
            self.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
        case BRCDetailCellInfoTypeSchedule: {
            NSAttributedString *attributedString = cellInfo.value;
            self.textLabel.numberOfLines = 0;
            [self setPlainTextApperance:colors];
            self.textLabel.attributedText = attributedString;
            break;
        }
        case BRCDetailCellInfoTypeRelationship: {
            BRCRelationshipDetailInfoCell *relationshipCellInfo = (BRCRelationshipDetailInfoCell *)cellInfo;
            NSMutableString *textString = [relationshipCellInfo.dataObject.title mutableCopy];
            if ([relationshipCellInfo.dataObject.playaLocation length] && [BRCEmbargo allowEmbargoedData]) {
                [textString appendFormat:@"\n%@",relationshipCellInfo.dataObject.playaLocation];
            }
            self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            self.textLabel.numberOfLines = 0;
            self.textLabel.text = textString;
            [self setSelectableAppearance:colors];
            break;
        }
        case BRCDetailCellInfoTypeEventRelationship: {
            self.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            self.textLabel.numberOfLines = 0;
            self.textLabel.text = @"Hosted Events";
            [self setSelectableAppearance:colors];
            break;
        }
        case BRCDetailCellInfoTypeDate: {
            NSDate *date = cellInfo.value;
            self.textLabel.text = [[NSDateFormatter brc_playaEventsAPIDateFormatter] stringFromDate:date];
            [self setPlainTextApperance:colors];
            break;
        }
        case BRCDetailCellInfoTypeImage: {
            NSURL *imageURL = cellInfo.value;
            self.textLabel.text = nil;
            UIImage *image = [UIImage imageWithContentsOfFile:imageURL.path];
            if (image) {
                // https://stackoverflow.com/a/26056737/805882
                CGFloat aspectRatio = image.size.width / image.size.height;
                self.aspectConstraint = [NSLayoutConstraint constraintWithItem:self.artImageView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self.artImageView attribute:NSLayoutAttributeHeight multiplier:aspectRatio constant:0.0];
                self.artImageView.image = image;
                self.artImageView.hidden = NO;
            }
            [self setPlainTextApperance:colors];
            break;
        }
    }
}

+ (NSString*) cellIdentifier {
    return NSStringFromClass(self.class);
}

@end
