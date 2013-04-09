package ;
import protohx.Message;
import protohx.Protohx;
import haxe.io.BytesOutput;
import haxe.io.Bytes;
import google.protobuf.compiler.CodeGeneratorRequest;
import test.Foo;
import test.IntTestMessage;
import test.complexmessage.Point;
import test.complexmessage.MsgType;
import test.ComplexMessage;

class Main {
    public function new() {
    }

    public static function main():Void {
#if js
        haxe.unit.TestRunner.print = function ( v : Dynamic ){
            untyped __js__("console.log(v);");
        }
#end

        var r = new haxe.unit.TestRunner();
        r.add(new TestComplex());
        r.run();
    }
}


class TestBase extends haxe.unit.TestCase {
    public function copyMsg<T>(obj:T):T {
        var b = new BytesOutput();
        untyped obj.writeTo(b);
        var copy = Type.createInstance(Type.getClass(obj), []);
        untyped copy.mergeFrom(b.getBytes());
        return copy;
    }
}

class TestComplex extends TestBase {
    public function testBasic() {
        function p(x, y) {
            var pt = new Point();
            pt.x = x;
            pt.y = y;
            return pt;
        }

        var obj = new ComplexMessage();

        obj.type = MsgType.BBB;
        obj.msg = "msg1";
        obj.id = 12345;

        obj.uid = 54321;
        obj.offline = true;

        obj.attach = null;
        obj.statuses = ["123", "456"];
        obj.points = [p(1, 2), p(3, 4)];

        obj.msgOpt = "msgOpt1";

        obj.rnd = -1;

        obj.attach = Bytes.alloc(256);
        for (b in 0...256) {
            obj.attach.set(b, b);
        }
        assertEquals(obj.attach.length, 256);

        obj.setType(MsgType.BBB).setMsg("setMsg").setId(12345).setMsgOpt("setMsgOpt");

        var b = new BytesOutput();
        obj.writeTo(b);
        var copy = new ComplexMessage();
        copy.mergeFrom(b.getBytes());

        assertEquals(obj.type, copy.type);
        assertEquals(obj.msg, copy.msg);
        assertEquals(obj.id, copy.id);
        assertEquals(obj.uid, copy.uid);
        assertEquals(obj.offline, copy.offline);
        assertEquals(Std.string(obj.statuses), Std.string(copy.statuses));

        assertEquals(obj.rnd, copy.rnd);
        assertEquals(copy.attach.length, 256);

        for (b in 0...256) {
            var c = copy.attach.get(b);
            assertEquals(c, b);
        }

        var foo = new Foo();
        assertEquals("1.0", foo.version);

        trace(protohx.MessageUtils.toJson(obj));
        assertEquals(protohx.MessageUtils.toJson(obj), protohx.MessageUtils.toJson(copy));
    }

}