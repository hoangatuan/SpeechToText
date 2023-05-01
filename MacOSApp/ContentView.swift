//
//  ContentView.swift
//  MacOSApp
//
//  Created by Tuan Hoang on 20/04/2023.
//

import SwiftUI
import AVFoundation
import Speech

struct ContentView: View {
    @ObservedObject
    private var recordService: RecordService

    init() {
        recordService = RecordService()
    }

    var body: some View {
        VStack {
            Text(recordService.audioText)

            Button {
                recordService.startRecording()
            } label: {
                Text("Record")
            }

            Spacer().frame(height: 16)

            Button {
                recordService.stopRecording()
            } label: {
                Text("Stop")
            }
        }
        .padding()
        .onAppear {
            recordService.requestRecordPermission()
            recordService.askingForSpeechPermission()
        }
    }


}

final class RecordService: NSObject, AVCaptureFileOutputRecordingDelegate, ObservableObject {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        debugPrint("Tuanha24: Did finish recording to: \(outputFileURL)")
    }

    // Speech
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Record
    private var audioOutput: AVCaptureAudioFileOutput?
    private var audioInput: AVCaptureDeviceInput?
    private var captureSession = AVCaptureSession()

    @Published
    var audioText = "Not recording right now"

    func askingForSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    debugPrint("Authorized for speech")
                case .denied:
                    debugPrint("Denied for speech")
                case .restricted:
                    debugPrint("Restricted for speech")
                case .notDetermined:
                    debugPrint("Not Determined for speech")
                }
            }
        }
    }

    func requestRecordPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            debugPrint("Authorized for record")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                debugPrint("Is granted for record: \(granted)")
            }
        case .restricted, .denied:
            debugPrint("Restricted/Denied for record")
        }
    }

    func prepare() throws {
        let captureDevice = AVCaptureDevice.default(for: .audio)!
        do {
            try captureDevice.lockForConfiguration()
            audioInput = try AVCaptureDeviceInput(device: captureDevice)
            captureDevice.unlockForConfiguration()

            audioOutput = AVCaptureAudioFileOutput()
            audioOutput?.audioSettings = RecordConstants.recordSettings
        } catch let error {
            throw(error)
        }

        guard let audioInput = audioInput, let audioOutput = audioOutput else {
            fatalError()
        }

        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()
        if !captureSession.canAddInput(audioInput) || !captureSession.canAddOutput(audioOutput) {
            fatalError()
        }

        captureSession.addInput(audioInput)
        captureSession.addOutput(audioOutput)

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    func startRecording() {
        audioText = "I'm listening..."
        if audioOutput == nil {
            do {
                try prepare()
                prepareSpeech()
            } catch let error {
                fatalError()
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        audioEngine.prepare()

        guard let fileUrl = RecordUtil.generateRecordFileURL() else { fatalError() }
        debugPrint("Tuanha24: File URL: \(fileUrl)")
        audioOutput?.startRecording(to: fileUrl, outputFileType: .m4a, recordingDelegate: self)
        try! audioEngine.start()
    }

    func prepareSpeech() {
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
//        recognitionRequest.requiresOnDeviceRecognition = false

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false

            if let result = result {
                // Update the text view with the results.
                self.audioText = result.bestTranscription.formattedString
                isFinal = result.isFinal
                print("Text \(result.bestTranscription.formattedString)")
            }

            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
    }

    func stopRecording() {
        audioText = "Not recording right now"
        recognitionRequest?.endAudio()
        audioOutput?.stopRecording()
        captureSession.stopRunning()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioOutput = nil
    }
}

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

final class RecordUtil {
    static func urlForRecordFolder() -> URL? {
        let fileManager = FileManager.default
        guard let cacheUrl = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let recordFolderUrl = cacheUrl.appendingPathComponent("MACOSAPP").appendingPathComponent(RecordConstants.recordFolderName)
        var isDirectory: ObjCBool = false
        let isFolderExists = fileManager.fileExists(atPath: recordFolderUrl.path, isDirectory: &isDirectory)

        if !isFolderExists || !isDirectory.boolValue {
            do {
                try fileManager.createDirectory(at: recordFolderUrl,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                return nil
            }
        }

        return recordFolderUrl
    }

    static func generateRecordFileURL() -> URL? {
        guard let recordFolderURL = urlForRecordFolder() else {
            return nil
        }

        let dataFileUrl = recordFolderURL.appendingPathComponent("RecordDemo.m4a")
        return dataFileUrl
    }

    static func generateRemoveNoiseRecordFileURL(from url: URL) -> URL? {
        let baseUrl = url.deletingPathExtension()
        var csFilePath = baseUrl.absoluteString
        csFilePath.append(contentsOf: "-CS")
        csFilePath.append(contentsOf: ".m4a")
        return URL(string: csFilePath)
    }
}

