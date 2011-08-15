/*
 * Copyright (c) 2008, Keith Lazuka, dba The Polypeptides
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *	- Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *	- Neither the name of the The Polypeptides nor the
 *	  names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY Keith Lazuka ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL Keith Lazuka BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "KLGraphicsUtils.h"
#import <QuartzCore/QuartzCore.h>

void MyDrawText (CGContextRef myContext, CGRect contextRect, CGFloat fontSize, const char *text, int length)
{
    float w, h;
    w = contextRect.size.width;
    h = contextRect.size.height;
    
    CGContextSaveGState(myContext);
    CGContextSelectFont (myContext,
                         "Helvetica-Bold",
                         fontSize,
                         kCGEncodingMacRoman);
    CGContextSetCharacterSpacing (myContext, 1);
    CGContextSetTextDrawingMode (myContext, kCGTextFill);
    CGContextSetRGBFillColor (myContext, 0, 0, 0, 1);
    CGContextShowTextAtPoint (myContext, contextRect.origin.x, contextRect.origin.y, text, length);
    CGContextRestoreGState(myContext);
}

void MyDrawTextAsClip (CGContextRef myContext, CGRect contextRect, CGFloat fontSize, const char *text, int length)
{
    float w, h;
    w = contextRect.size.width;
    h = contextRect.size.height;
    
    CGContextSelectFont (myContext,
                         "Helvetica-Bold",
                         fontSize,
                         kCGEncodingMacRoman);
    CGContextSetCharacterSpacing (myContext, 1);
    CGContextSetTextDrawingMode (myContext, kCGTextClip);
    CGContextSetRGBFillColor (myContext, 0, 0, 0, 1);
    CGContextShowTextAtPoint (myContext, contextRect.origin.x, contextRect.origin.y, text, length);
}

// --------------------------------------------------------------------------------------------
//      CreateCGImageFromCALayer()
// 
//      Given a Core Animation layer, render it in a bitmap context and return the CGImageRef
//
CGImageRef CreateCGImageFromCALayer(CALayer *sourceLayer)
{
    CGFloat width = sourceLayer.bounds.size.width;
    CGFloat height = sourceLayer.bounds.size.height;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, 4*width, colorSpace, kCGImageAlphaPremultipliedLast);
    NSCAssert(ctx, @"failed to create bitmap context from CALayer");
    
    // rotate 180 degrees and flip vertically (otherwise the CALayer will render backwards)
    CGAffineTransform xform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, width);
    CGContextConcatCTM(ctx, xform);
    
    // rasterize the UIView's backing layer
    [sourceLayer renderInContext:ctx];
    CGImageRef raster = CGBitmapContextCreateImage(ctx);
    
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(ctx);
    
    return raster;
}
