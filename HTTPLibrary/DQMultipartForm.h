//
//  DQMultipartForm.h
//  DQExport
//
//  Created by Farcaller on 09.12.08.
//  Copyright 2008 Hack&Dev FSO. All rights reserved.
//

//#import <Cocoa/Cocoa.h>


@interface DQMultipartForm : NSObject {
	NSMutableArray *fields;
	NSURL *url;
}

- (id)initWithURL:(NSURL *)url;
- (void)addValue:(id)v forField:(NSString *)f;
- (NSURLRequest *)urlRequest;

@end
