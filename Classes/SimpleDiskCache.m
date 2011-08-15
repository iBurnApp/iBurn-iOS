//
//  SimpleDiskCache.m

#import "SimpleDiskCache.h"
#import "util.h"

@implementation SimpleDiskCache


+ (NSCharacterSet*) getNonAlphaNumericCharacterSet {
  static NSCharacterSet* cs;
  if (!cs) {
    cs = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    cs = [cs retain];
  }
  return cs;
}

+ (void) cacheURL:(NSURL*) url forData:(NSData*)data {
  NSString* filename = [[[url absoluteString] componentsSeparatedByCharactersInSet:
                        [NSCharacterSet punctuationCharacterSet]] componentsJoinedByString:@""];
  NSString * storePath = 
    [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
  [data writeToFile:storePath atomically:NO];
}


+ (NSData*) getDataForURL:(NSURL*) url {
  NSString* filename = [[[url absoluteString] componentsSeparatedByCharactersInSet:
                         [NSCharacterSet punctuationCharacterSet]] componentsJoinedByString:@""];
  NSString * storePath = 
     [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
  
  NSFileManager *fileManager = [NSFileManager defaultManager]; 
  
  if ([fileManager fileExistsAtPath:storePath]) {
    return [NSData dataWithContentsOfFile:storePath]; 
  }
  return nil;
}
@end
