package server.nodejs;
#if js
import common.Config;
import haxe.Timer;
import samples.PlayerData;
import samples.ClientType;
import samples.ClientPlatform;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;
import common.MsgQueue;
import server.logic.SessionRegistry;
import server.logic.Session;
import haxe.io.Bytes;
import js.Node;
import server.nodejs.NodeUtils;
using  server.nodejs.NodeUtils;

class BotClient {
    private static var net:NodeNet = Node.net;
    private static var console:NodeConsole = Node.console;

    public static function main() {
        for(i in 0...20){
            tcpClientTest(Config.DEFAULT_HOST, Config.DEFAULT_TCP_PORT);
        }
    }

    public static function tcpClientTest(host:String, port:Int) {
        var msgQueue:MsgQueue = new MsgQueue();
        var client:NodeNetSocket = net.connect(port, host);
        var id:Int = 0;
        var player:PlayerData = null;
        var timer:Int = 0;
        client.on(NodeC.EVENT_STREAM_CONNECT, function() {
            console.log('client connected to: '+ client.addressPort());
            var msg = new ProtocolMessage();
            msg.type = MsgType.LOGIN_REQ;
            msg.loginReq = new LoginReq();
            msg.loginReq.status = "ok";
            msg.loginReq.clientType = ClientType.CT_BOT;
            msg.loginReq.clientPlatform = ClientPlatform.CP_NODEJS;
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
                        timer = Node.setInterval(function() {
                            var msg = new ProtocolMessage();
                            msg.type = MsgType.UPDATE_PLAYER_REQ;
                            msg.updatePlayerReq = new PlayerData();
                            msg.updatePlayerReq.x = player.x + Math.floor(Math.random() * 40 - 20);
                            msg.updatePlayerReq.y = player.y + Math.floor(Math.random() * 40 - 20);
                            client.writeMsgSafe(msg);
                        }, 1000 + Std.int(1000 * Math.random()));
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
            if (timer != 0) {
                Node.clearInterval(timer);
            }
//            console.log('server got client close: ${client.getAP()}');
        });
    }

}
#end
