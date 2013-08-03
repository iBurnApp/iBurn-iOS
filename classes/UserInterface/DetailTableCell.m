//
//  DetailTableCell.m
//  iBurn
//
//  Created by Andrew Johnson on 8/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "DetailTableCell.h"


@implementation DetailTableCell

- (void) setBlackness {
  self.backgroundView = [[UIView  alloc]initWithFrame:self.frame];
  self.backgroundView.backgroundColor = [UIColor blackColor];
  self.contentView.backgroundColor = [UIColor blackColor];
}  

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
      //self.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    }
    return self;
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}




@end
