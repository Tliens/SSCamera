//
//  SSCamera.swift
//  SSCamera
//
//  Created by 2020 on 2021/5/7.
//

import Foundation
import AVFoundation
import Photos
import CoreMotion

open class SSCamera: NSObject{
    // MARK: - Public properties

    /// 自定义相册名称 for image
    open var imageAlbumName: String?

    /// 自定义相册名称 for video
    open var videoAlbumName: String?

    /// 采集会话 for 自定义相机设置
    open var captureSession: AVCaptureSession?

    /**
     是否应该为用户自动显示错误。如果想自定义显示错误，把它设为false。
     如果想添加自定义错误UI，在showErrorBlock中回调处理
     */
    open var showErrorsToUsers = false

    /// 是否应该在需要时立即显示摄像头权限弹出框，或者你想手动显示它。缺省值为true。
    open var showAccessPermissionPopupAutomatically = true

    /// 用于向用户显示错误消息
    open var showErrorBlock: (_ erTitle: String, _ erMessage: String) -> Void = { (erTitle: String, erMessage: String) -> Void in
        
        var alertController = UIAlertController(title: erTitle, message: erMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { (_) -> Void in }))
        
        if let topController = UIApplication.shared.keyWindow?.rootViewController {
            topController.present(alertController, animated: true, completion: nil)
        }
    }

    open func canSetPreset(preset: AVCaptureSession.Preset) -> Bool? {
        if let validCaptureSession = captureSession {
            return validCaptureSession.canSetSessionPreset(preset)
        }
        return nil
    }

    /**
     是否应该将资源写入相册
     */
    open var writeFilesToPhoneLibrary = true

    /**
     是否跟随设备旋转.默认是
     */
    open var shouldRespondToOrientationChanges = true {
        didSet {
            if shouldRespondToOrientationChanges {
                _startFollowingDeviceOrientation()
            } else {
                _stopFollowingDeviceOrientation()
            }
        }
    }

    /**
     是否前置镜像，默认否
     */
    open var shouldFlipFrontCameraImage = false

    /**
     确定当方向变化时，manager是否应该保持视图具有相同的边界，默认否
     */
    open var shouldKeepViewAtOrientationChanges = false

    /**
     是否可以对焦，默认是
     */
    open var shouldEnableTapToFocus = true {
        didSet {
            focusGesture.isEnabled = shouldEnableTapToFocus
        }
    }

    /**
     是否允许缩放手势，默认是
     */
    open var shouldEnablePinchToZoom = true {
        didSet {
            zoomGesture.isEnabled = shouldEnablePinchToZoom
        }
    }

    /**
     应该使平移改变曝光/亮度，默认是
     */
    open var shouldEnableExposure = true {
        didSet {
            exposureGesture.isEnabled = shouldEnableExposure
        }
    }

    /// 相机是否可以使用
    open var cameraIsReady: Bool {
        return cameraIsSetup
    }

    /// 当前设备是否有前置摄像头
    open var hasFrontCamera: Bool = {
        let frontDevices = AVCaptureDevice.videoDevices.filter { $0.position == .front }
        return !frontDevices.isEmpty
    }()

    /// 当前设备是否有闪光灯
    open var hasFlash: Bool = {
        let hasFlashDevices = AVCaptureDevice.videoDevices.filter { $0.hasFlash }
        return !hasFlashDevices.isEmpty
    }()

    /**
     切换设备时，是否显示翻转动画，默认是
     */
    open var animateCameraDeviceChange: Bool = true

    /**
     在拍照时启用或禁用快门动画，默认是
     */
    open var animateShutter: Bool = true

    /**
     是否启用定位服务，默认否
     */
    open var shouldUseLocationServices: Bool = false {
        didSet {
            if shouldUseLocationServices {
                self.locationManager = SSCameraLocationManager()
            }
        }
    }

    /// 前后置切换
    open var cameraDevice: SSCameraDevice = .back {
        didSet {
            if cameraIsSetup, cameraDevice != oldValue {
                if animateCameraDeviceChange {
                    doFlipAnimation()
                }
                _updateCameraDevice(cameraDevice)
                _updateIlluminationMode(flashMode)
                _setupMaxZoomScale()
                _zoom(0)
                _orientationChanged()
            }
        }
    }

    /// 闪灯切换
    open var flashMode: SSCameraFlashMode = .off {
        didSet {
            if cameraIsSetup && flashMode != oldValue {
                _updateIlluminationMode(flashMode)
            }
        }
    }

    /// 输出质量切换
    open var cameraOutputQuality: AVCaptureSession.Preset = .high {
        didSet {
            if cameraIsSetup && cameraOutputQuality != oldValue {
                _updateCameraQualityMode(cameraOutputQuality)
            }
        }
    }

    /// 输出模式切换
    open var cameraOutputMode: SSCameraOutputMode = .stillImage {
        didSet {
            if cameraIsSetup {
                if cameraOutputMode != oldValue {
                    _setupOutputMode(cameraOutputMode, oldCameraOutputMode: oldValue)
                }
                _setupMaxZoomScale()
                _zoom(0)
            }
        }
    }

    /// 视频录制时长
    open var recordedDuration: CMTime { return movieOutput?.recordedDuration ?? CMTime.zero }

    /// 视频录制大小
    open var recordedFileSize: Int64 { return movieOutput?.recordedFileSize ?? 0 }

    /// 对角模式
    open var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus

    /// 曝光模式
    open var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure

    /// 防抖切换
    open var videoStabilisationMode: AVCaptureVideoStabilizationMode = .auto {
        didSet {
            if oldValue != videoStabilisationMode {
                _setupVideoConnection()
            }
        }
    }

    // 当前防抖模式
    open var activeVideoStabilisationMode: AVCaptureVideoStabilizationMode {
        if let movieOutput = movieOutput {
            for connection in movieOutput.connections {
                for port in connection.inputPorts {
                    if port.mediaType == AVMediaType.video {
                        let videoConnection = connection as AVCaptureConnection
                        return videoConnection.activeVideoStabilizationMode
                    }
                }
            }
        }
        
        return .off
    }

    // MARK: - Private properties

    var locationManager: SSCameraLocationManager?

    weak var embeddingView: UIView?
    var videoCompletion: ((_ videoURL: URL?, _ error: NSError?) -> Void)?

    var sessionQueue: DispatchQueue = DispatchQueue(label: "CameraSessionQueue", attributes: [])

    lazy var frontCameraDevice: AVCaptureDevice? = {
        AVCaptureDevice.videoDevices.filter { $0.position == .front }.first
    }()

    lazy var backCameraDevice: AVCaptureDevice? = {
        AVCaptureDevice.videoDevices.filter { $0.position == .back }.first
    }()

    lazy var mic: AVCaptureDevice? = {
        AVCaptureDevice.default(for: AVMediaType.audio)
    }()

    var stillImageOutput: AVCaptureStillImageOutput?
    var movieOutput: AVCaptureMovieFileOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var library: PHPhotoLibrary?

    var cameraIsSetup = false
    var cameraIsObservingDeviceOrientation = false

    var zoomScale = CGFloat(1.0)
    var beginZoomScale = CGFloat(1.0)
    var maxZoomScale = CGFloat(1.0)

    func _tempFilePath() -> URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tempMovie\(Date().timeIntervalSince1970)").appendingPathExtension("mp4")
        return tempURL
    }

    var coreMotionManager: CMMotionManager!

    /// Real device orientation from DeviceMotion
    var deviceOrientation: UIDeviceOrientation = .portrait

    /**
     The stored handler for QR codes.
     */
    var qrCodeDetectionHandler: QRCodeDetectionHandler?
    
    /**
     The stored meta data output; used to detect QR codes.
     */
    var qrOutput: AVCaptureOutput?
    
    lazy var zoomGesture = UIPinchGestureRecognizer()
    lazy var focusGesture = UITapGestureRecognizer()
    lazy var exposureGesture = UIPanGestureRecognizer()
    var lastFocusRectangle: CAShapeLayer?
    var lastFocusPoint: CGPoint?
    
    var exposureValue: Float = 0.1 // EV
    var translationY: Float = 0
    var startPanPointInPreviewLayer: CGPoint?
    
    let exposureDurationPower: Float = 4.0 // the exposure slider gain
    let exposureMininumDuration: Float64 = 1.0 / 2000.0
    
    /**
     Switches between the current and specified camera using a flip animation similar to the one used in the iOS stock camera app.
     */
    
    var cameraTransitionView: UIView?
    var transitionAnimating = false
    
    deinit {
        _stopFollowingDeviceOrientation()
        stopAndRemoveCaptureSession()
    }
}
