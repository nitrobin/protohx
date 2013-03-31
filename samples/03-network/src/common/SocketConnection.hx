package common;

import haxe.io.BytesData;
import haxe.io.BytesOutput;
import haxe.io.Bytes;
import haxe.io.Eof;
#if flash

import flash.events.Event;
import flash.events.ErrorEvent;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.events.ProgressEvent;
class SocketConnection {
    var socket:flash.net.Socket;

    public function connect(host, port, onConnect, addBytes, onClose) {
        socket.connect(host, port);
        this.onConnect = onConnect;
        this.onClose = onClose;
        this.addBytes = addBytes;
    }

    public dynamic function onConnect():Void {}
    public dynamic function onClose():Void {}
    public dynamic function addBytes(bytes:Bytes):Void {}

    public function new() {
        socket = new flash.net.Socket();
        socket.addEventListener(Event.CLOSE, closeHandler);
        socket.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
        socket.addEventListener(IOErrorEvent.NETWORK_ERROR, errorHandler);
        socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
        socket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
        socket.addEventListener(Event.CONNECT, connectHandler);
        socket.endian = flash.utils.Endian.LITTLE_ENDIAN ;
    }

    private function closeHandler(e:Event):Void {
        trace("closeHandler");
        detach();
        onClose();
    }

    private function errorHandler(e:ErrorEvent):Void {
        trace("errorHandler" + Std.string(e));
        detach();
        onClose();
    }

    private function connectHandler(e:Event):Void {
//        trace("connectHandler");
        onConnect();
    }

    public function writeMsg(msg:protohx.Message):Void {
        var b = new BytesOutput();
        msg.writeTo(b);
        var bytes = b.getBytes();
        socket.writeInt(bytes.length);
        socket.writeBytes(cast bytes.getData());
    }

    private function socketDataHandler(e:ProgressEvent):Void {
        try {
//            trace("socketDataHandler");
            var b = new flash.utils.ByteArray();
            socket.readBytes(b);
            var bs = Bytes.ofData(cast b);
            addBytes(bs);
        } catch (e:Dynamic) {
            trace('error: ' + haxe.Json.stringify(e));
        }
    }

    public function detach():Void {
        socket.removeEventListener(Event.CLOSE, closeHandler);
        socket.removeEventListener(IOErrorEvent.IO_ERROR, errorHandler);
        socket.removeEventListener(IOErrorEvent.NETWORK_ERROR, errorHandler);
        socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, errorHandler);
        socket.removeEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
        socket.removeEventListener(Event.CONNECT, connectHandler);
    }
}
#elseif cpp
class SocketConnection {
    var socket:sys.net.Socket;

    public function connect(host, port, onConnect, addBytes, onClose) {
        this.onConnect = onConnect;
        this.addBytes = addBytes;
        this.onClose = onClose;
        try{
            socket.connect(new sys.net.Host(host), port);
        }catch(e:Dynamic){
            trace(e);
            trace(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
            onClose();
            return;
        }
        trace("connected");
        onConnect();

        var buffer = Bytes.alloc(1024);
        var socks = [socket];
        var timer = new haxe.Timer(100);
        timer.run = function() {
            try {
                var r:Array<sys.net.Socket>;
                do {
                    r = sys.net.Socket.select(socks, null, null, 0.001).read;
                    for (s in r) {
                        var size = s.input.readBytes(buffer, 0, buffer.length);
                        addBytes(buffer.sub(0, size));
                    }
                } while (r.length > 0);
            } catch (e:haxe.io.Eof) {
                timer.stop();
                onClose();
                socket.close();
            } catch (e:Dynamic) {
                trace(e);
            }
        };
    }

    public dynamic function onConnect():Void {}
    public dynamic function onClose():Void {}
    public dynamic function addBytes(bytes:Bytes):Void {}

    public function new() {
        socket = new sys.net.Socket();
        socket.input.bigEndian = false;
        socket.output.bigEndian = false;
    }

    public function writeMsg(msg:protohx.Message):Void {
        var b = new BytesOutput();
        msg.writeTo(b);
        var bytes = b.getBytes();
        socket.output.writeInt32(bytes.length);
        socket.output.writeBytes(bytes, 0, bytes.length);
    }
}
#elseif js
//    var socket = io.connect('http://localhost');
//    socket.on('news', function (data) {
//        console.log(data);
//        socket.emit('my other event', { my: 'data' });
//    });
class SocketConnection {
    var socket:Dynamic;

    public dynamic function onConnect():Void {}
    public dynamic function onClose():Void {}
    public dynamic function addBytes(bytes:Bytes):Void {}

    public function new() {

    }

    public function handleMsg(msg:String):Void {
    }
    public function writeMsg(msg:protohx.Message):Void {
        socket.emit("message", haxe.Serializer.run(msgToFrameBytes(msg)));
    }

    public static function msgToFrameBytes(msg:protohx.Message):haxe.io.Bytes {
        var b = new BytesOutput();
        msg.writeTo(b);
        var data = b.getBytes();

        var res = new BytesOutput();
        res.writeInt32(data.length);
        res.write(data);
        return res.getBytes();
    }

    public function connect(host, port, onConnect, addBytes, onClose) {
        this.onConnect = onConnect;
        this.addBytes = addBytes;
        this.onClose = onClose;
        var self = this;
        untyped __js__("
        //self.socket = io.connect('http://'+host+':'+port);
        self.socket = io.connect();
        this.socket.on('connect', function () {
            onConnect();
            self.socket.on('message', function (msg) {
                addBytes(haxe.Unserializer.run(msg));
            });
            self.socket.on('disconnect', function (msg) {
                onClose();
                self.socket.disconnect();
            });
        });
        ");
    }
}

#end
