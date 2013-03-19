package logic;
class BakedMsg {
    public var msg:protohx.Message;
    public var data:Dynamic;
    public function new(msg:protohx.Message, ?data:Dynamic) {
        this.msg = msg;
        this.data = data;
    }
}
