package ;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;
import protohx.Message;
import protohx.ProtocolTypes;
import haxe.io.BytesOutput;
import haxe.io.Bytes;

class MainClient extends nme.display.Sprite {

    public static function main() {
       var pm = new ProtocolMessage();
       pm.type = MsgType.LOGIN_REQ;
       pm.loginReq = new LoginReq();
       pm.loginReq.nick = "user";
    }
}