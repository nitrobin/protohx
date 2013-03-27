package server.logic;
import common.MsgQueue;
import samples.ProtocolMessage;
import samples.PlayerData;

class Session {
    public var id:Int;
    public var player:PlayerData;

    public var incomeMsgQueue:MsgQueue;

    public function new() {
        incomeMsgQueue = new MsgQueue();
    }

    public function close():Void {
    }

    public function bakeMsg(msg:protohx.Message):BakedMsg {
        return new BakedMsg(msg);
    }

    public function writeMsgBaked(msg:BakedMsg):Void {
        writeMsg(msg.msg);
    }

    public function writeMsg(msg:protohx.Message):Void {
    }
}
