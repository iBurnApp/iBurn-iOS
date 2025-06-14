#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface BRCArtImage : MTLModel <MTLJSONSerializing>

@property (nonatomic, copy, readonly, nullable) NSURL *thumbnailURL;
@property (nonatomic, copy, readonly, nullable) NSString *galleryRef;

@end

NS_ASSUME_NONNULL_END