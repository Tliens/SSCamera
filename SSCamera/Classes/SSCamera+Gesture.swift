import Foundation
import AVFoundation

extension SSCamera:UIGestureRecognizerDelegate{

    func attachZoom(_ view: UIView) {
        DispatchQueue.main.async {
            self.zoomGesture.addTarget(self, action: #selector(SSCamera._zoomStart(_:)))
            view.addGestureRecognizer(self.zoomGesture)
            self.zoomGesture.delegate = self
        }
    }
    
    open func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            beginZoomScale = zoomScale
        }
        
        return true
    }
    
    @objc func _zoomStart(_ recognizer: UIPinchGestureRecognizer) {
        guard let view = embeddingView,
            let previewLayer = previewLayer
            else { return }
        
        var allTouchesOnPreviewLayer = true
        let numTouch = recognizer.numberOfTouches
        
        for i in 0 ..< numTouch {
            let location = recognizer.location(ofTouch: i, in: view)
            let convertedTouch = previewLayer.convert(location, from: previewLayer.superlayer)
            if !previewLayer.contains(convertedTouch) {
                allTouchesOnPreviewLayer = false
                break
            }
        }
        if allTouchesOnPreviewLayer {
            _zoom(recognizer.scale)
        }
    }
    
    func _zoom(_ scale: CGFloat) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
            case .back:
                device = backCameraDevice
            case .front:
                device = frontCameraDevice
        }
        
        do {
            let captureDevice = device
            try captureDevice?.lockForConfiguration()
            
            zoomScale = max(1.0, min(beginZoomScale * scale, maxZoomScale))
            
            captureDevice?.videoZoomFactor = zoomScale
            
            captureDevice?.unlockForConfiguration()
            
        } catch {
            print("Error locking configuration")
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    
    func attachFocus(_ view: UIView) {
        DispatchQueue.main.async {
            self.focusGesture.addTarget(self, action: #selector(SSCamera._focusStart(_:)))
            view.addGestureRecognizer(self.focusGesture)
            self.focusGesture.delegate = self
        }
    }
    
    
    func attachExposure(_ view: UIView) {
        DispatchQueue.main.async {
            self.exposureGesture.addTarget(self, action: #selector(SSCamera._exposureStart(_:)))
            view.addGestureRecognizer(self.exposureGesture)
            self.exposureGesture.delegate = self
        }
    }
    
    @objc func _focusStart(_ recognizer: UITapGestureRecognizer) {
        let device: AVCaptureDevice?
        
        switch cameraDevice {
            case .back:
                device = backCameraDevice
            case .front:
                device = frontCameraDevice
        }
        
        _changeExposureMode(mode: .continuousAutoExposure)
        translationY = 0
        exposureValue = 0.5
        
        if let validDevice = device,
            let validPreviewLayer = previewLayer,
            let view = recognizer.view {
            let pointInPreviewLayer = view.layer.convert(recognizer.location(in: view), to: validPreviewLayer)
            let pointOfInterest = validPreviewLayer.captureDevicePointConverted(fromLayerPoint: pointInPreviewLayer)
            
            do {
                try validDevice.lockForConfiguration()
                
                _showFocusRectangleAtPoint(pointInPreviewLayer, inLayer: validPreviewLayer)
                
                if validDevice.isFocusPointOfInterestSupported {
                    validDevice.focusPointOfInterest = pointOfInterest
                }
                
                if validDevice.isExposurePointOfInterestSupported {
                    validDevice.exposurePointOfInterest = pointOfInterest
                }
                
                if validDevice.isFocusModeSupported(focusMode) {
                    validDevice.focusMode = focusMode
                }
                
                if validDevice.isExposureModeSupported(exposureMode) {
                    validDevice.exposureMode = exposureMode
                }
                
                validDevice.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }

    func _showFocusRectangleAtPoint(_ focusPoint: CGPoint, inLayer layer: CALayer, withBrightness brightness: Float? = nil) {
        if let lastFocusRectangle = lastFocusRectangle {
            lastFocusRectangle.removeFromSuperlayer()
            self.lastFocusRectangle = nil
        }
        
        let size = CGSize(width: 75, height: 75)
        let rect = CGRect(origin: CGPoint(x: focusPoint.x - size.width / 2.0, y: focusPoint.y - size.height / 2.0), size: size)
        
        let endPath = UIBezierPath(rect: rect)
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.minY + 5.0))
        endPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.maxX - 5.0, y: rect.minY + size.height / 2.0))
        endPath.move(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY))
        endPath.addLine(to: CGPoint(x: rect.minX + size.width / 2.0, y: rect.maxY - 5.0))
        endPath.move(to: CGPoint(x: rect.minX, y: rect.minY + size.height / 2.0))
        endPath.addLine(to: CGPoint(x: rect.minX + 5.0, y: rect.minY + size.height / 2.0))
        if brightness != nil {
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4, y: rect.minY + size.height))
            
            endPath.move(to: CGPoint(x: rect.minX + size.width + size.width / 4 - size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
            endPath.addLine(to: CGPoint(x: rect.minX + size.width + size.width / 4 + size.width / 16, y: rect.minY + size.height - CGFloat(brightness!) * size.height))
        }
        
        let startPath = UIBezierPath(cgPath: endPath.cgPath)
        let scaleAroundCenterTransform = CGAffineTransform(translationX: -focusPoint.x, y: -focusPoint.y).concatenating(CGAffineTransform(scaleX: 2.0, y: 2.0).concatenating(CGAffineTransform(translationX: focusPoint.x, y: focusPoint.y)))
        startPath.apply(scaleAroundCenterTransform)
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = endPath.cgPath
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = UIColor(red: 1, green: 0.83, blue: 0, alpha: 0.95).cgColor
        shapeLayer.lineWidth = 1.0
        
        layer.addSublayer(shapeLayer)
        lastFocusRectangle = shapeLayer
        lastFocusPoint = focusPoint
        
        CATransaction.begin()
        
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut))
        
        CATransaction.setCompletionBlock {
            if shapeLayer.superlayer != nil {
                shapeLayer.removeFromSuperlayer()
                self.lastFocusRectangle = nil
            }
        }
        if brightness == nil {
            let appearPathAnimation = CABasicAnimation(keyPath: "path")
            appearPathAnimation.fromValue = startPath.cgPath
            appearPathAnimation.toValue = endPath.cgPath
            shapeLayer.add(appearPathAnimation, forKey: "path")
            
            let appearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
            appearOpacityAnimation.fromValue = 0.0
            appearOpacityAnimation.toValue = 1.0
            shapeLayer.add(appearOpacityAnimation, forKey: "opacity")
        }
        
        let disappearOpacityAnimation = CABasicAnimation(keyPath: "opacity")
        disappearOpacityAnimation.fromValue = 1.0
        disappearOpacityAnimation.toValue = 0.0
        disappearOpacityAnimation.beginTime = CACurrentMediaTime() + 0.8
        disappearOpacityAnimation.fillMode = CAMediaTimingFillMode.forwards
        disappearOpacityAnimation.isRemovedOnCompletion = false
        shapeLayer.add(disappearOpacityAnimation, forKey: "opacity")
        
        CATransaction.commit()
    }
    
    @objc func _exposureStart(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.view != nil else { return }
        let view = gestureRecognizer.view!
        
        _changeExposureMode(mode: .custom)
        
        let translation = gestureRecognizer.translation(in: view)
        let currentTranslation = translationY + Float(translation.y)
        if gestureRecognizer.state == .ended {
            translationY = currentTranslation
        }
        if currentTranslation < 0 {
            // up - brighter
            exposureValue = 0.5 + min(abs(currentTranslation) / 400, 1) / 2
        } else if currentTranslation >= 0 {
            // down - lower
            exposureValue = 0.5 - min(abs(currentTranslation) / 400, 1) / 2
        }
        _changeExposureDuration(value: exposureValue)
        
        // UI Visualization
        if gestureRecognizer.state == .began {
            if let validPreviewLayer = previewLayer {
                startPanPointInPreviewLayer = view.layer.convert(gestureRecognizer.location(in: view), to: validPreviewLayer)
            }
        }
        
        if let validPreviewLayer = previewLayer, let lastFocusPoint = self.lastFocusPoint {
            _showFocusRectangleAtPoint(lastFocusPoint, inLayer: validPreviewLayer, withBrightness: exposureValue)
        }
    }
}
