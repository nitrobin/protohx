package protohx;
import haxe.Json;
import haxe.Int64;
using haxe.Int64;
import haxe.io.Bytes;
import protohx.Message;
using StringTools;

class MessageUtils {
    public static function toObject(value:Dynamic, keepNulls:Bool = false):Dynamic {
        if (
            (value == null)
            || Std.is(value, String)
            || Std.is(value, Float)
            || Std.is(value, Int)
            || Std.is(value, Bool)
        ) {
            return value;
        } else if (Std.is(value, Bytes)) {
            return cast(value, Bytes).toHex();
#if (haxe_ver >= 3.2)
        } else if (Int64.is(value)) {
#else
        } else if (Std.is(value, Int64)) {
#end
            return Int64.toStr(cast(value));
        } else if (Std.is(value, protohx.Message)) {
            var m:Dynamic = {};
            var msg = cast(value, protohx.Message);
            msg.forEachFields(function (f, v) {
                Reflect.setField(m, f, toObject(v, keepNulls));
            });
            return m;
        } else if (Std.is(value, Array)) {
            var a:Array<Dynamic> = [];
            for (sv in cast(value, Array<Dynamic>)) {
                a.push(toObject(sv, keepNulls));
            }
            return a;
        } else {
            return Std.string(value);
        }
        return null;
    }

    public static function toJson(msg:protohx.Message, keepNulls:Bool = false):String {
        var o:Dynamic = toObject(msg, keepNulls);
        return Json.stringify(o);
    }
}
