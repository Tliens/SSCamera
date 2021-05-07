import CoreMotion
import AVFoundation

extension SSCamera{
    /**
     Check if the device rotation is locked
     */
    open func deviceOrientationMatchesInterfaceOrientation() -> Bool {
        return deviceOrientation == UIDevice.current.orientation
    }
    func _imageOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation, isMirrored: Bool) -> UIImage.Orientation {
        switch deviceOrientation {
            case .landscapeLeft:
                return isMirrored ? .upMirrored : .up
            case .landscapeRight:
                return isMirrored ? .downMirrored : .down
            default:
                break
        }
        
        return isMirrored ? .leftMirrored : .right
    }
    func _startFollowingDeviceOrientation() {
        if shouldRespondToOrientationChanges, !cameraIsObservingDeviceOrientation {
            coreMotionManager = CMMotionManager()
            coreMotionManager.deviceMotionUpdateInterval = 1 / 30.0
            if coreMotionManager.isDeviceMotionAvailable {
                coreMotionManager.startDeviceMotionUpdates(to: OperationQueue()) { motion, _ in
                    guard let motion = motion else { return }
                    let x = motion.gravity.x
                    let y = motion.gravity.y
                    let previousOrientation = self.deviceOrientation
                    if fabs(y) >= fabs(x) {
                        if y >= 0 {
                            self.deviceOrientation = .portraitUpsideDown
                        } else {
                            self.deviceOrientation = .portrait
                        }
                    } else {
                        if x >= 0 {
                            self.deviceOrientation = .landscapeRight
                        } else {
                            self.deviceOrientation = .landscapeLeft
                        }
                    }
                    if previousOrientation != self.deviceOrientation {
                        self._orientationChanged()
                    }
                }
                
                cameraIsObservingDeviceOrientation = true
            } else {
                cameraIsObservingDeviceOrientation = false
            }
        }
    }

    //    func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
    //        deviceOrientation = orientation
    //    }

    func _stopFollowingDeviceOrientation() {
        if cameraIsObservingDeviceOrientation {
            coreMotionManager.stopDeviceMotionUpdates()
            cameraIsObservingDeviceOrientation = false
        }
    }
    @objc func _orientationChanged() {
        var currentConnection: AVCaptureConnection?
        
        switch cameraOutputMode {
            case .stillImage:
                currentConnection = stillImageOutput?.connection(with: AVMediaType.video)
            case .videoOnly, .videoWithMic:
                currentConnection = _getMovieOutput().connection(with: AVMediaType.video)
                if let location = locationManager?.latestLocation {
                    _setVideoWithGPS(forLocation: location)
            }
        }
        
        if let validPreviewLayer = previewLayer {
            if !shouldKeepViewAtOrientationChanges {
                if let validPreviewLayerConnection = validPreviewLayer.connection,
                    validPreviewLayerConnection.isVideoOrientationSupported {
                    validPreviewLayerConnection.videoOrientation = _currentPreviewVideoOrientation()
                }
            }
            if let validOutputLayerConnection = currentConnection,
                validOutputLayerConnection.isVideoOrientationSupported {
                validOutputLayerConnection.videoOrientation = _currentCaptureVideoOrientation()
            }
            if !shouldKeepViewAtOrientationChanges && cameraIsObservingDeviceOrientation {
                DispatchQueue.main.async { () -> Void in
                    if let validEmbeddingView = self.embeddingView {
                        validPreviewLayer.frame = validEmbeddingView.bounds
                    }
                }
            }
        }
    }
    
    func _currentCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        if deviceOrientation == .faceDown
            || deviceOrientation == .faceUp
            || deviceOrientation == .unknown {
            return _currentPreviewVideoOrientation()
        }
        
        return _videoOrientation(forDeviceOrientation: deviceOrientation)
    }
    
    func _currentPreviewDeviceOrientation() -> UIDeviceOrientation {
        if shouldKeepViewAtOrientationChanges {
            return .portrait
        }
        
        return UIDevice.current.orientation
    }
    
    func _currentPreviewVideoOrientation() -> AVCaptureVideoOrientation {
        let orientation = _currentPreviewDeviceOrientation()
        return _videoOrientation(forDeviceOrientation: orientation)
    }
    
    open func resetOrientation() {
        // Main purpose is to reset the preview layer orientation.  Problems occur if you are recording landscape, present a modal VC,
        // then turn portriat to dismiss.  The preview view is then stuck in a prior orientation and not redrawn.  Calling this function
        // will then update the orientation of the preview layer.
        _orientationChanged()
    }
    
    func _videoOrientation(forDeviceOrientation deviceOrientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch deviceOrientation {
            case .landscapeLeft:
                return .landscapeRight
            case .landscapeRight:
                return .landscapeLeft
            case .portraitUpsideDown:
                return .portraitUpsideDown
            case .faceUp:
                /*
                 Attempt to keep the existing orientation.  If the device was landscape, then face up
                 getting the orientation from the stats bar would fail every other time forcing it
                 to default to portrait which would introduce flicker into the preview layer.  This
                 would not happen if it was in portrait then face up
                 */
                if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection {
                    return connection.videoOrientation // Keep the existing orientation
                }
                // Could not get existing orientation, try to get it from stats bar
                return _videoOrientationFromStatusBarOrientation()
            case .faceDown:
                /*
                 Attempt to keep the existing orientation.  If the device was landscape, then face down
                 getting the orientation from the stats bar would fail every other time forcing it
                 to default to portrait which would introduce flicker into the preview layer.  This
                 would not happen if it was in portrait then face down
                 */
                if let validPreviewLayer = previewLayer, let connection = validPreviewLayer.connection {
                    return connection.videoOrientation // Keep the existing orientation
                }
                // Could not get existing orientation, try to get it from stats bar
                return _videoOrientationFromStatusBarOrientation()
            default:
                return .portrait
        }
    }
    
    func _videoOrientationFromStatusBarOrientation() -> AVCaptureVideoOrientation {
        var orientation: UIInterfaceOrientation?
        
        DispatchQueue.main.async {
            orientation = UIApplication.shared.statusBarOrientation
        }
        
        /*
         Note - the following would fall into the guard every other call (it is called repeatedly) if the device was
         landscape then face up/down.  Did not seem to fail if in portrait first.
         */
        guard let statusBarOrientation = orientation else {
            return .portrait
        }
        
        switch statusBarOrientation {
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            case .portrait:
                return .portrait
            case .portraitUpsideDown:
                return .portraitUpsideDown
            default:
                return .portrait
        }
    }
    
    func fixOrientation(withImage image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        var isMirrored = false
        let orientation = image.imageOrientation
        if orientation == .rightMirrored
            || orientation == .leftMirrored
            || orientation == .upMirrored
            || orientation == .downMirrored {
            isMirrored = true
        }
        
        let newOrientation = _imageOrientation(forDeviceOrientation: deviceOrientation, isMirrored: isMirrored)
        
        if image.imageOrientation != newOrientation {
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: newOrientation)
        }
        
        return image
    }
}
