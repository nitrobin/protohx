package server.nodejs;
#if js
import common.Config;
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
        socket.emit("message", common.Base64.encodeBase64(bytes));
    }

    public override function close():Void {
        socket.disconnect();
    }

    public override function bakeMsg(msg:protohx.Message):BakedMsg {
        return new BakedMsg(msg, null);
    }

    public override function writeMsgBaked(msg:BakedMsg):Void {
        trace("OUT: "+protohx.MessageUtils.toJson(msg.msg));
        writeMsgSafe_(msg.msg.msgToFrameBytes());
    }

    public override function writeMsg(msg:protohx.Message):Void {
        trace("OUT: "+protohx.MessageUtils.toJson(msg));
        writeMsgSafe_(msg.msgToFrameBytes());
    }
}

class SocketIoServer {

    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;

    public static function main() {
        var sr:SessionRegistry = new SessionRegistry();
//        NetServer.runSocketServer(sr, Config.DEFAULT_TCP_PORT);
        var port = untyped  (__js__("process.env.VMC_APP_PORT ") || Config.DEFAULT_HTTP_PORT);
        runSocketIoServer(sr, port);
    }

    public static function runSocketIoServer(sr:SessionRegistry, port:Int) {
        var policyXml = '<cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>';
        var newSocketIoSession = function (s:Dynamic) {
        return new SocketIoSession(s);
        }
        var decodeBytes = common.Base64.decodeBase64;
        var statistics = sr.getStatisticsStr;
        untyped __js__("
        var http = require('http')
        , socket_io = require('socket.io')
        , fs = require('fs')
        , console = require('console')
        , express = require('express')

        var app = express();
        var httpServer = http.createServer(app)
        httpServer.listen(port);
        console.log('socket.io server on '+port+' port ')
        var io = socket_io.listen(httpServer);

        io.configure('development', function(){
            io.set('transports', ['xhr-polling']);
        });

        app.get('/stat', function(req, res){
        res.setHeader('Content-Type', 'text/json');
            res.send(statistics());
        });
        app.get('/crossdomain.xml', function(req, res){
            res.setHeader('Content-Type', 'text/xml');
            res.setHeader('Content-Length', policyXml.length);
            res.end(policyXml);
        });
        app.use(express.static(__dirname + '/static'));

        io.sockets.on('connection', function (socket) {
            var session = newSocketIoSession(socket);
            sr.sessionConnect(session);
            socket.on('message', function (data) {
                var bytes = decodeBytes(data);
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