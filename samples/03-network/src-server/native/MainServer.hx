package native;

import logic.SessionRegistry;
import haxe.io.BytesOutput;
import haxe.io.Bytes;
import haxe.CallStack;
import sys.net.Socket;
import neko.net.ThreadServer;
import neko.Lib;

class NativeSession extends logic.Session {

    public var socket:Socket;

    public function new(socket:Socket) {
        super();
        this.socket = socket;
        socket.setFastSend(true);
        socket.output.bigEndian = false;
        socket.input.bigEndian = false;
    }

    public override function close():Void {
        socket.close();
    }

    public override function bakeMsg(msg:protohx.Message):logic.BakedMsg {
        return new logic.BakedMsg(msg);
    }

    public override function writeMsgBaked(msg:logic.BakedMsg):Void {
        writeMsg(msg.msg);
    }

    public override function writeMsg(msg:protohx.Message):Void {
        try{
            var bytes = msgToBytes(msg);
            socket.output.writeInt32(bytes.length);
            socket.output.write(bytes);
            socket.output.flush();
        }catch(e:Dynamic){
            trace(e);
            var stack = CallStack.toString(CallStack.exceptionStack());
            trace(stack);
        }
    }

    public static function msgToBytes(msg:protohx.Message):haxe.io.Bytes {
        var b = new BytesOutput();
        msg.writeTo(b);
        return b.getBytes();
    }

}

class MainServer extends ThreadServer<NativeSession, Bytes> {
    var sr:SessionRegistry;

    public function new() {
        super();
        sr = new SessionRegistry();
    }

// create a Client

    override function clientConnected(s:Socket):NativeSession {
        var session = new NativeSession(s);
        sr.sessionConnect(session);
        Lib.println("client: " + session.id + " / " + s.peer());
        return session;
    }

    override function clientDisconnected(session:NativeSession) {
        Lib.println("client " + Std.string(session.id) + " disconnected");
        sr.sessionDisconnect(session);
    }

    override function readClientMessage(session:NativeSession, buf:Bytes, pos:Int, len:Int) {
//        trace("data " + buf.length + ":" + pos + ":" + len);
        return {msg: buf.sub(pos, len), bytes: len};
    }

    override function clientMessage(session:NativeSession, bytes:Bytes) {
//        trace("bytes: "+bytes.length);
        sr.sessionData(session, bytes);
    }

    public static function main() {
        var server = new MainServer();
        trace("Running..");
        server.run("0.0.0.0", 5000);
    }
}

