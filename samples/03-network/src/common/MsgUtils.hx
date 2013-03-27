package common;
import haxe.Json;
import haxe.Int64;
using haxe.Int64;
import haxe.io.Bytes;
import protohx.Message;
using StringTools;

class MsgUtils {
    public static function toJson(msg:Message, skipEmpty:Bool = true):String {
        return Json.stringify(toObject(msg, skipEmpty));
    }

    public static function toObject(value:Dynamic, skipEmpty:Bool = true):Dynamic {
        if ((value == null) || Std.is(value, String) || Std.is(value, Float) || Std.is(value, Int) || Std.is(value, Bool)) {
            return value;
        } else if (Std.is(v, Bytes)) {
            return cast(v, Bytes).toHex();
        } else if (Std.is(v, Int64)) {
            return cast(v, Int64).toStr();
        } else if (Std.is(value, Message)) {
            var m:Dynamic = {};
            for (f in Type.getInstanceFields(Type.getClass(msg))) {
                if (f.startsWith("get_")) {
                    var fn = f.substr(4);
                    var v = Reflect.callMethod(msg, Reflect.field(msg, f), null);
                    Reflect.setField(m, fn, toObject(v));
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
            return Std.string(v);
        }
    }
}
