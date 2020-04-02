#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Foundation/Foundation.h>

// compile command: clang -framework Foundation -framework AVFoundation AVFoundationProto.m -o codec

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

// Logger Macros

#define LogError(aMessage, ...) NSLog((@"ERROR:             [Line %d] " aMessage ),     __LINE__, ## __VA_ARGS__);
#define LogInfo(aMessage, ...) NSLog((@"INFO:              [Line %d] " aMessage ), __LINE__, ## __VA_ARGS__);
#define LogSuccess(aMessage, ...) NSLog((@"SUCCESS:           [Line %d] " aMessage ), __LINE__, ## __VA_ARGS__);
#define LogFunctionEntry(aMessage, ...) NSLog((@"Entering function: %s" aMessage ), __PRETTY_FUNCTION__, ## __VA_ARGS__)

// Class Interface

@interface AVVideoEncoding : NSObject

@property (nonatomic, strong) AVCaptureSession *mSession;
@property (nonatomic, strong) AVCaptureDevice  *mCamera;
@property (nonatomic, strong) AVCaptureInput   *mInput;
@property (nonatomic, strong) AVCaptureMovieFileOutput  *mOutput;

@property (nonatomic, strong) dispatch_queue_t mVideoDataOutputQueue;
@property (nonatomic, strong) dispatch_queue_t mSessionQueue;

@end

// Class Implementation

@implementation AVVideoEncoding


- ( instancetype ) init
{
    LogFunctionEntry();

    self = [ super init ];
    if ( self )
    {
        [ self InitCaptureDevice ];
        [ self InitCaptureInput ];
        [ self InitCaptureOutput ];
        [ self InitCaptureSession ];
    }

    return self;
}


#pragma mark -
#pragma mark AVFoundation Setup

- ( void ) GetCaptureDeviceWithType: (NSMutableArray< AVCaptureDevice*>*) aArray deviceType:(AVCaptureDeviceType) aType
{
    AVCaptureDeviceDiscoverySession* lCaptureDeviceDiscoverySession = [ AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[ aType ] 
                                                                        mediaType:AVMediaTypeVideo 
                                                                        position:AVCaptureDevicePositionBack ];
    NSArray< AVCaptureDevice*>* lDevices = [ lCaptureDeviceDiscoverySession devices ];

    for( AVCaptureDevice* lDevice in lDevices )
    {
        [ aArray addObject:lDevice ];
    }
}

- ( void ) InitCaptureDevice
{
    LogFunctionEntry();

    NSMutableArray< AVCaptureDevice*>* lAllDevices = [[NSMutableArray alloc ] init ];
    [ self GetCaptureDeviceWithType: lAllDevices deviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera ];
    [ self GetCaptureDeviceWithType: lAllDevices deviceType:AVCaptureDeviceTypeExternalUnknown ];

    int lDeviceCount = lAllDevices.count;
    
    if ( lDeviceCount == 0 )
    {
        LogError("No camera devices available");
        return;
    }

    LogInfo(@"Number of available devices: %d", lDeviceCount )

    for( AVCaptureDevice* lDevice in lAllDevices )
    {
        if ( lDevice != nil )
        {
            LogInfo(@"Camera device properties: \n Camera Device ID %@ \n Camera device name %@ \n Camera device manufacturer %@ \n Camera device unique ID %@", lDevice.modelID, lDevice.localizedName, lDevice.manufacturer, lDevice.uniqueID );
        }
    }

    LogInfo("Selecting last camera in list.");

    self.mCamera = lAllDevices[lDeviceCount-1];

    LogInfo("Camera capabilities are as follows:");
    [ self GetCaps:self.mCamera ];

    if ( self.mCamera )
    {
        LogSuccess(@"Camera device added!");
    }
    else
    {
        LogError(@"No camera device to be added!");
    }

    LogInfo(@"Capture device has been initialized");
}


- ( void ) InitCaptureInput
{
    LogFunctionEntry();

    NSError* lError = nil;
    BOOL lIsDeviceLockedForConfig = [ self.mCamera lockForConfiguration:&lError];
    if ( lIsDeviceLockedForConfig )
    {
        LogInfo(@"Video device is locked for configuration");
        // configure device here
    }
    [ self.mCamera unlockForConfiguration ];

    self.mInput = [AVCaptureDeviceInput deviceInputWithDevice:self.mCamera error:&lError];
    if( self.mInput == nil )
    {
        LogError(@"Capture input can't be initialized: @");
    }

    LogInfo(@"Capture input has been initialized");
}

- ( void ) InitCaptureOutput
{
    LogFunctionEntry();

    self.mOutput = [ [ AVCaptureMovieFileOutput alloc ] init ];
 
    AVCaptureConnection *lConnection = [ self.mOutput connectionWithMediaType:AVMediaTypeVideo ];
    
    [ self.mOutput setOutputSettings:@{ AVVideoCodecKey: AVVideoCodecTypeH264 } forConnection:lConnection ];

    LogInfo( @"Getting output settings..." );
    NSDictionary<NSString*, id>* lSupportedSettings = [ self.mOutput outputSettingsForConnection:lConnection ];
    int lDictSize = [ lSupportedSettings count ];
    LogInfo( @"Number of output settings: %d", lDictSize );
    for ( id iKey in lSupportedSettings )
    {
        LogInfo( @"Supported setting key: %p", iKey );
    }

    LogInfo(@"Capture output has been initialized");
}

- ( void ) InitCaptureSession
{
    LogFunctionEntry();
    self.mSession = [ [ AVCaptureSession alloc ] init ];
   
    [ self.mSession beginConfiguration ];
      
    [ self SetupCaptureSession ];

    [ self.mSession commitConfiguration ];

    LogInfo(@"Capture session has been initialized");
}

- (BOOL) CheckForMediaAuthorizationStatus
{
    LogFunctionEntry();

    switch ( [ AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo ] )
    {
        case AVAuthorizationStatusAuthorized:
        {
            LogSuccess(@"Authorization status: Authorized!");
            return true;
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            LogError(@"Authorization status not determined!");
            [ AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler: ^( BOOL bGranted )
            {
                if ( bGranted )
                {
                    return;
                }
            } ];
            break;
        }
        case AVAuthorizationStatusDenied:
        {
            LogError(@"The user previously has denied access!");
            return false;
        }
        case AVAuthorizationStatusRestricted:
        {
            LogError(@"The user cannot grant access due to restrictions!");
            return false;
        }
    }

    return false;
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

    self.mSessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );

    if ( [ self.mSession canAddInput:self.mInput ] )
    {
        LogInfo("Can add video input");
        [ self.mSession addInput:self.mInput ];
    }

    if ([ self.mSession canAddOutput:self.mOutput ] )
    {
        LogInfo("Can add video output");
        [ self.mSession addOutput : self.mOutput ];
    }

    NSString* lSessionPreset = AVCaptureSessionPreset640x480;
    if ( [ self.mSession canSetSessionPreset:lSessionPreset ] )
    {
        [ self.mSession setSessionPreset:lSessionPreset ];
    }

    [ [ NSNotificationCenter defaultCenter ]
        addObserver: self
        selector:    @selector( IsErrorSession: )
        name:        AVCaptureSessionRuntimeErrorNotification
        object:      nil
    ];
}


/*!
 * Get the capability list of the given device
 *
 * \param  aDevice  The given device to get the capability list from
 */
-(void) GetCaps:(AVCaptureDevice*)aDevice
{
    if ( [aDevice hasMediaType:AVMediaTypeVideo])
    {
        [self GetVideoCaps:aDevice];
    }
     
    if ( [aDevice hasMediaType:AVMediaTypeAudio])
    {
        // @todo!
    }
}
 
/*!
 * Get the video capabilities of the given device
 *
 * \param  aDevice  The given device to get the capability list from
 */
-(void) GetVideoCaps:(AVCaptureDevice*)aDevice
{
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
 
/*!
 * List the formats: supported resolutions and pixel format or codec type with the supported frame rates
 *
 * \param  aDevice  The given device to get the formats from
 */
-(void) ListVideoFormats:(AVCaptureDevice*)aDevice
{
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

@end


int main( int argc, char* argv[] )
{
    AVVideoEncoding* lVideoEncoding = [ [ AVVideoEncoding alloc ] init ];

    BOOL lIsCaptureAuthorized = [ lVideoEncoding CheckForMediaAuthorizationStatus ];

    if ( lIsCaptureAuthorized )
    {
        LogSuccess(@"Capture is authorized, we can setup capture session.");        
        dispatch_async( lVideoEncoding.mSessionQueue
                  , ^(void)
                    {
                        if ( lVideoEncoding.mSession != nil )
                        {
                            [ lVideoEncoding.mSession startRunning ];
                        }
                    } );
    }
    else
    {
        LogError(@"Capture is not authorized, stopping process.");
    }

    LogInfo(@"Ended");
    return 0;
}