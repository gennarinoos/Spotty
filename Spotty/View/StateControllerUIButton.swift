//
//  SPStateControllerUIButton.swift
//  Spotty
//
//  Created by Gennaro on 12/3/18.
//  Copyright © 2018 Gennaro. All rights reserved.
//

import UIKit

let ShadowOpacity: Float = 0.8

class StateControllerUIButton: UIButton {
    
    var shadowLayer: CAShapeLayer!
    var recordingState: AudioRecordingState = .idle
    
    override func awakeFromNib() {
        self.addTarget(self, action: #selector(toggleState), for: .touchUpInside)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if shadowLayer == nil {
            shadowLayer = CAShapeLayer()
            shadowLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: self.frame.size.height / 2).cgPath
            shadowLayer.fillColor = UIColor.white.cgColor
            
            shadowLayer.shadowColor = UIColor.darkGray.cgColor
            shadowLayer.shadowPath = shadowLayer.path
            shadowLayer.shadowOffset = CGSize(width: 2.0, height: 2.0)
            shadowLayer.shadowOpacity = ShadowOpacity
            shadowLayer.shadowRadius = 2
            
            layer.insertSublayer(shadowLayer, below: nil)
        }
        
        self.setTitle(recordingState == .listening ? "L" : "I", for: .normal)
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0) { [unowned self] in
                if let layer = self.shadowLayer {
                    layer.shadowOpacity = self.isHighlighted ? 0.1 : ShadowOpacity
                }
            }
        }
    }
    
    @objc func toggleState() {
        if recordingState == .idle {
            NotificationCenter.default.post(name: Notification.Name.listening,
                                            object: AudioRecordingState.listening,
                                            userInfo: nil)
            recordingState = .listening
        } else {
            NotificationCenter.default.post(name: Notification.Name.idle,
                                            object: AudioRecordingState.idle,
                                            userInfo: nil)
            recordingState = .idle
        }
        
        self.setNeedsLayout()
        
    }
    
}
