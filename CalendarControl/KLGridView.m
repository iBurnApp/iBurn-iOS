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

#import "KLGridView.h"
#import "KLTile.h"
#import "KLColors.h"

@implementation KLGridView

- (id)initWithFrame:(CGRect)frame
{
    if (![super initWithFrame:frame])
        return nil;
    
    self.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.clipsToBounds = YES;
    self.backgroundColor = [UIColor colorWithCGColor:kCalendarBodyDarkColor];
    _numberOfColumns = 7;
    _tiles = [[NSMutableArray alloc] init];

    return self;
}

- (CGFloat)columnWidth { return 1+floorf(self.bounds.size.width/_numberOfColumns); } // 46px when zoomed out

- (void)layoutSubviews
{
    NSInteger currentColumnIndex = 0;
    NSInteger currentRowIndex = 0;
    
    [UIView beginAnimations:nil context:NULL];
    for (UIView *tileContainer in [self subviews]) {
        CGRect containerFrame = tileContainer.frame;
        containerFrame.size.width = containerFrame.size.height = ([self columnWidth]); // square it up and zoom
        containerFrame.origin.x = currentColumnIndex * [self columnWidth];
        containerFrame.origin.y = currentRowIndex * [self columnWidth]; // tiles are required to be square!
        
        KLTile *tile = [[tileContainer subviews] objectAtIndex:0];
        CGRect tileFrame = containerFrame;
        tileFrame.origin.x = tileFrame.origin.y = 0.0f;
        
        tileContainer.frame = containerFrame;
        tile.frame = tileFrame;
        
        currentColumnIndex++;
        if (currentColumnIndex == _numberOfColumns) {
            currentRowIndex++;
            currentColumnIndex = 0;
        } 
    }
    [UIView commitAnimations];
}

// --------------------------------------------------------------------------------------------
//      addTile:
// 
//      The only way correct way to place a tile in the KLGridView
//
- (void)addTile:(KLTile *)tile
{
    UIView *container = [[[UIView alloc] initWithFrame:tile.frame] autorelease];
    [container addSubview:tile];
    [self addSubview:container];

    [_tiles addObject:tile];
}

- (void)removeAllTiles
{
    for (KLTile *tile in _tiles)
        [[tile superview] removeFromSuperview]; // remove the tile's container
    [_tiles removeAllObjects];
}

- (void)flipView:(UIView *)viewToBeRemoved toRevealView:(UIView *)replacementView transition:(UIViewAnimationTransition)transition
{
    [UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:1];
    UIView *container = [viewToBeRemoved superview];
	[UIView setAnimationTransition:transition forView:container cache:YES];
	[viewToBeRemoved removeFromSuperview];
	[container addSubview:replacementView];
    [self setNeedsLayout];
	[UIView commitAnimations];
}

- (KLTile *)tileOrNilAtIndex:(NSInteger)tileIndex
{
    return (tileIndex >= 0 && tileIndex <  [_tiles count]) ? [_tiles objectAtIndex:tileIndex] : nil;
}

- (void)redrawAllTiles
{
    for (KLTile *tile in _tiles)
        [tile setNeedsDisplay];
}

- (void)redrawNeighborsAndTile:(KLTile *)tile
{
    NSInteger tileIndex = [_tiles indexOfObject:tile];
    
    [[self tileOrNilAtIndex:tileIndex-_numberOfColumns+1] setNeedsDisplay]; // top left
    [[self tileOrNilAtIndex:tileIndex-_numberOfColumns] setNeedsDisplay];   // top
    [[self tileOrNilAtIndex:tileIndex-_numberOfColumns-1] setNeedsDisplay]; // top right
    [[self tileOrNilAtIndex:tileIndex-1] setNeedsDisplay];                  // left
    [[self tileOrNilAtIndex:tileIndex+1] setNeedsDisplay];                  // right
    [[self tileOrNilAtIndex:tileIndex+_numberOfColumns-1] setNeedsDisplay]; // bottom left
    [[self tileOrNilAtIndex:tileIndex+_numberOfColumns] setNeedsDisplay];   // bottom
    [[self tileOrNilAtIndex:tileIndex+_numberOfColumns+1] setNeedsDisplay]; // bottom right

    [tile setNeedsDisplay]; // the center tile itself
}

- (KLTile *)leftNeighborOfTile:(KLTile *)tile
{
    NSInteger tileIndex = [_tiles indexOfObject:tile];
    return [self tileOrNilAtIndex:tileIndex-1];
}

- (KLTile *)rightNeighborOfTile:(KLTile *)tile
{
    NSInteger tileIndex = [_tiles indexOfObject:tile];
    return [self tileOrNilAtIndex:tileIndex+1];
}


- (void)dealloc {
    [_tiles release];
	[super dealloc];
}


@end
