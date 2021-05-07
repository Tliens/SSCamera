import Foundation
import AVFoundation
import CoreLocation
extension SSCamera{
    

    func _setVideoWithGPS(forLocation location: CLLocation) {
        let metadata = AVMutableMetadataItem()
        metadata.keySpace = AVMetadataKeySpace.quickTimeMetadata
        metadata.key = AVMetadataKey.quickTimeMetadataKeyLocationISO6709 as NSString
        metadata.identifier = AVMetadataIdentifier.quickTimeMetadataLocationISO6709
        metadata.value = String(format: "%+09.5f%+010.5f%+.0fCRSWGS_84", location.coordinate.latitude, location.coordinate.longitude, location.altitude) as NSString
        _getMovieOutput().metadata = [metadata]
    }
    
    func _imageDataWithEXIF(forImage _: UIImage, _ data: Data) -> NSData? {
        let cfdata: CFData = data as CFData
        let source = CGImageSourceCreateWithData(cfdata, nil)!
        let UTI: CFString = CGImageSourceGetType(source)!
        let mutableData: CFMutableData = NSMutableData(data: data) as CFMutableData
        let destination = CGImageDestinationCreateWithData(mutableData, UTI, 1, nil)!
        
        let imageSourceRef = CGImageSourceCreateWithData(cfdata, nil)
        let imageProperties = CGImageSourceCopyMetadataAtIndex(imageSourceRef!, 0, nil)!
        
        var mutableMetadata = CGImageMetadataCreateMutableCopy(imageProperties)!
        
        if let location = locationManager?.latestLocation {
            mutableMetadata = _gpsMetadata(mutableMetadata, withLocation: location)
        }
        
        let finalMetadata: CGImageMetadata = mutableMetadata
        CGImageDestinationAddImageAndMetadata(destination, UIImage(data: data)!.cgImage!, finalMetadata, nil)
        CGImageDestinationFinalize(destination)
        return mutableData
    }
    
    func _gpsMetadata(_ imageMetadata: CGMutableImageMetadata, withLocation location: CLLocation) -> CGMutableImageMetadata {
        let altitudeRef = Int(location.altitude < 0.0 ? 1 : 0)
        let latitudeRef = location.coordinate.latitude < 0.0 ? "S" : "N"
        let longitudeRef = location.coordinate.longitude < 0.0 ? "W" : "E"
        
        let f = DateFormatter()
        f.timeZone = TimeZone(abbreviation: "UTC")
        
        f.dateFormat = "yyyy:MM:dd"
        let isoDate = f.string(from: location.timestamp)
        
        f.dateFormat = "HH:mm:ss.SSSSSS"
        let isoTime = f.string(from: location.timestamp)
        
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSLatitudeRef, latitudeRef as CFTypeRef)
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSLatitude, abs(location.coordinate.latitude) as CFTypeRef)
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSLongitudeRef, longitudeRef as CFTypeRef)
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSLongitude, abs(location.coordinate.longitude) as CFTypeRef)
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSAltitude, Int(abs(location.altitude)) as CFTypeRef)
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSAltitudeRef, altitudeRef as CFTypeRef)
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSTimeStamp, isoTime as CFTypeRef)
        CGImageMetadataSetValueMatchingImageProperty(imageMetadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSDateStamp, isoDate as CFTypeRef)
        
        return imageMetadata
    }
    
}
