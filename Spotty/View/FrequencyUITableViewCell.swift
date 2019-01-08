//
//  FrequencyUITableViewCell.swift
//  Spotty
//
//  Created by Gennaro on 1/1/19.
//  Copyright © 2019 Gennaro. All rights reserved.
//

import UIKit

class FrequencyUITableViewCell: UITableViewCell {
    
    @IBOutlet var mainBackground: UIView?
    @IBOutlet var shadowLayer: ShadowView?
    
    var barViews: [UIView] = []
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.initializeViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.initializeViews()
    }
    
    func initializeViews() {
        self.setupBarViews()
        
        self.backgroundColor = UIColor.clear
        
        //We want to handle the layout of the subviews
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func setupBarViews() {
        for _ in 0...255 {
            let view = UIView(frame: CGRect.zero)
            view.backgroundColor = UIColor.red // MainViewBackgroundColor
            barViews.append(view)
            self.addSubview(view)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.mainBackground?.backgroundColor = UIColor.white
        self.mainBackground?.layer.cornerRadius = 8
        self.mainBackground?.layer.masksToBounds = true
    }
    
    func updateBarFrames(frequencyValues: [Float]) {
        let frame = CGRect(x: self.contentView.frame.minX + 12,
                           y: self.contentView.frame.minY + 12,
                           width: self.contentView.frame.width - 24,
                           height: self.contentView.frame.height - 24)
        
        //Layout the bars based on the updated view frame
        let barWidth = frame.size.width / CGFloat(barViews.count)
        
        for i in 0 ..< barViews.count {
            let barView = barViews[i]
            
            var barHeight = CGFloat(0)
            let viewHeight = frame.size.height
            
            if frequencyValues.count > i {
                barHeight = viewHeight * CGFloat(frequencyValues[i]);
            }
            
            barView.frame = CGRect(x: CGFloat(i) * barWidth, y: viewHeight - barHeight, width: barWidth, height: barHeight);
        }
    }
}
