//
//  SSHelpExtension.swift
//  DancerCamera
//
//  Created by 2020 on 2021/4/19.
//

import UIKit
import AVFoundation


extension AVCaptureDevice {
    static var videoDevices: [AVCaptureDevice] {
        return AVCaptureDevice.devices(for: AVMediaType.video)
    }
}
