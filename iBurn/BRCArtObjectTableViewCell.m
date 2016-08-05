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

- (void) setDataObject:(BRCDataObject *)dataObject {
    [super setDataObject:dataObject];
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

@end
