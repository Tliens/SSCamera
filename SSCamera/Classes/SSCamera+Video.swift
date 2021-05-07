import Foundation
import AVFoundation

extension SSCamera{
    /**
     Starts recording a video with or without voice as in the session preset.
     */
    open func startRecordingVideo() {
        guard cameraOutputMode != .stillImage else {
            _show(NSLocalizedString("Capture session output still image", comment: ""), message: NSLocalizedString("I can only take pictures", comment: ""))
            return
        }
    
        let videoOutput = _getMovieOutput()
        
        if shouldUseLocationServices {
            
            let specs = [kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: AVMetadataIdentifier.quickTimeMetadataLocationISO6709,
                         kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String] as [String: Any]
            
            var locationMetadataDesc: CMFormatDescription?
            CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: [specs] as CFArray, formatDescriptionOut: &locationMetadataDesc)
            
            // Create the metadata input and add it to the session.
            guard let captureSession = captureSession, let locationMetadata = locationMetadataDesc else {
                return
            }
            
            let newLocationMetadataInput = AVCaptureMetadataInput(formatDescription: locationMetadata, clock: CMClockGetHostTimeClock())
            captureSession.addInputWithNoConnections(newLocationMetadataInput)
            
            // Connect the location metadata input to the movie file output.
            let inputPort = newLocationMetadataInput.ports[0]
            captureSession.addConnection(AVCaptureConnection(inputPorts: [inputPort], output: videoOutput))
            
        }

        _updateIlluminationMode(flashMode)
        
        videoOutput.startRecording(to: _tempFilePath(), recordingDelegate: self)
    }
    
    /**
     Stop recording a video. Save it to the cameraRoll and give back the url.
     */
    open func stopVideoRecording(_ completion: ((_ videoURL: URL?, _ error: NSError?) -> Void)?) {
        if let runningMovieOutput = movieOutput,
            runningMovieOutput.isRecording {
            videoCompletion = completion
            runningMovieOutput.stopRecording()
        }
    }
    
    
    
    func _saveVideoToLibrary(_ fileURL: URL) {
        let location = locationManager?.latestLocation
        let date = Date()
        
        library?.save(videoAtURL: fileURL, albumName: videoAlbumName, date: date, location: location, completion: { _ in
            self._executeVideoCompletionWithURL(fileURL, error: nil)
        })
    }
    
    func _executeVideoCompletionWithURL(_ url: URL?, error: NSError?) {
        if let validCompletion = videoCompletion {
            validCompletion(url, error)
            videoCompletion = nil
        }
    }
    func _removeMicInput() {
        guard let inputs = captureSession?.inputs else { return }
        
        for input in inputs {
            if let deviceInput = input as? AVCaptureDeviceInput,
                deviceInput.device == mic {
                captureSession?.removeInput(deviceInput)
                break
            }
        }
    }
}
