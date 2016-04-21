/********* CameraServer.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>

#import <AVFoundation/AVFoundation.h>

#import "DDLog.h"
#import "DDTTYLogger.h"
#import "HTTPServer.h"
#import "CameraManager.h"

@interface CameraServer : CDVPlugin {
    // Member variables go here.
    
    /*CameraManager *cameraManager;*/
}

@property(nonatomic, retain) HTTPServer *httpServer;
@property(nonatomic, retain) NSString *localPath;
@property(nonatomic, retain) NSString *url;
@property(nonatomic, retain) NSString *jsonInfo;

@property (nonatomic, retain) NSString* www_root;
@property (assign) int port;
@property (assign) BOOL localhost_only;
@property (assign) long numRequests;

//@property (nonatomic, retain) NSData* jpgData;
//@property (nonatomic, retain) NSString *base64String;

@property(nonatomic, retain) CameraManager *cameraManager;

- (void)startServer:(CDVInvokedUrlCommand*)command;
- (void)stopServer:(CDVInvokedUrlCommand*)command;
- (void)getURL:(CDVInvokedUrlCommand*)command;
- (void)getLocalPath:(CDVInvokedUrlCommand*)command;
- (void)getNumRequests:(CDVInvokedUrlCommand*)command;

- (NSDictionary *)getIPAddresses;
- (NSString *)getLocalIPAddress:(BOOL)preferIPv4;

- (void)startCamera:(CDVInvokedUrlCommand*)command;
- (void)stopCamera:(CDVInvokedUrlCommand*)command;

- (void)getJpegImage:(CDVInvokedUrlCommand *)command;
- (void)getVideoFormats:(CDVInvokedUrlCommand *)command;
- (void)setVideoFormat:(CDVInvokedUrlCommand *)command;

- (void)getBrightness:(CDVInvokedUrlCommand *)cmd;
- (void)setBrightness:(CDVInvokedUrlCommand *)cmd;

- (void)getTorch:(CDVInvokedUrlCommand *)cmd;
- (void)setTorch:(CDVInvokedUrlCommand *)cmd;

- (void)getIPAddress:(CDVInvokedUrlCommand *)cmd;

@end

#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

#define OPT_WWW_ROOT        @"www_root"
#define OPT_PORT            @"port"
#define OPT_LOCALHOST_ONLY  @"localhost_only"
#define OPT_JSON_INFO       @"json_info"
#define OPT_VIDEO_FORMAT    @"videoFormat"


#define IP_LOCALHOST        @"127.0.0.1"
#define IP_ANY              @"0.0.0.0"

@implementation CameraServer

- (NSString *)getLocalIPAddress:(BOOL)preferIPv4
{
    NSArray *searchArray = preferIPv4 ?
    @[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    NSLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : IP_ANY;
}

- (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

- (void)pluginInitialize
{
    self.httpServer = nil;
    self.localPath = @"";
    self.url = @"";
    self.www_root = @"";
    self.port = 8080;
    self.localhost_only = false;
    self.numRequests = 0;
    self.jsonInfo = @"";
    
    //self.jpgData = NULL;
    //self.base64String = @"";

    // Disabling cache may reduce memory ??
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
}

/* WEBSERVER METHODS */
- (void)startServer:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    
    NSDictionary* options = [command.arguments objectAtIndex:0];
    
    NSString* str = [options valueForKey:OPT_WWW_ROOT];
    if(str) self.www_root = str;
    
    str = [options valueForKey:OPT_PORT];
    if(str) self.port = [str intValue];
    
    str = [options valueForKey:OPT_LOCALHOST_ONLY];
    if(str) self.localhost_only = [str boolValue];

    str = [options valueForKey:OPT_JSON_INFO];
    if(str) self.jsonInfo = str;
    
    if(self.httpServer != nil) {
        if([self.httpServer isRunning]) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"server is already up"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
    }
    
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    self.httpServer = [[HTTPServer alloc] init];
    
    // Tell the server to broadcast its presence via Bonjour.
    // This allows browsers such as Safari to automatically discover our service.
    //[self.httpServer setType:@"_http._tcp."];
    
    // Normally there's no need to run our server on any specific port.
    // Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
    // However, for easy testing you may want force a certain port so you can just hit the refresh button.
    // [httpServer setPort:12345];
    
    [self.httpServer setPort:self.port];

    [self.httpServer setJsonInfo:self.jsonInfo];

    if(self.localhost_only) [self.httpServer setInterface:IP_LOCALHOST];
    
    // Serve files from our embedded Web folder
    const char * docroot = [self.www_root UTF8String];
    if(*docroot == '/') {
        self.localPath = self.www_root;
    } else {
        NSString* basePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"www"];
        self.localPath = [NSString stringWithFormat:@"%@/%@", basePath, self.www_root];
    }
    NSLog(@"Setting document root: %@", self.localPath);
    [self.httpServer setDocumentRoot:self.localPath];
    
    NSError *error;
    if([self.httpServer start:&error]) {
        int listenPort = [self.httpServer listeningPort];
        NSString* ip = self.localhost_only ? IP_LOCALHOST : [self getLocalIPAddress:YES];
        NSLog(@"Started httpd on port %d", listenPort);
        self.url = [NSString stringWithFormat:@"http://%@:%d/", ip, listenPort];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:self.url];
        
    } else {
        NSLog(@"Error starting httpd: %@", error);
        
        NSString* errmsg = [error description];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:errmsg];
    }

    // TEST :: Clear Cache to free memory ??

    //[[NSURLCache sharedURLCache] removeAllCachedResponses];
    //[[NSURLCache sharedURLCache] setDiskCapacity:0];
    //[[NSURLCache sharedURLCache] setMemoryCapacity:0];

    // TEST :: END

    [self.httpServer setCameraManager:self.cameraManager];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)stopServer:(CDVInvokedUrlCommand*)command
{
    if(self.httpServer != nil) {
        
        [self.httpServer stop];
        self.httpServer = nil;
        
        self.localPath = @"";
        self.url = @"";
        
        NSLog(@"httpd stopped");
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)setInfo:(CDVInvokedUrlCommand *)command
{
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* jsonString = [options valueForKey:OPT_JSON_INFO];

    self.jsonInfo = jsonString;

    if(self.httpServer != nil) {

        [self.httpServer setJsonInfo:jsonString];

        NSLog(@"httpd info set");
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsBool:YES];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getURL:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsString:(self.url ? self.url : @"")];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void)getIPAddress:(CDVInvokedUrlCommand *)command
{
    NSString* ip = [self getLocalIPAddress:YES];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsString:(ip ? ip : @"")];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getLocalPath:(CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsString:(self.localPath ? self.localPath : @"")];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getNumRequests:(CDVInvokedUrlCommand *)command
{
    
    self.numRequests = self.httpServer.numberOfHTTPRequests;
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsInt:(int)(self.numRequests)];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

/* CAMERA METHODS */
- (void)startCamera:(CDVInvokedUrlCommand*)command
{
    if(self.cameraManager != nil) {
        [self.cameraManager stopScanning];
        [self.cameraManager deinitCapture];
        self.cameraManager = nil;
    }

    self.cameraManager = [[CameraManager alloc] init];
    [self.cameraManager initCapture];

    // start on demand / request :)
    //[self.cameraManager startScanning];

    if(self.httpServer != nil) {
        [self.httpServer setCameraManager:self.cameraManager];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)stopCamera:(CDVInvokedUrlCommand*)command
{
    if(self.cameraManager != nil) {
        [self.cameraManager stopScanning];
        [self.cameraManager deinitCapture];
        self.cameraManager = nil;
    }

    if(self.httpServer != nil) {
        [self.httpServer setCameraManager:nil];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getJpegImage:(CDVInvokedUrlCommand *)command
{
    @autoreleasepool {
        NSData* jpgData = NULL;
        
        if(self.cameraManager != nil) {
            jpgData = [self.cameraManager getJpegImage];
        }
        
        NSString *base64String;
        
        if (jpgData != NULL)
        {
            base64String = [jpgData base64EncodedStringWithOptions:0];
            
#if !__has_feature(objc_arc)
            [jpgData release];
#endif
        }
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                          messageAsString:base64String];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}


- (NSString *)stringWithFourCharCode:(unsigned int) fourCharCode {
    
    char c0 = fourCharCode >> 24;
    char c1 = (fourCharCode >> 16) & 0xff;
    char c2 = (fourCharCode >> 8) & 0xff;
    char c3 = fourCharCode & 0xff;
    
    return [NSString stringWithFormat:@"%c%c%c%c", c0, c1, c2, c3];
}


- (void)getVideoFormats:(CDVInvokedUrlCommand *)command
{
    // messageAsArray NSArray*
    // messageAsArrayBuffer NSData*
    // messageAsDictionary NSDictionary*
    
    NSMutableArray* formats = [[NSMutableArray alloc] init];;
    
    if(self.cameraManager != nil) {
        for(AVCaptureDeviceFormat *vFormat in [self.cameraManager getVideoFormats] )
        {
            
            FourCharCode desc = CMVideoFormatDescriptionGetCodecType(vFormat.formatDescription);
            CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription);
            
            int minRate = 999;
            int maxRate = 0;
            
            for ( AVFrameRateRange *range in vFormat.videoSupportedFrameRateRanges ) {
                
                if ( range.maxFrameRate > maxRate ) {
                    maxRate = range.maxFrameRate;
                }
                
                if ( range.minFrameRate < minRate ) {
                    minRate = range.minFrameRate;
                }
            }
            
            // vFormat.mediaType
            // vFormat.formatDescription (Full Block info)
            
            //NSLog(@">> AVFormats  %@ %@ %@",vFormat.mediaType,vFormat.formatDescription,vFormat.videoSupportedFrameRateRanges);
            
            NSString *fourcc = [self stringWithFourCharCode:desc];
            NSString *formatStr = [NSString stringWithFormat:@"(%@) %dx%d , %d-%dfps", fourcc, size.width, size.height, minRate, maxRate];
            [formats addObject:formatStr];
        }
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                       messageAsArray:formats];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setVideoFormat:(CDVInvokedUrlCommand *)command
{
    
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* vFormat = [options valueForKey:OPT_VIDEO_FORMAT];
    
    NSLog(@">> Received AVFormat  %@",vFormat);
    
    if(self.cameraManager != nil) {
        [self.cameraManager setVideoFormat:vFormat.intValue];
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsBool:YES];
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getBrightness:(CDVInvokedUrlCommand *)command
{
    float brightnessVal = [[UIScreen mainScreen] brightness];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsInt:(int)(brightnessVal * 100.0)];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setBrightness:(CDVInvokedUrlCommand *)command
{
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* brightness = [options valueForKey:@"brightness"];
    float brightnessVal = [brightness floatValue]/100;

    [[UIScreen mainScreen] setBrightness:brightnessVal];
}

- (void)getTorch:(CDVInvokedUrlCommand *)command
{
    BOOL torchEnabled = false;

    if(self.cameraManager != nil) {
        torchEnabled = [self.cameraManager getTorch];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsBool:(BOOL)torchEnabled];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setTorch:(CDVInvokedUrlCommand *)command
{
    NSDictionary* options = [command.arguments objectAtIndex:0];
    NSString* torchEnabled = [options valueForKey:@"enabled"];

    BOOL torchVal = [torchEnabled boolValue];

    if(self.cameraManager != nil) {
        [self.cameraManager setTorch:torchVal];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsBool:YES];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


@end