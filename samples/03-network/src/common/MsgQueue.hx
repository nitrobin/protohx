package common;
import samples.ProtocolMessage;
import haxe.io.BytesInput;
import haxe.io.BytesBuffer;
import haxe.io.Bytes;

class MsgQueue {
    public static inline var HEADER_SIZE:Int = 2;

    private var bytesBuff:Bytes;
    private var msgs:List<ProtocolMessage>;

    public function new() {
        msgs = new List<ProtocolMessage>();
    }

    public inline function hasMsg():Bool {
        return !msgs.isEmpty();
    }

    public inline function popMsg():ProtocolMessage {
        return msgs.pop();
    }

    public inline function addMsg(msg:ProtocolMessage):Void {
        msgs.add(msg);
    }

    public function addBytes(bytes:Bytes) {
        if(bytes == null){
            return;
        }
        if (bytesBuff == null) {
            bytesBuff = bytes;
        } else {
            var buffer = new BytesBuffer();
            buffer.add(bytesBuff);
            buffer.add(bytes);
            bytesBuff = buffer.getBytes();
        }
        if (bytesBuff == null || bytesBuff.length < HEADER_SIZE) {
            return;
        }
        var available = bytesBuff.length;
        var bi = new BytesInput(bytesBuff);
        bi.bigEndian = false;
        while (available >= HEADER_SIZE) {
            var packetSize = bi.readUInt16();
            available -= HEADER_SIZE;
            if (packetSize <= available) {
                available -= packetSize;
                var msgBytes = bi.read(packetSize);
                var msg = new ProtocolMessage();
                msg.mergeFrom(msgBytes);
                addMsg(msg);
            } else {
                available += HEADER_SIZE;
                break;
            }
        }
        if (available == 0) {
            bytesBuff = null;
        } else if (available > 0) {
            if (bytesBuff.length != available) {
                var pos = bytesBuff.length - available;
                bytesBuff = bytesBuff.sub(pos, available);
            }
        } else {
            throw "Wrong available: " + available;
        }
    }
}
