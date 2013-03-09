package;
import calc.OpCode;
import calc.ValueMessage;
import calc.OutputMessage;
import calc.InputMessage;
import sys.io.Process;
import haxe.io.BytesOutput;

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
            vm.ui32 = i;
            vm.si32 = i;
            vm.d = i;
            vm.f = i;
            return vm;
        }
        runCalc([v(1), v(2), v(3)],  [OpCode.ADD, OpCode.MUL], v(7)) ;
        runCalc([v(0xff00), v(0x00ff)],  [OpCode.ADD], v(0xffff)) ;
        runCalc([v(0xfff000), v(0xfff)],  [OpCode.ADD], v(0xffffff)) ;
        runCalc([v(0xf0f000), v(0x0f0)],  [OpCode.ADD], v(0xf0f0f0)) ;
        runCalc([v(0xffff0000), v(0xffff)],  [OpCode.ADD], v(0xffffffff)) ;
        runCalc([v(0xffffffff), v(0x01)],  [OpCode.ADD], v(0x00)) ;
        runCalc([v(0xffffffff), v(0x02)],  [OpCode.ADD], v(0x01)) ;
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

        assertTrue(om.success);
        assertEquals("ok", om.msg);
        assertEquals(r.i32, om.value.i32);
        assertEquals(r.ui32, om.value.ui32);
        assertEquals(r.si32, om.value.si32);
        assertEquals(r.d, om.value.d);
        assertEquals(r.f, om.value.f);

    }
}