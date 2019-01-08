//
//  ViewController.swift
//  Spotty
//
//  Created by Gennaro on 12/3/18.
//  Copyright © 2018 Gennaro. All rights reserved.
//

import UIKit

let MainViewBackgroundColor = UIColor(red: 8.0/255.0, green: 161.0/255.0, blue: 95.0/255.0, alpha: 1.0)

class MainViewController: UIViewController {
    
    let stateManager = StateManager.sharedInstance()
    
    @IBOutlet var tableView: UITableView?
    @IBOutlet var stateControllerView: UIView?
    @IBOutlet var stateControllerButton: StateControllerUIButton?
    
    let tableViewController = MainTableViewController()
    
    var timer: Timer?
    
    @objc func timerTick(_ sender: Timer?) {
        if stateManager.recordingState == .listening {
            tableViewController.frequencyValues = Array<Float>(stateManager.audioRecorder.audioBuffer())
        } else {
            tableViewController.frequencyValues = Array<Float>(repeating: 0.1, count: 256)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer = Timer(timeInterval: 0.01,
                      target: self,
                      selector: #selector(MainViewController.timerTick),
                      userInfo: nil,
                      repeats: true)
        RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
        
        self.view.backgroundColor = MainViewBackgroundColor
        
        self.styleTableView()
        self.styleStateControllerView()
        
        self.tableView?.delegate = tableViewController
        self.tableView?.dataSource = tableViewController
    }
    
    func styleTableView() {
        self.tableView?.backgroundColor = .clear
        self.tableView?.separatorStyle = .none
        self.tableView?.keyboardDismissMode = .onDrag
        self.tableView?.isScrollEnabled = false
        self.tableView?.allowsSelection = false
    }
    
    func styleStateControllerView() {
        self.stateControllerView?.backgroundColor = UIColor.clear
    }
}

