//
//  MainTableView.swift
//  Spotty
//
//  Created by Gennaro on 1/1/19.
//  Copyright © 2019 Gennaro. All rights reserved.
//

import UIKit

let TableViewRowHeight: CGFloat = 200.0

class ShadowView: UIView {
    override var bounds: CGRect {
        didSet {
            setupShadow()
        }
    }
    
    private func setupShadow() {
        self.layer.cornerRadius = 8
        self.layer.shadowOffset = CGSize(width: 0, height: 3)
        self.layer.shadowRadius = 3
        self.layer.shadowOpacity = 0.3
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, byRoundingCorners: .allCorners, cornerRadii: CGSize(width: 8, height: 8)).cgPath
        self.layer.shouldRasterize = true
        self.layer.rasterizationScale = UIScreen.main.scale
    }
}

class MainTableViewController: UITableViewController {
    
    var spectogramCellRef: FrequencyUITableViewCell? = nil
    
    var frequencyValues: Array<Float> = [] {
        didSet(freqVals) {
            spectogramCellRef?.updateBarFrames(frequencyValues: frequencyValues)
            spectogramCellRef?.setNeedsLayout()
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Spectogram"
        } else if section == 1 {
            return "Image"
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.backgroundColor = .clear
            headerView.backgroundView?.backgroundColor = .clear
            headerView.textLabel?.textColor = .white
            headerView.textLabel?.textAlignment = .right
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 {
            return TableViewRowHeight
        }
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "Main") as? FrequencyUITableViewCell
        if cell == nil {
            cell = FrequencyUITableViewCell(style: .default, reuseIdentifier: "Main")
        }
        spectogramCellRef = cell
        return cell!
    }
}
