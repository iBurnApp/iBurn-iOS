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

- (void) setFavoriteIcon {
  if ([self isFavorite]) {
    self.badgeIcon = [UIImage imageNamed:@"empty_star.png"];
  }
}

- (UIImage*) annotationIcon {
  if ([self isFavorite]) {
    return [UIImage imageNamed:@"empty_star.png"];
  }
  return annotationIcon;
}

@end
