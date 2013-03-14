package player;
import haxe.io.BytesInput;
import haxe.io.BytesBuffer;
import samples.ProtocolMessage;
import js.Node.NodeNetSocket;
import haxe.io.Bytes;
class BytesParser {
    private var bytesBuff:Bytes;
    private var msgs:List<ProtocolMessage>;

    public function new() {
        msgs = new List<ProtocolMessage>();
    }

    public function hasMsg():Bool {
        return !msgs.isEmpty();
    }

    public function popMsg():ProtocolMessage {
        return msgs.pop();
    }

    public function addBytes(bytes:Bytes) {
        trace("added bytes:" + bytes.length);
        if (bytesBuff == null) {
            bytesBuff = bytes;
        } else {
            var buffer = new BytesBuffer();
            buffer.add(bytesBuff);
            buffer.add(bytes);
            bytesBuff = buffer.getBytes();
        }
//        trace("bytes:" + (bytesBuff != null ? bytesBuff.length : 0));

        if (bytesBuff == null || bytesBuff.length < 4) {
            return;
        }
        var available = bytesBuff.length;
        var bi = new BytesInput(bytesBuff);
        bi.bigEndian = false;
        while (available >= 4) {
            var packetSize = bi.readInt32();
            available -= 4;
            if (packetSize <= available) {
                trace("LEN IN:"+packetSize);

                available -= packetSize;
                var msgBytes = bi.read(packetSize);
                var msg = new ProtocolMessage();
                msg.mergeFrom(msgBytes);
//                trace("msg:" + packetSize);
                msgs.add(msg);
            } else {
                available += 4;
//                trace("available:" + available);
                break;
            }
        }
        trace("available:" + available);
        if (available == 0) {
            bytesBuff == null;
        } else if (available > 0) {
            if (bytesBuff.length != available) {
                bytesBuff = bytesBuff.sub(bytesBuff.length - available, available);
            }
        } else {
            throw "error";
        }
    }
}
