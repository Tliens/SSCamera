import Foundation
extension SSCamera{
    
    
    
    func _saveImageToLibrary(atFileURL filePath: URL, _ imageCompletion: @escaping (SSCaptureResult) -> Void) {
        let location = locationManager?.latestLocation
        let date = Date()
        
        library?.save(imageAtURL: filePath, albumName: imageAlbumName, date: date, location: location) { asset in
            
            guard let _ = asset else {
                return imageCompletion(.failure(SSCaptureError.assetNotSaved))
            }
        }
    }
    
}
