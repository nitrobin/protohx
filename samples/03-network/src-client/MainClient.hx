package ;
import flash.events.MouseEvent;
import flash.text.TextField;
import haxe.ds.IntMap;
import samples.PlayerData;
import flash.display.Sprite;
import haxe.io.BytesData;
import net.MsgQueue;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;
import protohx.Message;
import protohx.ProtocolTypes;
import haxe.io.BytesOutput;
import haxe.io.Bytes;
import flash.events.Event;
import flash.events.ErrorEvent;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.events.ProgressEvent;
import com.eclecticdesignstudio.motion.Actuate;
import com.eclecticdesignstudio.motion.easing.Quad;


class PlayerNode extends flash.display.Sprite {
    public var player:PlayerData;
    var tf:TextField;

    public function new(player:PlayerData) {
        super();
        this.player = player;
        var bot:Bool = ((player.nick != null) && player.nick.indexOf("bot") == 0);

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
//#if flash
//TODO refactoring
class SocketConnection {
    var socket:flash.net.Socket;
    var msgQueue:MsgQueue;
    var s:Sprite;
    var players:IntMap<PlayerNode>;

    public function connect(s:Sprite) {
        this.s = s;
        socket.connect("127.0.0.1", 5000);
        s.addEventListener(MouseEvent.CLICK, onClick);
    }

    public function new() {
        players = new IntMap<PlayerNode>();
        msgQueue = new MsgQueue();
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
    }

    private function errorHandler(e:ErrorEvent):Void {
        trace("errorHandler" + Std.string(e));
    }

    private function onClick(e:MouseEvent):Void {
        var msg = new ProtocolMessage();
        msg.type = MsgType.UPDATE_PLAYER_REQ;
        msg.updatePlayerReq = new PlayerData();
        msg.updatePlayerReq.x = cast e.stageX;
        msg.updatePlayerReq.y = cast e.stageY;
        writeMsg(msg);
    }

    private function connectHandler(e:Event):Void {
//        trace("connectHandler");
        var msg = new ProtocolMessage();
        msg.type = MsgType.LOGIN_REQ;
        msg.loginReq = new LoginReq();
        msg.loginReq.nick = "uf" + Math.floor(Math.random() * 100);
        writeMsg(msg);
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
            msgQueue.addBytes(bs);

            while (msgQueue.hasMsg()) {
                var msg:ProtocolMessage = msgQueue.popMsg();
//                trace('CLIENT MSG: ' + haxe.Json.stringify(msg));
                if (msg.type == MsgType.REMOVE_PLAYER_RES) {
                    var node = players.get(msg.removePlayerRes.id);
                    if (node != null) {
                        players.remove(msg.removePlayerRes.id) ;
                        s.removeChild(node);
                    }
                } else if (msg.type == MsgType.ADD_PLAYER_RES) {
                    var p = msg.addPlayerRes;
                    var node = new PlayerNode(p);
                    players.set(p.id, node);
                    s.addChild(node);
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
//#else


class MainClient extends flash.display.Sprite {

    public static function main() {
        flash.Lib.current.addChild(new MainClient());
    }
    public function new() {
        super();
        graphics.clear();
        graphics.beginFill(0x888888);
        graphics.drawRect(0, 0, 400, 400);
        graphics.endFill();

        var s = new SocketConnection();
        s.connect(this);
    }
}