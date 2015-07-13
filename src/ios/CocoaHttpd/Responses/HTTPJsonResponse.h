#import <Foundation/Foundation.h>
#import "HTTPResponse.h"

@class HTTPConnection;


@interface HTTPJsonResponse : NSObject <HTTPResponse>
{
	HTTPConnection *connection;
	
    NSString* jsonInfo;
    
	UInt64 fileLength;
	UInt64 fileOffset;
	
	BOOL aborted;
	
	void *buffer;
	NSUInteger bufferSize;
}

- (id)initWithConnection:(HTTPConnection *)connection;
- (NSString *)filePath;

@end
