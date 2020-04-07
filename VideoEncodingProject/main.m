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

// compile command: clang -framework Foundation -framework AVFoundation AVFoundationProto.m -framework CoreMedia -o codec

// Useful links:
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

// Logger Macros

#define LogError(aMessage, ...) NSLog((@"ERROR:             [Line %d] " aMessage ),     __LINE__, ## __VA_ARGS__);
#define LogInfo(aMessage, ...) NSLog((@"INFO:              [Line %d] " aMessage ), __LINE__, ## __VA_ARGS__);
#define LogSuccess(aMessage, ...) NSLog((@"SUCCESS:           [Line %d] " aMessage ), __LINE__, ## __VA_ARGS__);
#define LogFunctionEntry(aMessage, ...) NSLog((@"Entering function: %s" aMessage ), __PRETTY_FUNCTION__, ## __VA_ARGS__)

// Class Interface

@interface AVVideoEncoding : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *mSession;
@property (nonatomic, strong) AVCaptureDevice  *mCamera;
@property (nonatomic, strong) AVCaptureInput   *mInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput  *mOutput;

@property (nonatomic, strong) dispatch_queue_t mVideoDataOutputQueue;
@property (nonatomic, strong) dispatch_queue_t mSessionQueue;

@property (atomic) int mFrameCount;

@property (nullable) NSError *mError;

@end

// Class Implementation

@implementation AVVideoEncoding


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
        }
        else
        {
            return nil;
        }
    }

    return self;
}


#pragma mark -
#pragma mark AVFoundation Setup

- ( void ) GetCaptureDeviceWithType: (NSMutableArray< AVCaptureDevice*>*) aArray deviceType:(AVCaptureDeviceType) aType
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

- ( BOOL ) InitCaptureDevice
{
    LogFunctionEntry();

    NSMutableArray< AVCaptureDevice*>* lAllDevices = [[NSMutableArray alloc ] init ];
    [ self GetCaptureDeviceWithType: lAllDevices deviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera ];
    [ self GetCaptureDeviceWithType: lAllDevices deviceType:AVCaptureDeviceTypeExternalUnknown ];

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

- (void)SaveCaptureOutputToFile:(CMSampleBufferRef)aSampleBuffer
{
    LogFunctionEntry();
    
    CVImageBufferRef imageBuffer    = CMSampleBufferGetImageBuffer( aSampleBuffer );
    CIImage         *ciImage        = [CIImage imageWithCVPixelBuffer:imageBuffer];
    
    LogInfo( "Image extent will be h: %f, w: %f, x: %f, y: %f", ciImage.extent.size.height, ciImage.extent.size.width, ciImage.extent.origin.x, ciImage.extent.origin.y );
    
    NSString        *lPathComponent = [NSString stringWithFormat:@"file:///Users/attila.krupl/Pictures/Image%d.jpeg", _mFrameCount];
    
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


- (void)EncodeCaptureOutputIntoH264:(CMSampleBufferRef)aSampleBuffer
{
    LogFunctionEntry();
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    LogFunctionEntry();
    
    if ( captureOutput == _mOutput )
    {
        [ self SaveCaptureOutputToFile: sampleBuffer ];
        [ self EncodeCaptureOutputIntoH264: sampleBuffer ];
        _mFrameCount += 1;
    }
}


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

//    [ _mOutput setOutputSettings:@{ AVVideoCodecKey: AVVideoCodecTypeH264 } forConnection:lConnection ];

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

- ( void ) InitCaptureSession
{
    LogFunctionEntry();
    _mSession = [ [ AVCaptureSession alloc ] init ];
    _mSession.sessionPreset = AVCaptureSessionPresetMedium;
    
    [ _mSession beginConfiguration ];
      
    [ self SetupCaptureSession ];

    [ _mSession commitConfiguration ];

    LogInfo(@"Capture session has been initialized");
}


- (void) IsErrorSession: (NSNotification *) notification
{
    LogFunctionEntry();

    NSError *lError = notification.userInfo[ AVCaptureSessionErrorKey ];
    LogError(@"%@", lError.localizedDescription);
}


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


int main(int argc, const char * argv[])
{
    AVVideoEncoding* lVideoEncoding = [ [ AVVideoEncoding alloc ] init ];
    [ lVideoEncoding StartCaptureOnThread ];
  
    return NSApplicationMain(argc, argv);
}
