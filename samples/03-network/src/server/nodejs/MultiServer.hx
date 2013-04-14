package server.nodejs;
import server.logic.SessionRegistry;
import common.Config;

class MultiServer {
    public static function main() {
        var sr:SessionRegistry = new SessionRegistry();
        NetServer.runSocketServer(sr, Config.DEFAULT_TCP_PORT);
        var port = untyped  (__js__("process.env.VMC_APP_PORT ") || Config.DEFAULT_HTTP_PORT);
        SocketIoServer.runSocketIoServer(sr, port);
    }
}
