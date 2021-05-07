import Foundation
extension SSCamera{
    
    open func doFlipAnimation() {
        if transitionAnimating {
            return
        }
        
        if let validEmbeddingView = embeddingView,
           let validPreviewLayer = previewLayer {
            var tempView = UIView()
            
            if _blurSupported() {
                let blurEffect = UIBlurEffect(style: .light)
                tempView = UIVisualEffectView(effect: blurEffect)
                tempView.frame = validEmbeddingView.bounds
            } else {
                tempView = UIView(frame: validEmbeddingView.bounds)
                tempView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            }
            
            validEmbeddingView.insertSubview(tempView, at: Int(validPreviewLayer.zPosition + 1))
            
            cameraTransitionView = validEmbeddingView.snapshotView(afterScreenUpdates: true)
            
            if let cameraTransitionView = cameraTransitionView {
                validEmbeddingView.insertSubview(cameraTransitionView, at: Int(validEmbeddingView.layer.zPosition + 1))
            }
            tempView.removeFromSuperview()
            
            transitionAnimating = true
            
            validPreviewLayer.opacity = 0.0
            
            DispatchQueue.main.async {
                self._flipCameraTransitionView()
            }
        }
    }    
    
    // Determining whether the current device actually supports blurring
    // As seen on: http://stackoverflow.com/a/29997626/2269387
    func _blurSupported() -> Bool {
        var supported = Set<String>()
        supported.insert("iPad")
        supported.insert("iPad1,1")
        supported.insert("iPhone1,1")
        supported.insert("iPhone1,2")
        supported.insert("iPhone2,1")
        supported.insert("iPhone3,1")
        supported.insert("iPhone3,2")
        supported.insert("iPhone3,3")
        supported.insert("iPod1,1")
        supported.insert("iPod2,1")
        supported.insert("iPod2,2")
        supported.insert("iPod3,1")
        supported.insert("iPod4,1")
        supported.insert("iPad2,1")
        supported.insert("iPad2,2")
        supported.insert("iPad2,3")
        supported.insert("iPad2,4")
        supported.insert("iPad3,1")
        supported.insert("iPad3,2")
        supported.insert("iPad3,3")
        
        return !supported.contains(_hardwareString())
    }
    
    func _hardwareString() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        guard let deviceName = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) else {
            return ""
        }
        return deviceName
    }
    
    func _flipCameraTransitionView() {
        if let cameraTransitionView = cameraTransitionView {
            UIView.transition(with: cameraTransitionView,
                              duration: 0.5,
                              options: UIView.AnimationOptions.transitionFlipFromLeft,
                              animations: nil,
                              completion: { (_) -> Void in
                                self._removeCameraTransistionView()
                              })
        }
    }
    
    fileprivate func _removeCameraTransistionView() {
        if let cameraTransitionView = cameraTransitionView {
            if let validPreviewLayer = previewLayer {
                validPreviewLayer.opacity = 1.0
            }
            
            UIView.animate(withDuration: 0.5,
                           animations: { () -> Void in
                            
                            cameraTransitionView.alpha = 0.0
                            
                           }, completion: { (_) -> Void in
                            
                            self.transitionAnimating = false
                            
                            cameraTransitionView.removeFromSuperview()
                            self.cameraTransitionView = nil
                           })
        }
    }
    
    func _performShutterAnimation(_ completion: (() -> Void)?) {
        if let validPreviewLayer = previewLayer {
            DispatchQueue.main.async {
                let duration = 0.1
                
                CATransaction.begin()
                
                if let completion = completion {
                    CATransaction.setCompletionBlock(completion)
                }
                
                let fadeOutAnimation = CABasicAnimation(keyPath: "opacity")
                fadeOutAnimation.fromValue = 1.0
                fadeOutAnimation.toValue = 0.0
                validPreviewLayer.add(fadeOutAnimation, forKey: "opacity")
                
                let fadeInAnimation = CABasicAnimation(keyPath: "opacity")
                fadeInAnimation.fromValue = 0.0
                fadeInAnimation.toValue = 1.0
                fadeInAnimation.beginTime = CACurrentMediaTime() + duration * 2.0
                validPreviewLayer.add(fadeInAnimation, forKey: "opacity")
                
                CATransaction.commit()
            }
        }
    }



}
