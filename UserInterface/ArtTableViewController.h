//
//  ArtTableViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-24.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XMLTableViewController.h"
#import "NodeController.h"
//	id<CellMapLinkDelegate> mapDelegate;
	
@interface ArtTableViewController : XMLTableViewController <NodeFetchDelegate> {
//@property (nonatomic, retain, readwrite) id<CellMapLinkDelegate> mapDelegate;
}

@end
