//
//  AudioProcessor.swift
//  Spotty
//
//  Created by Gennaro on 12/10/18.
//  Copyright © 2018 Gennaro. All rights reserved.
//

import AVFoundation
import Accelerate

protocol AudioRecorderDelegate {
    func process(audioBufferList: UnsafeMutablePointer<AudioBufferList>,
                 frameCount: UInt32)
    func buffer(ofSize size: Int) -> ArraySlice<Float>
}

class AudioProcessor : AudioRecorderDelegate {
    
    let circBuffSize = 32768            // lock-free circular fifo/buffer size
    var circBuffer = [Float](repeating: 0, count: 32768)  // for incoming samples
    var circInIdx: Int =  0
    var audioLevel: Float  = 0.0
    
    func process(audioBufferList: UnsafeMutablePointer<AudioBufferList>,
                 frameCount: UInt32) {
        
        let inputDataPtr = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let mBuffers: AudioBuffer = inputDataPtr[0]
        let count = Int(frameCount)
        
        do {
            let dataArray = try mBuffers.toBufferPointer()
            
            var sum : Float = 0.0
            var j = self.circInIdx
            let m = self.circBuffSize
            for i in 0 ..< (count/2) {
                let x = Float(dataArray[i + i  ])     // copy left  channel sample
                let y = Float(dataArray[i + i + 1])   // copy right channel sample
                self.circBuffer[j    ] = x
                self.circBuffer[j + 1] = y
                j += 2 ; if j >= m { j = 0 }          // into circular buffer
                sum += x * x + y * y
            }
            self.circInIdx = j              // circular index will always be less than size
            if sum > 0.0 && count > 0 {
                let tmp = 5.0 * (logf(sum / Float(count)) + 20.0)
                let r : Float = 0.2
                audioLevel = r * tmp + (1.0 - r) * audioLevel
            }
        } catch {
            
        }
    }
    
    func buffer(ofSize size: Int) -> ArraySlice<Float> {
        return self.circBuffer.suffix(size)
    }
    
    func performFFT(of audioBuffer: AudioBuffer,
                    frameCount: UInt32) throws -> [Float] {
        let bufferSize: Int = Int(audioBuffer.mDataByteSize)
        
        // Set up the transform
        let log2n = UInt(round(log2(Double(bufferSize))))
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        
        // Create the complex split value to hold the output of the transform
        var realp = [Float](repeating: 0, count: bufferSize/2)
        var imagp = [Float](repeating: 0, count: bufferSize/2)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        let channelSamples = try audioBuffer.sampleChannels()
        
        // Convert the signal from the buffer to complex value
        vDSP_ctoz(channelSamples, 2, &output, 1, UInt(bufferSize / 2))
        
        // Do the fast Fournier forward transform
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, Int32(FFT_FORWARD))
        
        // Convert the complex output to magnitude
        var fft = [Float](repeating: 0.0, count: Int(bufferSize / 2))
        vDSP_zvmags(&output, 1, &fft, 1, vDSP_Length(bufferSize / 2))
        
        // Release the setup
        vDSP_destroy_fftsetup(fftSetup)
        
        var complexValues = [Float]()
        var scalar: Float = Float(1/(2 * frameCount))
        vDSP_vsmul(realp, 1, &scalar, &(complexValues) + 0, 2, (UInt)(bufferSize/2))
        vDSP_vsmul(imagp, 1, &scalar, &(complexValues) + 1, 2, (UInt)(bufferSize/2))
        
        return complexValues
        
//        var spectrum = [Float]()
//        for i in 0 ..< bufferSize/2 {
//            let imag = output.imagp[i]
//            let real = output.realp[i]
//            let magnitude = sqrt(pow(real,2) + pow(imag,2))
//            spectrum.append(magnitude)
//        }
        
        // TODO: Convert fft to [Float:Float] dictionary of frequency vs magnitude. How?
    }
}

extension AudioBuffer {
    
    func toBufferPointer() throws -> UnsafeMutablePointer<Float> {
        let bufferPointer = UnsafeMutableRawPointer(self.mData)
        
        guard let bptr = bufferPointer else { throw RecorderError.genericError(code: 1) }
        return bptr.assumingMemoryBound(to: Float.self)
    }
    
    func sampleChannels() throws -> [DSPComplex] {
        var channelSamples: [DSPComplex] = []
        
        let bufferSize = Int(self.mDataByteSize)
        let isInterleaved = self.mNumberChannels > 1
        let bufferStride = Int(self.mNumberChannels)
        
        let dataArray = try self.toBufferPointer()
        
        for i in 0 ..< Int(self.mNumberChannels) {
            let firstSample = isInterleaved ? i : i * bufferSize
            for j in stride(from: firstSample, to: bufferSize, by: bufferStride * 2) {
                channelSamples.append(DSPComplex(real: dataArray[i + j],
                                                 imag: dataArray[i + j + bufferStride]))
            }
        }
        
        return channelSamples
    }
}
