var argscheck = require('cordova/argscheck'),
    exec = require('cordova/exec');

var cameraserver_exports = {};

cameraserver_exports.startServer = function(options, success, error) {
	  var defaults = {
			    'www_root': '',
			    'port': 8080,
			    'localhost_only': false,
		  		'json_info' : '{"AppVersion":"Undefined"}'
			  };
	  
	  // Merge optional settings into defaults.
	  for (var key in defaults) {
	    if (typeof options[key] !== 'undefined') {
	      defaults[key] = options[key];
	    }
	  }
			  
  exec(success, error, "CameraServer", "startServer", [ defaults ]);
};

cameraserver_exports.stopServer = function(success, error) {
	  exec(success, error, "CameraServer", "stopServer", []);
};

cameraserver_exports.getURL = function(success, error) {
	  exec(success, error, "CameraServer", "getURL", []);
};

cameraserver_exports.getIPAddress = function(success, error) {
	exec(success, error, "CameraServer", "getIPAddress", []);
};

cameraserver_exports.getLocalPath = function(success, error) {
	  exec(success, error, "CameraServer", "getLocalPath", []);
};

cameraserver_exports.getNumRequests = function(success, error) {
	exec(success, error, "CameraServer", "getNumRequests", []);
};

cameraserver_exports.startCamera = function(success, error) {
	exec(success, error, "CameraServer", "startCamera", []);
};

cameraserver_exports.stopCamera = function(success, error) {
	exec(success, error, "CameraServer", "stopCamera", []);
};

cameraserver_exports.getJpegImage = function(success, error) {
	exec(success, error, "CameraServer", "getJpegImage", []);
};

cameraserver_exports.setVideoFormat = function(options, success, error) {
	var defaults = {
		'videoFormat': 0
	};

	// Merge optional settings into defaults.
	for (var key in defaults) {
		if (typeof options[key] !== 'undefined') {
			defaults[key] = options[key];
		}
	}

	exec(success, error, "CameraServer", "setVideoFormat", [defaults]);
};

cameraserver_exports.getVideoFormats = function(success, error) {
	exec(success, error, "CameraServer", "getVideoFormats", []);
};

cameraserver_exports.setBrightness = function(options, success, error) {
	var defaults = {
		'brightness': 50
	};

	// Merge optional settings into defaults.
	for (var key in defaults) {
		if (typeof options[key] !== 'undefined') {
			defaults[key] = options[key];
		}
	}

	exec(success, error, "CameraServer", "setBrightness", [defaults]);
};

cameraserver_exports.getBrightness = function(success, error) {
	exec(success, error, "CameraServer", "getBrightness", []);
};

cameraserver_exports.setTorch = function(options, success, error) {
	var defaults = {
		'enabled': false
	};

	// Merge optional settings into defaults.
	for (var key in defaults) {
		if (typeof options[key] !== 'undefined') {
			defaults[key] = options[key];
		}
	}

	exec(success, error, "CameraServer", "setTorch", [defaults]);
};

cameraserver_exports.getTorch = function(success, error) {
	exec(success, error, "CameraServer", "getTorch", []);
};

cameraserver_exports.setInfo = function(options, success, error) {
	var defaults = {
		'json_info': '{}'
	};

	// Merge optional settings into defaults.
	for (var key in defaults) {
		if (typeof options[key] !== 'undefined') {
			defaults[key] = options[key];
		}
	}

	exec(success, error, "CameraServer", "setInfo", [defaults]);
};


module.exports = cameraserver_exports;

