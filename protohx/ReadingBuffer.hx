package protohx;
import protohx.Protohx;
import haxe.io.Bytes;
import haxe.io.BytesInput;

class ReadingBuffer {
    public var length (default, null):Int;
    public var bytesAvailable (default, null):Int;

    private var buf:BytesInput;

    public function new(bytes:Bytes) {
        this.length = bytes.length;
        this.bytesAvailable = length;
        this.buf = new BytesInput(bytes);
        Protohx.setInputEndian(this.buf);
    }

    public function readBytes(len:Int):Bytes {
        var b = Bytes.alloc(len);
        buf.readBytes(b, 0, len);
        bytesAvailable -= len;
        return b;
    }

    public function readUTFBytes(len:Int):String {
        bytesAvailable -= len;
        return buf.readString(len);
    }

    public function readInt() {
        bytesAvailable -= 4;
        return buf.readInt32();
    }

//    public function readUnsignedInt() {
//        bytesAvailable -= 4;
//        return buf.readInt32();
//    }

    public function readUnsignedByte() {
        bytesAvailable -= 1;
        return buf.readByte();
    }
//    public function readByte() {
//        bytesAvailable -= 1;
//        return buf.readByte();
//    }
    public function readDouble() {
        bytesAvailable -= 8;
        return buf.readDouble();
    }
    public function readFloat() {
        bytesAvailable -= 4;
        return buf.readFloat();
    }
}





