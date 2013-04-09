package;
import protohx.Protohx;
import calc.OpCode;
import calc.ValueMessage;
import calc.OutputMessage;
import calc.InputMessage;
import sys.io.Process;
import haxe.io.BytesOutput;
import haxe.Int64;
using haxe.Int64;

class HaxeMain {
    public static function main():Void {
        var r = new haxe.unit.TestRunner();
        r.add(new TestBasics());
        r.run();
    }
}

class TestBasics extends haxe.unit.TestCase {
    public function testPlugin() {
        function v(i:Int) {
            var vm = new ValueMessage();
            vm.i32 = i;
            vm.fi32 = i;
            vm.ui32 = i;
            vm.si32 = i;
            vm.sfi32 = i;
            vm.d = i;
            vm.f = i;
            return vm;
        }
        runCalc([v(1), v(2), v(3)], [OpCode.ADD, OpCode.MUL], v(7)) ;
        runCalc([v(0xff00), v(0x00ff)], [OpCode.ADD], v(0xffff)) ;
        runCalc([v(0xfff000), v(0xfff)], [OpCode.ADD], v(0xffffff)) ;
        runCalc([v(0xf0f000), v(0x0f0)], [OpCode.ADD], v(0xf0f0f0)) ;
        runCalc([v(0xffff0000), v(0xffff)], [OpCode.ADD], v(0xffffffff)) ;
        runCalc([v(0xffffffff), v(0x01)], [OpCode.ADD], v(0x00)) ;
        runCalc([v(0xffffffff), v(0x02)], [OpCode.ADD], v(0x01)) ;
    }

    public function v(h:Int, l:Int):ValueMessage {
        var vm = new ValueMessage();
        vm.si64 = Protohx.newInt64(h, l);
        vm.sfi64 = Protohx.newInt64(h, l);
        vm.i64 = Protohx.newInt64(h, l);
        vm.fi64 = Protohx.newInt64(h, l);
        vm.ui64 = Protohx.newUInt64(h, l);
        return vm;
    }
    public function testPlugin64() {
        runCalc([v(0, 1), v(0, 1)], [ OpCode.MUL], v(0, 1)) ;
        runCalc([v(0, 1), v(0, 2), v(0, 3)], [OpCode.ADD, OpCode.MUL], v(0, 7)) ;
        runCalc([v(0, 0xffffffff), v(0, 1), v(0, 1)], [OpCode.ADD, OpCode.MUL], v(1, 0)) ;
//        runCalc([v(0xff00), v(0x00ff)],  [OpCode.ADD], v(0xffff)) ;
//        runCalc([v(0xfff000), v(0xfff)],  [OpCode.ADD], v(0xffffff)) ;
//        runCalc([v(0xf0f000), v(0x0f0)],  [OpCode.ADD], v(0xf0f0f0)) ;
//        runCalc([v(0xffff0000), v(0xffff)],  [OpCode.ADD], v(0xffffffff)) ;
//        runCalc([v(0xffffffff), v(0x01)],  [OpCode.ADD], v(0x00)) ;
//        runCalc([v(0xffffffff), v(0x02)],  [OpCode.ADD], v(0x01)) ;
    }

    public function runCalc(values, opCodes, r:ValueMessage) {

        var p = new Process("out/calc", []);
        var im = new InputMessage();
        im.values = values;
        im.opCodes = opCodes;

        var b = new BytesOutput();
        im.writeTo(b);
        var bytes = b.getBytes();
        p.stdin.bigEndian = true;
        p.stdin.writeInt32(bytes.length);
        p.stdin.write(bytes);
        p.stdin.flush();

        p.stdout.bigEndian = true;
        var len = p.stdout.readInt32();
        var resBytes = p.stdout.read(len);
        var om = new OutputMessage();
        om.mergeFrom(resBytes);

        p.close();
//        trace(protohx.MessageUtils.toJson(im));
//        trace(protohx.MessageUtils.toJson(om));

        assertTrue(om.success);
//        assertEquals("ok", om.msg);
        var ir:ValueMessage = om.value;
        if (r.hasI32()) {assertEquals(r.i32, ir.i32); }
        if (r.hasUi32()) {assertEquals(r.ui32, ir.ui32); }
        if (r.hasSi32()) {assertEquals(r.si32, ir.si32); }
        if (r.hasF()) {assertEquals(r.f, ir.f);}
        if (r.hasD()) {assertEquals(r.d, ir.d);}
        if (r.hasI64()) {
            assertEquals(Protohx.getLow(r.i64), Protohx.getLow(ir.i64));
            assertEquals(Protohx.getHigh(r.i64), Protohx.getHigh(ir.i64));
        }
        if (r.hasFi64()) {
            assertEquals(Protohx.getLow(r.fi64), Protohx.getLow(ir.fi64));
            assertEquals(Protohx.getHigh(r.fi64), Protohx.getHigh(ir.fi64));
        }
        if (r.hasUi64()) {
            assertEquals(Protohx.getLow(r.ui64), Protohx.getLow(ir.ui64));
            assertEquals(Protohx.getHigh(r.ui64), Protohx.getHigh(ir.ui64));
        }
        if (r.hasSfi64()) {
            assertEquals(Protohx.getLow(r.sfi64), Protohx.getLow(ir.sfi64));
            assertEquals(Protohx.getHigh(r.sfi64), Protohx.getHigh(ir.sfi64));
        }
        if (r.hasSi64()) {
            assertEquals(Protohx.getLow(r.si64), Protohx.getLow(ir.si64));
            assertEquals(Protohx.getHigh(r.si64), Protohx.getHigh(ir.si64));
        }
    }
}