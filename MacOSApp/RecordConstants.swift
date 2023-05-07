//
//  Constant.swift
//  MacOSApp
//
//  Created by Tuan Hoang on 07/05/2023.
//

import Foundation
import AVFoundation

enum RecordConstants {
    static let bitRate: Int = 192_000
    static let sampleRate: Double = 44_100.0
    static let channels: Int = 1

    static let recordSettings: [String: AnyObject] = [
        AVFormatIDKey: NSNumber(value: Int32(kAudioFormatMPEG4AAC)),
        // Change below to any quality your app requires
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue as AnyObject,
        AVEncoderBitRateKey: bitRate as AnyObject,
        AVNumberOfChannelsKey: channels as AnyObject,
        AVSampleRateKey: sampleRate as AnyObject
    ]

    static let recordFolderName: String = "Record"
}
