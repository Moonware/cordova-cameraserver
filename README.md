## CameraServer Plugin For Cordova ##

Supported platform:
* iOS
* Android

Provides Live Camera images over HTTP (over Wifi or locally to a Cordova Application):

Why over HTTP ?

* A known memory leak problem occurs when retrieving data/result in Cordova (see [CameraPlus](https://github.com/Moonware/cordova-cameraplus/))
* It's faster and purely in native code so it was suitable for our application <strong>Netcam Studio Smart Camera</strong>

## How to use CameraServer? ##

Add the plugin to your cordova project:

    cordova plugin add https://github.com/Moonware/cordova-cameraserver   
    
## Javascript APIs ##

```javascript

startServer( options, success_callback, error_callback );

stopServer( success_callback, error_callback );

getURL( success_callback, error_callback );

getLocalPath( success_callback, error_callback );

getNumRequests( success_callback, error_callback );

startCamera( success_callback, error_callback );

stopCamera( success_callback, error_callback );

/* Just for testing, do not use this since it leaks */
getJpegImage( success_callback, error_callback );

```

## Quick Start ##

Start the Web Server

```javascript
cordova.plugins.CameraServer.startServer({
    'www_root' : '/',
    'port' : 8080,
    'localhost_only' : false,
    'json_info': []
}, function( url ){
    // if server is up, it will return the url of http://<server ip>:port/
    // the ip is the active network connection
    // if no wifi or no cell, "127.0.0.1" will be returned.
    console.log('CameraServer Started @ ' + url); 
}, function( error ){
    console.log('CameraServer Start failed: ' + error);
});
```

Start the Camera Capture (will act on demand when a HTTP request arrives)

```javascript
cordova.plugins.CameraServer.startCamera(function(){
      console.log('Capture Started');
  },function( error ){
      console.log('CameraServer StartCapture failed: ' + error);
  });
```

Downloading a Live Image in Javascript (AngluarJS / Ionic)

```javascript
var localImg = 'http://localhost:8080/live.jpg';

$http.get(localImg).
    success(function(data, status, headers, config) {
        console.log("Image Downloaded");
    }).
    error(function(data, status, headers, config) {
        console.log("Image Download failed");
    });
```

Displaying a Live Image in a Cordova App is as simple as:

```html
<img src='http://localhost:8080/live.jpg'>
```

## Usage in applications ##

This plugin was developped for the needs of <strong>Netcam Studio Smart Camera</strong>:

[Netcam Studio Smart Camera iOS](https://itunes.apple.com/us/app/netcam-studio-smart-camera/id974703108)

[Netcam Studio Smart Camera Android](https://play.google.com/store/apps/details?id=com.moonware.smart&hl=en)

## Credits ##

This Cordova plugin is  based on CorHttpd, thanks to the authors:

* [CorHttpd](https://github.com/floatinghotpot/cordova-httpd), by floatinghotpot

Which is itself based on:

* [NanoHTTPD](https://github.com/NanoHttpd/nanohttpd), written in java, for java / android, by psh.
* [CocoaHTTPServer](https://github.com/robbiehanson/CocoaHTTPServer), written in Obj-C, for iOS / Mac OS X, by robbiehanson.

You can use this plugin for FREE. 

Feel free to fork, improve and send pull request. 

We will of course appreciate if you share any improvement or addition made to the plugin.
