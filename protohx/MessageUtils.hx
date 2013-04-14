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
// workaround bug https://code.google.com/p/haxe/issues/detail?id=1674
#if java
        } else if (untyped __java__('value instanceof java.lang.Long')) {
#else
        } else if (Std.is(value, Int64)) {
#end
            return cast(value, Int64).toStr();
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
