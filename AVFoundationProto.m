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
@property (nonatomic, strong) AVCaptureOutput  *mOutput;

@property (nonatomic, strong) dispatch_queue_t mVideoDataOutputQueue;
@property (nonatomic, strong) dispatch_queue_t mSessionQueue;

// - (BOOL)CheckForMediaAuthorizationStatus;
// - (void)SetupCaptureSession;
// - (void)IsErrorSession:( NSNotification* ) notification;
@end

// Class Implementation

@implementation AVVideoEncoding


- ( instancetype ) init
{
    LogFunctionEntry();

    self = [ super init ];
    if ( self )
    {
        [ self InitCaptureInput ];
        [ self InitCaptureOutput ];
        [ self InitCaptureDevice ];
        [ self InitCaptureSession ];
    }

    return self;
}


#pragma mark -
#pragma mark AVFoundation Setup

- ( void ) InitCaptureInput
{
    LogFunctionEntry();

    AVCaptureDevice* lVideoDevice = [ AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo ];
    NSError*         lError       = nil;

    BOOL lIsDeviceLockedForConfig = [ lVideoDevice lockForConfiguration:&lError];
    if ( lIsDeviceLockedForConfig )
    {
        LogInfo(@"Video device is locked for configuration");
        // configure device here
    }
    [ lVideoDevice unlockForConfiguration ];

    self.mInput = [AVCaptureDeviceInput deviceInputWithDevice:lVideoDevice error:&lError];
    LogInfo(@"Capture input has been initialized");
}

- ( void ) InitCaptureOutput
{
    LogFunctionEntry();

    self.mOutput = [ [ AVCaptureMovieFileOutput alloc ] init ];

    LogInfo(@"Capture output has been initialized");
}

- ( void ) InitCaptureDevice
{
    LogFunctionEntry();

    AVCaptureDeviceDiscoverySession* lCaptureDeviceDiscoverySession = [ AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera ] 
                                                                        mediaType:AVMediaTypeVideo 
                                                                        position:AVCaptureDevicePositionBack ];
    NSArray< AVCaptureDevice*>* lDevices = [ lCaptureDeviceDiscoverySession devices ];
    
    int lDeviceCount = lDevices.count;
    LogInfo(@"Number of available devices: %d", lDeviceCount )

    for(AVCaptureDevice* lDevice in lDevices )
    {
        LogInfo(@"Camera device properties: \n\t\t\t\t\t\t\t\t\t Camera Device ID %@ \n\t\t\t\t\t\t\t\t\t Camera device name %@ \n\t\t\t\t\t\t\t\t\t Camera device manufacturer %@ \n\t\t\t\t\t\t\t\t\t Camera device unique ID %@", lDevice.modelID, lDevice.localizedName, lDevice.manufacturer, lDevice.uniqueID );
    }

    self.mCamera = lDevices[0];
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

- ( void ) InitCaptureSession
{
    LogFunctionEntry();
    self.mSession = [ [ AVCaptureSession alloc ] init ];
   
    [ self.mSession addInput  : self.mInput ];    
    [ self.mSession addOutput : self.mOutput ];
        
    [ self SetupCaptureSession ];

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

    _mSessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );

    if ( [ self.mSession canAddInput:self.mInput ] )
    {
        LogInfo(@"Can add video input");
        [ self.mSession addInput:self.mInput ];
    }

    AVCaptureMovieFileOutput* lMovieFileOutput = [ [ AVCaptureMovieFileOutput alloc ] init ];
    AVCaptureConnection*      lConnection      = [ lMovieFileOutput connectionWithMediaType:AVMediaTypeVideo ];
    
    [ lMovieFileOutput setOutputSettings:@{ AVVideoCodecKey: AVVideoCodecTypeH264 } forConnection:lConnection ];

    LogInfo( @"Getting output settings..." );
    NSDictionary<NSString*, id>* lSupportedSettings = [ lMovieFileOutput outputSettingsForConnection:lConnection ];
    int lDictSize = [ lSupportedSettings count ];
    LogInfo( @"Number of output settings: %d", lDictSize );

    for ( id iKey in lSupportedSettings )
    {
        LogInfo( @"Supported setting key: %p", iKey );
    }

    if ( [ self.mSession canAddOutput:lMovieFileOutput ] )
    {
        LogSuccess(@"Can add video output");
        [ self.mSession beginConfiguration ];
        self.mSession.sessionPreset = @"AVCaptureSessionPreset1280x720";
        [ self.mSession addOutput:lMovieFileOutput ];
        [ self.mSession commitConfiguration ];
    }

    [ [ NSNotificationCenter defaultCenter ]
        addObserver: self
        selector:    @selector( IsErrorSession: )
        name:        AVCaptureSessionRuntimeErrorNotification
        object:      nil
    ];

    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0 ), ^{
        [ self.mSession startRunning ];
        LogInfo(@"Whithin dispatch async after start running");
    });

        LogInfo(@"Dispatch async done!");
}

@end


int main( int argc, char* argv[] )
{
    AVVideoEncoding* lVideoEncoding = [ [ AVVideoEncoding alloc ] init ];

    BOOL lIsCaptureAuthorized = [ lVideoEncoding CheckForMediaAuthorizationStatus ];

    if ( lIsCaptureAuthorized )
    {
        LogSuccess(@"Capture is authorized, we can setup capture session.");
        [ lVideoEncoding.mSession startRunning ];
    }
    else
    {
        LogError(@"Capture is not authorized, stopping process.");
    }

    LogInfo(@"Ended");
    return 0;
}