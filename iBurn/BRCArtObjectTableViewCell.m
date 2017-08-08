//
//  BRCArtObjectTableViewCell.m
//  iBurn
//
//  Created by Chris Ballinger on 8/4/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

#import "BRCArtObjectTableViewCell.h"
#import <Mantle/Mantle.h>
#import "BRCArtObject.h"
#import "iBurn-Swift.h"
@import AVFoundation;

@implementation BRCArtObjectTableViewCell

- (instancetype) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.isPlayingAudio = NO;
    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.isPlayingAudio = NO;
}

- (void) setDataObject:(BRCDataObject *)dataObject metadata:(nonnull BRCObjectMetadata *)metadata {
    [super setDataObject:dataObject metadata:metadata];
    if ([dataObject isKindOfClass:[BRCArtObject class]]) {
        BRCArtObject *art = (BRCArtObject*)dataObject;
        if (art.audioURL) {
            self.playPauseButton.hidden = NO;
        } else {
            self.playPauseButton.hidden = YES;
        }
    }
}

- (void) setIsPlayingAudio:(BOOL)isPlayingAudio {
    _isPlayingAudio = isPlayingAudio;
    if (!isPlayingAudio) {
        [self.playPauseButton setTitle:@"🔈 ▶️" forState:UIControlStateNormal];
    } else {
        [self.playPauseButton setTitle:@"🔊 ⏸" forState:UIControlStateNormal];
    }
}

- (IBAction)playPauseButtonPressed:(id)sender {
    self.isPlayingAudio = !self.isPlayingAudio;
    if (self.playPauseBlock) {
        self.playPauseBlock(self);
    }
}

- (void) configurePlayPauseButton:(BRCArtObject *)artObject {
    if ([[BRCAudioPlayer sharedInstance] isPlaying:artObject]) {
        self.isPlayingAudio = YES;
    } else {
        self.isPlayingAudio = NO;
    }
    [self setPlayPauseBlock:^(BRCArtObjectTableViewCell *sender) {
        if (sender.isPlayingAudio) {
            [[BRCAudioPlayer sharedInstance] playAudioTour:@[artObject]];
        } else {
            [[BRCAudioPlayer sharedInstance] togglePlayPause];
        }
    }];
}

@end
