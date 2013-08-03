//  SimpleDiskCache.h


@interface SimpleDiskCache : NSObject { }

+ (void) cacheURL:(NSURL*) url forData:(NSData*)data;
+ (NSData*) getDataForURL:(NSURL*) url;

@end
