package net;
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

    public static function toObject(msg:Message, skipEmpty:Bool = true):Dynamic {
        var m:Dynamic = {};
        for (f in Type.getInstanceFields(Type.getClass(msg))) {
            if (f.startsWith("get_")) {
                var fn = f.substr(4);
                var v = Reflect.callMethod(msg, Reflect.field(msg, f), null);
                if (v == null) {
                    if (!skipEmpty) {
                        Reflect.setField(m, fn, null);
                    }
                } else if (Std.is(v, Message)) {
                    Reflect.setField(m, fn, toObject(v));
                } else if (Std.is(v, String)) {
                    Reflect.setField(m, fn, v);
                } else if (Std.is(v, Bytes)) {
                    Reflect.setField(m, fn, cast(v, Bytes).toHex());
                } else if (Std.is(v, Int64)) {
                    Reflect.setField(m, fn, cast(v, Int64).toStr());
                } else {
                    Reflect.setField(m, fn, Std.string(v));
                }
            }
        }
        return m;
    }
}
