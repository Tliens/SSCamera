
import Photos

public enum SSCameraState {
    case ready, accessDenied, noDeviceFound, notDetermined
}

public enum SSCameraDevice {
    case front, back
}

public enum SSCameraFlashMode: Int {
    case off, on, auto
}

public enum SSCameraOutputMode {
    case stillImage, videoWithMic, videoOnly
}

public enum SSCaptureResult {
    case success(content: SSCaptureContent)
    case failure(Error)
    
    init(_ image: UIImage) {
        self = .success(content: .image(image))
    }
    
    init(_ data: Data) {
        self = .success(content: .imageData(data))
    }
    
    init(_ asset: PHAsset) {
        self = .success(content: .asset(asset))
    }
    
    var imageData: Data? {
        if case let .success(content) = self {
            return content.asData
        } else {
            return nil
        }
    }
}

public enum SSCaptureContent {
    case imageData(Data)
    case image(UIImage)
    case asset(PHAsset)
}

extension SSCaptureContent {
    public var asImage: UIImage? {
        switch self {
            case let .image(image): return image
            case let .imageData(data): return UIImage(data: data)
            case let .asset(asset):
                if let data = getImageData(fromAsset: asset) {
                    return UIImage(data: data)
                } else {
                    return nil
            }
        }
    }
    
    public var asData: Data? {
        switch self {
            case let .image(image): return image.jpegData(compressionQuality: 1.0)
            case let .imageData(data): return data
            case let .asset(asset): return getImageData(fromAsset: asset)
        }
    }
    
    private func getImageData(fromAsset asset: PHAsset) -> Data? {
        var imageData: Data?
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.version = .original
        options.isSynchronous = true
        manager.requestImageData(for: asset, options: options) { data, _, _, _ in
            
            imageData = data
        }
        return imageData
    }
}

public enum SSCaptureError: Error {
    case noImageData
    case invalidImageData
    case noVideoConnection
    case noSampleBuffer
    case assetNotSaved
}
