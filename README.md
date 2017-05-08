# syncs-swift

[![Version](https://img.shields.io/cocoapods/v/Syncs.svg?style=flat)](http://cocoapods.org/pods/Syncs)
[![License](https://img.shields.io/cocoapods/l/Syncs.svg?style=flat)](http://cocoapods.org/pods/Syncs)
[![Platform](https://img.shields.io/cocoapods/p/Syncs.svg?style=flat)](http://cocoapods.org/pods/Syncs)

__A Swift Package for Syncs Real-Time Web Applications__

_syncs-swift_ is Swift framework to work with [Syncs](https://github.com/manp/syncs).











## Initialization
_syncs-swift_ is easy to setup.
Syncs is available through [CocoaPods](http://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod "Syncs"
```
then run `pod install` command

## Example
To run the example project, clone the repo, and run `pod install` from the Example directory first.
Example project needs syncs server which is avilable [here](https://github.com/manp/syncs-samples/tree/master/groups-server)



## Create Connection
Developers can create real-time connection by creating an instance of `Syncs` class.

```Swift
import Syncs
let io:Syncs=Syncs("ws://localhost:8080/syncs");

```


The path parameter is required that determines Syncs server address.
initializer method has other input parameter:
+ `autoConnect:boolean`: If `autoConnect` is `false` then the Syncs instance will not connect to server on creation. To connect manuly to server developers should call `io.connect()` method. default value is `true`.
+ `autoReconnect:boolean`: This config makes the connection presistent on connection drop. default value is `true`.
+ `reconnectDelay: number`: time to wait befor each reconnecting try. default value is `1000`.
+ `debug:bolean`: This parameter enables debug mode on client side. default value is `false`.

```swift
let io=Syncs("ws://localhost:8080/syncs", autoConnect: false, autoReconnect: true, reconnectDelay: 10000, debug: true)

```

## Handling connection
Syncs client script can automatically connect to Syncs server. If `autoConnect` config is set to `false`, the developer should connect manual to server using `connect` method.

Using `connect` method developers can connect to defined server.

```Swift
io.connect();
```

Target application can establish connection or disconnect from server using provided methods.
```Swift
io.disconnect()
```

Developers can handle _disconnect_ and _close_ event with `onDisconnect` and `onClose`  method.
```Swift
io.onOpen {
// handle open
}
```
```Swift
io.onClose {
// handle open
}
```
```Swift
io.onDisconnect {
// handle open
}
```
Developers can use one listener to handle connection status

```swift
class ViewController: UIViewController,SyncsDelegate {
...
func onOpen(from syncs: Syncs) {
// handle open
}
}

```

It's also possible to check connection status using `online` property of Syncs instance.
```swift
if(io.online){
//do semething
}
```



## Abstraction Layers

Syncs provides four abstraction layer over its real-time functionality for developers.


### 1. onMessage Abstraction Layer

Developers can send messages using `send` method of `Syncs` instance to send `JSON` message to the server.Also all incoming messages are catchable using `onMessage`.
Syncs uses [SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) library to handle JSON messages.

```Swift
io.send(data,JSON["message":"Hello, Syncs"]);
```

```swift
io.onMessage(){ data in
// handle message here
}
```
Or use `SyncsDelegate` protocol
```swift
class ViewController: UIViewController,SyncsDelegate {
...
func onMessage(with data: JSON, from syncs: Syncs) {
// handle message here
}
}
```

### 2. Publish and Subscribe Abstraction Layer
With a Publish and Subscribe solution developers normally subscribe to data using a string identifier. This is normally called a Channel, Topic or Subject.

```swift
io.publish("mouse-move-event",jsonData);
```
```swift
io.subscribe("weather-update"){event,data,io in

}
```

### 3. Shared Data Abstraction Layer
Syncs provides Shared Data functionality in form of variable sharing. Shared variables can be accessible in tree level: _Global Level_, _Group Level_ and _Client Level_. Only _Client Level_ shared data can be write able with client.

To get _Client Level_ shared object use `shared` method of `Syncs` instance.
```swift
let info:SharedObject=io.shared("info");
info.set("title","Syncs is cool!");
```
To get _Group Level_ shared object use `groupShared` method of `Syncs` instance. First parameter is group name and second one is shared object name.

```swift
info:SharedObject=io.groupShared('vips','info');
info.getInteger("onlineVips")+" vip member are online";
```

To get _Global Level_ shared object use `globalShared` method of `Syncs` instance.
```swift
let settings=io.globalShared("settings");
applyBackground(settings.getString("backgrounColor"));
```


It's possible to watch changes in shared object by using shared object as a function.
```swift
info.onChange { (values, by) in

}
```
The callback function has two argument.
+ `values`: an array that contains names of changed properties.
+ `by:Enum` an Enum  variable with two value ( `'SERVER'` and `'CLIENT'`) which shows who changed these properties.



### 4. Remote Method Invocation (RMI) Abstraction Layer
With help of RMI developers can call and pass argument to remote function and make it easy to develop robust and web developed application. RMI may abstract things away too much and developers might forget that they are making calls _over the wire_.

Before calling remote method from server ,developer should declare the function on client script.

`functions` method in `Syncs` instance is the place to declare functions.

```swift
io.functions("showMessage"){ args,promise in
//show message
return nil	
}
```

To call remote method on server use `remote` object.
```swift
io.remote("setLocation", args: latitude,longitude)
```



The remote side can return a result (direct value or Promise object) which is accessible using `Promise` object provided by `functions`.


```swift
io.functions("askUser"){ args,promise in
// ask user and return result
return result;	
}
```

```swift
io.functions("startQuiz"){ args,promise in
// start quiz
return promise;
// call promise.result(...) later
}
// after a while
promise.result(quizStatics);
```

```swift
io.remote("getWeather", args: cityName){ result,error in

}
```
