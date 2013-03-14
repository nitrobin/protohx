package ;
import samples.LoginReq;
import samples.RemovePlayerRes;
import samples.LoginRes;
import samples.ProtocolMessage;
import samples.PlayerData;
import samples.protocolmessage.MsgType;
import protohx.Message;
import protohx.ProtocolTypes;
import player.Session;
import player.BytesParser;
import haxe.io.BytesOutput;
import haxe.io.Bytes;
import js.Node;
import nodejs.NodeUtils;
using nodejs.NodeUtils;

class MainServer {

    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;
    private static var mainServer:MainServer;

    private var clients:List<NodeNetSocket>;
    private var sessionId:Int;

    public function nextSessionId():Int {
        sessionId++;
        return sessionId;
    }

    public static function main() {
        net = Node.net;
        console = Node.console;
        mainServer = new MainServer();
    }

    public function new() {
        clients = new List<NodeNetSocket>();
        sessionId = 0;
        flashCrossDomain();
        tcpTest();
        haxe.Timer.delay(tcpClientTest, 1000);
    }

    public function handleDisconnect(session:Session) {
        if (session.player == null) {
            return;
        }

        var removePlayer = new ProtocolMessage();
        removePlayer.type = MsgType.REMOVE_PLAYER_RES;
        removePlayer.removePlayerRes = new RemovePlayerRes();
        removePlayer.removePlayerRes .id = session.player.id;

        for (client in clients) {
            var sessionOther = client.getSession();
            if (sessionOther != null && sessionOther.player != null) {
                client.writeMsg(removePlayer);
            }
        }

    }

    public function handlePackets(session:Session) {
        while(session.bytesParser.hasMsg()){
            var msg:ProtocolMessage = session.bytesParser.popMsg();
            handleMsg(session, msg);
        }
    }

    public function handleMsg(session:Session, msg:ProtocolMessage) {
        trace("MSG SERVER: " + Std.string(msg));
        if (msg.type == MsgType.LOGIN_REQ) {
            if (session.player != null) {
                console.log("double login!");
                session.client.end();
                return;
            }
            session.player = new PlayerData();
            session.player.id = session.id;
            session.player.nick = msg.loginReq.nick;
            session.player.x = cast (Math.random() * 100);
            session.player.y = cast (Math.random() * 100);
            session.player.status = "hi!";
            session.player.nick = msg.loginReq.nick;

            var pm = new ProtocolMessage();
            pm.type = MsgType.LOGIN_RES;
            pm.loginRes = new LoginRes();
            pm.loginRes.id = session.id ;
            session.client.writeMsg(pm);

            var addPlayer = new ProtocolMessage();
            addPlayer.type = MsgType.ADD_PLAYER_RES;
            addPlayer.addPlayerRes = session.player;

            for (client in clients) {
                var sessionOther = client.getSession();
                if (sessionOther != null) {
                    if (sessionOther == session) {
                        client.writeMsg(addPlayer);
                    } else {
                        client.writeMsg(addPlayer);

                        var addOtherPlayer = new ProtocolMessage();
                        addOtherPlayer.type = MsgType.ADD_PLAYER_RES;
                        addOtherPlayer.addPlayerRes = sessionOther.player;
                        session.client.writeMsg(addOtherPlayer);
                    }
                }
            }
        }
    }

    public function tcpTest() {
        var server:NodeNetServer = net.createServer(function(client:NodeNetSocket) {
//            client.setEncoding(NodeC.BINARY);
            client.on(NodeC.EVENT_STREAM_CONNECT, function() {
                clients.add(client);
                var session = new Session();
                session.id = nextSessionId();
                session.client = client;
                client.setSession(session);
                console.log('server got client connection: ${client.getAP()}');
            });

//            client.on(NodeC.EVENT_STREAM_DRAIN, function() {
//                console.log('client drain: ${client.getAP()}');
//            });
            client.on(NodeC.EVENT_STREAM_ERROR, function(e) {
                console.log('server got client error: ${client.getAP()}:\n  ${e}');
            });
            client.on(NodeC.EVENT_STREAM_DATA, function(buffer:NodeBuffer) {
//                console.log(buffer);
                var bytes = buffer.toBytes();
                var session = client.getSession();
                session.bytesParser.addBytes(bytes);
                handlePackets(session);
//                client.writeBytes(bytes);
            });
            client.on(NodeC.EVENT_STREAM_CLOSE, function() {
                console.log('server got client close: ${client.getAP()}');
            });
            client.on(NodeC.EVENT_STREAM_END, function(d) {
                console.log('server got client end: ${client.getAP()}');
                client.end();
                clients.remove(client);
                handleDisconnect(client.getSession());
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

    public function tcpClientTest() {
        var bytesParser:BytesParser = new BytesParser();
        var client:NodeNetSocket = net.connect(5000, "127.0.0.1");
        client.on(NodeC.EVENT_STREAM_CONNECT, function() {
            console.log('client connected to: ${client.getAP()}');

            var pm = new ProtocolMessage();
            pm.type = MsgType.LOGIN_REQ;
            pm.loginReq = new LoginReq();
            pm.loginReq.nick = "nick" + Math.floor(Math.random()*100);

            client.writeMsg(pm);
        });
        client.on(NodeC.EVENT_STREAM_DATA, function(buffer:NodeBuffer) {
            var bytes = buffer.toBytes();
            bytesParser.addBytes(bytes);
            while(bytesParser.hasMsg()){
                var msg:ProtocolMessage = bytesParser.popMsg();
                trace("MSG CLIENT: " + Std.string(msg));
            }

        });
    }

    public function flashCrossDomain() {
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