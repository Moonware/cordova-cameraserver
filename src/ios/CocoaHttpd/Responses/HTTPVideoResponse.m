#import "HTTPVideoResponse.h"
#import "HTTPConnection.h"
#import "HTTPLogging.h"

#import <unistd.h>
#import <fcntl.h>

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels : off, error, warn, info, verbose
// Other flags: trace
static const int httpLogLevel = HTTP_LOG_LEVEL_WARN; // | HTTP_LOG_FLAG_TRACE;

#define NULL_FD  -1

@implementation HTTPVideoResponse

- (id)initWithConnection:(HTTPConnection *)parent

{
	if((self = [super init]))
	{
		HTTPLogTrace();
		
		connection = parent; // Parents retain children, children do NOT retain parents
		
		aborted = NO;
        
        // we receive a copy that we will release when finished
        jpegImage = [connection getJpegImage];
       
        fileLength = [jpegImage length];
        
        fileOffset = 0;
		
		// We don't bother opening the file here.
		// If this is a HEAD request we only need to know the fileLength.
	}
	return self;
}

- (void)abort
{
	HTTPLogTrace();
	
	[connection responseDidAbort:self];
	aborted = YES;
}


- (UInt64)contentLength
{
	HTTPLogTrace();
	
	return fileLength;
}

- (UInt64)offset
{
	HTTPLogTrace();
	
	return fileOffset;
}

- (void)setOffset:(UInt64)offset
{
	HTTPLogTrace2(@"%@[%p]: setOffset:%llu", THIS_FILE, self, offset);
    
	fileOffset = offset;

}

- (NSData *)readDataOfLength:(NSUInteger)length
{
	HTTPLogTrace2(@"%@[%p]: readDataOfLength:%lu", THIS_FILE, self, (unsigned long)length);
	
    
    // Determine how much data we should read.
	// 
	// It is OK if we ask to read more bytes than exist in the file.
	// It is NOT OK to over-allocate the buffer.
	
	UInt64 bytesLeftInFile = fileLength - fileOffset;
	
	NSUInteger bytesToRead = (NSUInteger)MIN(length, bytesLeftInFile);
	
	// Make sure buffer is big enough for read request.
	// Do not over-allocate.
	
	if (buffer == NULL || bufferSize < bytesToRead)
	{
		bufferSize = bytesToRead;
		buffer = reallocf(buffer, (size_t)bufferSize);
		
		if (buffer == NULL)
		{
			HTTPLogError(@"%@[%p]: Unable to allocate buffer", THIS_FILE, self);
			
			[self abort];
			return nil;
		}
	}
	
	// Perform the read
    memcpy(buffer, [jpegImage bytes], bytesToRead);
    
    // remote bytes from the front
    if (bytesLeftInFile - bytesToRead > 0)
    {
        jpegImage = [jpegImage subdataWithRange:NSMakeRange(bytesToRead, bytesLeftInFile - bytesToRead)];
        HTTPLogVerbose(@"%@[%p]: %ld bytes left", THIS_FILE, self, (long)bytesLeftInFile - bytesToRead);
    }
    else
    {
        HTTPLogVerbose(@"%@[%p]: EOF", THIS_FILE, self);
    }

    HTTPLogVerbose(@"%@[%p]: Read %ld bytes from file", THIS_FILE, self, (long)bytesToRead);
		
	fileOffset += bytesToRead;
    
    
  	return [NSData dataWithBytes:buffer length:bytesToRead];
	
}

- (BOOL)isDone
{
	BOOL result = (fileOffset == fileLength);
	
	HTTPLogTrace2(@"%@[%p]: isDone - %@", THIS_FILE, self, (result ? @"YES" : @"NO"));
	
	return result;
}


- (void)dealloc
{
	HTTPLogTrace();
	
	
	if (buffer)
		free(buffer);
    
    if (jpegImage)
    {
#if ! __has_feature(objc_arc)
            [jpegImage release];
#endif
        jpegImage = nil;
    }
	
}

@end
