//
//  BurnRMAnnotation.m
//  iBurn
//
//  Created by Andrew Johnson on 8/3/13.
//
//

#import "BurnRMAnnotation.h"
#import "Favorite.h"

@implementation BurnRMAnnotation
@synthesize burningManID;

- (BOOL) isFavorite {
  return [Favorite isFavorite:self.annotationType id:self.burningManID];

}

- (BOOL) isSelected {
  return [Favorite isSelected:self.annotationType id:self.burningManID];
  
}

- (void) setFavoriteIcon {
  if ([self isFavorite]) {
    self.badgeIcon = [UIImage imageNamed:@"star-pin-down.png"];
  }
}

- (UIImage*) annotationIcon {
  if ([self isSelected]) {
    return [UIImage imageNamed:@"gaia-icon.png"];
  }
  if ([self isFavorite]) {
    return [UIImage imageNamed:@"star-pin-down.png"];
  }
  return annotationIcon;
}

- (int) minZoom {
  if ([self isFavorite]) {
    return 13;
  }
  return [super minZoom];
}

@end
