# Mini-Mallows: A Multi-Part Form Wrapper for Cocoa & iPhone

All I wanted was some simple code to POST an image to a web service from my iPhone project.  No big deal, right?  Apparently, not.

Based on my google search results many people we were wanting the same thing and just not finding it.  There are a couple iphone
development sites giving examples and some really old open-source projects but nothing really felt right to me.  So being a good
developer I hacked something together which works for me and posted it on GitHub.

Issuing standard GETs and POSTs with Cocoa is pretty easy, but I couldn't find anything _easy_ to make multi-part forms for
POSTing.  This is where mini-mallows comes in.  Just make some Cocoa, add some mini-mallows (form fields & a file), and POST.

Easy.

## Current status

This project was written to satisfy my need to POST a single image and related form fields from an iPhone app to a web service.
It only allows for the addition of one file per request.  I am very open to comments, patches, and ridicule.

**UPDATE: Vladimir Pouzanov has written a multi-part form wrapper for cocoa which I've added to MM.  If you can read Russian his blog
post is [here](http://byteflow.hackndev.org/blog/index.php/2008/12/multipartform-data-%D0%B2-cocoa/).  I'll move all this readme to
the wiki if I can get Vladimir to write an English version.

## Installation

Copy the files `MultipartForm.h` and `MultipartForm.m` anywhere you like into your Xcode project.

## Usage

First, add your standard `#import`.

    #import "MultipartForm.h"

Create a NSURL object as you'll need to send that to Mini-Mallows.

    NSURL *postUrl = [NSURL URLWithString:@"http://www.domain.com"];
    
Now create a `MultipartForm` object and a few form fields and a file.  I really wanted to call the class `MiniMallows` but
`MultipartForm` is easier on the eyes.

    MultipartForm *form = [[MultipartForm alloc] initWithURL:postUrl];
    [form addFormField:@"formFieldName1" withStringData:@"This is some data"];
    [form addFormField:@"formFieldName2" withStringData:@"This is more data"];
    [form addFile:@"path/to/file" withFieldName:@"formFieldForFile"];
    
When you are done adding fields and the file you can get a fully formed `NSMutableURLRequest` object from Mini-Mallows.

    NSMutableURLRequest *postRequest = [form mpfRequest];

All set so POST the form.

    NSData *urlData;
    NSURLResponse *response;
    NSError *error;

    urlData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];

## DQMultipartForm Usage

DQMultipartForm is based on the concepts of MultipartForm, but has simplier interface. To create new form you init it with NSURL object:

    NSURL *postUrl = [NSURL URLWithString:@"http://www.domain.com"];
    DQMultipartForm *form = [[[DQMultipartForm alloc] initWithURL:postUrl] autorelease];

Now you can add fields to your form. This is done via addValue:forField: selctor. You can pass any object to get its description as value, so you can simply add NSNumber without converting to NSString:

    [form addValue:[NSNumber numberWithInt:10] forKey:@"myInt"];

If the passed object is a NSString and key starts with "@" than it's parsed a request to add file. In this case value is a file name pointing to file that would be added for given key without "@" char.

DQMultipartForm supports adding several values for same key, this is useful in case you have php on server side and want to process key[]=value1&key[]=value2 autoarrays.

To build a request you simply call

    NSURLRequest *rq = [form urlRequest];

Please note, that actual data processing (and file loading) is done at this step.

## Caveats

File data is loaded in one big chunk, so it may take large amounts of RAM if you add a big file.

## Authors

Samuel Schroeder 

* samuelschroeder@gmail.com
* [http://samuelschroeder.com](http://samuelschroeder.com)
* Managing Consultant <:> Proton Microsystems, LLC <:> iPhone/Rails Development
* twitter - [@SamSchroeder](http://twitter.com/SamSchroeder)


Vladimir Pouzanov

* Blog	[http://farcaller.net/blog/](http://farcaller.net/blog/)
* Email	farcaller@gmail.com
* Jabber	farcaller@im.hackndev.com
* Twitter	[@farcaller](http://twitter.com/farcaller)
* Linkedin	[farcaller](http://www.linkedin.com/in/farcaller)

## License

Copyright (c) 2008 Samuel Schroeder / Proton Microsystems, LLC & Vladimir Pouzanov / Hack&Dev FSO

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.