package server.logic;
import protohx.Protohx;
import samples.RemovePlayerRes;
import samples.ClientType;
import samples.PlayerData;
import samples.LoginRes;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;

enum NetEvent {
    NEConnect;
    NEMsg(type:Int, msg:ProtocolMessage);
    NEDisconnect;
}

class SessionRegistry {
    private inline static var MAX_X:Int = 320;
    private inline static var MAX_Y:Int = 320;

    private var sessions:List<Session>;
    private var sessionId:Int;

    private var sDate:Date;
    private var byCT:IntMap<Int>;
    private var byCP:IntMap<Int>;

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
        sDate = Date.now();
        byCT = new IntMap<Int>();
        byCP = new IntMap<Int>();
    }

    public function scanPlayer(playerData:PlayerData):Void {
        var t = byCT.get(playerData.clientType);
        byCT.set(playerData.clientType, t == null ? 1 : t + 1);
        var p = byCP.get(playerData.clientPlatform);
        byCP.set(playerData.clientPlatform, p == null ? 1 : p + 1);
    }

    public function getStatisticsStr():String {
        var online = 0;
        forEachSessions(isAuthorized, function(s:Session):Void {
            online++;
        });
        var byTypes = {};
        for (key in byCT.keys()) {
            Reflect.setField(byTypes, common.Config.getTypeName(key), byCT.get(key));
        }
        var byPlatforms = {};
        for (key in byCP.keys()) {
            Reflect.setField(byPlatforms, common.Config.getPlatformName(key), byCP.get(key));
        }
        return haxe.Json.stringify({
            "sDate":sDate,
            "nowDate":Date.now(),
            "playersHandled":sessionId,
            "playersOnline":online,
            "byClientType":byTypes,
            "byClientPlatform":byPlatforms
        });
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
            trace("IN: " + protohx.MessageUtils.toJson(msg));
            handleMsg(session, NEMsg(msg.type, msg));
        }
    }

    private function handleMsg(session:Session, event:NetEvent) {
        switch(event){
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
            }
            case NEMsg(type, msg):{
                switch(type) {
                    case MsgType.LOGIN_REQ: {
                        if (session.player != null) {
                            log("double login!");
                            session.close();
                            return;
                        }
                        var playerData = new PlayerData();
                        playerData.id = session.id;
                        if(msg.loginReq.clientType == ClientType.CT_BOT){
                            playerData.nick = "bot" + session.id;
                        } else {
                            playerData.nick = "usr" + session.id;
                        }
                        playerData.x = Std.int(Math.random() * MAX_X);
                        playerData.y = Std.int(Math.random() * MAX_Y);
                        playerData.status = "hi!";
                        playerData.clientType = msg.loginReq.clientType;
                        playerData.clientPlatform = msg.loginReq.clientPlatform;
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
                        scanPlayer(playerData);
                    }
                    case MsgType.UPDATE_PLAYER_REQ: {
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
    }

}
