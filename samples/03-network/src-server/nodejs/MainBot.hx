package nodejs;
import haxe.Timer;
import samples.PlayerData;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;
import net.MsgQueue;
import logic.SessionRegistry;
import logic.Session;
import haxe.io.Bytes;
import js.Node;
import nodejs.NodeUtils;
using nodejs.NodeUtils;

class MainBot {
    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;

    public static function main() {
        tcpClientTest();
    }

    public static function tcpClientTest() {
        var msgQueue:MsgQueue = new MsgQueue();
        var client:NodeNetSocket = net.connect(5000, "127.0.0.1");
        var id:Int = 0;
        var player:PlayerData = null;
        var timer:Timer = null;
        client.on(NodeC.EVENT_STREAM_CONNECT, function() {
            console.log('client connected to: ${client.getAP()}');
            var msg = new ProtocolMessage();
            msg.type = MsgType.LOGIN_REQ;
            msg.loginReq = new LoginReq();
            msg.loginReq.nick = "bot" + Math.floor(Math.random() * 100);
            client.writeMsgSafe(msg);
//            client.end();
//            haxe.Timer.delay(function() {
//                client.end();
//            }, 1000);
        });
        client.on(NodeC.EVENT_STREAM_DATA, function(buffer:NodeBuffer) {
            var bytes = buffer.toBytes();
            msgQueue.addBytes(bytes);
            while (msgQueue.hasMsg()) {
                var msg:ProtocolMessage = msgQueue.popMsg();
                if (msg.type == MsgType.LOGIN_RES) {
                    id = msg.loginRes.id;
                } else if (msg.type == MsgType.ADD_PLAYER_RES) {
                    if (id == msg.addPlayerRes.id) {
                        player = msg.addPlayerRes;
                        timer = new Timer(1000);
                        timer.run = function() {
                            var msg = new ProtocolMessage();
                            msg.type = MsgType.UPDATE_PLAYER_REQ;
                            msg.updatePlayerReq = new PlayerData();
                            msg.updatePlayerReq.x = player.x + Math.floor(Math.random() * 40 - 20);
                            msg.updatePlayerReq.y = player.y + Math.floor(Math.random() * 40 - 20);
                            client.writeMsgSafe(msg);
                        }
                    }
                } else if (msg.type == MsgType.UPDATE_PLAYER_RES) {
                    if (id == msg.updatePlayerRes.id) {
                        if (msg.updatePlayerRes.hasX()) {
                            player.x = msg.updatePlayerRes.x;
                        }
                        if (msg.updatePlayerRes.hasY()) {
                            player.y = msg.updatePlayerRes.y;
                        }
                    }
                }
//                trace('CLIENT MSG ${id}: ' + haxe.Json.stringify(msg));
            }
        });
        client.on(NodeC.EVENT_STREAM_CLOSE, function() {
            if (timer != null) {
                timer.stop();
            }
//            console.log('server got client close: ${client.getAP()}');
        });
    }

}
