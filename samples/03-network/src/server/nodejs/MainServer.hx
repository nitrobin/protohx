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

class NodeSession extends Session {

    public var socket:NodeNetSocket;

    public function new(socket:NodeNetSocket) {
        super();
        this.socket = socket;
    }

    public override function close():Void {
        socket.end();
    }

    public override function bakeMsg(msg:protohx.Message):BakedMsg {
        return new BakedMsg(msg, null);
    }

    public override function writeMsgBaked(msg:BakedMsg):Void {
        trace("OUT: "+protohx.MessageUtils.toJson(msg.msg));
        socket.writeSafe(msg.msg.toFrame());
    }

    public override function writeMsg(msg:protohx.Message):Void {
        trace("OUT: "+protohx.MessageUtils.toJson(msg));
        socket.writeMsgSafe(msg);
    }
}

class MainServer {

    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;

    public static function main() {
        var sr:SessionRegistry = new SessionRegistry();
        flashCrossDomain(843);
//        flashCrossDomain(Config.ADDITIONAL_POLICY_PORT);
        runSocketServer(sr, Config.DEAFULT_TCP_PORT);
        haxe.Timer.delay(function(){
            for(i in 0...20){
                MainBot.tcpClientTest("127.0.0.1", Config.DEAFULT_TCP_PORT);
            }
        }, 1000);
    }

    public static function runSocketServer(sr:SessionRegistry, port:Int) {
        var server:NodeNetServer = net.createServer({allowHalfOpen:true}, function(client:NodeNetSocket) {
//            client.on(NodeC.EVENT_STREAM_CONNECT, function() {
                var session = new NodeSession(client);
                client.setSession(session);
                sr.sessionConnect(session);
                console.log('server got client connection: ${client.getAP()}');
//            });
//            client.on(NodeC.EVENT_STREAM_DRAIN, function() {
//                console.log('client drain: ${client.getAP()}');
//            });
            client.on(NodeC.EVENT_STREAM_ERROR, function(e) {
                console.log('server got client error: ${client.getAP()}:\n  ${e}');
            });
            client.on(NodeC.EVENT_STREAM_DATA, function(buffer:NodeBuffer) {
                var session = client.getSession();
                var bytes = buffer.toBytes();
                sr.sessionData(session, bytes);
            });
            client.on(NodeC.EVENT_STREAM_END, function(d) {
//                console.log('server got client end: ${client.getAP()}');
                client.end();
            });
            client.on(NodeC.EVENT_STREAM_CLOSE, function() {
                console.log('server got client close: ${client.getAP()}');
                sr.sessionDisconnect(client.getSession());
            });
        });
        server.on(NodeC.EVENT_STREAM_ERROR, function(e) {
            console.log('server got server error: ${e}');
        });
        server.listen(port, /* "localhost", */ function() {
            console.log('server bound: ${server.serverAddressPort()}');
        });
        console.log('simple server started');
    }

    public static function flashCrossDomain(port:Int) {
        var xml = '<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>';
        var len = NodeBuffer.byteLength(xml);
        var b = new NodeBuffer(len + 1);
        b.write(xml, 0);
        b.writeUInt8(0, len);
        var server = net.createServer({allowHalfOpen:true}, function(client:NodeNetSocket) {
            client.addListener(NodeC.EVENT_STREAM_CONNECT, function() {
                client.write(b);
                console.log('server cross-domain-policy');
                client.end();
            });
            client.on(NodeC.EVENT_STREAM_ERROR, function(e) {
                console.log('server error:\n  ${e}');
            });
            client.on(NodeC.EVENT_STREAM_END, function(d) {
//                console.log('server end');
                client.end();
            });
        });
        server.on(NodeC.EVENT_STREAM_ERROR, function(e) {
            console.log('server error: ${e}');
        });

        server.listen(port, function() {
            console.log('flashCrossDomain server bound: ${server.serverAddressPort()}');
        });
    }
}

#end
