package common;

#if haxe3
import haxe.crypto.BaseCode;
#else
import haxe.BaseCode;
#end

class Base64 {
    private inline static var BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    private static var codec:BaseCode;

    public function new() {

    }

    static function getCodec():BaseCode {
        if (codec == null) {
            var bytes = haxe.io.Bytes.ofString(BASE64);
            codec = new BaseCode(bytes);
        }
        return codec;
    }

    public static function encodeBase64(content:haxe.io.Bytes):String {
        var suffix = switch (content.length % 3){
            case 2: "=";
            case 1: "==";
            default: "";
        };

        var bytes = getCodec().encodeBytes(content);
        return bytes.toString() + suffix;
    }

    private static function removeNullbits(s:String):String {
        var len = s.length;
        while (len > 0 && s.charAt(len - 1) == "=") {
            len--;
            if (len <= 0) {
                return "";
            }
        }
        return s.substr(0, len);
    }

    public static function decodeBase64(content:String):haxe.io.Bytes {
        var bytes:haxe.io.Bytes = haxe.io.Bytes.ofString(removeNullbits(content));
        return getCodec().decodeBytes(bytes);
    }

}
