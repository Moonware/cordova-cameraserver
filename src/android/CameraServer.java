package com.moonware.cameraserver;

import java.io.File;
import java.io.IOException;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.PluginResult;
import org.apache.cordova.PluginResult.Status;
import org.apache.http.conn.util.InetAddressUtils;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Base64;
import android.util.Log;
import android.view.Window;
import android.view.WindowManager;
import android.content.Context;
import android.content.res.AssetManager;


/**
 * This class echoes a string called from JavaScript.
 */

public class CameraServer extends CordovaPlugin {

    /** Common tag used for logging statements. */
    private static final String LOGTAG = "CameraServer";
    
    /** Cordova Actions. */
    private static final String ACTION_START_SERVER = "startServer";
    private static final String ACTION_STOP_SERVER = "stopServer";
    private static final String ACTION_SET_JSON_INFO = "setInfo";
    private static final String ACTION_GET_URL = "getURL";
    private static final String ACTION_GET_IP_ADDRESS = "getIPAddress";
    private static final String ACTION_GET_LOCAL_PATH = "getLocalPath";
    private static final String ACTION_GET_NUM_REQUESTS = "getNumRequests";

    private static final String ACTION_START_CAMERA = "startCamera";
    private static final String ACTION_STOP_CAMERA = "stopCamera";

    private static final String ACTION_GET_JPEG_IMAGE = "getJpegImage";
    private static final String ACTION_GET_VIDEO_FORMATS = "getVideoFormats";
    private static final String ACTION_SET_VIDEO_FORMATS = "setVideoFormat";

    private static final String ACTION_GET_BRIGHTNESS = "getBrightness";
    private static final String ACTION_SET_BRIGHTNESS = "setBrightness";

    private static final String ACTION_GET_TORCH = "getTorch";
    private static final String ACTION_SET_TORCH = "setTorch";

    private static final String OPT_WWW_ROOT = "www_root";
    private static final String OPT_PORT = "port";
    private static final String OPT_JSON_INFO = "json_info";
    private static final String OPT_LOCALHOST_ONLY = "localhost_only";
    private static final String OPT_BRIGHTNESS = "brightness";
    private static final String OPT_ENABLED = "enabled";


    private String www_root = "";
	private int port = 8080;	
	private boolean localhost_only = false;

    private String json_info = "";

	private String localPath = "";
	private WebServer server = null;
	private String	url = "";
	
	private int brightness = 50;
	private boolean torchEnabled = false;

    @Override
    public boolean execute(String action, JSONArray inputs, CallbackContext callbackContext) throws JSONException {
        PluginResult result = null;
        if (ACTION_START_SERVER.equals(action)) {
            result = startServer(inputs, callbackContext);
            
        } else if (ACTION_STOP_SERVER.equals(action)) {
            result = stopServer(inputs, callbackContext);
            
        } else if (ACTION_GET_URL.equals(action)) {
            result = getURL(inputs, callbackContext);

        } else if (ACTION_GET_IP_ADDRESS.equals(action)) {
            result = getIPAddress(inputs, callbackContext);

        } else if (ACTION_GET_LOCAL_PATH.equals(action)) {
            result = getLocalPath(inputs, callbackContext);
            
        } else if (ACTION_GET_NUM_REQUESTS.equals(action)) {
            result = getNumRequests(inputs, callbackContext);

        } else if (ACTION_START_CAMERA.equals(action)) {
            result = startCamera(inputs, callbackContext);

        } else if (ACTION_STOP_CAMERA.equals(action)) {
            result = stopCamera(inputs, callbackContext);

        } else if (ACTION_GET_JPEG_IMAGE.equals(action)) {
            result = getJpegImage(inputs, callbackContext);

        } else if (ACTION_GET_VIDEO_FORMATS.equals(action)) {
            result = getVideoFormats(inputs, callbackContext);

        } else if (ACTION_SET_VIDEO_FORMATS.equals(action)) {
            result = setVideoFormats(inputs, callbackContext);

        } else if (ACTION_GET_BRIGHTNESS.equals(action)) {
            result = getBrightness(inputs, callbackContext);

        } else if (ACTION_SET_BRIGHTNESS.equals(action)) {
            result = setBrightness(inputs, callbackContext);

        } else if (ACTION_GET_TORCH.equals(action)) {
            result = getTorch(inputs, callbackContext);

        } else if (ACTION_SET_TORCH.equals(action)) {
            result = setTorch(inputs, callbackContext);

        } else if (ACTION_SET_JSON_INFO.equals(action)) {
            result = setInfo(inputs, callbackContext);

        } else {
            Log.d(LOGTAG, String.format("Invalid action passed: %s", action));
            result = new PluginResult(Status.INVALID_ACTION);
        }
        
        if(result != null) callbackContext.sendPluginResult( result );
        
        return true;
    }
    
    private String __getLocalIpAddress() {
    	try {
            for (Enumeration<NetworkInterface> en = NetworkInterface.getNetworkInterfaces(); en.hasMoreElements();) {
                NetworkInterface intf = en.nextElement();
                for (Enumeration<InetAddress> enumIpAddr = intf.getInetAddresses(); enumIpAddr.hasMoreElements();) {
                    InetAddress inetAddress = enumIpAddr.nextElement();
                    if (! inetAddress.isLoopbackAddress()) {
                    	String ip = inetAddress.getHostAddress();
                    	if(InetAddressUtils.isIPv4Address(ip)) {
                    		Log.w(LOGTAG, "local IP: "+ ip);
                    		return ip;
                    	}
                    }
                }
            }
        } catch (SocketException ex) {
            Log.e(LOGTAG, ex.toString());
        }
    	
		return "127.0.0.1";
    }

    private PluginResult startServer(JSONArray inputs, CallbackContext callbackContext) {
		Log.w(LOGTAG, "startServer");

        JSONObject options = inputs.optJSONObject(0);
        if(options == null) return null;
        
        www_root = options.optString(OPT_WWW_ROOT);
        port = options.optInt(OPT_PORT, 8080);
        localhost_only = options.optBoolean(OPT_LOCALHOST_ONLY, false);
        json_info = options.optString(OPT_JSON_INFO);

        if(www_root.startsWith("/")) {
    		//localPath = Environment.getExternalStorageDirectory().getAbsolutePath();
        	localPath = www_root;
        } else {
        	//localPath = "file:///android_asset/www";
        	localPath = "www";
        	if(www_root.length()>0) {
        		localPath += "/";
        		localPath += www_root;
        	}
        }
        
        final CallbackContext delayCallback = callbackContext;
        cordova.getActivity().runOnUiThread(new Runnable(){
			@Override
            public void run() {
				String errmsg = __startServer();
				if(errmsg != "") {
					delayCallback.error( errmsg );
				} else {
			        url = "http://" + __getLocalIpAddress() + ":" + port;
			        
	                delayCallback.success( url );
				}
            }
        });
        
        return null;
    }

     private PluginResult stopServer(JSONArray inputs, CallbackContext callbackContext) {
    		Log.w(LOGTAG, "stopServer");

            final CallbackContext delayCallback = callbackContext;
            cordova.getActivity().runOnUiThread(new Runnable(){
    			@Override
                public void run() {
    				__stopServer();
    				url = "";
    				localPath = "";
                    delayCallback.success();
                }
            });

            return null;
        }
    
    private String __startServer() {
    	String errmsg = "";
    	try {
    		AndroidFile f = new AndroidFile(localPath);
    		
	        Context ctx = cordova.getActivity().getApplicationContext();
			AssetManager am = ctx.getResources().getAssets();
    		f.setAssetManager( am );
    		
    		if(localhost_only) {
    			InetSocketAddress localAddr = InetSocketAddress.createUnresolved("127.0.0.1", port);
    			server = new WebServer(localAddr, f);
    		} else {
    			server = new WebServer(port, f);
    		}
    			        
	        Log.w(LOGTAG, "Setting jsonInfo to: " + json_info);

	        server.SetJsonInfo(json_info);
		} catch (IOException e) {
			errmsg = String.format("IO Exception: %s", e.getMessage());
			Log.w(LOGTAG, errmsg);
		}
    	return errmsg;
    }

    private void __stopServer() {
		if (server != null) {
			server.stop();
			server = null;
		}
    }

   private PluginResult setInfo(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "setInfo");

        JSONObject options = inputs.optJSONObject(0);
        if(options == null) return null;

        json_info = options.optString(OPT_JSON_INFO);

        if (server != null)
        {
            server.SetJsonInfo(json_info);
            callbackContext.success();
        }
        else
        {
            callbackContext.error( 0 );
        }

        return null;
    }
    
   private PluginResult getURL(JSONArray inputs, CallbackContext callbackContext) {
		Log.w(LOGTAG, "getURL");
		
    	callbackContext.success( this.url );
        return null;
    }

   private PluginResult getIPAddress(JSONArray inputs, CallbackContext callbackContext) {
		Log.w(LOGTAG, "getIPAddress");

    	callbackContext.success( __getLocalIpAddress() );
        return null;
    }

    private PluginResult getLocalPath(JSONArray inputs, CallbackContext callbackContext) {
		Log.w(LOGTAG, "getLocalPath");
		
    	callbackContext.success( this.localPath );
        return null;
    }

    private PluginResult getNumRequests(JSONArray inputs, CallbackContext callbackContext) {
		Log.w(LOGTAG, "getNumRequests");
		
		int nReq = 0;
		
		if (server != null)
		{
			nReq = server.NumRequested();
		}
		
    	callbackContext.success( nReq );
        return null;
    }
    


    private PluginResult startCamera(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "startCamera");

         // initialize the camera manager :)
         CameraManager.init(cordova.getActivity().getApplicationContext());
         startCapture();

         callbackContext.success();
         
         return null;
    }

    private PluginResult stopCamera(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "stopCamera");

        // stop Capturing but do not we cannot free the CameraManager :s
        stopCapture();

        callbackContext.success();
        
        return null;
    }

    private PluginResult getJpegImage(JSONArray inputs, CallbackContext callbackContext) {
    	Log.w(LOGTAG, "getJpegImage");
        
        byte[] bArray = CameraManager.lastFrame();
        
        if (bArray != null)
        {
        	Log.w(LOGTAG, "Received " + String.valueOf(bArray.length) + " bytes...");
        
        	String imageEncoded = Base64.encodeToString(bArray,Base64.NO_WRAP);

        	//Log.e("LOOK", imageEncoded);       

        	callbackContext.success( imageEncoded );
        }
        else
        {
        	callbackContext.error(0);        	
        }
        
        return null;
    }

    private PluginResult getVideoFormats(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "getVideoFormats");

        callbackContext.error( 0 );
        return null;
    }

    private PluginResult setVideoFormats(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "setVideoFormats");

        callbackContext.success( "false" );
        return null;
    }

    private PluginResult getBrightness(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "getBrightness");

        final CallbackContext delayCallback = callbackContext;
                cordova.getActivity().runOnUiThread(new Runnable(){
        			@Override
                    public void run() {

        				Window w = cordova.getActivity().getWindow();
        		        WindowManager.LayoutParams lp = w.getAttributes();

        		        delayCallback.success( String.valueOf(lp.screenBrightness) );
                    }
                });

        return null;
    }
    
    private PluginResult setBrightness(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "setBrightness");
        
        JSONObject options = inputs.optJSONObject(0);
        if(options == null) return null;
        
        brightness = options.optInt(OPT_BRIGHTNESS, 50);
        
        final CallbackContext delayCallback = callbackContext;
        cordova.getActivity().runOnUiThread(new Runnable(){
			@Override
            public void run() {
				
				Window w = cordova.getActivity().getWindow();
		        WindowManager.LayoutParams lp = w.getAttributes();
		        lp.screenBrightness = (float)brightness/100;
		        if (lp.screenBrightness<.01f) lp.screenBrightness=.01f;
		        w.setAttributes(lp);
				
		        delayCallback.success( "True" );				
            }
        });
        
        return null;
    }


    private PluginResult getTorch(JSONArray inputs, CallbackContext callbackContext) {
        Log.w(LOGTAG, "getTorch");

        // TODO: IMPLEMENT        
        callbackContext.error(0);
        
        return null;
    }

    private PluginResult setTorch(JSONArray inputs, CallbackContext callbackContext) {
    	Log.w(LOGTAG, "setTorch( " + torchEnabled + ")");

        JSONObject options = inputs.optJSONObject(0);
        if(options == null) return null;

        torchEnabled = options.optBoolean(OPT_ENABLED, false);

        CameraManager cMgr = CameraManager.get();
        
        if (cMgr != null)
        {        	
        	cMgr.setTorch(torchEnabled);
        	callbackContext.success( );
        }
        else
        {
        	callbackContext.error(0);        
        }

        return null;
    }


    private boolean startCapture(){
        Log.w(LOGTAG, "startCapture");

        if (false){
            CameraManager.setDesiredPreviewSize(1280, 720);
        } else {
            CameraManager.setDesiredPreviewSize(800, 480);
        }

        try {
			CameraManager.get().openDriver();
		} catch (IOException e) {
			Log.w(LOGTAG, "Exception in openDriver");
		}
        
        //CameraManager.get().startPreview();        

        return true;
    }
    
    private boolean stopCapture(){
        Log.w(LOGTAG, "stopCapture");
                
        CameraManager.get().stopPreview();                
        
        try {
			CameraManager.get().closeDriver();
		} catch (Exception e) {
			Log.w(LOGTAG, "Exception in closeDriver");
		}
        
        return true;
    }

    /**
     * Called when the system is about to start resuming a previous activity.
     *
     * @param multitasking		Flag indicating if multitasking is turned on for app
     */
    public void onPause(boolean multitasking) {

        if(! multitasking)
        {
            Log.w(LOGTAG, "onPause fired... [MultiTask not enabled]");
        }
        else
        {
            Log.w(LOGTAG, "onPause fired... [MultiTask enabled]");
        }

    	//if(! multitasking) __stopServer();
    }

    /**
     * Called when the activity will start interacting with the user.
     *
     * @param multitasking		Flag indicating if multitasking is turned on for app
     */
    public void onResume(boolean multitasking) {
        Log.w(LOGTAG, "onResume fired...");

    	//if(! multitasking) __startServer();
    }

    /**
     * The final call you receive before your activity is destroyed.
     */
    public void onDestroy() {
    	__stopServer();
    }
}
