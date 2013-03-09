package protohx;

import protohx.ProtocolTypes;

class BaseUtil {

    public static function fromCharCode(digitChars:Array<PT_UInt>):String {
        return Lambda.map(digitChars, function(a) return String.fromCharCode(a)).join("");
    }

    private static var BASE_CHARS:String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    public static function toNumericBase(input:Int, base:Int):String {
        var result:String = "";
        while (input > 0) {
            result = BASE_CHARS.charAt(input % base) + result;
            input = Std.int(input / base);
        }
        return result;
    }

    public static function toDecimal(input:String, base:Int):Int {
        input = input.toUpperCase();
        var i:Int, len:Int;
        i = len = input.length;
        var result:Int = 0;

        while (i-- > 0) {
            result += Std.int(Math.pow(base, i) * BASE_CHARS.indexOf(input.charAt(len - i - 1)));
        }

        return result;
    }
}