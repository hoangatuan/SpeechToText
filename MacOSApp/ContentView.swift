//
//  ContentView.swift
//  MacOSApp
//
//  Created by Tuan Hoang on 20/04/2023.
//

import SwiftUI

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
