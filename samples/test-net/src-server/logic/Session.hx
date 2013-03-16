package logic;
import net.MsgQueue;
import samples.ProtocolMessage;
import samples.PlayerData;
import js.Node;

class Session {
    public var id:Int;
    public var player:PlayerData;

    public var msgQueue:MsgQueue;

    public function new() {
        msgQueue = new MsgQueue();
    }

    public function close():Void {
    }

    public function writeMsg(msg:protohx.Message):Void {
    }
}
