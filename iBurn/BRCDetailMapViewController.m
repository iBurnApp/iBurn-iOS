//
//  BRCDetailMapViewController.m
//  iBurn
//
//  Created by David Chiles on 7/30/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDetailMapViewController.h"
#import "BRCDataObject.h"
#import "BRCAnnotation.h"
@interface BRCDetailMapViewController ()

@property (nonatomic, strong) BRCDataObject *dataObject;

@end

@implementation BRCDetailMapViewController

- (instancetype)initWithDataObject:(BRCDataObject *)dataObject
{
    if (self = [self init]) {
        self.dataObject = dataObject;
        self.title = dataObject.title;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.mapView addAnnotation:[BRCAnnotation annotationWithMapView:self.mapView dataObject:self.dataObject]];
}

@end
