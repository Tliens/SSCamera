import Foundation
import AVFoundation

extension SSCamera{
    /**
     The signature for a handler.
     The success value is the string representation of a scanned QR code, if any.
     */
    public typealias QRCodeDetectionHandler = (Result<String, Error>) -> Void
    
    /**
     Start detecting QR codes.
     */
    open func startQRCodeDetection(_ handler: @escaping QRCodeDetectionHandler) {
        guard let captureSession = self.captureSession
            else { return }
        
        let output = AVCaptureMetadataOutput()
        
        guard captureSession.canAddOutput(output)
            else { return }
        
        qrCodeDetectionHandler = handler
        captureSession.addOutput(output)
        
        // Note: The object types must be set after the output was added to the capture session.
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417].filter { output.availableMetadataObjectTypes.contains($0) }
    }
    
    /**
     Stop detecting QR codes.
     */
    open func stopQRCodeDetection() {
        qrCodeDetectionHandler = nil
        
        if let output = qrOutput {
            captureSession?.removeOutput(output)
        }
        qrOutput = nil
    }
    
}
extension SSCamera: AVCaptureMetadataOutputObjectsDelegate {
    /**
     Called when a QR code is detected.
     */
    public func metadataOutput(_: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from _: AVCaptureConnection) {
        // Check if there is a registered handler.
        guard let handler = qrCodeDetectionHandler
            else { return }
        
        // Get the detection result.
        let stringValues = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap { $0.stringValue }
        
        guard let stringValue = stringValues.first
            else { return }
        
        handler(.success(stringValue))
    }
}
