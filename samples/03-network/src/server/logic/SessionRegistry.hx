package server.logic;
import samples.RemovePlayerRes;
import samples.PlayerData;
import samples.LoginRes;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;

enum NetEvent{
    NEConnect;
    NEMsg(type:Int, msg:ProtocolMessage);
    NEDisconnect;
}

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

    private static function isAuthorized(session:Session):Bool {
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
        handleMsg(session, NEConnect);
    }

    public function sessionDisconnect(session:Session) {
        unRegisterSession(session);
        handleMsg(session, NEDisconnect);
    }

    public function sessionData(session:Session, bytes:haxe.io.Bytes) {
        session.incomeMsgQueue.addBytes(bytes);
        while (session.incomeMsgQueue.hasMsg()) {
            var msg:ProtocolMessage = session.incomeMsgQueue.popMsg();
            trace("IN: "+protohx.MessageUtils.toJson(msg));
            handleMsg(session, NEMsg(msg.type, msg));
        }
    }

    private function handleMsg(session:Session, e:NetEvent) {
        switch(e){
        case NEConnect:{ /*pass*/};
        case NEDisconnect:{
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
        };
        case NEMsg(MsgType.LOGIN_REQ, msg): {
            if (session.player != null) {
                log("double login!");
                session.close();
                return;
            }
            var playerData = new PlayerData();
            playerData.id = session.id;
            playerData.nick = msg.loginReq.nick;
            playerData.x = Std.int(Math.random() * MAX_X);
            playerData.y = Std.int(Math.random() * MAX_Y);
            playerData.status = "hi!";
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
        };
        case NEMsg(MsgType.UPDATE_PLAYER_REQ, msg): {
            var player = session.player;
            if(player == null){
                return;
            }
            var updateData = msg.updatePlayerReq;
            updateData.id = player.id;
            if (updateData.hasX()) {
                updateData.x = Std.int(Math.min(Math.max(0, updateData.x), MAX_X));
                player.x = updateData.x;
            }
            if (updateData.hasY()) {
                updateData.y = Std.int(Math.min(Math.max(0, updateData.y), MAX_Y));
                player.y = updateData.y;
            }
            if (updateData.hasStatus()) {
                player.status = updateData.status;
            }
            var respMsg = new ProtocolMessage();
            respMsg.type = MsgType.UPDATE_PLAYER_RES;
            respMsg.updatePlayerRes = updateData;
            var respMsgBaked = session.bakeMsg(respMsg);
            forEachSessions(isAuthorized, function(sessionOther:Session) {
                sessionOther.writeMsgBaked(respMsgBaked);
            });
        }
        }
    }

}
