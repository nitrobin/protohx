package logic;
import samples.RemovePlayerRes;
import samples.PlayerData;
import samples.LoginRes;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;

class SessionRegistry {
    private inline static var MAX_X:Int = 400;
    private inline static var MAX_Y:Int = 400;

    private var sessions:List<Session>;
    private var sessionId:Int;

    public function log(msg):Void {
        trace(msg);
    }

    public function nextSessionId():Int {
        sessionId++;
        return sessionId;
    }

    public function new() {
        sessions = new List<Session>();
        sessionId = 0;
    }


    public function registerSession(session:Session) {
        session.id = nextSessionId();
        sessions.add(session);
    }

    public function handleDisconnect(session:Session) {
        sessions.remove(session);
        if (session.player == null) {
            return;
        }
        var removePlayer = new ProtocolMessage();
        removePlayer.type = MsgType.REMOVE_PLAYER_RES;
        removePlayer.removePlayerRes = new RemovePlayerRes();
        removePlayer.removePlayerRes .id = session.player.id;

        for (sessionOther in getAuthorizedSessions()) {
            sessionOther.writeMsg(removePlayer);
        }
    }

    public function getAuthorizedSessions():Iterable<Session> {
        return Lambda.filter(sessions, function(session:Session):Bool {
            return session != null && session.player != null;
        });
    }

    public function handleData(session:Session) {
        while (session.msgQueue.hasMsg()) {
            var msg:ProtocolMessage = session.msgQueue.popMsg();
            handleMsg(session, msg);
        }
    }

    public function handleMsg(session:Session, msg:ProtocolMessage) {
        log("SERVER MSG: " + haxe.Json.stringify(msg));
        if (msg.type == MsgType.LOGIN_REQ) {
            if (session.player != null) {
                log("double login!");
                session.close();
                return;
            }
            var playerData = new PlayerData();
            playerData.id = session.id;
            playerData.nick = msg.loginReq.nick;
            playerData.x = cast (Math.random() * 100);
            playerData.y = cast (Math.random() * 100);
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

            for (sessionOther in getAuthorizedSessions()) {
                if (sessionOther == session) {
                    sessionOther.writeMsg(addPlayerMsg);
                } else {
                    sessionOther.writeMsg(addPlayerMsg);

                    var addOtherPlayer = new ProtocolMessage();
                    addOtherPlayer.type = MsgType.ADD_PLAYER_RES;
                    addOtherPlayer.addPlayerRes = sessionOther.player;
                    session.writeMsg(addOtherPlayer);
                }
            }
        } else if (msg.type == MsgType.UPDATE_PLAYER_REQ) {
            var respMsg = new ProtocolMessage();
            respMsg.type = MsgType.UPDATE_PLAYER_RES;
            respMsg.updatePlayerRes = new PlayerData();
            respMsg.updatePlayerRes.id = session.id ;
            if (msg.updatePlayerReq.hasX()) {
                respMsg.updatePlayerRes.x = cast Math.min(Math.max(0, msg.updatePlayerReq.x), MAX_X);
            }
            if (msg.updatePlayerReq.hasY()) {
                respMsg.updatePlayerRes.y = cast Math.min(Math.max(0, msg.updatePlayerReq.y), MAX_Y) ;
            }
            session.writeMsg(respMsg);

        }
    }

}
