//
//  ViewController.swift
//  Syncs
//
//  Created by manp on 05/06/2017.
//  Copyright (c) 2017 manp. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
	
	
	
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
		
    }

	
	@IBOutlet weak var address: UITextField!
	@IBOutlet weak var startBtn: UIButton!
	@IBAction func onAddressChange(_ sender: UITextField) {
		startBtn.isEnabled = address.text != ""
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		SyncsViewController.serverAddress=address.text!
	}
	
	
	
	
	
	
	
	
}

