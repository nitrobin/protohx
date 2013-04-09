package common;
import samples.ClientType;
import samples.ClientPlatform;

class Config {
    public static inline var DEAFULT_HOST:String = "127.0.0.1";
    public static inline var DEAFULT_TCP_PORT:Int = 15000;
    public static inline var DEAFULT_HTTP_PORT:Int = 15001;
    public static inline var ADDITIONAL_POLICY_PORT:Int = 15002;

    public static function getTypeName(code:Int):String {
        return  switch(code){
            case ClientType.CT_BOT: "bot";
            case ClientType.CT_HUMAN: "human";
            case ClientType.CT_UNKNOWN:default: "unknown";
        }
    }
    public static function getPlatformName(code:Int):String {
        return  switch(code){
            case ClientPlatform.CP_ANDROID: "android";
            case ClientPlatform.CP_LINUX: "linux";
            case ClientPlatform.CP_HTML5: "html5";
            case ClientPlatform.CP_FLASH: "flash";
            case ClientPlatform.CP_WINDOWS: "win";
            case ClientPlatform.CP_IOS: "ios";
            case ClientPlatform.CP_NODEJS: "node.js";
            case ClientPlatform.CP_UNKNOWN:default: "unknown";
        }
    }
    public static function getPlatform():Int {
        return
#if (flash || as3)
            ClientPlatform.CP_FLASH;
            #elseif (android)
            ClientPlatform.CP_ANDROID;
            #elseif (js || html5)
            ClientPlatform.CP_HTML5;
#elseif (linux)
            ClientPlatform.CP_LINUX;
            #elseif (windows)
            ClientPlatform.CP_WINDOWS;
            #elseif (ios)
            ClientPlatform.CP_IOS
            #else
        ClientPlatform.CP_UNKNOWN;
#end
    }
}
