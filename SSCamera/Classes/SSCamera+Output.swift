import AVFoundation
import Photos
extension SSCamera{
    func _setupOutputMode(_ newCameraOutputMode: SSCameraOutputMode, oldCameraOutputMode: SSCameraOutputMode?) {
        captureSession?.beginConfiguration()
        
        if let cameraOutputToRemove = oldCameraOutputMode {
            // remove current setting
            switch cameraOutputToRemove {
                case .stillImage:
                    if let validStillImageOutput = stillImageOutput {
                        captureSession?.removeOutput(validStillImageOutput)
                }
                case .videoOnly, .videoWithMic:
                    if let validMovieOutput = movieOutput {
                        captureSession?.removeOutput(validMovieOutput)
                    }
                    if cameraOutputToRemove == .videoWithMic {
                        _removeMicInput()
                }
            }
        }
        
        _setupOutputs()
        
        // configure new devices
        switch newCameraOutputMode {
            case .stillImage:
                let validStillImageOutput = _getStillImageOutput()
                if let captureSession = captureSession,
                    captureSession.canAddOutput(validStillImageOutput) {
                    captureSession.addOutput(validStillImageOutput)
            }
            case .videoOnly, .videoWithMic:
                let videoMovieOutput = _getMovieOutput()
                if let captureSession = captureSession,
                    captureSession.canAddOutput(videoMovieOutput) {
                    captureSession.addOutput(videoMovieOutput)
                }
                
                if newCameraOutputMode == .videoWithMic,
                    let validMic = _deviceInputFromDevice(mic) {
                    captureSession?.addInput(validMic)
            }
        }
        captureSession?.commitConfiguration()
        _updateCameraQualityMode(cameraOutputQuality)
        _orientationChanged()
    }
    
    func _setupOutputs() {
        if stillImageOutput == nil {
            stillImageOutput = AVCaptureStillImageOutput()
        }
        if movieOutput == nil {
            movieOutput = _getMovieOutput()
        }
        if library == nil {
            library = PHPhotoLibrary.shared()
        }
    }
    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured imageData
     */
    open func capturePictureDataWithCompletion(_ imageCompletion: @escaping (SSCaptureResult) -> Void) {
        guard cameraIsSetup else {
            _show(NSLocalizedString("No capture session setup", comment: ""), message: NSLocalizedString("I can't take any picture", comment: ""))
            return
        }
        
        guard cameraOutputMode == .stillImage else {
            _show(NSLocalizedString("Capture session output mode video", comment: ""), message: NSLocalizedString("I can't take any picture", comment: ""))
            return
        }
        
        _updateIlluminationMode(flashMode)
        
        sessionQueue.async {
            let stillImageOutput = self._getStillImageOutput()
            if let connection = stillImageOutput.connection(with: AVMediaType.video),
                connection.isEnabled {
                if self.cameraDevice == SSCameraDevice.front, connection.isVideoMirroringSupported,
                    self.shouldFlipFrontCameraImage {
                    connection.isVideoMirrored = true
                }
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = self._currentCaptureVideoOrientation()
                }
                
                stillImageOutput.captureStillImageAsynchronously(from: connection, completionHandler: { [weak self] sample, error in
                    
                    if let error = error {
                        self?._show(NSLocalizedString("Error", comment: ""), message: error.localizedDescription)
                        imageCompletion(.failure(error))
                        return
                    }
                    
                    guard let sample = sample else { imageCompletion(.failure(SSCaptureError.noSampleBuffer)); return }
                    if let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample) {
                        imageCompletion(SSCaptureResult(imageData))
                    } else {
                        imageCompletion(.failure(SSCaptureError.noImageData))
                    }
                    
                })
            } else {
                imageCompletion(.failure(SSCaptureError.noVideoConnection))
            }
        }
    }
    /**
     Captures still image from currently running capture session.
     
     :param: imageCompletion Completion block containing the captured UIImage
     */
    open func capturePictureWithCompletion(_ imageCompletion: @escaping (SSCaptureResult) -> Void) {
        capturePictureDataWithCompletion { result in
            
            guard let imageData = result.imageData else {
                if case let .failure(error) = result {
                    imageCompletion(.failure(error))
                } else {
                    imageCompletion(.failure(SSCaptureError.noImageData))
                }
                
                return
            }
            
            if self.animateShutter {
                self._performShutterAnimation {
                    self._capturePicture(imageData, imageCompletion)
                }
            } else {
                self._capturePicture(imageData, imageCompletion)
            }
        }
    }
    
    func _capturePicture(_ imageData: Data, _ imageCompletion: @escaping (SSCaptureResult) -> Void) {
        guard let img = UIImage(data: imageData) else {
            imageCompletion(.failure(NSError()))
            return
        }
        
        let image = fixOrientation(withImage: img)
        let newImageData = _imageDataWithEXIF(forImage: image, imageData)! as Data
        
        if writeFilesToPhoneLibrary {
            let filePath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempImg\(Int(Date().timeIntervalSince1970)).jpg")
            
            do {
                try newImageData.write(to: filePath)
                
                // make sure that doesn't fail the first time
                if PHPhotoLibrary.authorizationStatus() != .authorized {
                    PHPhotoLibrary.requestAuthorization { status in
                        if status == PHAuthorizationStatus.authorized {
                            self._saveImageToLibrary(atFileURL: filePath, imageCompletion)
                        }
                    }
                } else {
                    _saveImageToLibrary(atFileURL: filePath, imageCompletion)
                }
                
            } catch {
                imageCompletion(.failure(error))
                return
            }
        }
        
        imageCompletion(SSCaptureResult(newImageData))
    }
    
    
    func _getMovieOutput() -> AVCaptureMovieFileOutput {
        if movieOutput == nil {
            _createMovieOutput()
        }
        
        return movieOutput!
    }
    
    func _createMovieOutput() {
        
        let newMovieOutput = AVCaptureMovieFileOutput()
        newMovieOutput.movieFragmentInterval = CMTime.invalid

        movieOutput = newMovieOutput
        
        _setupVideoConnection()
        
        if let captureSession = captureSession, captureSession.canAddOutput(newMovieOutput) {
            captureSession.beginConfiguration()
            captureSession.addOutput(newMovieOutput)
            captureSession.commitConfiguration()
        }
    }
    
    func _setupVideoConnection() {
        if let movieOutput = movieOutput {
            for connection in movieOutput.connections {
                for port in connection.inputPorts {
                    if port.mediaType == AVMediaType.video {
                        let videoConnection = connection as AVCaptureConnection
                        // setup video mirroring
                        if videoConnection.isVideoMirroringSupported {
                            videoConnection.isVideoMirrored = (cameraDevice == SSCameraDevice.front && shouldFlipFrontCameraImage)
                        }

                        if videoConnection.isVideoStabilizationSupported {
                            videoConnection.preferredVideoStabilizationMode = videoStabilisationMode
                        }
                    }
                }
            }
        }
    }

    func _getStillImageOutput() -> AVCaptureStillImageOutput {
        if let stillImageOutput = stillImageOutput, let connection = stillImageOutput.connection(with: AVMediaType.video),
            connection.isActive {
            return stillImageOutput
        }
        let newStillImageOutput = AVCaptureStillImageOutput()
        stillImageOutput = newStillImageOutput
        if let captureSession = captureSession,
            captureSession.canAddOutput(newStillImageOutput) {
            captureSession.beginConfiguration()
            captureSession.addOutput(newStillImageOutput)
            captureSession.commitConfiguration()
        }
        return newStillImageOutput
    }
}
extension SSCamera:AVCaptureFileOutputRecordingDelegate{
    // MARK: - AVCaptureFileOutputRecordingDelegate
    
    public func fileOutput(_: AVCaptureFileOutput, didStartRecordingTo _: URL, from _: [AVCaptureConnection]) {
        captureSession?.beginConfiguration()
        if flashMode != .off {
            _updateIlluminationMode(flashMode)
        }
        
        captureSession?.commitConfiguration()
    }
    
    open func fileOutput(_: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from _: [AVCaptureConnection], error: Error?) {
        if let error = error {
            _show(NSLocalizedString("Unable to save video to the device", comment: ""), message: error.localizedDescription)
        } else {
            if writeFilesToPhoneLibrary {
                if PHPhotoLibrary.authorizationStatus() == .authorized {
                    _saveVideoToLibrary(outputFileURL)
                } else {
                    PHPhotoLibrary.requestAuthorization { autorizationStatus in
                        if autorizationStatus == .authorized {
                            self._saveVideoToLibrary(outputFileURL)
                        }
                    }
                }
            } else {
                _executeVideoCompletionWithURL(outputFileURL, error: error as NSError?)
            }
        }
    }
}
