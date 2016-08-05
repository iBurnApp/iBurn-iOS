//
//  BRCArtObjectTableViewCell.h
//  iBurn
//
//  Created by Chris Ballinger on 8/4/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

#import "BRCDataObjectTableViewCell.h"

@interface BRCArtObjectTableViewCell : BRCDataObjectTableViewCell

#pragma mark Audio Tour

/** Setting this toggles the button's play/pause states */
@property (nonatomic) BOOL isPlayingAudio;
/** button is shown if art object has audioURL */
@property (weak, nonatomic) IBOutlet UIButton *playPauseButton;
/** Fired when button is pressed */
@property (nonatomic, copy) void (^playPauseBlock)(BRCArtObjectTableViewCell *sender);

@end
