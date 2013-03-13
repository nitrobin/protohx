package ;
import nodejs.NodeUtils;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;
import protohx.Message;
import haxe.io.BytesOutput;
import protohx.ProtocolTypes;
import haxe.io.Bytes;
import js.Node;
import nodejs.NodeUtils;
using nodejs.NodeUtils;

class MainServer {

    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;

    private static var clients:List<NodeNetSocket> ;

    public static function main() {
        net = Node.net;
        console = Node.console;
        clients = new List<NodeNetSocket>();
//        clientTest();
        flashCrossDomain();
        tcpTest();
    }

    public static function tcpTest() {
        var server:NodeNetServer = net.createServer(function(client:NodeNetSocket) {
//            client.setEncoding(NodeC.BINARY);
            client.on(NodeC.EVENT_STREAM_CONNECT, function() {
                clients.add(client);
                client.setAP();
                console.log('got client connection: ${client.getAP()}');
                var pm = new ProtocolMessage();
                pm.type = MsgType.LOGIN_REQ;
                pm.loginReq = new LoginReq();
                pm.loginReq.nick = "user";
                client.writeMsg(pm);
            });

//            client.on(NodeC.EVENT_STREAM_DRAIN, function() {
//                console.log('client drain: ${client.getAP()}');
//            });
            client.on(NodeC.EVENT_STREAM_ERROR, function(e) {
                console.log('client error: ${client.getAP()}:\n  ${e}');
            });
            client.on(NodeC.EVENT_STREAM_DATA, function(buffer:NodeBuffer) {
//                client.write(d); //echo
//                console.log(buffer);
                var bytes = buffer.toBytes();
                client.writeBytes(bytes);
            });
            client.on(NodeC.EVENT_STREAM_CLOSE, function() {
                console.log('client close: ${client.getAP()}');
            });
            client.on(NodeC.EVENT_STREAM_END, function(d) {
                console.log('client end: ${client.getAP()}');
                client.end();
                clients.remove(client);
            });
        });
        server.on(NodeC.EVENT_STREAM_ERROR, function(e) {
            console.log('server error: ${e}');
        });
        server.listen(5000, /* "localhost", */ function() {
            console.log('server bound: ${server.serverAddressPort()}');
        });
        console.log('tcpTest server started');
    }

    public static function flashCrossDomain() {
        var server = net.createServer(function(client) {
            client.addListener(NodeC.EVENT_STREAM_CONNECT, function() {
                client.write('<?xml version="1.0"?><cross-domain-policy><allow-access-from domain="*" to-ports="*"/></cross-domain-policy>');
                client.end();
            });
            client.on(NodeC.EVENT_STREAM_ERROR, function(e) {
                console.log('client error: ${client.getAP()}:\n  ${e}');
            });
            client.on(NodeC.EVENT_STREAM_END, function(d) {
                console.log('client end: ${client.getAP()}');
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