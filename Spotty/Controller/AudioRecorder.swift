//
//  AudioRecorder.swift
//  Spotty
//
//  Created by Gennaro on 12/3/18.
//  Copyright © 2018 Gennaro. All rights reserved.
//

import Foundation
import AVFoundation

enum RecorderError: Error {
    case recordingInProgress
    case audioUnitNotReady(code: Int)
}

class AudioRecorder {
    var sessionActive = false
    var isRecording = false
    
    var audioUnit: AudioUnit? = nil
    
    var sampleRate: Double = 44100.0    // default audio sample rate
    let circBuffSize = 32768            // lock-free circular fifo/buffer size
    var circBuffer = [Float](repeating: 0, count: 32768)  // for incoming samples
    var circInIdx: Int =  0
    var audioLevel: Float  = 0.0
    
    private var interrupted = false // for restart from audio interruption notification
    private var hwSRate = 48000.0   // guess of device hardware sample rate
    
    var numberOfChannels: Int =  2
    
    private let outputBus: UInt32 =  0
    private let inputBus: UInt32 =  1
    
    
    func startRecording() throws {
        guard !isRecording else {
            throw RecorderError.recordingInProgress
        }
        
        try startAudioSession()
        
        if sessionActive {
            try startAudioUnit()
        }
    }
    
    func startAudioSession() throws {
        if (sessionActive == false) {
            // set and activate Audio Session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .default, options: .allowBluetooth)
            
            // choose 44100 or 48000 based on hardware rate
            // sampleRate = 44100.0
            var preferredIOBufferDuration = 0.0058      // 5.8 milliseconds = 256 samples
            hwSRate = audioSession.sampleRate           // get native hardware rate
            if hwSRate == 48000.0 { sampleRate = 48000.0 }  // set session to hardware rate
            if hwSRate == 48000.0 { preferredIOBufferDuration = 0.0053 }
            let desiredSampleRate = sampleRate
            try audioSession.setPreferredSampleRate(desiredSampleRate)
            try audioSession.setPreferredIOBufferDuration(preferredIOBufferDuration)
            
            NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
                                                   object: nil,
                                                   queue: nil,
                                                   using: audioSessionInterruptionHandler)
            
            try audioSession.setActive(true)
            sessionActive = true
        }
    }
    
    func startAudioUnit() throws {
        var err: OSStatus = noErr
        
        if self.audioUnit == nil {
            try setupAudioUnit() // setup once
        }
        guard let au = self.audioUnit else {
            throw RecorderError.audioUnitNotReady(code: Int(err))
        }
        
        err = AudioUnitInitialize(au)
        if err != noErr {
            throw RecorderError.audioUnitNotReady(code: Int(err))
        }

        err = AudioOutputUnitStart(au)  // start
        
        if err == noErr {
            isRecording = true
        } else {
            throw RecorderError.audioUnitNotReady(code: Int(err))
        }
    }
    
    private func setupAudioUnit() throws {
        
        var componentDesc:  AudioComponentDescription
            = AudioComponentDescription(
                componentType:          OSType(kAudioUnitType_Output),
                componentSubType:       OSType(kAudioUnitSubType_RemoteIO),
                componentManufacturer:  OSType(kAudioUnitManufacturer_Apple),
                componentFlags:         UInt32(0),
                componentFlagsMask:     UInt32(0) )
        
        var osErr: OSStatus = noErr
        
        let component: AudioComponent! = AudioComponentFindNext(nil, &componentDesc)
        
        var tempAudioUnit: AudioUnit?
        osErr = AudioComponentInstanceNew(component, &tempAudioUnit)
        self.audioUnit = tempAudioUnit
        
        guard let au = self.audioUnit else {
            throw RecorderError.audioUnitNotReady(code: Int(osErr))
        }
        
        // Enable I/O for input.
        
        var one_ui32: UInt32 = 1
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Input,
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<Float32>.size))
        
        // Set format to 32-bit Floats, linear PCM
        let nc = 2  // 2 channel stereo
        var streamFormatDesc:AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate:        Double(sampleRate),
            mFormatID:          kAudioFormatLinearPCM,
            mFormatFlags:       ( kAudioFormatFlagsNativeFloatPacked ),
            mBytesPerPacket:    UInt32(nc * MemoryLayout<UInt32>.size),
            mFramesPerPacket:   1,
            mBytesPerFrame:     UInt32(nc * MemoryLayout<UInt32>.size),
            mChannelsPerFrame:  UInt32(nc),
            mBitsPerChannel:    UInt32(8 * (MemoryLayout<UInt32>.size)),
            mReserved:          UInt32(0)
        )
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input,
                                     outputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        osErr = AudioUnitSetProperty(au,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: recordingCallback,
                                     inputProcRefCon:
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                     AudioUnitScope(kAudioUnitScope_Global),
                                     inputBus,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // Ask CoreAudio to allocate buffers on render.
        osErr = AudioUnitSetProperty(au,
                                     AudioUnitPropertyID(kAudioUnitProperty_ShouldAllocateBuffer),
                                     AudioUnitScope(kAudioUnitScope_Output),
                                     inputBus,
                                     &one_ui32,
                                     UInt32(MemoryLayout<UInt32>.size))
        if osErr != noErr {
            throw RecorderError.audioUnitNotReady(code: Int(osErr))
        }
    }
    
    func audioSessionInterruptionHandler(notification: Notification) -> Void {
        let interuptionDict = notification.userInfo
        if let interuptionType = interuptionDict?[AVAudioSessionInterruptionTypeKey] {
            let rawValue = (interuptionType as AnyObject).uintValue!
            let interuptionVal = AVAudioSession.InterruptionType(rawValue: rawValue)
            if (interuptionVal == AVAudioSession.InterruptionType.began) {
                if (isRecording) {
                    stopRecording()
                    isRecording = false
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setActive(false)
                        sessionActive = false
                    } catch {
                    }
                    interrupted = true
                }
            } else if (interuptionVal == AVAudioSession.InterruptionType.ended) {
                if (interrupted) {
                    // potentially restart here
                }
            }
        }
    }
    
    let recordingCallback: AURenderCallback = { (
        inRefCon,
        ioActionFlags,
        inTimeStamp,
        inBusNumber,
        frameCount,
        ioData ) -> OSStatus in
        
        let audioObject = unsafeBitCast(inRefCon, to: AudioRecorder.self)
        var err: OSStatus = noErr
        
        // set mData to nil, AudioUnitRender() should be allocating buffers
        let mBuffers = AudioBuffer(mNumberChannels: UInt32(2),
                                   mDataByteSize: 2048,
                                   mData: nil)
        var bufferList = AudioBufferList(mNumberBuffers: 1,
                                         mBuffers: mBuffers)
        
        if let au = audioObject.audioUnit {
            err = AudioUnitRender(au,
                                  ioActionFlags,
                                  inTimeStamp,
                                  inBusNumber,
                                  frameCount,
                                  &bufferList)
        }
        
        audioObject.processMicrophoneBuffer(inputDataList: &bufferList,
                                            frameCount: UInt32(frameCount))
        return 0
    }
    
    //
    // process RemoteIO Buffer from mic input
    //
    func processMicrophoneBuffer(inputDataList: UnsafeMutablePointer<AudioBufferList>,
                                 frameCount: UInt32) {
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(inputDataList)
        let mBuffers : AudioBuffer = inputDataPtr[0]
        let count = Int(frameCount)
        
        let bufferPointer = UnsafeMutableRawPointer(mBuffers.mData)
        if let bptr = bufferPointer {
            let dataArray = bptr.assumingMemoryBound(to: Float.self)
            var sum : Float = 0.0
            var j = self.circInIdx
            let m = self.circBuffSize
            for i in 0..<(count/2) {
                let x = Float(dataArray[i+i  ])   // copy left  channel sample
                let y = Float(dataArray[i+i+1])   // copy right channel sample
                self.circBuffer[j    ] = x
                self.circBuffer[j + 1] = y
                j += 2 ; if j >= m { j = 0 }      // into circular buffer
                sum += x * x + y * y
            }
            self.circInIdx = j              // circular index will always be less than size
            if sum > 0.0 && count > 0 {
                let tmp = 5.0 * (logf(sum / Float(count)) + 20.0)
                let r : Float = 0.2
                audioLevel = r * tmp + (1.0 - r) * audioLevel
            }
        }
    }
    
    func stopRecording() {
        AudioUnitUninitialize(self.audioUnit!)
        isRecording = false
    }
}
