//
//  DQMultipartForm.m
//  DQExport
//
//  Created by Farcaller on 09.12.08.
//  Copyright 2008 Hack&Dev FSO. All rights reserved.
//  See http://www.faqs.org/rfcs/rfc2388.html

#import "DQMultipartForm.h"
#include <stdio.h>

static NSString *kPrefix = @"DQMultiPartFormData";
#define kRandomPartLength		10

@implementation DQMultipartForm

- (id)initWithURL:(NSURL *)u
{
	if( (self = [super init]) ) {
		fields = [[NSMutableArray alloc] init];
		url = [u retain];
	}
	return self;
}

- (void)dealloc
{
	[url release];
	[fields release];
	[super dealloc];
}

- (void)addValue:(id)v forField:(NSString *)f
{
	[fields addObject:[NSArray arrayWithObjects:v,f,nil]];
}

- (NSString *)getRandomBoundary
{
	NSMutableString *s = [NSMutableString string];
	[s appendString:kPrefix];
	int i;
	FILE *fp = fopen("/dev/urandom", "r");
	assert(fp);
	for(i=0; i<kRandomPartLength; ++i) {
		char c;
		do c = fgetc(fp); while (!isalnum(c));
		[s appendFormat:@"%c", c];
	}
	fclose(fp);
	return s;
}

- (NSURLRequest *)urlRequest
{
	NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
	
	NSString *boundaryString = [self getRandomBoundary];
	NSData *boundary = [[NSString stringWithFormat:@"--%@\r\n", boundaryString] dataUsingEncoding:NSUTF8StringEncoding];
	NSMutableData *body = [NSMutableData dataWithData:boundary];
	
	NSEnumerator *en = [fields objectEnumerator];
	NSArray *kv;
	
	BOOL isFile;
	id v;
	NSString *k, *fn;
	NSRange r;
	while( (kv = [en nextObject]) ) {
		v = [kv objectAtIndex:0];
		k = [kv objectAtIndex:1];
		isFile = NO;
		if([v isKindOfClass:[NSString class]]) {
			// either a field or file
			r = [k rangeOfString:@"@"];
			if(r.location == 0) {
				// file
				k = [k substringFromIndex:1];
				fn = v;
				v = [NSData dataWithContentsOfFile:v];
				isFile = YES;
				if(!v)
					return nil;
			} else {
				// field
				v = [v dataUsingEncoding:NSUTF8StringEncoding];
			}
		} else {
			// other stuff is processed by description
			v = [[v description] dataUsingEncoding:NSUTF8StringEncoding];
		}
		// TODO: NSData for direct file support?
		
		if(isFile) {
			[body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", k, [fn lastPathComponent]] dataUsingEncoding:NSUTF8StringEncoding]];
			[body appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		} else {
			[body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", k] dataUsingEncoding:NSUTF8StringEncoding]];
		}
		[body appendData:v];
		[body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[body appendData:boundary];
	}
	
	[urlRequest setHTTPMethod:@"POST"];
	NSString *ct = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundaryString];
	[urlRequest setValue:ct forHTTPHeaderField: @"Content-Type"];
	[urlRequest setHTTPBody:body];
	
	return urlRequest;
}

@end
