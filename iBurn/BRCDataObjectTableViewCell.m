//
//  BRCDataObjectTableViewCell.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObjectTableViewCell.h"
#import "BRCDataObject.h"
#import "TTTLocationFormatter+iBurn.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCEventObjectTableViewCell.h"
#import "BRCArtObjectTableViewCell.h"
#import "BRCDatabaseManager.h"
#import "BRCEmbargo.h"
#import <Mantle/Mantle.h>
#import "iBurn-Swift.h"
#import "BRCDataObject+Relationships.h"
#import "BRCCampObject.h"

@implementation BRCDataObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject metadata:(BRCObjectMetadata*)metadata {
    BRCImageColors *colors = Appearance.currentColors;
    [self setColorTheme:colors animated:NO];
    self.descriptionLabel.textColor = nil;

    self.titleLabel.text = dataObject.title;
    // strip those newlines rull good
    NSString *detailString = [dataObject.detailDescription stringByReplacingOccurrencesOfString:@"\r\n" withString:@" "];
    detailString = [detailString stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    if (detailString == nil) {
        detailString = @"";
    }
    
    NSMutableAttributedString *detailAttributedString = [[NSMutableAttributedString alloc] init];
    if (metadata.userNotes.length > 0) {
        NSString *userNotes = [NSString stringWithFormat:@"%@\n", metadata.userNotes];
        [detailAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:userNotes attributes:@{
            NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1],
            NSForegroundColorAttributeName: colors.detailColor
        }]];
    }
    [detailAttributedString appendAttributedString:[[NSAttributedString alloc] initWithString:detailString attributes:@{
        NSFontAttributeName:[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1],
        NSForegroundColorAttributeName: colors.secondaryColor
    }]];
    self.descriptionLabel.attributedText = detailAttributedString;
    
    if ([dataObject isKindOfClass:[BRCArtObject class]]) {
        BRCArtObject *art = (BRCArtObject*)dataObject;
        self.rightSubtitleLabel.text = art.artistName;
    } else {
        [self setupLocationLabel:self.rightSubtitleLabel dataObject:dataObject];
    }
    self.favoriteButton.selected = metadata.isFavorite;
    
    // Show event count for camps (art is handled in BRCArtObjectTableViewCell)
    if ([dataObject isKindOfClass:[BRCCampObject class]]) {
        __block NSArray *events = nil;
        [[BRCDatabaseManager shared].uiConnection readWithBlock:^(YapDatabaseReadTransaction * _Nonnull transaction) {
            events = [dataObject eventsWithTransaction:transaction];
        }];
        
        if (events.count > 0 && self.eventCountLabel) {
            self.eventCountLabel.text = [NSString stringWithFormat:@"📅 %lu", (unsigned long)events.count];
            self.eventCountLabel.hidden = NO;
        } else if (self.eventCountLabel) {
            self.eventCountLabel.hidden = YES;
        }
    } else if (![dataObject isKindOfClass:[BRCArtObject class]]) {
        // Hide for non-camp, non-art objects
        if (self.eventCountLabel) {
            self.eventCountLabel.hidden = YES;
        }
    }
}

- (void) setupLocationLabel:(UILabel*)label dataObject:(BRCDataObject*)dataObject {
    NSString *playaLocation = dataObject.playaLocation;
    if (!playaLocation.length) {
        playaLocation = dataObject.burnerMapLocationString;
        if (!playaLocation.length) {
            if ([dataObject isKindOfClass:BRCEventObject.class]) {
                BRCEventObject *event = (BRCEventObject*)dataObject;
                if (event.otherLocation.length > 0) {
                    playaLocation = @"Other Location";
                }
            } else {
                playaLocation = @"Location Unknown";
            }
        }
    }
    if ([BRCEmbargo canShowLocationForObject:dataObject]) {
        label.text = playaLocation;
    } else if (dataObject.burnerMapLocationString) {
        NSString *burnerMapAddress = dataObject.shortBurnerMapAddress;
        if (!burnerMapAddress) {
            burnerMapAddress = dataObject.burnerMapLocationString;
        }
        label.text = [NSString stringWithFormat:@"BurnerMap: %@",burnerMapAddress];
    } else {
        label.text = @"Location Restricted";
    }
}

- (void) updateDistanceLabelFromLocation:(CLLocation*)fromLocation dataObject:(BRCDataObject *)dataObject {
    CLLocation *recentLocation = fromLocation;
    CLLocationDistance distance = CLLocationDistanceMax;
    if (recentLocation) {
        distance = [dataObject distanceFromLocation:recentLocation];
    }
    if (distance == CLLocationDistanceMax || distance == 0) {
        self.subtitleLabel.text = @"🚶🏽 ? min   🚴🏽 ? min";
    } else {
        self.subtitleLabel.attributedText = [TTTLocationFormatter brc_humanizedStringForDistance:distance];
    }
}

- (void) traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    BRCImageColors *colors = Appearance.currentColors;
    [self setColorTheme:colors animated:NO];
}

+ (NSString*) cellIdentifier {
    return NSStringFromClass(self.class);
}

- (IBAction)favoriteButtonPressed:(id)sender {
    if (self.favoriteButton.selected) {
        [self.favoriteButton deselect];
    } else {
        [self.favoriteButton select];
    }
    if (self.favoriteButtonAction) {
        self.favoriteButtonAction(self, self.favoriteButton.selected);
    }
}

@end
