package ;
import samples.PlayerData;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;

import net.MsgQueue;
import net.SocketConnection;

import protohx.Message;
import protohx.ProtocolTypes;

import haxe.ds.IntMap;
import haxe.io.Bytes;

import flash.text.TextField;
import flash.display.Sprite;
import flash.events.MouseEvent;

import com.eclecticdesignstudio.motion.Actuate;
import com.eclecticdesignstudio.motion.easing.Quad;


class PlayerNode extends flash.display.Sprite {
    public var player:PlayerData;
    var tf:TextField;

    public function new(player:PlayerData) {
        super();
        this.player = player;
        var nick = player.nick;
        var bot:Bool = ((nick != null) && nick.indexOf("bot") == 0);

        graphics.clear();
        graphics.lineStyle(1, 0x000000);
        graphics.beginFill(bot ? 0x880000 : 0x00ff00);
//        graphics.drawCircle(0, 0, 20);
        graphics.drawRect(-15, -15, 40, 40);
        graphics.endFill();

        tf = new TextField();
        tf.x = -15 ;
        tf.y = -15 ;
        tf.selectable = false;
        addChild(tf);
        rebuild(false);
    }

    public function rebuild(animate:Bool) {
        tf.text = player.nick;
        if (animate) {
            var duration:Float = 1.0;
            var targetX:Float = player.x;
            var targetY:Float = player.y;
            Actuate.stop(this);
            Actuate.tween(this, duration, { x: targetX, y: targetY }, true).ease(Quad.easeOut);

        } else {
            x = player.x;
            y = player.y;
        }

    }
}


class MainClient extends flash.display.Sprite {

    var msgQueue:MsgQueue;
    var players:IntMap<PlayerNode>;
    var s:SocketConnection;

    public static function main() {
        flash.Lib.current.addChild(new MainClient());
    }

    public function new() {
        super();
        players = new IntMap<PlayerNode>();
        msgQueue = new MsgQueue();
        graphics.clear();
        graphics.beginFill(0x888888);
        graphics.drawRect(0, 0, 400, 400);
        graphics.endFill();
        addEventListener(MouseEvent.CLICK, onClick);

        s = new SocketConnection();
        s.connect("127.0.0.1", 5000, onConnect, addBytes, onClose);
    }

    private function onClick(e:MouseEvent):Void {
        var msg = new ProtocolMessage();
        msg.type = MsgType.UPDATE_PLAYER_REQ;
        msg.updatePlayerReq = new PlayerData();
        msg.updatePlayerReq.x = cast e.stageX;
        msg.updatePlayerReq.y = cast e.stageY;
        s.writeMsg(msg);
    }

    private function onClose():Void {
        trace("connection closed");
    }

    private function onConnect():Void {
        var msg = new ProtocolMessage();
        msg.type = MsgType.LOGIN_REQ;
        msg.loginReq = new LoginReq();
        msg.loginReq.nick = "uf" + Math.floor(Math.random() * 50);
        s.writeMsg(msg);
    }

    private function addBytes(bytes:Bytes):Void {
        msgQueue.addBytes(bytes);
        while (msgQueue.hasMsg()) {
            var msg:ProtocolMessage = msgQueue.popMsg();
//                trace('CLIENT MSG: ' + haxe.Json.stringify(msg));
            if (msg.type == MsgType.REMOVE_PLAYER_RES) {
                var node = players.get(msg.removePlayerRes.id);
                if (node != null) {
                    players.remove(msg.removePlayerRes.id) ;
                    removeChild(node);
                }
            } else if (msg.type == MsgType.ADD_PLAYER_RES) {
                var p = msg.addPlayerRes;
                var node = new PlayerNode(p);
                players.set(p.id, node);
                addChild(node);
            } else if (msg.type == MsgType.UPDATE_PLAYER_RES) {
                var node = players.get(msg.updatePlayerRes.id);
                if (node != null) {
                    if (msg.updatePlayerRes.hasX()) {
                        node.player.x = msg.updatePlayerRes.x;
                    }
                    if (msg.updatePlayerRes.hasY()) {
                        node.player.y = msg.updatePlayerRes.y;
                    }
                    node.rebuild(true);
                }
            }
        }
    }

}