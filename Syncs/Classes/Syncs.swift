//
//  Syncs.swift
//  Pods
//
//  Created by Mostafa Alinaghi-pour on 5/6/17.
//
//

import Foundation
import SwiftWebSocket
import SwiftyJSON

public class Syncs{
	public var config:SyncsConfig
	private var socket:WebSocket?
	public var online:Bool=false
	public var delegate:SyncsDelegate?
	private var socketId:String?
	private var handledClose=false
	private var onMessageHandlers:[(_ data:JSON)->()]=[]
	private var onOpenHandlers:[()->()]=[]
	private var onCloseHandlers:[()->()]=[]
	private var onDisconnectHandlers:[()->()]=[]
	// event
	private var subscriptions=[String: [String:(event:String, data:JSON , syncs:Syncs)->()] ]()
	// sync
	private var globalSharedObjects: [String:SharedObject]=[:]
	private var groupSharedObjects: [String: [String:SharedObject] ] = [:]
	private var clientSharedObjects: [String:SharedObject]=[:]
	//RMIT
	private var rmiFunctions:[String : (_ args:[JSON],_ promise:Promise)-> Any? ]=[:]
	private var rmiResultCallbacks:[String: (_ result:JSON,_ error:String?)->() ]=[:]




	public init(_ path:String, autoConnect:Bool=true , autoReconnect:Bool=true , reconnectDelay:Int=1000,debug:Bool=false){
		config=SyncsConfig(path: path, autoConnect: autoConnect, autoReconnect: autoReconnect, reconnectDelay: reconnectDelay, debug: debug);
		
		if config.autoConnect {
			initWebSocket()
		}
	}
	
	
	public func connect(){
		if online {
			return
		}
		if(socket==nil){
			initWebSocket()
		}else{
			socket?.open(config.path)
		}
	}
	private func initWebSocket(){
		do{
			socket = try WebSocket(config.path)
			socket?.event.open=onSocketConnect;
			socket?.event.close=onSocketClose;
			socket?.event.message=onSocketMessage;
			socket?.event.error={_ in }
		}catch{
			
		}
		
		
	}
	
	
	private func onSocketConnect(){
		
	}
	private func onSocketClose(code:Int, reason:String, clean:Bool){
		online=false
		if handledClose || !config.autoReconnect{
			handledClose=false
			triggerOnClose()
		}else{
			triggerOnDisconnect()
			DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(config.reconnectDelay)) {
				if(!self.online){
					self.connect()
				}
				
			}
		}
		
	}
	private func onSocketMessage(message:Any){
		let parsedMessage=parseMessage(message: message as! String)
		if(parsedMessage != nil){
			if parsedMessage["command"].exists() && parsedMessage["type"].exists() {
				handleCommand(command: parsedMessage)
			}else{
				triggerOnMessaage(parsedMessage)
			}
		}
		
	}
	
	private func triggerOnMessaage(_ message:JSON){
		if(delegate != nil){
			delegate?.onMessage(with: message, from: self)
		}
		for var handler in onMessageHandlers {
			handler(message)
		}
		
	}
	private func triggerOnOpen(){
		if(delegate != nil){
			delegate?.onOpen(from: self)
		}
		for var handler in onOpenHandlers {
			handler()
		}
	}
	private func triggerOnClose(){
		if(delegate != nil){
			delegate?.onClose(from: self)
		}
		for var handler in onCloseHandlers {
			handler()
		}
	}
	private func triggerOnDisconnect(){
		if(delegate != nil){
			delegate?.onDisconnect(from: self)
		}
		for var handler in onDisconnectHandlers {
			handler()
		}
	}
	public func onOpen(_ handler: @escaping ()->()){
		onOpenHandlers.append(handler)
	}
	
	public func onClose(_ handler: @escaping ()->() ) {
		onCloseHandlers.append(handler)
	}
	
	public func onDisconnect(_ handler: @escaping ()->() ) {
		onDisconnectHandlers.append(handler)
	}
	
	public func onMessage(_ handler:@escaping (_ data:JSON)->() ) {
		onMessageHandlers.append(handler)
	}
	/**
	* enables debug mode
	*/
	public func enableDebugMode() {
		config.debug=true
	}
	
	/**
	* disables debug mode
	*/
	public func disableDebugMode() {
		config.debug = false;
	}
	
	private func parseMessage(message:String)->JSON{
		let msg=message.removingPercentEncoding
		var json:Any?
		do {
			return try JSON(data:msg!.data(using: .utf8)!)
		} catch {
			return nil
		}
	}
	
	
	private func handleCommand(command:JSON) {
		if config.debug{
			print("INPUT: ",command.rawString())
		}
		
		switch command["type"].string! {
		case "getSocketId":
			sendSocketId()
			if(socketId != nil){
				triggerOnOpen()
			}
			break
		case "setSocketId":
			socketId = command["socketId"].string;
			online = true;
			triggerOnOpen()
			break;
		case "event":
			handleEvent(command);
			break;
		case "sync":
			handleSync(command)
			break
		case "rmi":
			handleRMICommand(command)
			break
		case "rmi-result":
			handleRMIResultCommand(command)
			break
		default: break
			
		}
		
	}
	
	private func sendSocketId() {
		
		if (socketId != nil) {
			let command:JSON=[
				"command":true,
				"type":"reportSocketId",
				"socketId":socketId
				
			]
			sendCommand(command);
			online = true;
		} else {
			let command:JSON=[
				"command":true,
				"type":"reportSocketId",
				"socketId":false
			]
			sendCommand(command);
		}
	}
	
	
	fileprivate func sendCommand(_ command: JSON)->Bool {
		do{
			if(config.debug){
				print("OUT",command.rawString())
			}
			let msg=command.rawString()
			socket?.send(command.rawString())
			return true
		}catch{
			return false
		}
	}
	public func send(_ message: String)->Bool {
		if(online){
			socket?.send(message);
			return true;
		}
		return false;
	}
	public func send(_ message: JSON)->Bool {
		if(online){
			socket?.send(message.rawString());
			return true;
		}
		return false;
	}
	
	
	/************* EVENT *************/
	private func handleEvent(_ command: JSON) {
		if command["event"].exists() {
			if let subs=subscriptions[command["event"].string!] {
				for var sub in subs.values {
						sub(command["event"].string!, command["data"], self)
				}

			}
		}
	}

	public func subscribe(_ event:String,_ callback: @escaping (_ event:String, _ data:JSON , _ syncs:Syncs)->() )->String{
		if subscriptions[event] == nil {
			subscriptions[event]=[:]
		}
		let id=UUID().uuidString
		subscriptions[event]?[id]=callback
		return id
	}

	public func unSubscribe(_ event:String,_ id:String ) {
		if subscriptions[event] != nil {
			subscriptions[event]?.removeValue(forKey: id)
		}
		
	}
	
	public func publish(_ event:String, _ data:JSON)->Bool{
		let command:JSON=[
			"command":true,
			"type":"event",
			"event":event,
			"data":data
		]
		return sendCommand(command)
	}
	

	/************* Shared **************/
	private func handleSync(_ command:JSON){
		let scope=command["scope"].string!
		switch scope {
		case "GLOBAL":
			setGlobalSharedObject(command)
			break
		case "GROUP":
			setGroupSharedObject(command)
			break
		case "CLIENT":
			setClientSharedObject(command)
			break
		default:
			break
		}
	}
	
	private func setGlobalSharedObject(_ command:JSON){
		let name:String=command["name"].string!
		if var sharedObject=globalSharedObjects[name] {
			sharedObject.setProperties(values: command["values"])
		}else{
			globalSharedObjects[name] = SharedObject(name: name, initializeData: [:], server: self, type: .GLOBAL)
		}
	}
	
	private func setGroupSharedObject(_ command:JSON){
		let name:String=command["name"].string!
		let groupName:String=command["group"].string!
		if groupSharedObjects[groupName] == nil {
			groupSharedObjects[groupName]=[:]
		}
		if var sharedObject=groupSharedObjects[groupName]?[name] {
			sharedObject.setProperties(values: command["values"])
		}else{
			groupSharedObjects[groupName]?[name]=SharedObject(name: name, initializeData: [:], server: self, type: .GROUP)
		}
	}
	private func setClientSharedObject(_ command:JSON){
		let name:String=command["name"].string!
		if var sharedObject=clientSharedObjects[name] {
			sharedObject.setProperties(values: command["values"])
		}else{
			clientSharedObjects[name]=SharedObject(name: name, initializeData: [:], server: self, type: .CLIENT)
		}
	}
	public func shared(_ name:String)->SharedObject {
		if clientSharedObjects[name] == nil {
			clientSharedObjects[name]=SharedObject(name: name, initializeData: [:], server: self, type: .CLIENT)
		}
		return clientSharedObjects[name]!
	}
	public func groupShared(_ group:String,_ name:String)->SharedObject{
		if groupSharedObjects[group] == nil {
			groupSharedObjects[group]=[:]
		}
		if groupSharedObjects[group]![name] == nil {
			groupSharedObjects[group]![name]=SharedObject(name: name, initializeData: [:], server: self, type: .GROUP)
		}
		return	groupSharedObjects[group]![name]!
	}
	public func globalShared(_ name:String)->SharedObject {
		if globalSharedObjects[name] == nil {
			globalSharedObjects[name]=SharedObject(name: name, initializeData: [:], server: self, type: .GLOBAL)
		}
		return globalSharedObjects[name]!
	}
	
	
	
	/********** RMI ***********/
	public func functions(_ name:String,_ function: @escaping (_ args:[JSON],_ promise:Promise)-> Any? ){
		self.rmiFunctions[name]=function
	}
	
	
	public func handleRMICommand(_ command:JSON){
		let name:String=command["name"].string!
		let id=command["id"].string!
		if let function=rmiFunctions[name] {
			do{
				var result:Any = function(command["args"].arrayValue,Promise(id,self))
				if result is Promise {
					
				}else {
					sendRmiResultCommand(result: result, error: nil, id: id)
				}
			}catch{
				sendRmiResultCommand(result: nil, error: "function error", id: id)
			}
		}else{
			sendRmiResultCommand(result: nil, error: "undefined", id: id)
		}
	}
	fileprivate func sendRmiResultCommand(result:Any?, error:String? , id:String) {
		var command=JSON([
				"command":true,
				"type":"rmi-result",
				"id":id,
				"result":result,
				"error":error
			])
		
		sendCommand(command);
	}
	
	private func handleRMIResultCommand(_ command:JSON){
		let id=command["id"].string!
		let error=command["error"].string
		let then=rmiResultCallbacks[id]
		if( then != nil ){
			then!(command["result"],error)
			rmiResultCallbacks.removeValue(forKey: id)
		}
	
	}
	
	
	
	public func remote(_ name:String, args:Any...,_ then:@escaping (_ result:JSON, _ error:String?)->() = {result in} ){
		let id:String = UUID().uuidString
		rmiResultCallbacks[id]=then;
		sendRMICommand(name, args, id: id)
	}
	private func sendRMICommand(_ name:String,_ args:[Any] , id:String){
		var command=JSON([
			"command":true,
			"type":"rmi",
			"id":id,
			"name":name,
			"args":args
			])
		
		sendCommand(command);
	}
}


/********** SyncsConfig **********/
public struct SyncsConfig{
	var path:String
	var autoConnect:Bool
	var autoReconnect:Bool
	var reconnectDelay:Int
	var debug:Bool
}


/************ Syncs Delegate ***********/
public protocol SyncsDelegate{
	func onMessage(with data:JSON,from syncs:Syncs)
	func onOpen(from syncs:Syncs)
	func onClose(from syncs:Syncs)
	func onDisconnect(from syncs:Syncs)
}

public extension SyncsDelegate{
	func onMessage(with data:JSON,from syncs:Syncs){}
	func onOpen(from syncs:Syncs){}
	func onClose(from syncs:Syncs){}
	func onDisconnect(from syncs:Syncs){}
	
}


/************ SharedObject ***************/
public class SharedObject{
	public var name:String="";
	private var rawData:[String:Any]=[:]
	private var type:Type?
	private var readOnly = true
	private var server: Syncs?
	private var onChangeHandler:Any?;
	
	
	public init(name: String, initializeData: [String:JSON], server: Syncs,type:Type) {
		self.name = name;
		self.type = type;
		self.readOnly = type != .CLIENT;
		
		self.rawData = initializeData;
		self.server = server;
	}
	
	
	
	public func getString(_ property:String)->String?{
		do {
			var data=try JSON(rawData[property]);
			return try data.string
		} catch {
			return nil
		}
	}
	
	public func getInt(_ property:String)->Int?{
		do {
			var data=try JSON(rawData[property]);
			return try data.int
		} catch {
			return nil
		}
	}
	public func getBool(_ property:String)->Bool?{
		do {
			var data=try JSON(rawData[property]);
			return try data.bool
		} catch {
			return nil
		}
	}
	public func getJSON(_ property:String)->JSON?{
		do {
			return try JSON(rawData[property]);
		} catch {
			return nil
		}
	}
	
	public func set(_ property:String,_ value:String)->SharedObject{
		return setData(property, value)
	}
	public func set(_ property:String,_ value:Int)->SharedObject{
		return setData(property, value)
	}
	public func set(_ property:String,_ value:Bool)->SharedObject{
		return setData(property, value)
	}
	public func set(_ property:String,_ value:JSON)->SharedObject{
		return setData(property, value)
	}
	private func setData(_ key:String,_ value:Any)->SharedObject{
		if(readOnly){
			return self
		}
		rawData[key]=value
		if onChangeHandler != nil {
			var handler:(_ values:[String:JSON], _ by: By)->() = onChangeHandler as! ([String : JSON], SharedObject.By) -> ()
			handler([key:JSON(value)], .CLIENT)
		}
		sendSyncsCommand(key: key)
		
		return self
	}

	private func sendSyncsCommand(key:String){
		let command=JSON([
				"command":true,
				"type":"sync",
				"name":name,
				"scope":"CLIENT",
				"key":key,
				"value":rawData[key]
			])
		server?.sendCommand(command)
	}

	
	fileprivate func setProperties(values:JSON){
		var changedValues:[String:JSON]=[:]
		for (key,value) in values{
			rawData[key]=value.rawValue
			changedValues[key]=value
		}
		if onChangeHandler != nil {
			var handler:(_ values:[String:JSON], _ by: By)->() = onChangeHandler as! ([String : JSON], SharedObject.By) -> ()
			handler(changedValues, .SERVER)
		}
		
	}

	public func onChange(_ handler:@escaping (_ values:[String:JSON], _ by: By)->() ){
		onChangeHandler=handler
	}
	
	/************ ENUMS ************/
	public enum `Type`{
		case GLOBAL
		case GROUP
		case CLIENT
	}
	public enum By{
		case SERVER
		case CLIENT
	}
}


/************ Promise ****************/
public class Promise{
	private var id:String
	private var server:Syncs
	fileprivate init(_ id:String,_ server:Syncs){
		self.id=id
		self.server=server
	}
	public func result(result:Any){
		server.sendRmiResultCommand(result: result, error: nil, id: id)
	}
	
}

