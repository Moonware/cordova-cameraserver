/*
 * Copyright (C) 2014-2015 Moonware Studios
 */

#import "CameraManager.h"
#include <mach/mach_host.h>

@implementation CameraManager {
    
}

@synthesize captureSession = _captureSession;
@synthesize device = _device;
@synthesize videoFormat = _selectedFormat;

#pragma mark -
#pragma mark Initialization


- (void) deinitCapture {
    
    if (self.device != nil){
        
#if !__has_feature(objc_arc)
        [self.device release];
#endif
        self.device=nil;
    }
    
    if (self.captureSession != nil){
        
        if (_isCapturing)
        {
            [self.captureSession stopRunning];
        }
        
#if !__has_feature(objc_arc)
        [self.captureSession release];
#endif
        self.captureSession=nil;
    }
    
    if (_jpegLock != nil){
        
#if !__has_feature(objc_arc)
        [_jpegLock release];
#endif
        _jpegLock=nil;
    }
    
    _isCapturing = NO;
}

- (void)initCapture
{
    _jpegLock = [[NSLock alloc] init];
    
    /*We setup the input*/
    self.device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    /*We setup the output*/
    
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    // Set the video output to store frame in BGRA
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;

    // 420YpCbCr8 is supposed to be faster
    //NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    //NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];

    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    
    //And we create a capture session
    self.captureSession = [[AVCaptureSession alloc] init];
    
    //We add input and output
    [self.captureSession addInput:captureInput];
    [self.captureSession addOutput:captureOutput];
    
    // Update the orientation based on device's current
    AVCaptureConnection* connection = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
    if ([connection isVideoOrientationSupported]) {
        connection.videoOrientation = [self videoOrientationFromDeviceOrientation];
    }
    
    /*if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080])
    {
     NSLog(@"Set preview port to 1920X1080");
     self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
    } else*/
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720])
    {
        NSLog(@"Set preview port to 1280X720");
        self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
    } else
    //set to 640x480 if 1280x720 not supported on device
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset640x480])
    {
        NSLog(@"Set preview port to 640X480");
        self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    }
    
    // Limit camera FPS to 15 for single core devices (iPhone 4 and older) so more CPU power is available for decoder
    host_basic_info_data_t hostInfo;
    mach_msg_type_number_t infoCount;
    infoCount = HOST_BASIC_INFO_COUNT;
    host_info( mach_host_self(), HOST_BASIC_INFO, (host_info_t)&hostInfo, &infoCount ) ;
    
    if (hostInfo.max_cpus < 2)
    {
        if ([self.device respondsToSelector:@selector(setActiveVideoMinFrameDuration:)]){
            [self.device lockForConfiguration:nil];
            [self.device setActiveVideoMinFrameDuration:CMTimeMake(1, 15)];
            [self.device unlockForConfiguration];
        } else {
            AVCaptureConnection *conn = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
            [conn setVideoMinFrameDuration:CMTimeMake(1, 15)];
        }
    }
    /*
    else
    {
        // High FPS using Slow Motion Capture (60-120FPS) :)
        int highest = 0;
        
        for(AVCaptureDeviceFormat *vFormat in [self.device formats] )
        {
            CMFormatDescriptionRef description= vFormat.formatDescription;
            
            float maxrate= 0;
            for ( AVFrameRateRange *range in vFormat.videoSupportedFrameRateRanges ) {
                
                if ( range.maxFrameRate > maxrate ) {
                    maxrate = range.maxFrameRate;
                }
            }
            
            if(maxrate>59 && CMFormatDescriptionGetMediaSubType(description)==kCVPixelFormatType_32BGRA)
            {
                if ( YES == [self.device lockForConfiguration:NULL] )
                {
                    self.device.activeFormat = vFormat;
                    [self.device  setActiveVideoMinFrameDuration:CMTimeMake(1,maxrate)];
                    [self.device  setActiveVideoMaxFrameDuration:CMTimeMake(1,maxrate)];
                    [self.device  unlockForConfiguration];
                    NSLog(@"formats  %@ %@ %@",vFormat.mediaType,vFormat.formatDescription,vFormat.videoSupportedFrameRateRanges);
                    
                    highest = maxrate;
                }
            }
        }
    }
    */
}

-(AVCaptureVideoOrientation)videoOrientationFromDeviceOrientation {
    AVCaptureVideoOrientation result = [UIDevice currentDevice].orientation;
    if ( result == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( result == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    return result;
}


- (void)setTorch:(BOOL)enabled
{
    if ([self.device isTorchModeSupported:AVCaptureTorchModeOn]) {
        NSError *error;
        
        if ([self.device lockForConfiguration:&error]) {
            if ([self.device torchMode] == AVCaptureTorchModeOn){
                [self.device setTorchMode:AVCaptureTorchModeOff];
            }
            else {
                [self.device setTorchMode:AVCaptureTorchModeOn];
            }
            
            [self.device unlockForConfiguration];
        }
    }
}


- (BOOL)getTorch
{
    BOOL torchEnabled = false;

    if ([self.device isTorchModeSupported:AVCaptureTorchModeOn]) {
        NSError *error;

        if ([self.device lockForConfiguration:&error]) {
            torchEnabled = [self.device torchMode] == AVCaptureTorchModeOn;
            [self.device unlockForConfiguration];
        }
    }

    return torchEnabled;
}

#pragma mark -
#pragma mark AVCaptureSession delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    BOOL imageNeeded = true;
    
    // Should the previous data be free'd ?
    [_jpegLock lock];
    imageNeeded = _newJpgNeeded;
    [_jpegLock unlock];
    
    if (!_newJpgNeeded)
    {
        //NSLog(@"Input frame discarded... not requested.");
        return;
    }
    
    
    @autoreleasepool {
        // Create a UIImage from the sample buffer data
        UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    
        // GENERATE JPG
    
        // Should the previous data be free'd ?
        [_jpegLock lock];
    
    
        _jpgData = UIImageJPEGRepresentation(image,0.75);
        _newJpgNeeded = NO;
    
        [_jpegLock unlock];
    }
    
    // SAVE TO JPG
    
    //NSData* data = UIImageJPEGRepresentation(image,1.0);
    //NSLog(@"Got Jpeg :)");
    //NSLog(@"Got %@",_jpgData);

    // END OF SAVE TO JPG

    //NSString *path = @"%Out.jpeg";
    //[data writeToFile:path atomically:YES];

    // CALLBACK TO Javascript

    //NSString *javascript = @"cameraplus_exports.onCapture('data:image/jpeg;base64,";
    //javascript = [javascript stringByAppendingString:encodedString];
    //javascript = [javascript stringByAppendingString:@"');"];
    //[self.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:javascript waitUntilDone:YES];

    

#if !__has_feature(objc_arc)
    [image release];
#endif
    

    //[pool drain];
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    @autoreleasepool {
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        // Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, 0);

        // Get the number of bytes per row for the pixel buffer
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);

        // Get the number of bytes per row for the pixel buffer
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        // Get the pixel buffer width and height
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);

        // Create a device-dependent RGB color space
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        // Create a bitmap graphics context with the sample buffer data
        CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                     bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        // Create a Quartz image from the pixel data in the bitmap graphics context
        CGImageRef quartzImage = CGBitmapContextCreateImage(context);
        // Unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer,0);

        // Free up the context and color space
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);

        // Create an image object from the Quartz image
        UIImage *image = [UIImage imageWithCGImage:quartzImage];

        // Release the Quartz image
        CGImageRelease(quartzImage);

        return (image);
    }
}


#pragma mark -
#pragma mark Memory management

- (void) startScanning {
    if (!_isCapturing)
    {
        [self.captureSession startRunning];
        _isCapturing = YES;
        
        [_jpegLock lock];
        _newJpgNeeded = YES;
        [_jpegLock unlock];
    }
}

- (void)stopScanning {
    if (_isCapturing)
    {
        [self.captureSession stopRunning];
        _isCapturing = NO;
    }
}


- (BOOL)isRunning
{
    return self.device != nil;
}

- (NSData*)getJpegImage
{
    if (!_isCapturing)
    {
        [self startScanning];
    }
    
    /*
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(addTimerInMainThread) withObject:nil waitUntilDone:NO];
    }
    else
    {
        [self addTimerInMainThread];
    }
    */
    
    @autoreleasepool {
        [_jpegLock lock];
        NSData *jpegCopy = [NSData dataWithData:_jpgData];
        _newJpgNeeded = YES;
        [_jpegLock unlock];
        
        return jpegCopy;
    }
}


- (NSArray*)getVideoFormats
{
    
    //"formats" is an array of AVCaptureDeviceFormat
    
    if (self.device != NULL)
    {
        return [self.device formats];
    }
    else
    {
        return NULL;
    }
    
    // Jsonify:
    /*
     NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
     [dict setValue:@"Survey1" forKey:@"surveyid"];
     
     NSError *err;
     NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&err];
     
     NSString* retStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
     
     NSLog(@"JSON = %@", retStr);
     
     return retStr;
     */
}

- (void)setVideoFormat:(int)videoFormat {
    
    [self stopScanning];
    
    int curFmt = 0;
    
    for(AVCaptureDeviceFormat *vFormat in [self.device formats] )
    {
        
        if (curFmt == videoFormat)
        {
            float maxrate= 0;
            for ( AVFrameRateRange *range in vFormat.videoSupportedFrameRateRanges ) {
                
                if ( range.maxFrameRate > maxrate ) {
                    maxrate = range.maxFrameRate;
                }
            }
            
            if ( YES == [self.device lockForConfiguration:NULL] )
            {
                self.device.activeFormat = vFormat;
                [self.device  setActiveVideoMinFrameDuration:CMTimeMake(1,maxrate)];
                [self.device  setActiveVideoMaxFrameDuration:CMTimeMake(1,maxrate)];
                [self.device  unlockForConfiguration];
                NSLog(@"format %d %@ %@",videoFormat,vFormat.formatDescription,vFormat.videoSupportedFrameRateRanges);
            }
        }
        
        curFmt++;
    }
    
    [self startScanning];
}

-(void)addTimerInMainThread
{
    if (_inactiveTimer) {
        [_inactiveTimer invalidate];
        _inactiveTimer = NULL;
    }
    
    NSLog(@"Add Timer event fired...");
    _inactiveTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(onInactiveTick:) userInfo:nil repeats:NO];
}

- (void)onInactiveTick:(NSTimer *)timer
{
    NSLog(@"Tick... Shutting down capture.");
    [self stopScanning];
}


@end