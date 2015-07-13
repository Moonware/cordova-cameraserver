#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;


@interface HTTPVideoResponse : NSObject <HTTPResponse>
{
	HTTPConnection *connection;
	
    NSData* jpegImage;
    
	UInt64 fileLength;
	UInt64 fileOffset;
	
	BOOL aborted;
	
	void *buffer;
	NSUInteger bufferSize;
}

- (id)initWithConnection:(HTTPConnection *)connection;
- (NSString *)filePath;

@end
