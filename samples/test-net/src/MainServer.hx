package ;
import samples.LoginReq;
import samples.ProtocolMessage;
import samples.protocolmessage.MsgType;
import protohx.Message;
import haxe.io.BytesOutput;
import protohx.ProtocolTypes;
import haxe.io.Bytes;
import js.Node;

class MainServer {

    public static
    function main() {
//        clientTest();
  tcpTest();
//flashCrossDomain();
    }

    public static function
    tcpTest() {

        var tcp = Node.net;

        var s = tcp.createServer(function(c:NodeNetSocket) {
            c.addListener('connect', function(d) {
                trace("got connection");
                c.write("hello\r\n");

                var b = new BytesOutput();
                var pm = new ProtocolMessage();
                pm.type = MsgType.LOGIN_REQ;
                pm.loginReq = new LoginReq();
                pm.loginReq.nick = "user";
                pm.writeTo(b);
                c.write(new NodeBuffer(b.getBytes().getData()));
                c.write("hello\r\n");
            });

            c.addListener('data', function(d) {
                c.write(d);
            });

            c.addListener('data', function(d) {
                trace("lost connection");
                c.end();
            });
        });

        s.listen(5000, "localhost");

        trace("here");
    }

    public static function flashCrossDomain() {
        var tcp = Node.net;

        var s = tcp.createServer(function(c) {
            c.addListener('connect', function(d) {
                c.write('<?xml version="1.0"?>
                < !DOCTYPE cross- domain - policy
                SYSTEM "http://www.macromedia.com/xml/dtds/cross-domain-policy.dtd">
                <cross -domain - policy>
                <allow - access - from domain = "*" to - ports = "1138,1139,1140" / >
                < / cross - domain - policy>');
                c.end();
            });

            c.addListener('end', function(d) {
                trace("lost connection");
                c.end();
            });
        });

        trace("args[1] " + Node.process.argv[2]);
        s.listen(843, Node.process.argv[2]);

    }


    static function clientTest() {
        var
        console = Node.console,
        http = Node.http,
        google = http.createClient(80, "www.google.cl"),
        request = google.request("GET", "/", {host: "www.google.cl"});


        request.addListener('response', function(response) {
            console.log("STATUS: " + response.statusCode);
            console.log("HEADERS: " + Node.stringify(response.headers));
            response.addListener("data", function(chunk) {
                console.log("BODY: " + chunk);
            });
        });

        request.end();

    }
}