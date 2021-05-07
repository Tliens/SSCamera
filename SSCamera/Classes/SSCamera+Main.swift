import AVFoundation

extension SSCamera{
    /**
     Asks the user for camera permissions. Only works if the permissions are not yet determined. Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
     
     :param: completion Completion block with the result of permission request
     */
    open func askUserForCameraPermission(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { (allowedAccess) -> Void in
            if self.cameraOutputMode == .videoWithMic {
                AVCaptureDevice.requestAccess(for: AVMediaType.audio, completionHandler: { (allowedAccess) -> Void in
                    DispatchQueue.main.async { () -> Void in
                        completion(allowedAccess)
                    }
                })
            } else {
                DispatchQueue.main.async { () -> Void in
                    completion(allowedAccess)
                }
            }
        })
    }
    func _checkIfCameraIsAvailable() -> SSCameraState {
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.front)
        if deviceHasCamera {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            let userAgreedToUseIt = authorizationStatus == .authorized
            if userAgreedToUseIt {
                return .ready
            } else if authorizationStatus == AVAuthorizationStatus.notDetermined {
                return .notDetermined
            } else {
                _show(NSLocalizedString("Camera access denied", comment: ""), message: NSLocalizedString("You need to go to settings app and grant acces to the camera device to use it.", comment: ""))
                return .accessDenied
            }
        } else {
            _show(NSLocalizedString("Camera unavailable", comment: ""), message: NSLocalizedString("The device does not have a camera.", comment: ""))
            return .noDeviceFound
        }
    }
    
    /**
     Zoom in to the requested scale.
     */
    open func zoom(_ scale: CGFloat) {
        _zoom(scale)
    }
    
    func _setupMaxZoomScale() {
        var maxZoom = CGFloat(1.0)
        beginZoomScale = CGFloat(1.0)
        
        if cameraDevice == .back, let backCameraDevice = backCameraDevice {
            maxZoom = backCameraDevice.activeFormat.videoMaxZoomFactor
        } else if cameraDevice == .front, let frontCameraDevice = frontCameraDevice {
            maxZoom = frontCameraDevice.activeFormat.videoMaxZoomFactor
        }
        
        maxZoomScale = maxZoom
    }
    /**
     Current camera status.
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined
     */
    open func currentCameraStatus() -> SSCameraState {
        return _checkIfCameraIsAvailable()
    }
    
    func _canLoadCamera() -> Bool {
        let currentCameraState = _checkIfCameraIsAvailable()
        return currentCameraState == .ready || (currentCameraState == .notDetermined && showAccessPermissionPopupAutomatically)
    }
    
    func _setupCamera(_ completion: @escaping () -> Void) {
        captureSession = AVCaptureSession()
        
        sessionQueue.async {
            if let validCaptureSession = self.captureSession {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = AVCaptureSession.Preset.high
                self._updateCameraDevice(self.cameraDevice)
                self._setupOutputs()
                self._setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: nil)
                self._setupPreviewLayer()
                validCaptureSession.commitConfiguration()
                self._updateIlluminationMode(self.flashMode)
                self._updateCameraQualityMode(self.cameraOutputQuality)
                validCaptureSession.startRunning()
                self._startFollowingDeviceOrientation()
                self.cameraIsSetup = true
                self._orientationChanged()
                
                completion()
            }
        }
    }
    func _updateCameraDevice(_: SSCameraDevice) {
        if let validCaptureSession = captureSession {
            validCaptureSession.beginConfiguration()
            defer { validCaptureSession.commitConfiguration() }
            let inputs: [AVCaptureInput] = validCaptureSession.inputs
            
            for input in inputs {
                if let deviceInput = input as? AVCaptureDeviceInput, deviceInput.device != mic {
                    validCaptureSession.removeInput(deviceInput)
                }
            }
            
            switch cameraDevice {
                case .front:
                    if hasFrontCamera {
                        if let validFrontDevice = _deviceInputFromDevice(frontCameraDevice),
                            !inputs.contains(validFrontDevice) {
                            validCaptureSession.addInput(validFrontDevice)
                        }
                }
                case .back:
                    if let validBackDevice = _deviceInputFromDevice(backCameraDevice),
                        !inputs.contains(validBackDevice) {
                        validCaptureSession.addInput(validBackDevice)
                }
            }
        }
    }
    func _updateCameraQualityMode(_ newCameraOutputQuality: AVCaptureSession.Preset) {
        if let validCaptureSession = captureSession {
            var sessionPreset = newCameraOutputQuality
            if newCameraOutputQuality == .high {
                if cameraOutputMode == .stillImage {
                    sessionPreset = AVCaptureSession.Preset.photo
                } else {
                    sessionPreset = AVCaptureSession.Preset.high
                }
            }
            
            if validCaptureSession.canSetSessionPreset(sessionPreset) {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = sessionPreset
                validCaptureSession.commitConfiguration()
            } else {
                _show(NSLocalizedString("Preset not supported", comment: ""), message: NSLocalizedString("Camera preset not supported. Please try another one.", comment: ""))
            }
        } else {
            _show(NSLocalizedString("Camera error", comment: ""), message: NSLocalizedString("No valid capture session found, I can't take any pictures or videos.", comment: ""))
        }
    }
    func _deviceInputFromDevice(_ device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        guard let validDevice = device else { return nil }
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        } catch let outError {
            _show(NSLocalizedString("Device setup error occured", comment: ""), message: "\(outError)")
            return nil
        }
    }
    func _show(_ title: String, message: String) {
        if showErrorsToUsers {
            DispatchQueue.main.async { () -> Void in
                self.showErrorBlock(title, message)
            }
        }
    }
}
