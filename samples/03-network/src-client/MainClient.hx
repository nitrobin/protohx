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

#if flash
class SocketConnection {
    var socket:flash.net.Socket;

    public function connect(host, port, onConnect, addBytes) {
        socket.connect(host, port);
        this.onConnect = onConnect;
        this.addBytes = addBytes;
    }

    public dynamic function onConnect():Void {}

    public dynamic function addBytes(bytes:Bytes):Void {}

    public function new() {
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

    private function connectHandler(e:Event):Void {
//        trace("connectHandler");
        onConnect();
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
            addBytes(bs);
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
#else
class SocketConnection {
    var socket:sys.net.Socket;

    public function connect(host, port, onConnect, addBytes) {
        this.onConnect = onConnect;
        this.addBytes = addBytes;
        socket.connect(new sys.net.Host(host), port);
        trace("connected");
        onConnect();

        var buffer = Bytes.alloc(1024);
        var timer = new haxe.Timer(500);
        timer.run = function() {
            try {
                var r:{ read:Array<sys.net.Socket> } = sys.net.Socket.select([socket], [], [], 0.01);
                if (r.read == null || r.read.length == 0) {
                    return;
                }
                var size = socket.input.readBytes(buffer, 0, buffer.length);
                addBytes(buffer.sub(0, size));
            } catch (e:Dynamic) {
                trace(e);
            }
        };
    }

    public dynamic function onConnect():Void {}

    public dynamic function addBytes(bytes:Bytes):Void {}

    public function new() {
        socket = new sys.net.Socket();
        socket.input.bigEndian = false;
        socket.output.bigEndian = false;
    }

    public function writeMsg(msg:protohx.Message):Void {
        var b = new BytesOutput();
        msg.writeTo(b);
        var bytes = b.getBytes();
        socket.output.writeInt32(bytes.length);
        socket.output.writeBytes(bytes, 0, bytes.length);
    }


}
#end


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
        s.connect("127.0.0.1", 5000, onConnect, addBytes);
    }

    private function onClick(e:MouseEvent):Void {
        var msg = new ProtocolMessage();
        msg.type = MsgType.UPDATE_PLAYER_REQ;
        msg.updatePlayerReq = new PlayerData();
        msg.updatePlayerReq.x = cast e.stageX;
        msg.updatePlayerReq.y = cast e.stageY;
        s.writeMsg(msg);
    }


    private function onConnect():Void {
        var msg = new ProtocolMessage();
        msg.type = MsgType.LOGIN_REQ;
        msg.loginReq = new LoginReq();
        msg.loginReq.nick = "uf" + Math.floor(Math.random() * 100);
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