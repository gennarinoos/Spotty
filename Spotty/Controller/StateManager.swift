//
//  StateManager.swift
//  Spotty
//
//  Created by Gennaro on 12/3/18.
//  Copyright © 2018 Gennaro. All rights reserved.
//

import Foundation
import AVFoundation

enum AudioRecordingState {
    case listening
    case idle
}

extension Notification.Name {
    static let listening = Notification.Name("listening")
    static let idle = Notification.Name("idle")
    static let inconsistentState = Notification.Name("inconsistentState")
    static let permissionDenied = Notification.Name("permissionDenied")
    static let recorderError = Notification.Name("recorderError")
}

class StateManager {
    
    var recordingState: AudioRecordingState = .idle
    
    let audioRecorder: AudioRecorder
    let recordingSession: AVAudioSession
    
    init() {
        audioRecorder = AudioRecorder()
        recordingSession = AVAudioSession.sharedInstance()
        setupObservers()
    }
    
    func setupObservers() {
        NotificationCenter.default.addObserver(forName: .listening,
                                               object: nil,
                                               queue: nil,
                                               using: startListening)
        NotificationCenter.default.addObserver(forName: .idle,
                                               object: nil,
                                               queue: nil,
                                               using: stopListening)
    }
    
    @objc func startListening(notification: Notification) {
        guard recordingState != .listening else {
            NotificationCenter.default.post(name: .inconsistentState,
                                            object: recordingState,
                                            userInfo: nil)
            return
        }
        
        recordingState = .listening
        
        do {
            try recordingSession.setCategory(.record, mode: .default)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        do {
                            try self.audioRecorder.startRecording()
                        } catch RecorderError.audioUnitNotReady(let code) {
                            NotificationCenter.default.post(name: .recorderError,
                                                            object: code,
                                                            userInfo: nil)
                        } catch {
                            NotificationCenter.default.post(name: .recorderError,
                                                            object: nil,
                                                            userInfo: nil)
                        }
                    } else {
                        NotificationCenter.default.post(name: .permissionDenied,
                                                        object: nil,
                                                        userInfo: nil)
                    }
                }
            }
        } catch {
            
        }
        
    }
    
    @objc func stopListening(notification: Notification) {
        recordingState = .idle
        
        self.audioRecorder.stopRecording()
    }
}
