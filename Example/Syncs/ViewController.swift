//
//  ViewController.swift
//  Syncs
//
//  Created by manp on 05/06/2017.
//  Copyright (c) 2017 manp. All rights reserved.
//

import UIKit
import Syncs
import SwiftyJSON
class ViewController: UIViewController,SyncsDelegate {
	
	var io:Syncs!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
		self.io=Syncs("ws://192.168.1.33:8080/syncs");
		io.delegate=self
		
		
		
		
		
		
		
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
	
    }

	
	@IBAction func sliderChange(_ sender: UISlider) {
		_ = self.io.shared("info").set("slider1", Int(sender.value))
	}
	
	@IBOutlet weak var remoteSlider: UISlider!
	func onOpen(from syncs: Syncs) {
		print("open")
	}
	func onDisconnect(from syncs: Syncs) {
		print("close")
	}
}

