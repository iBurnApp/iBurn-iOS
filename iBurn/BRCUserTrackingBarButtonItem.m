//
//  BRCUserTrackingBarButtonItem.m
//  MapView
//
// Copyright (c) 2008-2013, Route-Me Contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice, this
//   list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "BRCUserTrackingBarButtonItem.h"

#define RMPostVersion7 (floor(NSFoundationVersionNumber) >  NSFoundationVersionNumber_iOS_6_1)
#define RMPreVersion7  (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)

typedef enum : NSUInteger {
    MLNUserTrackingButtonStateNone     = 0,
    MLNUserTrackingButtonStateActivity = 1,
    MLNUserTrackingButtonStateLocation = 2,
    MLNUserTrackingButtonStateHeading  = 3
} MLNUserTrackingButtonState;

#pragma mark -

@interface BRCUserTrackingBarButtonItem ()

@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, strong) UIImageView *buttonImageView;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;
@property (nonatomic, assign) MLNUserTrackingButtonState state;
@property (nonatomic, assign) UIViewTintAdjustmentMode tintAdjustmentMode;

- (void)createBarButtonItem;
- (void)updateState;
- (void)changeMode:(id)sender;

@end

#pragma mark -

@implementation BRCUserTrackingBarButtonItem

@synthesize mapView = _mapView;
@synthesize segmentedControl = _segmentedControl;
@synthesize buttonImageView = _buttonImageView;
@synthesize activityView = _activityView;
@synthesize state = _state;

- (id)initWithMapView:(MLNMapView *)mapView
{
    if ( ! (self = [super initWithCustomView:[[UIControl alloc] initWithFrame:CGRectMake(0, 0, 32, 32)]]))
        return nil;
    
    [self createBarButtonItem];
    [self setMapView:mapView];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if ( ! (self = [super initWithCoder:aDecoder]))
        return nil;
    
    [self setCustomView:[[UIControl alloc] initWithFrame:CGRectMake(0, 0, 32, 32)]];
    
    [self createBarButtonItem];
    
    return self;
}

- (void)createBarButtonItem
{
    if (RMPreVersion7)
    {
        _segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObject:@""]];
        [_segmentedControl setWidth:32.0 forSegmentAtIndex:0];
        _segmentedControl.userInteractionEnabled = NO;
        _segmentedControl.tintColor = self.tintColor;
        _segmentedControl.center = self.customView.center;
        
        [self.customView addSubview:_segmentedControl];
    }
    
    _buttonImageView = [[UIImageView alloc] initWithImage:nil];
    _buttonImageView.contentMode = UIViewContentModeCenter;
    _buttonImageView.frame = CGRectMake(0, 0, 32, 32);
    _buttonImageView.center = self.customView.center;
    _buttonImageView.userInteractionEnabled = NO;
    
    [self updateImage];
    
    [self.customView addSubview:_buttonImageView];
    
    _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle: UIActivityIndicatorViewStyleMedium];
    _activityView.hidesWhenStopped = YES;
    _activityView.center = self.customView.center;
    _activityView.userInteractionEnabled = NO;
    
    [self.customView addSubview:_activityView];
    
    [((UIControl *)self.customView) addTarget:self action:@selector(changeMode:) forControlEvents:UIControlEventTouchUpInside];
    
    _state = MLNUserTrackingButtonStateNone;
    
    [self updateSize:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSize:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
}

- (void)dealloc
{
    [_mapView removeObserver:self forKeyPath:@"userTrackingMode"];
    [_mapView removeObserver:self forKeyPath:@"userLocation.location"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
}

#pragma mark -

- (void)setMapView:(MLNMapView *)newMapView
{
    if ( ! [newMapView isEqual:_mapView])
    {
        [_mapView removeObserver:self forKeyPath:@"userTrackingMode"];
        [_mapView removeObserver:self forKeyPath:@"userLocation.location"];
        
        _mapView = newMapView;
        [_mapView addObserver:self forKeyPath:@"userTrackingMode"      options:NSKeyValueObservingOptionNew context:nil];
        [_mapView addObserver:self forKeyPath:@"userLocation.location" options:NSKeyValueObservingOptionNew context:nil];
        
        [self updateState];
    }
}

- (void)setTintColor:(UIColor *)newTintColor
{
    [super setTintColor:newTintColor];
    
    if (RMPreVersion7)
        _segmentedControl.tintColor = newTintColor;
    else
        [self updateImage];
}

#pragma mark -

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self updateState];
}

#pragma mark -

- (void)updateSize:(NSNotification *)notification
{
    NSInteger orientation = (notification ? [[notification.userInfo objectForKey:UIApplicationStatusBarOrientationUserInfoKey] integerValue] : [[UIApplication sharedApplication] statusBarOrientation]);
    
    CGFloat dimension = (UIInterfaceOrientationIsPortrait(orientation) ? (RMPostVersion7 ? 36 : 32) : 24);
    
    self.customView.bounds = _buttonImageView.bounds = _segmentedControl.bounds = CGRectMake(0, 0, dimension, dimension);
    [_segmentedControl setWidth:dimension forSegmentAtIndex:0];
    self.width = dimension;
    
    _segmentedControl.center = _buttonImageView.center = _activityView.center = CGPointMake(dimension / 2, dimension / 2 - (RMPostVersion7 ? 1 : 0));
    
    [self updateImage];
}

- (void)updateImage
{
    if (RMPreVersion7)
    {
        if (_mapView.userTrackingMode == MLNUserTrackingModeFollowWithHeading)
            _buttonImageView.image = [UIImage imageNamed:@"TrackingHeading.png"];
        else
            _buttonImageView.image = [UIImage imageNamed:@"TrackingLocation.png"];
    }
    else
    {
        CGRect rect = CGRectMake(0, 0, self.customView.bounds.size.width, self.customView.bounds.size.height);
        
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, [[UIScreen mainScreen] scale]);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        UIImage *image;
        
        if (_mapView.userTrackingMode == MLNUserTrackingModeNone || ! _mapView)
            image = [UIImage imageNamed:@"TrackingLocationOffMask.png"];
        else if (_mapView.userTrackingMode == MLNUserTrackingModeFollow)
            image = [UIImage imageNamed:@"TrackingLocationMask.png"];
        else if (_mapView.userTrackingMode == MLNUserTrackingModeFollowWithHeading)
            image = [UIImage imageNamed:@"TrackingHeadingMask.png"];
        
        UIGraphicsPushContext(context);
        [image drawAtPoint:CGPointMake((rect.size.width  - image.size.width) / 2, ((rect.size.height - image.size.height) / 2) + 2)];
        UIGraphicsPopContext();
        
        CGContextSetBlendMode(context, kCGBlendModeSourceIn);
        CGContextSetFillColorWithColor(context, self.tintColor.CGColor);
        CGContextFillRect(context, rect);
        
        _buttonImageView.image = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        
        CABasicAnimation *backgroundColorAnimation = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
        CABasicAnimation *cornerRadiusAnimation    = [CABasicAnimation animationWithKeyPath:@"cornerRadius"];
        
        backgroundColorAnimation.duration = cornerRadiusAnimation.duration = 0.25;
        
        CGColorRef filledColor = [[self.tintColor colorWithAlphaComponent:0.1] CGColor];
        CGColorRef clearColor  = [[UIColor clearColor] CGColor];
        
        CGFloat onRadius  = 4.0;
        CGFloat offRadius = 0;
        
        if (_mapView.userTrackingMode != MLNUserTrackingModeNone && self.customView.layer.cornerRadius != onRadius)
        {
            backgroundColorAnimation.fromValue = (__bridge id)clearColor;
            backgroundColorAnimation.toValue   = (__bridge id)filledColor;
            
            cornerRadiusAnimation.fromValue = @(offRadius);
            cornerRadiusAnimation.toValue   = @(onRadius);
            
            self.customView.layer.backgroundColor = filledColor;
            self.customView.layer.cornerRadius    = onRadius;
        }
        else if (_mapView.userTrackingMode == MLNUserTrackingModeNone && self.customView.layer.cornerRadius != offRadius)
        {
            backgroundColorAnimation.fromValue = (__bridge id)filledColor;
            backgroundColorAnimation.toValue   = (__bridge id)clearColor;
            
            cornerRadiusAnimation.fromValue = @(onRadius);
            cornerRadiusAnimation.toValue   = @(offRadius);
            
            self.customView.layer.backgroundColor = clearColor;
            self.customView.layer.cornerRadius    = offRadius;
        }
        
        [self.customView.layer addAnimation:backgroundColorAnimation forKey:@"animateBackgroundColor"];
        [self.customView.layer addAnimation:cornerRadiusAnimation    forKey:@"animateCornerRadius"];
    }
}

- (void)updateState
{
    // "selection" state
    //
    if (RMPreVersion7)
        _segmentedControl.selectedSegmentIndex = (_mapView.userTrackingMode == MLNUserTrackingModeNone ? UISegmentedControlNoSegment : 0);
    
    // activity/image state
    //
    if (_mapView.userTrackingMode != MLNUserTrackingModeNone && ( ! _mapView.userLocation || ! _mapView.userLocation.location || (_mapView.userLocation.location.coordinate.latitude == 0 && _mapView.userLocation.location.coordinate.longitude == 0)))
    {
        // if we should be tracking but don't yet have a location, show activity
        //
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^(void)
         {
             self->_buttonImageView.transform = CGAffineTransformMakeScale(0.01, 0.01);
             self->_activityView.transform    = CGAffineTransformMakeScale(0.01, 0.01);
         }
                         completion:^(BOOL finished)
         {
             self->_buttonImageView.hidden = YES;
             
             [self->_activityView startAnimating];
             
             [UIView animateWithDuration:0.25 animations:^(void)
              {
                  self->_buttonImageView.transform = CGAffineTransformIdentity;
                  self->_activityView.transform    = CGAffineTransformIdentity;
              }];
         }];
        
        _state = MLNUserTrackingButtonStateActivity;
    }
    else
    {
        if ((_mapView.userTrackingMode == MLNUserTrackingModeNone              && _state != MLNUserTrackingButtonStateNone)     ||
            (_mapView.userTrackingMode == MLNUserTrackingModeFollow            && _state != MLNUserTrackingButtonStateLocation) ||
            (_mapView.userTrackingMode == MLNUserTrackingModeFollowWithHeading && _state != MLNUserTrackingButtonStateHeading))
        {
            // we'll always animate if leaving activity state
            //
            __block BOOL animate = (_state == MLNUserTrackingButtonStateActivity);
            
            [UIView animateWithDuration:0.25
                                  delay:0.0
                                options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^(void)
             {
                 if (self->_state == MLNUserTrackingButtonStateHeading &&
                     self->_mapView.userTrackingMode != MLNUserTrackingModeFollowWithHeading)
                 {
                     // coming out of heading mode
                     //
                     animate = YES;
                 }
                 else if ((self->_state != MLNUserTrackingButtonStateHeading) &&
                          self->_mapView.userTrackingMode == MLNUserTrackingModeFollowWithHeading)
                 {
                     // going into heading mode
                     //
                     animate = YES;
                 }
                 
                 if (animate)
                     self->_buttonImageView.transform = CGAffineTransformMakeScale(0.01, 0.01);
                 
                 if (self->_state == MLNUserTrackingButtonStateActivity)
                     self->_activityView.transform = CGAffineTransformMakeScale(0.01, 0.01);
             }
                             completion:^(BOOL finished)
             {
                 [self updateImage];
                 
                 self->_buttonImageView.hidden = NO;
                 
                 if (self->_state == MLNUserTrackingButtonStateActivity)
                     [self->_activityView stopAnimating];
                 
                 [UIView animateWithDuration:0.25 animations:^(void)
                  {
                      if (animate)
                          self->_buttonImageView.transform = CGAffineTransformIdentity;
                      
                      if (self->_state == MLNUserTrackingButtonStateActivity)
                          self->_activityView.transform = CGAffineTransformIdentity;
                  }];
             }];
            
            if (_mapView.userTrackingMode == MLNUserTrackingModeNone)
                _state = MLNUserTrackingButtonStateNone;
            else if (_mapView.userTrackingMode == MLNUserTrackingModeFollow)
                _state = MLNUserTrackingButtonStateLocation;
            else if (_mapView.userTrackingMode == MLNUserTrackingModeFollowWithHeading)
                _state = MLNUserTrackingButtonStateHeading;
        }
    }
}

- (void)changeMode:(id)sender
{
    if (_mapView)
    {
        switch (_mapView.userTrackingMode)
        {
            case MLNUserTrackingModeNone:
            default:
            {
                _mapView.userTrackingMode = MLNUserTrackingModeFollow;
                
                break;
            }
            case MLNUserTrackingModeFollow:
            {
                if ([CLLocationManager headingAvailable])
                    _mapView.userTrackingMode = MLNUserTrackingModeFollowWithHeading;
                else
                    _mapView.userTrackingMode = MLNUserTrackingModeNone;
                
                break;
            }
            case MLNUserTrackingModeFollowWithHeading:
            {
                _mapView.userTrackingMode = MLNUserTrackingModeNone;
                
                break;
            }
        }
    }
    
    [self updateState];
}

@end
