package nodejs;
import logic.Session;
import haxe.io.BytesOutput;
import js.Node;

class NodeUtils {

    public static function setSession(socket:NodeNetSocket, session:Session):Void {
        untyped {
            socket.ap = addressPort(socket);
            socket.session = session;
        };
    }

    public static function getAP(socket:NodeNetSocket):String {
        return cast untyped {socket.ap;};
    }

    public static function getSession(socket:NodeNetSocket):Session {
        return cast untyped {socket.session;};
    }

    public static function serverAddressPort(server:NodeNetServer):String {
        var a = untyped __js__('server.address()');
        var address:String = a.address;
        var port:Int = a.port;
        return '${address}:${port}';
    }

    public static function addressPort(socket:NodeNetSocket):String {
        return '${socket.remoteAddress}:${socket.remotePort}';
    }

    public static function writeMsg(socket:NodeNetSocket, msg:protohx.Message):Void {
        var b = new BytesOutput();
        msg.writeTo(b);
        var bytes = b.getBytes();
        var lenBuf = new NodeBuffer(4);
        lenBuf.writeUInt32LE(bytes.length, 0);
        socket.write(lenBuf);
        writeBytes(socket, bytes);
    }

    public static function writeBytes(socket:NodeNetSocket, bytes:haxe.io.Bytes):Void {
        socket.write(new NodeBuffer(bytes.getData()));
    }

    public static function toBytes(buffer:NodeBuffer):haxe.io.Bytes {
        return haxe.io.Bytes.ofData(cast buffer);
    }
}
