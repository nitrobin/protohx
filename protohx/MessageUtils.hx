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
// java target fail on Std.is(value, Int64)
//        } else if (Std.is(value, Int64)) {
//            return cast(value, Int64).toStr();
        } else if (Std.is(value, protohx.Message)) {
            var m:Dynamic = {};
            for (f in Reflect.fields(value)) {
                if (!f.startsWith("hasField__")) {
                    var v = Reflect.field(value, f);
                    if(v != null || keepNulls){
                        Reflect.setField(m, f, toObject(v, keepNulls));
                    }
                }
            }
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
