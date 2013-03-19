package logic;
import samples.RemovePlayerRes;
import samples.PlayerData;
import samples.LoginRes;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;

//TODO optimize broadcasting
class SessionRegistry {
    private inline static var MAX_X:Int = 320;
    private inline static var MAX_Y:Int = 320;

    private var sessions:List<Session>;
    private var sessionId:Int;

    private function log(msg):Void {
        trace(msg);
    }

    private function nextSessionId():Int {
        sessionId++;
        return sessionId;
    }

    public function new() {
        sessions = new List<Session>();
        sessionId = 0;
    }

    private function registerSession(session:Session) {
        session.id = nextSessionId();
        sessions.add(session);
    }

    private function unRegisterSession(session:Session) {
        sessions.remove(session);
    }

    private function isAuthorized(session:Session):Bool {
        return session != null && session.player != null;
    }

    private function forEachSessions(test:Session -> Bool, body:Session -> Void):Void {
        for (session in sessions) {
            if (test(session)) {
                body(session);
            }
        }
    }

    public function sessionConnect(session:Session) {
        registerSession(session);
    }

    public function sessionDisconnect(session:Session) {
        unRegisterSession(session);
        if (session.player == null) {
            return;
        }
        var removePlayer = new ProtocolMessage();
        removePlayer.type = MsgType.REMOVE_PLAYER_RES;
        removePlayer.removePlayerRes = new RemovePlayerRes();
        removePlayer.removePlayerRes.id = session.player.id;
        var removePlayerBaked = session.bakeMsg(removePlayer);

        forEachSessions(isAuthorized, function(sessionOther:Session) {
            sessionOther.writeMsgBaked(removePlayerBaked);
        });
    }

    public function sessionData(session:Session, bytes:haxe.io.Bytes) {
        session.incomeMsgQueue.addBytes(bytes);
        while (session.incomeMsgQueue.hasMsg()) {
            var msg:ProtocolMessage = session.incomeMsgQueue.popMsg();
            handleMsg(session, msg);
        }
    }

    private function handleMsg(session:Session, msg:ProtocolMessage) {
//        log("SERVER MSG: " + haxe.Json.stringify(msg));
        if (msg.type == MsgType.LOGIN_REQ) {
            if (session.player != null) {
                log("double login!");
                session.close();
                return;
            }
            var playerData = new PlayerData();
            playerData.id = session.id;
            playerData.nick = msg.loginReq.nick;
            playerData.x = cast (Math.random() * MAX_X);
            playerData.y = cast (Math.random() * MAX_Y);
            playerData.status = "hi!";
            playerData.nick = msg.loginReq.nick;
            session.player = playerData;

            var respMsg = new ProtocolMessage();
            respMsg.type = MsgType.LOGIN_RES;
            respMsg.loginRes = new LoginRes();
            respMsg.loginRes.id = session.id ;
            session.writeMsg(respMsg);

            var addPlayerMsg = new ProtocolMessage();
            addPlayerMsg.type = MsgType.ADD_PLAYER_RES;
            addPlayerMsg.addPlayerRes = session.player;
            var addPlayerMsgBaked = session.bakeMsg(addPlayerMsg);

            forEachSessions(isAuthorized, function(sessionOther:Session) {
                sessionOther.writeMsgBaked(addPlayerMsgBaked);
                if (sessionOther != session) {
                    var addOtherPlayer = new ProtocolMessage();
                    addOtherPlayer.type = MsgType.ADD_PLAYER_RES;
                    addOtherPlayer.addPlayerRes = sessionOther.player;
                    session.writeMsg(addOtherPlayer);
                }
            });
        } else if (msg.type == MsgType.UPDATE_PLAYER_REQ) {
            var respMsg = new ProtocolMessage();
            respMsg.type = MsgType.UPDATE_PLAYER_RES;
            respMsg.updatePlayerRes = session.player;
            if (msg.updatePlayerReq.hasX()) {
                respMsg.updatePlayerRes.x = cast Math.min(Math.max(0, msg.updatePlayerReq.x), MAX_X);
            }
            if (msg.updatePlayerReq.hasY()) {
                respMsg.updatePlayerRes.y = cast Math.min(Math.max(0, msg.updatePlayerReq.y), MAX_Y) ;
            }
            var respMsgBaked = session.bakeMsg(respMsg);
            forEachSessions(isAuthorized, function(sessionOther:Session) {
                sessionOther.writeMsgBaked(respMsgBaked);
            });
        }
    }

}
