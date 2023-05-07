//
//  RecordService.swift
//  MacOSApp
//
//  Created by Tuan Hoang on 07/05/2023.
//

import Foundation
import AVFoundation
import Speech

final class RecordService: NSObject, ObservableObject {

    // MARK: - Speech
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Record
    private var audioOutput: AVCaptureAudioFileOutput?
    private var audioInput: AVCaptureDeviceInput?
    private var captureSession = AVCaptureSession()

    @Published
    var audioText = "Not recording right now"

    override init() {
        super.init()
        speechRecognizer.delegate = self
    }

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

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, delegate: self)
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

extension RecordService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        debugPrint("Did finish recording to: \(outputFileURL)")
    }
}

extension RecordService: SFSpeechRecognizerDelegate, SFSpeechRecognitionTaskDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("SpeechRecognizer available: \(available)")
    }

    // MARK: Speech Recognizer Task Delegate

    func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionDidDetectSpeech")

    }

    func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionTaskFinishedReadingAudio")
    }

    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        print("speechRecognitionTaskWasCancelled")
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didRecord audioPCMBuffer: AVAudioPCMBuffer) {
        print("didRecord")
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        print("didHypothesizeTranscription")
        self.audioText = transcription.formattedString
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        print("didFinishRecognition")
        if task.error != nil {
            debugPrint("Error occur: \(task.error)")
            stopRecording()
        }
    }

    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        debugPrint("Did finish: Is successfully: \(successfully) - error: \(task.error)")
        stopRecording()
    }
}
