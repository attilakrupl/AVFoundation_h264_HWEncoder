//
//  main.m
//  VideoEncodingProject
//
//  Created by attila.krupl on 2020. 04. 03..
//  Copyright © 2020. attila.krupl. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>


#pragma mark -
#pragma mark Compile command

// clang -framework Foundation -framework AVFoundation -framework CoreMedia main.m -o codec


#pragma mark -
#pragma mark Useful links

//  https://stackoverflow.com/questions/30126921/h-264-video-streaming-with-avfoundation-on-os-x
//  https://github.com/niswegmann/H264Streamer/blob/master/H264Streamer/ViewController.m
//  https://developer.apple.com/documentation/avfoundation/avcapturephotooutput?language=objc
//  https://stackoverflow.com/questions/626898/how-do-i-create-delegates-in-objective-c/17189015#17189015
//  https://stackoverflow.com/questions/19694935/averrormediaserviceswerereset-in-avcapturesessionruntimeerrornotification
//  https://gist.github.com/cameronehrlich/986c96fe35cc7f70aac2
//  https://developer.apple.com/documentation/avfoundation/avcapturefileoutput/1387224-startrecordingtooutputfileurl?language=objc
//  https://stackoverflow.com/questions/21005942/how-to-save-a-movie-from-avcapture
//  https://stackoverflow.com/questions/47217998/h264-encoding-and-decoding-using-videotoolbox
//  https://confluence.doclerholding.com/display/DEVZONE/AVFoundation+framework+on+mac
//  https://www.youtube.com/watch?v=wPXVeKyUCYw
//  https://softron.zendesk.com/hc/en-us/articles/115000013293-Encoding-in-H-264-or-H-265-HEVC-
//  https://stackoverflow.com/questions/51828494/getting-image-from-avcapturemoviefileoutput-without-switching
//  https://medium.com/@benwiz/how-to-install-openframeworks-on-a-mac-macos-high-sierra-a5a9b3f47ea1
//  https://apple.stackexchange.com/questions/63745/does-any-os-x-hardware-contain-on-chip-h-264-encoding-decoding
//  https://developer.apple.com/documentation/videotoolbox/1428285-vtcompressionsessioncreate?language=objc
//  https://stackoverflow.com/questions/29525000/how-to-use-videotoolbox-to-decompress-h-264-video-stream
//  https://developer.apple.com/documentation/videotoolbox/vtcompressionsession/compression_properties?language=objc


#pragma mark -
#pragma mark Logger macros

#define LogError(aMessage, ...) NSLog((@"ERROR:             [Line %d] " aMessage ),     __LINE__, ## __VA_ARGS__);
#define LogInfo(aMessage, ...) NSLog((@"INFO:              [Line %d] " aMessage ), __LINE__, ## __VA_ARGS__);
#define LogSuccess(aMessage, ...) NSLog((@"SUCCESS:           [Line %d] " aMessage ), __LINE__, ## __VA_ARGS__);
#define LogFunctionEntry(aMessage, ...) NSLog((@"Entering function: %s" aMessage ), __PRETTY_FUNCTION__, ## __VA_ARGS__)


#pragma mark -
#pragma mark Constant configuration values

// AVCaptureSessionPreset const mCaptureSessionPreset = AVCaptureSessionPreset640x480;
int                    const kRawFrameWidth        = 640;
int                    const kRawFrameHeight       = 480;
int                    const kMinCaptureFPS        = 30;
int                    const kMaxCaptureFPS        = 30;


#pragma mark -
#pragma mark Free Helper Functions


#pragma mark ProcessH264Output
void ProcessH264Output(void* aOutputCallbackRefCon, void* aSourceFrameRefCon, OSStatus aStatus, VTEncodeInfoFlags aInfoFlags, CMSampleBufferRef aSampleBuffer )
{
    LogFunctionEntry();
}


#pragma mark GetCaptureDeviceWithType
void GetCaptureDeviceWithType( NSMutableArray< AVCaptureDevice*>* aArray, AVCaptureDeviceType aType )
{
    LogFunctionEntry();
    
    AVCaptureDeviceDiscoverySession* lCaptureDeviceDiscoverySession = [ AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[ aType ]
                                                                        mediaType:AVMediaTypeVideo
                                                                        position:AVCaptureDevicePositionUnspecified ];
    NSArray< AVCaptureDevice*>* lDevices = [ lCaptureDeviceDiscoverySession devices ];

    for( AVCaptureDevice* lDevice in lDevices )
    {
        [ aArray addObject:lDevice ];
    }
}


#pragma mark SaveCaptureOutputToFile
void SaveCaptureOutputToFile( CMSampleBufferRef aSampleBuffer, int aFrameCount )
{
    LogFunctionEntry();
    
    CVImageBufferRef imageBuffer    = CMSampleBufferGetImageBuffer( aSampleBuffer );
    CIImage         *ciImage        = [CIImage imageWithCVPixelBuffer:imageBuffer];
    
    LogInfo( "Image extent will be h: %f, w: %f, x: %f, y: %f", ciImage.extent.size.height, ciImage.extent.size.width, ciImage.extent.origin.x, ciImage.extent.origin.y );
    
    NSString        *lPathComponent = [NSString stringWithFormat:@"file:///Users/attila.krupl/Pictures/Image%d.jpeg", aFrameCount];
    
    LogInfo( "File path will be %@", lPathComponent );
    
    NSURL           *lUrl           = [NSURL URLWithString:[lPathComponent stringByAddingPercentEncodingWithAllowedCharacters:[ NSCharacterSet URLQueryAllowedCharacterSet ] ] ];
    CIContext       *lContext       = [CIContext contextWithOptions:nil];
    CGColorSpaceRef  lColorSpace    = CGColorSpaceCreateDeviceRGB();
    NSDictionary    *lOptions       = @{ @"kCGImageDestinationLossyCompressionQuality" : @1.0 , @"depth" : @1, @"disparity" : @1, @"matte" : @1};
    NSError         *lError         = nil;
    
    if ( ![ lContext writeJPEGRepresentationOfImage:ciImage toURL:lUrl colorSpace:lColorSpace options: lOptions error: &lError ] )
    {
        if ( lError != nil )
        {
            LogError(@"%@", lError.localizedDescription );
            LogError(@"%@", lError.userInfo );
        }
    }
          
    CGColorSpaceRelease( lColorSpace );
}


#pragma mark EncodeCaptureOutputIntoH264
void EncodeCaptureOutputIntoH264( CMSampleBufferRef aSampleBuffer, VTCompressionSessionRef aCompressionSession )
{
    LogFunctionEntry();
    
    CVImageBufferRef lImageBuffer           = CMSampleBufferGetImageBuffer( aSampleBuffer );
    CMTime           lPresentationTimestamp = CMSampleBufferGetOutputPresentationTimeStamp( aSampleBuffer );
    VTCompressionSessionEncodeFrame( aCompressionSession
                                   , lImageBuffer
                                   , lPresentationTimestamp
                                   , kCMTimeInvalid
                                   , NULL
                                   , NULL
                                   , NULL );
}


#pragma mark -
#pragma mark AVVideoEncoding class

@interface AVVideoEncoding : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession         *mSession;
@property (nonatomic, strong) AVCaptureDevice          *mCamera;
@property (nonatomic, strong) AVCaptureInput           *mInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *mOutput;
@property (nonatomic, assign) VTCompressionSessionRef  mCompressionSession;

@property (nonatomic, strong) dispatch_queue_t mVideoDataOutputQueue;
@property (nonatomic, strong) dispatch_queue_t mSessionQueue;

@property (atomic) int mFrameCount;

@end

// Class Implementation

@implementation AVVideoEncoding


#pragma mark -
#pragma mark Initializer functions


#pragma mark init
- ( instancetype ) init
{
    LogFunctionEntry();

    self = [ super init ];
    if ( self )
    {
        if ( [ self InitCaptureDevice ])
        {
            [ self InitCaptureInput ];
            [ self InitCaptureOutput ];
            [ self InitCaptureSession ];
            [ self InitH264CompressionSession ];
        }
        else
        {
            return nil;
        }
    }

    return self;
}


#pragma mark InitCaptureDevice

- ( BOOL ) InitCaptureDevice
{
    LogFunctionEntry();

    NSMutableArray< AVCaptureDevice*>* lAllDevices = [[NSMutableArray alloc ] init ];
    GetCaptureDeviceWithType( lAllDevices, AVCaptureDeviceTypeBuiltInWideAngleCamera );
    GetCaptureDeviceWithType( lAllDevices, AVCaptureDeviceTypeExternalUnknown );

    unsigned long lDeviceCount = lAllDevices.count;
    
    if ( lDeviceCount == 0 )
    {
        LogError("No camera devices available");
        return false;
    }

    LogInfo(@"Number of available devices: %d", (int)lDeviceCount )

    for( AVCaptureDevice* lDevice in lAllDevices )
    {
        if ( lDevice != nil )
        {
            LogInfo(@"Camera device properties: \n Camera Device ID %@ \n Camera device name %@ \n Camera device manufacturer %@ \n Camera device unique ID %@", lDevice.modelID, lDevice.localizedName, lDevice.manufacturer, lDevice.uniqueID );
        }
    }

    unsigned long lCameraNumberToSelect = lDeviceCount;
    
    LogInfo("Selecting camera number %d in list.", (int)lCameraNumberToSelect );

    _mCamera = lAllDevices[lCameraNumberToSelect-1];

    LogInfo("Camera capabilities are as follows:");
    [ self GetCaps:_mCamera ];
    [ self ListVideoFormats:_mCamera];
    
    if ( _mCamera )
    {
        LogSuccess(@"Camera device added!");
    }
    else
    {
        LogError(@"No camera device to be added!");
        return false;
    }

    return true;
}


#pragma mark InitCaptureInput
- ( void ) InitCaptureInput
{
    LogFunctionEntry();

    NSError* lError = nil;
    BOOL lIsDeviceLockedForConfig = [ _mCamera lockForConfiguration:&lError];
    if ( lIsDeviceLockedForConfig )
    {
        LogInfo(@"Video device is locked for configuration");
        // configure device here
    }
    [ _mCamera unlockForConfiguration ];

    _mInput = [AVCaptureDeviceInput deviceInputWithDevice:_mCamera error:&lError];
    if( _mInput == nil )
    {
        LogError(@"Capture input can't be initialized!");
    }

    LogInfo(@"Capture input has been initialized.");
}


#pragma mark InitCaptureOutput
- ( void ) InitCaptureOutput
{
    LogFunctionEntry();

    _mOutput               = [ [ AVCaptureVideoDataOutput alloc ] init ];
    _mVideoDataOutputQueue = dispatch_queue_create( "video data output queue", DISPATCH_QUEUE_SERIAL );
    _mFrameCount           = 0;
    
    [ _mOutput setSampleBufferDelegate:self queue:self.mVideoDataOutputQueue];
    
    NSArray<AVVideoCodecType> *lAvailableVideoCodecTypes = [ _mOutput availableVideoCodecTypes ];
    
    for ( AVVideoCodecType lType in lAvailableVideoCodecTypes )
    {
        LogInfo("Available codec type: %@", lType);
    }
    
    AVCaptureConnection *lConnection = [ _mOutput connectionWithMediaType:AVMediaTypeVideo ];

    if (lConnection.isVideoMinFrameDurationSupported)
    {
        lConnection.videoMinFrameDuration = CMTimeMake(1, kMinCaptureFPS);
    }
        
    if (lConnection.isVideoMaxFrameDurationSupported)
    {
        lConnection.videoMaxFrameDuration = CMTimeMake(1, kMaxCaptureFPS);
    }
    
    if ([ _mSession canAddConnection:lConnection ])
    {
        LogSuccess("Adding connection to session.");
        [ _mSession addConnection:lConnection ];
    }
    else
    {
        LogError("Cannot add connection to session.");
    }

    LogInfo(@"Capture output has been initialized");
}


#pragma mark InitCaptureSession
- ( void ) InitCaptureSession
{
    LogFunctionEntry();
    _mSession = [ [ AVCaptureSession alloc ] init ];
    _mSession.sessionPreset = AVCaptureSessionPreset640x480;
    
    [ _mSession beginConfiguration ];
      
    [ self SetupCaptureSession ];

    [ _mSession commitConfiguration ];

    LogInfo(@"Capture session has been initialized");
}


#pragma mark InitH264CompressionSession
- (void) InitH264CompressionSession
{
    LogFunctionEntry();
    
    _mCompressionSession = nil;
    
    //https://developer.apple.com/documentation/videotoolbox/vtcompressionsession/compression_properties?language=objc
    
    CFDictionaryRef lEncoderSpecification = (__bridge CFDictionaryRef)@{ @"kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder" : @true
                                                                       , @"kVTCompressionPropertyKey_AverageBitRate" : @2000000
                                                                       , @"kVTCompressionPropertyKey_MaxH264SliceBytes" : @0
                                                                       , @"kVTCompressionPropertyKey_ProfileLevel":@"kVTProfileLevel_H264_Main_AutoLevel"
                                                                       , @"kVTCompressionPropertyKey_RealTime": @true };
    
    OSStatus lOSStatus = VTCompressionSessionCreate( nil
                                                   , kRawFrameWidth
                                                   , kRawFrameHeight
                                                   , kCMVideoCodecType_H264
                                                   , lEncoderSpecification
                                                   , nil
                                                   , kCFAllocatorDefault
                                                   , &ProcessH264Output
                                                   , nil
                                                   , &_mCompressionSession );
    
    if ( lOSStatus == noErr )
    {
        LogSuccess("Compression session has been created successfully!");
    }
    else
    {
        LogError("Couldn't create compression session!");
    }
}


#pragma mark -
#pragma mark captureOutput
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    LogFunctionEntry();
    
    if ( captureOutput == _mOutput )
    {
        // SaveCaptureOutputToFile( sampleBuffer, _mFrameCount );
        EncodeCaptureOutputIntoH264( sampleBuffer, _mCompressionSession );
        
        _mFrameCount += 1;
    }
}


#pragma mark IsErrorSession
- (void) IsErrorSession: (NSNotification *) notification
{
    LogFunctionEntry();

    NSError *lError = notification.userInfo[ AVCaptureSessionErrorKey ];
    LogError(@"%@", lError.localizedDescription);
}


#pragma mark SetupCaptureSession
- (void) SetupCaptureSession
{
    LogFunctionEntry();

    if ( [ _mSession canAddInput:_mInput ] )
    {
        LogInfo("Can add video input");
        [ _mSession addInput:_mInput ];
    }

    if ([ _mSession canAddOutput:_mOutput ] )
    {
        LogInfo("Can add video output");
        [ _mSession addOutput : _mOutput ];
    }

    NSString* lSessionPreset = AVCaptureSessionPreset640x480;
    if ( [ _mSession canSetSessionPreset:lSessionPreset ] )
    {
        [ _mSession setSessionPreset:lSessionPreset ];
    }

    [ [ NSNotificationCenter defaultCenter ]
        addObserver: self
        selector:    @selector( IsErrorSession: )
        name:        AVCaptureSessionRuntimeErrorNotification
        object:      nil
    ];
}

#pragma mark GetCaps
-(void) GetCaps:(AVCaptureDevice*)aDevice
{
    LogFunctionEntry();

    if ( [aDevice hasMediaType:AVMediaTypeVideo])
    {
        [self GetVideoCaps:aDevice];
    }
     
    if ( [aDevice hasMediaType:AVMediaTypeAudio])
    {
        // @todo!
    }
}
 

#pragma mark GetVideoCaps
-(void) GetVideoCaps:(AVCaptureDevice*)aDevice
{
    LogFunctionEntry();

    printf( "  Caps:\n" );
    printf( "    Focus modes:\n" );
    printf( "      Locked: %s\n", [aDevice isFocusModeSupported:AVCaptureFocusModeLocked] ? "YES" : "NO" );
    printf( "      AutoFocus: %s\n", [aDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus] ? "YES" : "NO" );
    printf( "      ContinuousAutoFocus: %s\n", [aDevice isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] ? "YES" : "NO" );
     
    printf( "      PointOfInterest: %s\n", [aDevice isFocusPointOfInterestSupported] ? "YES" : "NO" );
     
    printf( "    Exposure mode:\n" );
    printf( "      Locked: %s\n",               [aDevice isExposureModeSupported:AVCaptureExposureModeLocked                ] ? "YES" : "NO" );
    printf( "      AutoExpose: %s\n",           [aDevice isExposureModeSupported:AVCaptureExposureModeAutoExpose            ] ? "YES" : "NO" );
    printf( "      ContinouosAutoExpose: %s\n", [aDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] ? "YES" : "NO" );
     
    printf( "    Flash:\n" );
    printf( "      HasFlash: %s\n", [aDevice hasFlash] ? "YES" : "NO" );
    printf( "        On  : %s\n",   [aDevice isFlashModeSupported:AVCaptureFlashModeOn  ] ? "YES" : "NO" );
    printf( "        Off : %s\n",   [aDevice isFlashModeSupported:AVCaptureFlashModeOff ] ? "YES" : "NO" );
    printf( "        Auto: %s\n",   [aDevice isFlashModeSupported:AVCaptureFlashModeAuto] ? "YES" : "NO" );
     
    printf( "    Torch:\n" );
    printf( "      HasTorch: %s\n", [aDevice hasTorch] ? "YES" : "NO" );
    printf( "        On  : %s\n",   [aDevice isTorchModeSupported:AVCaptureTorchModeOn  ] ? "YES" : "NO" );
    printf( "        Off : %s\n",   [aDevice isTorchModeSupported:AVCaptureTorchModeOff ] ? "YES" : "NO" );
    printf( "        Auto: %s\n",   [aDevice isTorchModeSupported:AVCaptureTorchModeAuto] ? "YES" : "NO" );
     
    printf( "    Transport Controls: %s\n", [aDevice transportControlsSupported] ? "YES" : "NO" );
}
 

#pragma mark ListVideoFormats
-(void) ListVideoFormats:(AVCaptureDevice*)aDevice
{
    LogFunctionEntry();

    int i = 0;
    for ( AVCaptureDeviceFormat* lFormat in [aDevice formats] )
    {
        NSString* lFormatMediaType = [lFormat mediaType];
         
        printf( "  %d. format: %s\n", i, [lFormatMediaType UTF8String] );
         
        if ( [lFormatMediaType compare:AVMediaTypeVideo] == NSOrderedSame )
        {
            CMFormatDescriptionRef lFormatDescription = [lFormat formatDescription];
             
            CMMediaType lMediaType = CMFormatDescriptionGetMediaType( lFormatDescription );
            if ( lMediaType == kCMMediaType_Video )
            {
                CMVideoFormatDescriptionRef lVideoFormatDesc = (CMVideoFormatDescriptionRef)lFormatDescription;
 
                CMVideoDimensions           lVideoDimensions = CMVideoFormatDescriptionGetDimensions( lVideoFormatDesc );
                printf( "    Resolution: %d x %d\n", lVideoDimensions.width, lVideoDimensions.height );
                 
                FourCharCode lCodecType = CMVideoFormatDescriptionGetCodecType( lVideoFormatDesc );
                if ( lCodecType == kCMVideoCodecType_JPEG_OpenDML )
                {
                    printf( "        CodecType: JPEG OpenDML\n" );
                }
 
                NSArray* lFrameRateRanges = [lFormat videoSupportedFrameRateRanges];
                for ( AVFrameRateRange* lFrameRateRange in lFrameRateRanges )
                {
                    printf( "      frame rate: %f - %f\n", [lFrameRateRange minFrameRate], [lFrameRateRange maxFrameRate] );
                }
            }
        }
         
        i++;
    }
}


#pragma mark StartCaptureOnThread
- ( void )StartCaptureOnThread
{
    LogFunctionEntry();
    
    _mSessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
    
    dispatch_async( _mSessionQueue
                  , ^(void)
                    {
                        if ( self.mSession != nil )
                        {
                            LogInfo("Capture session is starting up.")
                            [ self.mSession startRunning ];
                        }
                    } );
}

@end


#pragma mark -
#pragma mark main
int main(int argc, const char * argv[])
{
    AVVideoEncoding* lVideoEncoding = [ [ AVVideoEncoding alloc ] init ];
    [ lVideoEncoding StartCaptureOnThread ];
  
    return NSApplicationMain(argc, argv);
}
