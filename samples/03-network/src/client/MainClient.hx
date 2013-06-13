package client;

import samples.ClientType;
import samples.ClientPlatform;
import flash.text.TextFieldType;
import samples.PlayerData;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;

import common.Config;
import common.MsgQueue;
import common.SocketConnection;

import protohx.Message;
import protohx.Protohx;

import haxe.io.Bytes;

import flash.text.TextField;
import flash.display.Sprite;
import flash.events.MouseEvent;

import motion.Actuate;
import motion.easing.Quad;


class PlayerNode extends flash.display.Sprite {
    public var player:PlayerData;
    private var tf:TextField;
    private var me:Bool;
    private var bot:Bool;

    public function new(player:PlayerData, myId:Int) {
        super();
        this.player = player;
//        trace(protohx.MessageUtils.toJson(player));
        me = (player.id == myId);
        bot = (player.clientType == ClientType.CT_BOT);

        graphics.clear();
        graphics.lineStyle(me ? 3 : 1, me ? 0xff0000 : 0x000000);
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
        tf.text = '' + player.nick + '\n[' + Config.getPlatformName(player.clientPlatform) + ']';
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


class SimpleBtn extends flash.display.Sprite {
    public var btn:TextField;

    public function new(label:String) {
        super();

        btn = new TextField();
        btn.defaultTextFormat.size = 24;
        btn.text = ""+label;
        btn.border = true;
        btn.borderColor = 0xff0000;
        btn.backgroundColor = 0x00ff00;
        btn.background = true;
        btn.selectable = false;
        btn.height = 28;
        btn.width = 100;
        btn.x = 0;
        btn.y = 0;
        addChild(btn);
        graphics.clear();
        graphics.beginFill(0x00ff00);
        graphics.drawRect(0, 0, 100, 28);
        graphics.endFill();

    }
}

class AddressSprite extends flash.display.Sprite {
    public var hostTF:TextField;
    public var portTF:TextField;
    public var btn:Sprite;

    public function new(host:String, port:Int) {
        super();
        hostTF = new TextField();
        hostTF.type = TextFieldType.INPUT;
        hostTF.defaultTextFormat.size = 24;
        hostTF.text = host;
        hostTF.border = true;
        hostTF.borderColor = 0x000000;
        hostTF.height = 28;
        hostTF.width = 100;
        hostTF.x = 0;
        hostTF.y = 0;
        addChild(hostTF);

        portTF = new TextField();
        portTF.type = TextFieldType.INPUT;
        portTF.defaultTextFormat.size = 24;
        portTF.text = Std.string(port);
        portTF.border = true;
        portTF.borderColor = 0x000000;
        portTF.height = 28;
        portTF.width = 100;
        portTF.x = 0;
        portTF.y = 30;
        addChild(portTF);

        btn = new SimpleBtn("connect");
        btn.x = 0;
        btn.y = 60;
        addChild(btn);
    }
}

class MainClient extends flash.display.Sprite {

    var msgQueue:MsgQueue;
    var players:IntMap<PlayerNode>;
    var s:SocketConnection;
    var welcome:Sprite;

    public static function main() {
        flash.Lib.current.addChild(new MainClient());
    }

    public function new() {
        super();
        graphics.clear();
        graphics.beginFill(0x888888);
        graphics.drawRect(0, 0, 400, 400);
        graphics.endFill();
        welcome = new Sprite();

        #if js
        var btn = new SimpleBtn("connect");
        btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void{
            connect("", 0);
        });
        welcome.addChild(btn);
        #else
        var address = new AddressSprite(Config.DEFAULT_HOST, Config.DEFAULT_TCP_PORT);
        address.btn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):Void{
            var host = address.hostTF.text;
            var port = Std.parseInt(address.portTF.text);
            connect(host, port);
        });
        welcome.addChild(address);
        #end

        start();
    }

    private function start():Void {
        addChild(welcome);
    }

    private function connect(host, port):Void {
        removeChild(welcome);
        players = new IntMap<PlayerNode>();
        msgQueue = new MsgQueue();
        s = new SocketConnection();
        s.connect(host, port, onConnect, addBytes, onClose);
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
        removeEventListener(MouseEvent.CLICK, onClick);
        while(numChildren>0){
            removeChildAt(0);
        }
        graphics.clear();
        graphics.beginFill(0xff8888);
        graphics.drawRect(0, 0, 400, 400);
        graphics.endFill();
    }

    private function onConnect():Void {
        addEventListener(MouseEvent.CLICK, onClick);
        var msg = new ProtocolMessage();
        msg.type = MsgType.LOGIN_REQ;
        msg.loginReq = new LoginReq();
        msg.loginReq.status = "ok";
        msg.loginReq.clientType = ClientType.CT_HUMAN;
        msg.loginReq.clientPlatform = Config.getPlatform();
        s.writeMsg(msg);
        graphics.clear();
        graphics.beginFill(0x88ff88);
        graphics.drawRect(0, 0, 400, 400);
        graphics.endFill();
    }

    private var myId:Int;

    private function addBytes(bytes:Bytes):Void {
        msgQueue.addBytes(bytes);
        while (msgQueue.hasMsg()) {
            var msg:ProtocolMessage = msgQueue.popMsg();
//                trace('CLIENT MSG: ' + haxe.Json.stringify(msg));
            if (msg.type == MsgType.LOGIN_RES) {
                myId = msg.loginRes.id;
            } else if (msg.type == MsgType.REMOVE_PLAYER_RES) {
                var node = players.get(msg.removePlayerRes.id);
                if (node != null) {
                    players.remove(msg.removePlayerRes.id) ;
                    removeChild(node);
                }
            } else if (msg.type == MsgType.ADD_PLAYER_RES) {
                var p = msg.addPlayerRes;
                var node = new PlayerNode(p, myId);
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
