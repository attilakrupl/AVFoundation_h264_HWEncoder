import AVFoundation



      let captureSession = AVCaptureSession()
guard let videoDevice    = AVCaptureDevice.default(for: .video) 
else 
{ 
    // Unable to wrap device
}
do 
{
    // Wrap the video device in a capture device input.
    let videoInput = try AVCaptureDeviceInput( device: videoDevice )
    // If the input can be added, add it to the session.
    if captureSession.canAddInput( videoInput ) 
    {
        captureSession.addInput( videoInput )
    }
} 
catch 
{
    // Configuration failed. Handle error.
}

let lMovieFileOutput = AVCaptureMovieFileOutput()
let lConnection      = lMovieFileOutput.connection( with: .video ) 
/* if lMovieFileOutput.availableVideoCodecTypes.contains( .h264 )
{
    lMovieFileOutput.setOutputSettings( [ AVVideoCodecKey: AVVideoCodecType.h264 ], for: lConnection! )
} */

