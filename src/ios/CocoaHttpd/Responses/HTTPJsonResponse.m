#import "HTTPJsonResponse.h"
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

@implementation HTTPJsonResponse

- (id)initWithConnection:(HTTPConnection *)parent

{
	if((self = [super init]))
	{
		HTTPLogTrace();
		
		connection = parent; // Parents retain children, children do NOT retain parents
		
		aborted = NO;
        
        // we receive a copy that we will release when finished
        jsonInfo = [connection getJsonInfo];
       
        fileLength = [jsonInfo length];
        
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
    
	fileOffset += fileLength;
    
    // WE ALWAYS RETURN THE FULL CONTENT!
    return [jsonInfo dataUsingEncoding:NSUTF8StringEncoding];
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
}

@end
