package common;
import haxe.Json;
import haxe.Int64;
using haxe.Int64;
import haxe.io.Bytes;
import protohx.Message;
using StringTools;

class MsgUtils {
    public static function toJson(msg:Message, keepNulls:Bool = false):String {
        return Json.stringify(toObject(msg, keepNulls));
    }

    public static function toObject(value:Dynamic, keepNulls:Bool = false):Dynamic {
        if ((value == null) || Std.is(value, String) || Std.is(value, Float) || Std.is(value, Int) || Std.is(value, Bool)) {
            return value;
        } else if (Std.is(value, Bytes)) {
            return cast(value, Bytes).toHex();
        } else if (Std.is(value, Int64)) {
            return cast(value, Int64).toStr();
        } else if (Std.is(value, Message)) {
            var m:Dynamic = {};
            for (f in Type.getInstanceFields(Type.getClass(value))) {
                if (f.startsWith("get_")) {
                    var fn = f.substr(4);
                    var v = Reflect.callMethod(value, Reflect.field(value, f), null);
                    if(v != null || keepNulls){
                        Reflect.setField(m, fn, toObject(v));
                    }
                }
            }
            return m;
        } else if (Std.is(value, Array)) {
            var a:Array<Dynamic> = [];
            for (sv in cast(value, Array<Dynamic>)) {
                a.push(toObject(sv));
            }
            return a;
        } else {
            return Std.string(value);
        }
    }
}
