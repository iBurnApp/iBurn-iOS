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


#import "KLColors.h"
#import "KLGraphicsUtils.h"

// Colors derived from Apple's calendar
CGColorRef kSlateBlueColor, kGridDarkColor, kGridLightColor, kCheckmarkColor,
           kCalendarHeaderLightColor, kCalendarHeaderDarkColor,
           kCalendarBodyLightColor, kCalendarBodyDarkColor,
           kLightCharcoalColor, kDarkCharcoalColor,
           kTileRegularTopColor, kTileRegularBottomColor,
		   kTileDimTopColor, kTileDimBottomColor;

// Basic grayscale colors
CGColorRef kBlackColor, kWhiteColor;


__attribute__((constructor))  // Makes this function run when the app loads
static void InitKColors()
{
    kSlateBlueColor = CreateRGB(0.451f, 0.537f, 0.647f, 1.0f);
    kGridDarkColor = CreateRGB(0.667f, 0.682f, 0.714f, 1.0f);
    kGridLightColor = CreateRGB(0.953f, 0.953f, 0.961f, 1.0f);
    kCalendarHeaderLightColor = CreateRGB(0.965f, 0.965f, 0.969f, 1.0f);
    kCalendarHeaderDarkColor = CreateRGB(0.808f, 0.808f, 0.824f, 1.0f);
    kCalendarBodyLightColor = CreateRGB(0.890f, 0.886f, 0.898f, 1.0f);
    kCalendarBodyDarkColor = CreateRGB(0.784f, 0.748f, 0.804f, 1.0f);
    kLightCharcoalColor = CreateRGB(0.3f, 0.3f, 0.3f, 1.0f);
    kDarkCharcoalColor = CreateRGB(0.1f, 0.1f, 0.1f, 1.0f);
    kTileRegularTopColor = CreateRGB(0.173f, 0.212f, 0.255f, 1.0f);
    kTileRegularBottomColor = CreateRGB(0.294f, 0.361f, 0.435f, 1.0f);
    kTileDimTopColor = CreateRGB(0.545f, 0.565f, 0.588f, 1.0f);
    kTileDimBottomColor = CreateRGB(0.600f, 0.635f, 0.675f, 1.0f);
	
	kBlackColor = CreateGray(0.0f, 1.0f);
    kWhiteColor = CreateGray(1.0f, 1.0f);
}

CGColorRef CreateGray(CGFloat gray, CGFloat alpha)
{
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    CGFloat components[2] = {gray, alpha};
    CGColorRef color = CGColorCreate(colorspace, components);
    CGColorSpaceRelease(colorspace);
    return color;
}

CGColorRef CreateRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha)
{
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGFloat components[4] = {red, green, blue, alpha};
    CGColorRef color = CGColorCreate(colorspace, components);
    CGColorSpaceRelease(colorspace);
    return color;
}



