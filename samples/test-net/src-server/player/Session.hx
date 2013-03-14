package player;
import haxe.io.BytesInput;
import samples.ProtocolMessage;
import samples.PlayerData;
import js.Node;
import haxe.io.Bytes;

class Session {
    public var id:Int;
    public var client:NodeNetSocket;
    public var player:PlayerData;

    public var bytesParser:BytesParser;

    public function new() {
        bytesParser = new BytesParser();
    }
}
