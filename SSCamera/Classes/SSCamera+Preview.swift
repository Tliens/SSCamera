import AVFoundation

extension SSCamera{
    /**
     Inits a capture session and adds a preview layer to the given view. Preview layer bounds will automaticaly be set to match given view. Default session is initialized with still image output.
     
     :param: view The view you want to add the preview layer to
     :param: cameraOutputMode The mode you want capturesession to run image / video / video and microphone
     :param: completion Optional completion block
     
     :returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined.
     */
    @discardableResult open func addPreviewLayerToView(_ view: UIView) -> SSCameraState {
        return addPreviewLayerToView(view, newCameraOutputMode: cameraOutputMode)
    }
    
    @discardableResult open func addPreviewLayerToView(_ view: UIView, newCameraOutputMode: SSCameraOutputMode) -> SSCameraState {
        return addLayerPreviewToView(view, newCameraOutputMode: newCameraOutputMode, completion: nil)
    }
    
    @discardableResult open func addLayerPreviewToView(_ view: UIView, newCameraOutputMode: SSCameraOutputMode, completion: (() -> Void)?) -> SSCameraState {
        if _canLoadCamera() {
            if let _ = embeddingView {
                if let validPreviewLayer = previewLayer {
                    validPreviewLayer.removeFromSuperlayer()
                }
            }
            if cameraIsSetup {
                _addPreviewLayerToView(view)
                cameraOutputMode = newCameraOutputMode
                if let validCompletion = completion {
                    validCompletion()
                }
            } else {
                _setupCamera {
                    self._addPreviewLayerToView(view)
                    self.cameraOutputMode = newCameraOutputMode
                    if let validCompletion = completion {
                        validCompletion()
                    }
                }
            }
        }
        return _checkIfCameraIsAvailable()
    }
    func _addPreviewLayerToView(_ view: UIView) {
        embeddingView = view
        attachZoom(view)
        attachFocus(view)
        attachExposure(view)
        
        DispatchQueue.main.async { () -> Void in
            guard let previewLayer = self.previewLayer else { return }
            previewLayer.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(previewLayer)
        }
    }
    func _setupPreviewLayer() {
        if let validCaptureSession = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        }
    }
}
