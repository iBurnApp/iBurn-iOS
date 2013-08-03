//
//  RotatingTabBarController.m
//
//  Created by Andrew Johnson on 12/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "RotatingTabBarController.h"


@implementation RotatingTabBarController

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {  
}  


- (BOOL)shouldAutorotate {
  return [self shouldAutorotateToInterfaceOrientation:UIDeviceOrientationPortrait];
}



@end
 