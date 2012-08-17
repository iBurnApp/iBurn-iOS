//
//  CampTableViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-12.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "XMLTableViewController.h"
#import "NodeController.h"

@interface CampTableViewController : XMLTableViewController <NodeFetchDelegate> {}

//@interface CampTableViewController : UITableViewController <CellMapLinkDelegate>{
//	id<CellMapLinkDelegate> mapDelegate;
	
//- (void) reloadTable;

//@property (nonatomic, retain, readwrite) id<CellMapLinkDelegate> mapDelegate;

@end
