//
//  AudioRecorder.swift
//  Spotty
//
//  Created by Gennaro on 12/3/18.
//  Copyright © 2018 Gennaro. All rights reserved.
//

import AVFoundation

enum RecorderError: Error {
    case recordingInProgress
    case audioUnitNotReady(code: Int)
    case genericError(code: Int)
}

class AudioRecorder {
    var sessionActive = false
    var isRecording = false
    
    var audioUnit: AudioUnit? = nil
    
    var sampleRate: Double = 44100.0    // default audio sample rate
    
    private var interrupted = false // for restart from audio interruption notification
    private var hwSRate = 48000.0   // guess of device hardware sample rate
    
    var numberOfChannels: Int =  2
    
    private let outputBus: UInt32 =  0
    private let inputBus: UInt32 =  1
    
    let delegate: AudioRecorderDelegate = AudioProcessor()
    
    func audioBuffer() -> ArraySlice<Float> {
        return delegate.buffer(ofSize: 256)
    }
    
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
            throw RecorderError.audioUnitNotReady(code: Int(kAudioUnitErr_Uninitialized))
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
        
        guard let audioUnit = self.audioUnit else {
            throw RecorderError.audioUnitNotReady(code: Int(kAudioUnitErr_Uninitialized))
        }
        
        // Enable I/O for input.
        
        var one_ui32: UInt32 = 1
        
        osErr = AudioUnitSetProperty(audioUnit,
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
        
        osErr = AudioUnitSetProperty(audioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input,
                                     outputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        osErr = AudioUnitSetProperty(audioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     inputBus,
                                     &streamFormatDesc,
                                     UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        
        var inputCallbackStruct
            = AURenderCallbackStruct(inputProc: recordingCallback,
                                     inputProcRefCon:
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        osErr = AudioUnitSetProperty(audioUnit,
                                     AudioUnitPropertyID(kAudioOutputUnitProperty_SetInputCallback),
                                     AudioUnitScope(kAudioUnitScope_Global),
                                     inputBus,
                                     &inputCallbackStruct,
                                     UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        
        // Ask CoreAudio to allocate buffers on render.
        osErr = AudioUnitSetProperty(audioUnit,
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
        ioData) -> OSStatus in
        
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
        } else {
            return kAudioUnitErr_Uninitialized
        }
        
        audioObject.delegate.process(audioBufferList: &bufferList,
                                     frameCount: UInt32(frameCount))
        return err
    }
    
    func stopRecording() {
        AudioUnitUninitialize(self.audioUnit!)
        isRecording = false
    }
}
