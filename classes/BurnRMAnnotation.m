//
//  BurnRMAnnotation.m
//  iBurn
//
//  Created by Andrew Johnson on 8/3/13.
//
//

#import "BurnRMAnnotation.h"
#import "Event.h"
#import "Favorite.h"
#import "MapViewController.h"

@implementation BurnRMAnnotation
@synthesize burningManID;

- (BOOL) isFavorite {
  return [Favorite isFavorite:self.annotationType id:self.burningManID];

}

- (BOOL) isSelected {
  return [Favorite isSelected:self.annotationType id:self.burningManID];
  
}

- (UIImage*) annotationIcon {
  if ([self isSelected]) {
    return [UIImage imageNamed:@"super-star-pin-down.png"];
  }
  if ([self isFavorite]) {
    if ([self.annotationType isEqualToString:THEME_CAMP_TYPE]) {
      return [UIImage imageNamed:FAVORITE_THEME_CAMP_PIN_NAME];
    }
    if ([self.annotationType isEqualToString:ART_INSTALL_TYPE]) {
      return [UIImage imageNamed:FAVORITE_ART_INSTALL_PIN_NAME];
    }
    if ([self.annotationType isEqualToString:EVENT_TYPE]) {
      return [UIImage imageNamed:FAVORITE_EVENT_PIN_NAME];
    }
  }
  return annotationIcon;
}


- (int) minZoom {
  if (self.mapView.zoom < 13) {
    return [super minZoom];
  }
  
  if ([self isFavorite]) {
    return 13;
  }
  if ([self isSelected]) {
    return 13;
  }
 
  if (self.mapView.zoom >= 14) {
   if (self.startDate) {
      int minutesToStart = abs([self.startDate timeIntervalSinceDate:[NSDate date]])/60;

      if (minutesToStart < 30) {
        return 14;
      }
      if (minutesToStart < 60) {
        return 15;
      }
      if (minutesToStart < 120) {
        return 16;
      }
      return 17;
    }
  }
  return [super minZoom];
}

@end
