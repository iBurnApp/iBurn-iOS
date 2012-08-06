//
//  MultipartForm.m
//  Mini-Mallows: A Multi-Part Form Wrapper for Cocoa & iPhone
//
//  Created by Sam Schroeder on 10/21/08.
//	http://www.samuelschroeder.com
//  Copyright 2008 Proton Microsystems, LLC. All rights reserved.
//

#import "MultipartForm.h"


@implementation MultipartForm

#pragma mark -
#pragma mark Initializers

- (id)init {
	[self dealloc];
	
	@throw [NSException exceptionWithName:@"MiniMallowsBadInitCall" 
								   reason:@"Initial MultipartForm with initWithURL:"
								 userInfo:nil];
	return nil;
}

- (id)initWithURL:(NSURL *)url {
	
	if (self = [super init]) {

    mpfRequest = [[NSMutableURLRequest requestWithURL:url] retain];
    mpfFormFields = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
    
    // Set boundry string
    // TODO: Create a dynamics boundry string
    mpfBoundry = @"MiniMallowsBoundary"; // [NSString stringWithString:@"MiniMallowsBoundry"];
    
    // Adding header information
    [mpfRequest setHTTPMethod:@"POST"];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", mpfBoundry];
    [mpfRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    // !!!: Alter the line below if you need a specific accept type
    //[mpfRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    // Set Body infomation
    mpfBody = [[NSMutableData data] retain];
  }
	
	return self;
}

- (void)dealloc {
	[mpfRequest release];
	[mpfFormFields release];
	[mpfBody release];
	[mpfBoundry release];
	[mpfFileName release];
	[mpfFieldNameForFile release];
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSMutableURLRequest *)mpfRequest {
	
	// Start Mutlipart Form
	[mpfBody appendData:[[NSString stringWithFormat:@"--%@\r\n", mpfBoundry] dataUsingEncoding:NSUTF8StringEncoding]];
	
	// Add Form Fields
	NSArray *fieldKeys = [NSArray arrayWithArray:[mpfFormFields allKeys]];
	
	NSEnumerator *enumerator = [fieldKeys objectEnumerator];
	id anObject;
	
	while (anObject = [enumerator nextObject]) {
		NSString *fieldKey = [NSString stringWithString:anObject];
		NSString *fieldData = [NSString stringWithString:[mpfFormFields objectForKey:anObject]];

		[mpfBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", fieldKey] dataUsingEncoding:NSUTF8StringEncoding]];
		[mpfBody appendData:[[NSString stringWithString:fieldData] dataUsingEncoding:NSUTF8StringEncoding]];
		[mpfBody appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", mpfBoundry] dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	// Add the File
	[mpfBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", mpfFieldNameForFile, [mpfFileName lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding]];
	[mpfBody appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[mpfBody appendData:[NSData dataWithContentsOfFile:mpfFileName]];
	
	// End Multipart Form
	[mpfBody appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", mpfBoundry] dataUsingEncoding:NSUTF8StringEncoding]];
	
	[mpfRequest setHTTPBody:mpfBody];
	
	return mpfRequest;
}

#pragma mark -
#pragma mark Builder Methods

- (void)addFormField:(NSString *)fieldName withStringData:(NSString *)fieldData {
	
	NSDictionary *newFieldDictionary = [NSDictionary dictionaryWithObject:fieldData	forKey:fieldName];
	[mpfFormFields addEntriesFromDictionary:newFieldDictionary];
}

- (void)addFile:(NSString *)fileName withFieldName:(NSString *)fieldName {
	
	[mpfFileName release];
	mpfFileName = [fileName retain];
	[mpfFieldNameForFile release];
	//mpfFieldNameForFile = [fieldName release];
}

@end
