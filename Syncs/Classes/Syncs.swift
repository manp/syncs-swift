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

/// Syncs class to create a presistent connection between swift application and Syncs server
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
	private var rmiFunctions:[String : (_ args:[JSON],_ promise:Promise) throws -> Any? ]=[:]
	private var rmiResultCallbacks:[String: (_ result:JSON,_ error:String?)->() ]=[:]



	/**
	creates new Syncs instance
	
	- parameters:
		- path: syncs server address ("ws://localhost/syncs")
		- autoConnect: automatically connect on create , default true
		- autoReconnect: automatically reconnect on unhandled disconnect, default true
		- reconnectDelay: time between each connection try, default 1000
		- debug: enables debug mode, defualt true
	
	*/
	public init(_ path:String, autoConnect:Bool=true , autoReconnect:Bool=true , reconnectDelay:Int=1000,debug:Bool=false){
		config=SyncsConfig(path: path, autoConnect: autoConnect, autoReconnect: autoReconnect, reconnectDelay: reconnectDelay, debug: debug);
		
		if config.autoConnect {
			initWebSocket()
		}
	}
	
	/**
	tries to connect to server
	*/
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
	
	
	/// disconnect from server
	public func disconnect(){
		self.handledClose=true;
		self.socket?.close()
	}
	private func initWebSocket(){
			socket = WebSocket(config.path)
			socket?.event.open=onSocketConnect;
			socket?.event.close=onSocketClose;
			socket?.event.message=onSocketMessage;
			socket?.event.error={_ in }
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
		if(parsedMessage != JSON.null){
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
		for handler in onMessageHandlers {
			handler(message)
		}
		
	}
	private func triggerOnOpen(){
		if(delegate != nil){
			delegate?.onOpen(from: self)
		}
		for  handler in onOpenHandlers {
			handler()
		}
	}
	private func triggerOnClose(){
		if(delegate != nil){
			delegate?.onClose(from: self)
		}
		for  handler in onCloseHandlers {
			handler()
		}
	}
	private func triggerOnDisconnect(){
		if(delegate != nil){
			delegate?.onDisconnect(from: self)
		}
		for  handler in onDisconnectHandlers {
			handler()
		}
	}
	
	/**
	handle open event
	- parameters:
		- handler: function to call when client connects to server
	*/
	public func onOpen(_ handler: @escaping ()->()){
		onOpenHandlers.append(handler)
	}
	/**
	handle close event
	- parameters:
		- handler: function to call when client close connection
	*/
	public func onClose(_ handler: @escaping ()->() ) {
		onCloseHandlers.append(handler)
	}
	
	/**
	handle disconnect event
	- parameters:
		- handler: function to call when client disconnect from server
	*/
	public func onDisconnect(_ handler: @escaping ()->() ) {
		onDisconnectHandlers.append(handler)
	}
	
	/**
	handle message event
	- parameters:
		- handler: function to call incoming message arives
	*/
	public func onMessage(_ handler:@escaping (_ data:JSON)->() ) {
		onMessageHandlers.append(handler)
	}
	/**
	enables debug mode
	*/
	public func enableDebugMode() {
		config.debug=true
	}
	
	/**
	disables debug mode
	*/
	public func disableDebugMode() {
		config.debug = false;
	}
	
	private func parseMessage(message:String)->JSON{
		let msg=message.removingPercentEncoding
		return JSON(data:msg!.data(using: .utf8)!)
	}
	
	
	private func handleCommand(command:JSON) {
		if config.debug{
			print("INPUT: ",command.rawString()! )
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
				"socketId":socketId!
				
			]
			_ = sendCommand(command);
			online = true;
		} else {
			let command:JSON=[
				"command":true,
				"type":"reportSocketId",
				"socketId":false
			]
			_ = sendCommand(command);
		}
	}
	
	
	fileprivate func sendCommand(_ command: JSON)->Bool {
			if(config.debug){
				print("OUT",command.rawString()!)
			}
			socket?.send(command.rawString()!)
			return true
	}
	
	
	/**
	send  String message to server
	- parameters:
		- message: message string
	- returns:
		send result in boolean
	*/
	public func send(_ message: String)->Bool {
		if(online){
			socket?.send(message);
			return true;
		}
		return false;
	}
	/**
	send json message to server
	- parameters:
		- message: json object
	- returns:
		send result in boolean
	*/
	public func send(_ message: JSON)->Bool {
		if(online){
			socket?.send(message.rawString()!);
			return true;
		}
		return false;
	}
	
	
	/************* EVENT *************/
	private func handleEvent(_ command: JSON) {
		if command["event"].exists() {
			if let subs=subscriptions[command["event"].string!] {
				for sub in subs.values {
						sub(command["event"].string!, command["data"], self)
				}

			}
		}
	}

	/**
	subscribe to an event
	- parameters:
		- event: event name in string
		- callback: function to call on event trigger
	- returns:
		String id to use for unsubscription
	*/
	public func subscribe(_ event:String,_ callback: @escaping (_ event:String, _ data:JSON , _ syncs:Syncs)->() )->String{
		if subscriptions[event] == nil {
			subscriptions[event]=[:]
		}
		let id=UUID().uuidString
		subscriptions[event]?[id]=callback
		return id
	}
	/**
	unsubscribe from an event
	- parameters:
		- event: event name in string
		- id: subsciption id
	*/
	public func unSubscribe(_ event:String,_ id:String ) {
		if subscriptions[event] != nil {
			_ = subscriptions[event]?.removeValue(forKey: id)
		}
		
	}
	
	/**
	publish an event to server
	- parameters:
		- event: event name in string
		- data: event data in JSON
	- returns:
		publish result in Bool
	*/
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
		if let sharedObject=globalSharedObjects[name] {
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
		if let sharedObject=groupSharedObjects[groupName]?[name] {
			sharedObject.setProperties(values: command["values"])
		}else{
			groupSharedObjects[groupName]?[name]=SharedObject(name: name, initializeData: [:], server: self, type: .GROUP)
		}
	}
	private func setClientSharedObject(_ command:JSON){
		let name:String=command["name"].string!
		if let sharedObject=clientSharedObjects[name] {
			sharedObject.setProperties(values: command["values"])
		}else{
			clientSharedObjects[name]=SharedObject(name: name, initializeData: [:], server: self, type: .CLIENT)
		}
	}
	
	
	/**
	allow access to Client level SharedObject
	- parameters:
		- name: shared object name
	- returns:
		shared object
	*/
	public func shared(_ name:String)->SharedObject {
		if clientSharedObjects[name] == nil {
			clientSharedObjects[name]=SharedObject(name: name, initializeData: [:], server: self, type: .CLIENT)
		}
		return clientSharedObjects[name]!
	}
	
	/**
	allow access to Group level SharedObject
	- parameters:
		- group: group name
		- name: shared object name
	- returns:
		shared object
	*/
	public func groupShared(_ group:String,_ name:String)->SharedObject{
		if groupSharedObjects[group] == nil {
			groupSharedObjects[group]=[:]
		}
		if groupSharedObjects[group]![name] == nil {
			groupSharedObjects[group]![name]=SharedObject(name: name, initializeData: [:], server: self, type: .GROUP)
		}
		return	groupSharedObjects[group]![name]!
	}
	
	/**
	allow access to Global level SharedObject
	- parameters:
		- name: shared object name
	- returns:
		shared object
	*/
	public func globalShared(_ name:String)->SharedObject {
		if globalSharedObjects[name] == nil {
			globalSharedObjects[name]=SharedObject(name: name, initializeData: [:], server: self, type: .GLOBAL)
		}
		return globalSharedObjects[name]!
	}
	
	
	
	/********** RMI ***********/
	
	

	/// using this method developers can register new remote function
	///
	/// - Parameters:
	///   - name: name of the remote function
	///   - function: remote function
	///		- parameter args: list of json arguments
	///		- parameter promise: promise to resolve if the result is not ready on call
	public func functions(_ name:String,_ function: @escaping (_ args:[JSON],_ promise:Promise)-> Any? ){
		self.rmiFunctions[name]=function
	}
	
	
	public func handleRMICommand(_ command:JSON){
		let name:String=command["name"].string!
		let id=command["id"].string!
		if let function=rmiFunctions[name] {
			do{
				let result:Any? = try function(command["args"].arrayValue,Promise(id,self))
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
		let command=JSON([
				"command":true,
				"type":"rmi-result",
				"id":id,
				"result":result,
				"error":error
			])
		
		_ = sendCommand(command);
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
	
	
	
	/// aloows to call remote function
	/// - parameter name: name of remote function
	/// - parameter args: list of args to send to remote
	/// - parameter then: function to call on result
	/// - parameter result: result json
	/// - parameter error: error string on remote
	public func remote(_ name:String, args:Any...,_ then:@escaping (_ result:JSON, _ error:String?)->() = {result in} ){
		let id:String = UUID().uuidString
		rmiResultCallbacks[id]=then;
		sendRMICommand(name, args, id: id)
	}
	private func sendRMICommand(_ name:String,_ args:[Any] , id:String){
		let command=JSON([
			"command":true,
			"type":"rmi",
			"id":id,
			"name":name,
			"args":args
			])
		
		_ = sendCommand(command);
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
	
	
	fileprivate init(name: String, initializeData: [String:JSON], server: Syncs,type:Type) {
		self.name = name;
		self.type = type;
		self.readOnly = type != .CLIENT;
		
		self.rawData = initializeData;
		self.server = server;
	}
	
	
	
	/// get string value of shared object
	///
	/// - Parameter property: name of property
	/// - Returns: string value or nil
	public func getString(_ property:String)->String?{
		if rawData[property] == nil {
			return nil
		}
		let data = JSON(rawData[property]!);
		return  data.string
		
	}
	
	/// get int value of shared object
	///
	/// - Parameter property: name of property
	/// - Returns: int value or nil
	public func getInt(_ property:String)->Int?{
		if rawData[property] == nil {
			return nil
		}
		let data = JSON(rawData[property]!);
		return  data.int
		
	}
	/// get bool value of shared object
	///
	/// - Parameter property: name of property
	/// - Returns: bool value or nil
	public func getBool(_ property:String)->Bool?{
		if rawData[property] == nil {
			return nil
		}
		let data = JSON(rawData[property]!);
		return  data.bool
		
	}
	
	/// get JSON value of shared object
	///
	/// - Parameter property: name of property
	/// - Returns: JSON value or nil
	public func getJSON(_ property:String)->JSON?{
		if rawData[property] == nil {
			return nil
		}
		return JSON(rawData[property]!);
	}
	
	
	/// set value of property in shared object
	///
	/// - Parameters:
	///   - property: name of property
	///   - value: value to set
	/// - Returns: shared object instance for chain call
	public func set(_ property:String,_ value:String)->SharedObject{
		return setData(property, value)
	}
	/// set value of property in shared object
	///
	/// - Parameters:
	///   - property: name of property
	///   - value: value to set
	/// - Returns: shared object instance for chain call
	public func set(_ property:String,_ value:Int)->SharedObject{
		return setData(property, value)
	}
	/// set value of property in shared object
	///
	/// - Parameters:
	///   - property: name of property
	///   - value: value to set
	/// - Returns: shared object instance for chain call
	public func set(_ property:String,_ value:Bool)->SharedObject{
		return setData(property, value)
	}
	/// set value of property in shared object
	///
	/// - Parameters:
	///   - property: name of property
	///   - value: value to set
	/// - Returns: shared object instance for chain call
	public func set(_ property:String,_ value:JSON)->SharedObject{
		return setData(property, value)
	}
	private func setData(_ key:String,_ value:Any)->SharedObject{
		if(readOnly){
			return self
		}
		rawData[key]=value
		if onChangeHandler != nil {
			let handler:(_ values:[String:JSON], _ by: By)->() = onChangeHandler as! ([String : JSON], SharedObject.By) -> ()
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
		_ = server?.sendCommand(command)
	}

	
	fileprivate func setProperties(values:JSON){
		var changedValues:[String:JSON]=[:]
		for (key,value) in values{
			rawData[key]=value.rawValue
			changedValues[key]=value
		}
		if onChangeHandler != nil {
			let handler:(_ values:[String:JSON], _ by: By)->() = onChangeHandler as! ([String : JSON], SharedObject.By) -> ()
			handler(changedValues, .SERVER)
		}
		
	}

	/// handle changes in shared object
	///
	/// - Parameter handler: function to call on change
	///		- parameter values: array of changed property
	///		- determines who changed the shared object
	public func onChange(_ handler:@escaping (_ values:[String:JSON], _ by: By)->() ){
		onChangeHandler=handler
	}
	
	
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
	/// method to call when the result is ready
	///
	/// - Parameter result: result data (string,int,bool,JSON)
	public func result(_ result:Any){
		server.sendRmiResultCommand(result: result, error: nil, id: id)
	}
	
}

