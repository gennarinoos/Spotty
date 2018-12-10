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
    
    @IBOutlet var stateControllerView: UIView?
    @IBOutlet var stateControllerButton: StateControllerUIButton?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = MainViewBackgroundColor
        self.stateControllerView?.backgroundColor = UIColor.clear
    }


}

