/*
 * Copyright (c) 2008, Keith Lazuka, dba The Polypeptides
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *	- Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *	- Neither the name of the The Polypeptides nor the
 *	  names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY Keith Lazuka ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Keith Lazuka BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

//
//	  NOTES
//
//        (1) Everything is drawn relative to self's bounds so that
//            the graphics can be scaled nicely just by changing the bounds.
//
//        (2) The calendar manages switching between months.
//
//        (3) When the month changes (or is first loaded), the calendar 
//            will send the 'didChangeMonths' message to the delegate
//            and it will give the delegate an opportunity to configure
//            each tile that is part of the selected month.
//

#import "KLCalendarView.h"
#import "KLCalendarModel.h"
#import "KLGridView.h"
#import "KLColors.h"
#import "THCalendarInfo.h"
#import "KLGraphicsUtils.h"

static const CGFloat ScaleFactor = 4.0f;  // for zooming in/out. You can try changing this, but no guarantees!

@interface KLCalendarView ()
- (void)addUI;
- (void)addTilesToGrid:(KLGridView *)grid;
- (void)refreshViewWithPushDirection:(NSString *)caTransitionSubtype;
- (void)showPreviousMonth;
- (void)showFollowingMonth;
@end

@implementation KLCalendarView

@synthesize delegate, grid = _grid;

- (id)initWithFrame:(CGRect)frame delegate:(id <KLCalendarViewDelegate>)aDelegate
{
    if (![super initWithFrame:frame])
        return nil;
    
    self.delegate = aDelegate;
    self.backgroundColor = [UIColor colorWithCGColor:kCalendarBodyLightColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.autoresizesSubviews = YES;
    _trackedTouchPoints = [[NSMutableArray alloc] init];
    _model = [[KLCalendarModel alloc] init];
    [self addUI];     // Draw the calendar itself (arrows, month & year name, empty grid)
    [self refreshViewWithPushDirection:nil]; // add tiles to the grid    
    
    return self;
}

- (CGFloat)headerHeight { return 0.13707f*self.bounds.size.height; }

// --------------------------------------------------------------------------------------------
//      drawDayNamesInContext:
// 
//      Draw the day names (Sunday, Monday, Tuesday, etc.) across the top of the grid
//
- (void)drawDayNamesInContext:(CGContextRef)ctx
{
    CGContextSaveGState(ctx);
    CGContextSetFillColorWithColor(ctx, kTileRegularTopColor);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0.0f, -1.0f), 1.0f, kWhiteColor);
    
    for (NSInteger columnIndex = 0; columnIndex < 7; columnIndex++) {
        NSString *header = [_model dayNameAbbreviationForDayOfWeek:columnIndex];
        
        CGFloat columnWidth = self.bounds.size.width / 7;
        CGFloat fontSize = 0.25f * columnWidth;
        CGFloat xOffset = columnIndex * columnWidth;
        CGFloat yOffset = (0.94f * [self headerHeight]) - fontSize;
        
        [header drawInRect:CGRectMake(xOffset, yOffset, columnWidth, fontSize) withFont: [UIFont boldSystemFontOfSize:fontSize] lineBreakMode: UILineBreakModeClip alignment: UITextAlignmentCenter];
    }
    
    CGContextRestoreGState(ctx);
}

// --------------------------------------------------------------------------------------------
//      drawGradientHeaderInContext:
// 
//      Draw the subtle gray vertical gradient behind the month, year, arrows, and day names
//
- (void)drawGradientHeaderInContext:(CGContextRef)ctx
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGColorRef rawColors[2] = { kCalendarHeaderLightColor, kCalendarHeaderDarkColor };
    CFArrayRef colors = CFArrayCreate(NULL, (void*)&rawColors, 2, NULL);
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colors, NULL);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0,0), CGPointMake(0, [self headerHeight]), kCGGradientDrawsBeforeStartLocation);
    
    CGGradientRelease(gradient);
    CFRelease(colors);
    CGColorSpaceRelease(colorSpace);    
}


// --------------------------------------------------------------------------------------------
//      drawRect:
// 
- (void)drawRect:(CGRect)frame
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [self drawGradientHeaderInContext:ctx];
    [self drawDayNamesInContext:ctx];
}

// --------------------------------------------------------------------------------------------
//      tileInSelectedMonthTapped:
// 
//      A good place to ask the delegate for what to do when a main tile is tapped.
//      This is the main interaction for a calendar app.
//
- (void)tileInSelectedMonthTapped:(KLTile *)tile
{
    NSAssert(self.delegate, @"CalendarView's delegate is required for handling calendar tile taps!");
    [self.delegate calendarView:self tappedTile:tile];
}

// --------------------------------------------------------------------------------------------
//      addTilesToView:
// 
//      Add tiles for each date in the weeks of the selected month to the scene.
//      This is called when the calendar is first loaded and whenever the user
//      switches between months. The KLGridView will handle laying out the tiles.
//
//		If you're looking for places to optimize, this code should probably
//		be modified to re-use tiles instead of just trashing them to create new ones
//		every time the user switches between months.
//
- (void)addTilesToGrid:(KLGridView *)grid
{
    // tiles for dates that belong to the final week of the previous month
    for (KLDate *date in [_model daysInFinalWeekOfPreviousMonth]) {
		KLTile *tile = [self.delegate calendarView:self createTileForDate:date];
        [tile addTarget:self action:@selector(showPreviousMonth) forControlEvents:UIControlEventTouchUpInside];
        tile.date = date;
        tile.text = [NSString stringWithFormat:@"%ld", (long)[date dayOfMonth]];
        tile.opaque = NO;
        tile.alpha = 0.4f;
        [grid addTile:tile];
        [tile release];
    }
    
    // tiles for dates that belong to the selected month
    NSArray *days = [_model daysInSelectedMonth];
    for (KLDate *date in days) {
		KLTile *tile = [self.delegate calendarView:self createTileForDate:date];
        [tile addTarget:self action:@selector(tileInSelectedMonthTapped:) forControlEvents:UIControlEventTouchUpInside];
        tile.date = date;
        tile.text = [NSString stringWithFormat:@"%ld", (long)[date dayOfMonth]];
        [grid addTile:tile];
        [tile release];
    }
    
    // tiles for dates that belong to the first week of the following month
    for (KLDate *date in [_model daysInFirstWeekOfFollowingMonth]) {
		KLTile *tile = [self.delegate calendarView:self createTileForDate:date];
        [tile addTarget:self action:@selector(showFollowingMonth) forControlEvents:UIControlEventTouchUpInside];
        tile.date = date;
        tile.text = [NSString stringWithFormat:@"%ld", (long)[date dayOfMonth]];
        tile.opaque = NO;
        tile.alpha = 0.4f;
        [grid addTile:tile];
        [tile release];
    }
}

// --------------------------------------------------------------------------------------------
//      addUI:
// 
//      Create the calendar header buttons and labels and add them to the calendar view.
//      This setup is only performed once during the life of the calendar.
//
- (void)addUI
{
    // Create the previous month button on the left side of the view
    CGRect previousMonthButtonFrame = CGRectMake(self.bounds.origin.x,
                                                 self.bounds.origin.y,
                                                 KL_CHANGE_MONTH_BUTTON_WIDTH, 
                                                 KL_CHANGE_MONTH_BUTTON_HEIGHT);
    UIButton *previousMonthButton = [[UIButton alloc] initWithFrame:previousMonthButtonFrame];
    [previousMonthButton setImage:[UIImage imageNamed:@"left-arrow.png"] forState:UIControlStateNormal];
    previousMonthButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    previousMonthButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [previousMonthButton addTarget:self action:@selector(showPreviousMonth) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:previousMonthButton];
    [previousMonthButton release];
    
    // Draw the selected month name centered and at the top of the view
    CGRect selectedMonthLabelFrame = CGRectMake((self.bounds.size.width/2.0f) - (KL_SELECTED_MONTH_WIDTH/2.0f),
                                                self.bounds.origin.y, 
                                                KL_SELECTED_MONTH_WIDTH, 
                                                KL_HEADER_HEIGHT);
    _selectedMonthLabel = [[UILabel alloc] initWithFrame:selectedMonthLabelFrame];
    _selectedMonthLabel.textColor = [UIColor colorWithCGColor:kTileRegularTopColor];
    _selectedMonthLabel.backgroundColor = [UIColor clearColor];
    _selectedMonthLabel.font = [UIFont boldSystemFontOfSize:KL_HEADER_FONT_SIZE];
    _selectedMonthLabel.textAlignment = UITextAlignmentCenter;
    [self addSubview:_selectedMonthLabel];
    
    // Create the next month button on the right side of the view
    CGRect nextMonthButtonFrame = CGRectMake(self.bounds.size.width - KL_CHANGE_MONTH_BUTTON_WIDTH, 
                                             self.bounds.origin.y, 
                                             KL_CHANGE_MONTH_BUTTON_WIDTH, 
                                             KL_CHANGE_MONTH_BUTTON_HEIGHT);
    UIButton *nextMonthButton = [[UIButton alloc] initWithFrame:nextMonthButtonFrame];
    [nextMonthButton setImage:[UIImage imageNamed:@"right-arrow.png"] forState:UIControlStateNormal];
    nextMonthButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    nextMonthButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [nextMonthButton addTarget:self action:@selector(showFollowingMonth) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:nextMonthButton];
    [nextMonthButton release];
     
    // The Grid of tiles
    self.grid = [[[KLGridView alloc] initWithFrame:CGRectMake(0,[self headerHeight],320,self.bounds.size.height - [self headerHeight])] autorelease];
    [self addSubview:self.grid];
}

- (void)clearAndFillGrid
{
    [self.grid removeAllTiles];
    [self addTilesToGrid:self.grid];

    [self.delegate didChangeMonths];
}

// --------------------------------------------------------------------------------------------
//      refreshViewWithPushDirection:
// 
//      Triggered when the calendar is first created and whenever the selected month changes.
//
- (void)refreshViewWithPushDirection:(NSString *)caTransitionSubtype
{
    // Update the header month and year
    _selectedMonthLabel.text = [NSString stringWithFormat:@"%@ %ld", [_model selectedMonthName], (long)[_model selectedYear]];

    if (!caTransitionSubtype) {   // refresh without animation
        [self clearAndFillGrid];
        return;
    }
    
    // Configure the animation for sliding the tiles in
    [CATransaction begin];
    [CATransaction setValue:[NSNumber numberWithBool:YES] forKey:kCATransactionDisableActions];
    [CATransaction setValue:[NSNumber numberWithFloat:0.5f] forKey:kCATransactionAnimationDuration];
    
    CATransition *push = [CATransition animation];
    push.type = kCATransitionPush;
    push.subtype = caTransitionSubtype;
    [self.grid.layer addAnimation:push forKey:kCATransition];
    [self clearAndFillGrid];
    
    [CATransaction commit];
}

// --------------------------------------------------------------------------------------------
//      showPreviousMonth
// 
//      Triggered whenever the previous button is tapped or when a date in
//      the previous month is tapped. Selects the previous month and updates the view.
//      Note that it is disabled while the calendar is in editing mode.
//
- (void)showPreviousMonth
{
    if ([self isZoomedIn])
        return;  // do not allow it when zoomed in
    
    [_model decrementMonth];
    [self refreshViewWithPushDirection:kCATransitionFromLeft];
}

// --------------------------------------------------------------------------------------------
//      showFollowingMonth
// 
//      Triggered whenever the 'next' button is tapped or when a date in
//      the following month is tapped. Selects the next month and updates the view.
//      Note that it is disabled while the calendar is in editing mode.
//

- (void)showFollowingMonth
{
    if ([self isZoomedIn])
        return;  // do not allow it when zoomed in
    
    [_model incrementMonth];
    [self refreshViewWithPushDirection:kCATransitionFromRight];
}

// --------------------------------------------------------------------------------------------
//      panBounds:toTile:scaleFactor
// 
//      Adjusts the provided 'bounds' rectangle such that the given tile is centered.
//      NOTE: This does not actually change the CalendarView's bounds, 
//            it just modifies the bounds passed in.
//      NOTE: When setting up the pan before a zoom, make sure you set the scaleFactor
//            to the amount that you are about to zoom by.
//            If you are panning the calendar when it is ALREADY zoomed,
//            then set scaleFactor to 1.0f
//
- (void)panBounds:(CGRect*)bounds toTile:(KLTile *)tile scaleFactor:(const CGFloat)scaleFactor
{
    UIView *clipView = [self superview];
    CGPoint clipCenter = CGPointMake(clipView.bounds.size.width/2, clipView.bounds.size.height/2);
    CGPoint tileCenterInClipCoordinates = [clipView convertPoint:CGPointMake(tile.bounds.size.width/2, tile.bounds.size.height/2) fromView:tile];
    bounds->origin.x -= scaleFactor * (clipCenter.x - tileCenterInClipCoordinates.x);
    bounds->origin.y -= scaleFactor * (clipCenter.y - tileCenterInClipCoordinates.y);
}

// assumes that no scaling is required since the calendar is already zoomed in
- (void)panToTile:(KLTile *)tile
{
    [UIView beginAnimations:nil context:NULL];
    CGRect bounds = self.bounds;
    
    // pan
    [self panBounds:&bounds toTile:tile scaleFactor:1.f];
    self.bounds = bounds;
    
    // update
    [self setNeedsDisplay];
    [self.grid redrawNeighborsAndTile:tile];
    [UIView commitAnimations];
}


// --------------------------------------------------------------------------------------------
//      zoomInOnTile:
// 
//      Zoom the calendarView and pan such that the given tile is centered
//
- (void)zoomInOnTile:(KLTile *)tile
{
    [UIView beginAnimations:nil context:NULL];
    CGRect bounds = self.bounds;
    
    // pan
    [self panBounds:&bounds toTile:tile scaleFactor:ScaleFactor];
    
    // zoom
    bounds.size.width *= ScaleFactor;
    bounds.size.height *= ScaleFactor;
    self.bounds = bounds;
    
    // update
    [self setNeedsDisplay];
    [self.grid redrawNeighborsAndTile:tile];
    [UIView commitAnimations];
}

// --------------------------------------------------------------------------------------------
//      zoomOutFromTile:
// 
//      Zoom the calendarView out to normal size so that the entire month is visible.
//
- (void)zoomOutFromTile:(KLTile *)tile
{
    [UIView beginAnimations:nil context:NULL];
    CGRect bounds = self.bounds;
    
    bounds.size.width /= ScaleFactor;
    bounds.size.height /= ScaleFactor;
    bounds.origin.x = bounds.origin.y = 0.0f;
    self.bounds = bounds;
    
    [self setNeedsDisplay];
    [self.grid redrawAllTiles];  // the current chain might have changed so we redraw all tiles, not just the neighbors
    [UIView commitAnimations];
}


// --------------------------------------------------------------------------------------------
//      isZoomedIn
// 
//      Returns YES if the calendar is zoomed in on a tile.
//
- (BOOL)isZoomedIn
{
    return self.bounds.size.width / ScaleFactor  == self.superview.bounds.size.width;
}

// --------------------------------------------------------------------------------------------
//      redrawNeighborsAndTile:
// 
//      Tells the calendar to redraw the given tile along with its adjacent tiles.
//		Motivation: when I zoom into the calendar, there is no need to redraw all of the tiles
//		since only the centered tile and its neighbors will be visible.
//
- (void)redrawNeighborsAndTile:(KLTile *)tile
{
	[self.grid redrawNeighborsAndTile:tile];
}

// --------------------------------------------------------------------------------------------
//      selectedMonthName
// 
//      Returns the name of the month currently being displayed
//
- (NSString *)selectedMonthName
{
    return [_model selectedMonthName];
}

// --------------------------------------------------------------------------------------------
//      selectedMonthNumberOfWeeks
// 
//      Returns the number of weeks that the calendar is currently displaying
//
- (NSInteger)selectedMonthNumberOfWeeks
{
    return [_model selectedMonthNumberOfWeeks];
}


// --------------------------------------------------------------------------------------------
//      touchesBegan:withEvent:
// 
//      Begin tracking a horizontal swipe, single finger
//
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_trackedTouchPoints removeAllObjects];
    UITouch *touch = [touches anyObject];
    [_trackedTouchPoints addObject:[NSValue valueWithCGPoint:[touch locationInView:self]]];
}

// --------------------------------------------------------------------------------------------
//      touchesMoved:withEvent:
// 
//      Continue tracking a horizontal swipe, single finger
//
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [_trackedTouchPoints addObject:[NSValue valueWithCGPoint:[touch locationInView:self]]];
}

// --------------------------------------------------------------------------------------------
//      touchesEnded:withEvent:
// 
//      Notifies the delegate when a horizontal swipe occurs
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [_trackedTouchPoints addObject:[NSValue valueWithCGPoint:[touch locationInView:self]]];
    
    // bail out if the delegate doesn't implement the swipe gesture handlers
    if (![self.delegate respondsToSelector:@selector(wasSwipedToTheRight)]
        || ![self.delegate respondsToSelector:@selector(wasSwipedToTheLeft)])
        return;
    
    CGFloat minX, maxX, minY, maxY;
    minX = minY = INFINITY;
    maxX = maxY = 0.f;

    for (NSValue *v in _trackedTouchPoints) {
        CGPoint point = [v CGPointValue];
        minX = MIN(point.x, minX);
        maxX = MAX(point.x, maxX);
        minY = MIN(point.y, minY);
        maxY = MAX(point.y, maxY);
    }
    
    if (abs(minY-maxY) < 30) {
        // okay, it's close enough to horizontal
        if (abs(minX-maxX) > 40) {
            // okay, it's long enough to be a swipe
            CGFloat firstX = [[_trackedTouchPoints objectAtIndex:0] CGPointValue].x;
            CGFloat lastX = [[_trackedTouchPoints lastObject] CGPointValue].x;
            if (firstX < lastX)
                [self.delegate wasSwipedToTheRight]; 
            else
                [self.delegate wasSwipedToTheLeft]; 
        }
    }


}

- (KLTile *)leftNeighborOfTile:(KLTile *)tile { return [self.grid leftNeighborOfTile:tile]; }
- (KLTile *)rightNeighborOfTile:(KLTile *)tile { return [self.grid rightNeighborOfTile:tile]; }



// --------------------------------------------------------------------------------------------
//      dealloc
// 
- (void)dealloc {
    [_trackedTouchPoints release];
    [_model release];
    [_selectedMonthLabel release];
    [_grid release];
	[super dealloc];
}

@end

