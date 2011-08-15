//
//  MultipartForm.h
//  Mini-Mallows: A Multi-Part Form Wrapper for Cocoa & iPhone
//
//  Created by Sam Schroeder on 10/21/08.
//	http://www.samuelschroeder.com
//  Copyright 2008 Proton Microsystems, LLC. All rights reserved.
//


@interface MultipartForm : NSObject {
	NSMutableURLRequest	*mpfRequest;
	NSMutableDictionary	*mpfFormFields;
	NSString			*mpfFileName;
	NSString			*mpfFieldNameForFile;
	NSString			*mpfBoundry;
	NSMutableData		*mpfBody;
}

- (NSMutableURLRequest *)mpfRequest;

- (id)initWithURL:(NSURL *)url;
- (void)addFormField:(NSString *)fieldName withStringData:(NSString *)fieldData;
- (void)addFile:(NSString *)fileName withFieldName:(NSString *)fieldName;

@end
