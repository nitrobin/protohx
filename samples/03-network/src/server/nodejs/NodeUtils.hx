package server.nodejs;
#if js
import  server.logic.Session;
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
        return ""+address+":"+port;
    }

    public static function addressPort(socket:NodeNetSocket):String {
        return ""+socket.remoteAddress+":"+socket.remotePort;
    }

    public static function writeSafe(socket:NodeNetSocket, frame:NodeBuffer):Void {
        try{
            socket.write(frame);
        } catch(e:Dynamic){
            trace(e);
        }
    }

    public static function writeMsgSafe(socket:NodeNetSocket, msg:protohx.Message):Void {
        try{
            writeMsg(socket, msg);
        } catch(e:Dynamic){
            trace(e);
        }
    }

    public static function writeMsg(socket:NodeNetSocket, msg:protohx.Message):Void {
        var bytes = msgToBytes(msg);
        var frameSize = new NodeBuffer(common.MsgQueue.HEADER_SIZE);
        frameSize.writeUInt16LE(bytes.length, 0);
        var frameData = toNodeBuffer(bytes);
        socket.write(frameSize);
        socket.write(frameData);
    }

    public static function toFrame(msg:protohx.Message):NodeBuffer {
        var b = new BytesOutput();
        b.writeUInt16(0);
        msg.writeTo(b);
        var bytes = b.getBytes();
        var frameData = toNodeBuffer(bytes);
        frameData.writeUInt16LE(bytes.length - common.MsgQueue.HEADER_SIZE, 0);
        return frameData;
    }

    public static function toNodeBuffer(bytes:haxe.io.Bytes):NodeBuffer {
       return new NodeBuffer(bytes.getData());
    }

    public static function msgToBytes(msg:protohx.Message):haxe.io.Bytes {
        var b = new BytesOutput();
        msg.writeTo(b);
        return b.getBytes();
    }

    public static function msgToFrameBytes(msg:protohx.Message):haxe.io.Bytes {
        var b = new BytesOutput();
        msg.writeTo(b);
        var data = b.getBytes();

        var res = new BytesOutput();
        res.writeUInt16(data.length);
        res.write(data);
        return res.getBytes();
    }

    public static function writeBytes(socket:NodeNetSocket, bytes:haxe.io.Bytes):Void {
        socket.write(toNodeBuffer(bytes));
    }

    public static function toBytes(buffer:NodeBuffer):haxe.io.Bytes {
        return haxe.io.Bytes.ofData(cast buffer);
    }
}

#end