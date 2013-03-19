package nodejs;
#if js
import logic.BakedMsg;
import logic.SessionRegistry;
import logic.Session;
import haxe.io.Bytes;
import js.Node;
import nodejs.NodeUtils;
using nodejs.NodeUtils;

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
        return new BakedMsg(msg, msg.toFrame());
    }

    public override function writeMsgBaked(msg:BakedMsg):Void {
        socket.writeSafe(msg.data);
    }

    public override function writeMsg(msg:protohx.Message):Void {
        socket.writeMsgSafe(msg);
    }
}

class MainServer {

    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;

    public static function main() {
        flashCrossDomain();
        tcpTest();
        haxe.Timer.delay(MainBot.tcpClientTest, 1000);
        haxe.Timer.delay(MainBot.tcpClientTest, 1000);
    }

    public static function tcpTest() {
        var sr:SessionRegistry = new SessionRegistry();
        var server:NodeNetServer = net.createServer({allowHalfOpen:true}, function(client:NodeNetSocket) {
            client.on(NodeC.EVENT_STREAM_CONNECT, function() {
                var session = new NodeSession(client);
                client.setSession(session);
                sr.sessionConnect(session);
                console.log('server got client connection: ${client.getAP()}');
            });
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
        server.listen(5000, /* "localhost", */ function() {
            console.log('server bound: ${server.serverAddressPort()}');
        });
        console.log('simple server started');
    }

    public static function flashCrossDomain() {
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

//        trace("args[1] " + Node.process.argv[2]);
        server.listen(843, function() {
            console.log('flashCrossDomain server bound: ${server.serverAddressPort()}');
        });
    }
}

#end