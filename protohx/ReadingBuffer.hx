package protohx;
import protohx.Protohx;
import haxe.io.Bytes;
import haxe.io.BytesInput;

class ReadingBuffer {
    public var length (get, null):Int;
    public var bytesAvailable (get, null):Int;

    private var buf:BytesInput;

    public function new(buf:BytesInput) {
        this.buf = buf;
        Protohx.setInputEndian(this.buf);
    }

    public inline static function fromBytes(bytes:Bytes, ?pos : Int, ?len : Int) {
        return new ReadingBuffer(new BytesInput(bytes, pos, len));
    }

    public inline function get_length():Int {
        return buf.length;
    }

    public inline function get_bytesAvailable():Int {
        return buf.length - buf.position;
    }

    public inline function readBytes(len:Int):Bytes {
        var b = Bytes.alloc(len);
        buf.readBytes(b, 0, len);
        return b;
    }

    public inline function readUTFBytes(len:Int):String {
        return buf.readString(len);
    }

    public inline function readInt32() {
        return buf.readInt32();
    }

//    public function readUnsignedInt() {
//        bytesAvailable -= 4;
//        return buf.readInt32();
//    }

    public inline function readUnsignedByte() {
        return buf.readByte();
    }
//    public function readByte() {
//        bytesAvailable -= 1;
//        return buf.readByte();
//    }
    public inline function readDouble() {
        return buf.readDouble();
    }
    public inline function readFloat() {
        return buf.readFloat();
    }
}





