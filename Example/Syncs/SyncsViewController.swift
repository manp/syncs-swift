//
//  SyncsViewController.swift
//  Syncs
//
//  Created by Mostafa Alinaghi-pour on 5/8/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import UIKit
import Syncs
import SwiftyJSON
public class SyncsViewController:UIViewController,SyncsDelegate {
	@IBOutlet weak var statusLabel: UILabel!
	@IBOutlet weak var loading: UIActivityIndicatorView!
	public static var serverAddress=""
	
	@IBOutlet weak var titleInput: UITextField!
	@IBOutlet weak var colorChooserBtn: UIButton!
	
	private var info:SharedObject?
	private var settings:SharedObject?
	var io:Syncs!
	var colors:[String:UIColor]=["red":UIColor.red,"green":UIColor.green,"orange":UIColor.orange,"blue":UIColor.blue,"purple":UIColor.purple,"brown":UIColor.brown]
	override public func viewDidLoad() {
		super.viewDidLoad()
		
		io=Syncs(SyncsViewController.serverAddress)
		io.delegate=self
		
		info=io.shared("info")
		
		
		info?.onChange(){ _,_ in
			self.settings=self.io.groupShared((self.info?.getString("group"))!, "settings")
			self.settings?.onChange(){ _,_ in
				self.renderSettings()
			}
		}
		
	}
	
	override public func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	

	
	public func onOpen(from syncs: Syncs) {
		loading.stopAnimating()
		statusLabel.text="connected"
		print("OPEN")
	}
	public func onClose(from syncs: Syncs) {
		
	}
	public func onDisconnect(from syncs: Syncs) {
		loading.startAnimating()
		statusLabel.text="connecting"
		print("DISCONNECT")
	}
	
	public func renderSettings(){
		if let settings=settings {
			self.view.backgroundColor=colors[settings.getString("color")!]
			self.colorChooserBtn.setTitle(settings.getString("color")!, for: .normal)
			self.colorChooserBtn.setTitleColor(colors[settings.getString("color")!], for: .normal)
			
			self.navigationController?.navigationBar.topItem?.title=settings.getString("title")!
			self.titleInput.text=settings.getString("title")!
			
			
		}
	}
	
	@IBAction func changeGroupBtnClick(_ sender: Any) {
		
		if let group=self.info?.getString("group") {
			
			let group0=UIAlertAction(title: "Group 1", style: .default, handler: {_ in
				_ = self.info?.set("group", "0")
			})
			let group1=UIAlertAction(title: "Group 2", style: .default, handler: {_ in
				_ = self.info?.set("group", "1")
			})
			let group2=UIAlertAction(title: "Group 3", style: .default, handler: {_ in
				_ = self.info?.set("group", "2")
			})
			
			
			let controller=UIAlertController(title: "Change Group", message: "select a group", preferredStyle: .actionSheet)
			
			
			
			
			if(group != "0"){
				controller.addAction(group0)
			}
			if(group != "1"){
				controller.addAction(group1)
			}
			if(group != "2"){
				controller.addAction(group2)
			}
			present(controller, animated: true, completion: nil)
		}
		
	}
	
	@IBAction func onTitleChange(_ sender: Any) {
		_ = io.publish("title-change", JSON(["group":info?.getString("group"),"title":titleInput.text]))

	}
	
	@IBAction func colorChange(_ sender: Any) {
		let controller=UIAlertController(title: "Chose a Color", message: nil, preferredStyle: .actionSheet)
		
		for color in colors.keys {
			controller.addAction(UIAlertAction(title: color, style: .default){
				_ in
				_ = self.io.publish("color-change", JSON(["group":self.info?.getString("group"),"color":color]))
			})
		}
		
		present(controller, animated: true, completion: nil)
		
	}
	
}
