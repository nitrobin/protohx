package common;
class Base64 {
    private inline static var BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    private static var codec:haxe.crypto.BaseCode;

    public function new() {

    }

    static function getCodec():haxe.crypto.BaseCode {
        if (codec == null) {
            codec = new haxe.crypto.BaseCode(haxe.io.Bytes.ofString(BASE64));
        }
        return codec;
    }

    public static function encodeBase64(content:haxe.io.Bytes):String {
        var suffix = switch (content.length % 3){
            case 2: "=";
            case 1: "==";
            default: "";
        };

        return getCodec().encodeBytes(content) + suffix;
    }

    private static function removeNullbits(s:String):String {
        var len = s.length;
        while (s.charAt(len-1) == "=") {
            lastChrIdx--;
            if (len <= 0) {
                return "";
            }
        }
        return s.substr(0, len);
    }

    public static function decodeBase64(content:String):haxe.io.Bytes {
        return getCodec().decodeBytes(removeNullbits(t));
    }

}
