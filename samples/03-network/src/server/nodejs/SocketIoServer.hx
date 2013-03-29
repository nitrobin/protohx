package server.nodejs;
#if js
import server.logic.BakedMsg;
import server.logic.SessionRegistry;
import server.logic.Session;
import haxe.io.Bytes;
import js.Node;
import  server.nodejs.NodeUtils;
using  server.nodejs.NodeUtils;

class SocketIoSession extends Session {

    public var socket:Dynamic;

    public function new(socket:Dynamic) {
        super();
        this.socket = socket;
    }

    public function writeMsgSafe_(bytes:Bytes):Void {
        socket.emit("message", haxe.Serializer.run(bytes));
    }

    public override function close():Void {
        socket.disconnect();
    }

    public override function bakeMsg(msg:protohx.Message):BakedMsg {
        return new BakedMsg(msg, null);
    }

    public override function writeMsgBaked(msg:BakedMsg):Void {
        writeMsgSafe_(msg.msg.msgToFrameBytes());
    }

    public override function writeMsg(msg:protohx.Message):Void {
        writeMsgSafe_(msg.msgToFrameBytes());
    }
}

class SocketIoServer {

    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;

    public static function main() {
        var sr:SessionRegistry = new SessionRegistry();
        MainServer.tcpTest(sr);
        tcpTest(sr);
    }

    public static function tcpTest(sr:SessionRegistry) {
        var newSocketIoSession = function (s:Dynamic) {
        return new SocketIoSession(s);
        }
        var unserialize = haxe.Unserializer.run;
        untyped __js__("
        var app = require('http').createServer(handler)
        , io = require('socket.io').listen(app)
        , fs = require('fs')
        , console = require('console')

        app.listen(5001);

        function handler (req, res) {
            console.log(req.url);
            var fn = __dirname + '/index.html';
            if(req.url.indexOf('protohx-samples-network-client.js')!=-1){
                fn = __dirname + '/protohx-samples-network-client.js';
            }
            fs.readFile(fn,
            function (err, data) {
                if (err) {
                    res.writeHead(500);
                    return res.end('Error loading index.html');
                }

                res.writeHead(200);
                res.end(data);
            });
        }

        io.sockets.on('connection', function (socket) {
            var session = newSocketIoSession(socket);
//            socket.set('session', session);
            sr.sessionConnect(session);
            socket.on('message', function (data) {
                console.log(data);
                var bytes = unserialize(data);
                sr.sessionData(session, bytes);
            });
            socket.on('disconnect', function () {
                sr.sessionDisconnect(session);
            });
        });
        ");
    }
}

#end