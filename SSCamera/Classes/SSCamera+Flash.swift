import AVFoundation

extension SSCamera{
    /**
     Change current flash mode to next value from available ones.
     
     :returns: Current flash mode: Off / On / Auto
     */
    open func changeFlashMode() -> SSCameraFlashMode {
        guard let newFlashMode = SSCameraFlashMode(rawValue: (flashMode.rawValue + 1) % 3) else { return flashMode }
        flashMode = newFlashMode
        return flashMode
    }
    
    /**
     Check the camera device has flash
     */
    open func hasFlash(for cameraDevice: SSCameraDevice) -> Bool {
        let devices = AVCaptureDevice.videoDevices
        for device in devices {
            if device.position == .back, cameraDevice == .back {
                return device.hasFlash
            } else if device.position == .front, cameraDevice == .front {
                return device.hasFlash
            }
        }
        return false
    }
    
    //MARK: Exposure  曝光
    // Available modes:
    // .Locked .AutoExpose .ContinuousAutoExposure .Custom
    func _changeExposureMode(mode: AVCaptureDevice.ExposureMode) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
            case .back:
                device = backCameraDevice
            case .front:
                device = frontCameraDevice
        }
        if device?.exposureMode == mode {
            return
        }
        
        do {
            try device?.lockForConfiguration()
            
            if device?.isExposureModeSupported(mode) == true {
                device?.exposureMode = mode
            }
            device?.unlockForConfiguration()
            
        } catch {
            return
        }
    }
    /// 曝光时长会影响帧率
    func _changeExposureDuration(value: Float) {
        if cameraIsSetup {
            let device: AVCaptureDevice?
            
            switch cameraDevice {
                case .back:
                    device = backCameraDevice
                case .front:
                    device = frontCameraDevice
            }
            
            guard let videoDevice = device else {
                return
            }
            
            do {
                try videoDevice.lockForConfiguration()
                
                let p = Float64(pow(value, exposureDurationPower)) // Apply power function to expand slider's low-end range
                let minDurationSeconds = Float64(max(CMTimeGetSeconds(videoDevice.activeFormat.minExposureDuration), exposureMininumDuration))
                let maxDurationSeconds = Float64(CMTimeGetSeconds(videoDevice.activeFormat.maxExposureDuration))
                let newDurationSeconds = Float64(p * (maxDurationSeconds - minDurationSeconds)) + minDurationSeconds // Scale from 0-1 slider range to actual duration
                
                if videoDevice.exposureMode == .custom {
                    let newExposureTime = CMTimeMakeWithSeconds(Float64(newDurationSeconds), preferredTimescale: 1000 * 1000 * 1000)
                    videoDevice.setExposureModeCustom(duration: newExposureTime, iso: AVCaptureDevice.currentISO, completionHandler: nil)
                }
                
                videoDevice.unlockForConfiguration()
            } catch {
                return
            }
        }
    }
    func _updateIlluminationMode(_ mode: SSCameraFlashMode) {
        if cameraOutputMode != .stillImage {
            _updateTorch(mode)
        } else {
            _updateFlash(mode)
        }
    }
    
    func _updateTorch(_: SSCameraFlashMode) {
        captureSession?.beginConfiguration()
        defer { captureSession?.commitConfiguration() }
        for captureDevice in AVCaptureDevice.videoDevices {
            guard let avTorchMode = AVCaptureDevice.TorchMode(rawValue: flashMode.rawValue) else { continue }
            if captureDevice.isTorchModeSupported(avTorchMode), cameraDevice == .back {
                do {
                    try captureDevice.lockForConfiguration()
                    
                    captureDevice.torchMode = avTorchMode
                    captureDevice.unlockForConfiguration()
                    
                } catch {
                    return
                }
            }
        }
    }
    
    func _updateFlash(_ flashMode: SSCameraFlashMode) {
        captureSession?.beginConfiguration()
        defer { captureSession?.commitConfiguration() }
        for captureDevice in AVCaptureDevice.videoDevices {
            guard let avFlashMode = AVCaptureDevice.FlashMode(rawValue: flashMode.rawValue) else { continue }
            if captureDevice.isFlashModeSupported(avFlashMode) {
                do {
                    try captureDevice.lockForConfiguration()
                    captureDevice.flashMode = avFlashMode
                    captureDevice.unlockForConfiguration()
                } catch {
                    return
                }
            }
        }
    }
}
