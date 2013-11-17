// vim: tabstop=4 shiftwidth=4

// Copyright (c) 2010 , NetEase.com,Inc. All rights reserved.
//
// Author: Yang Bo (pop.atry@gmail.com)
//
// Use, modification and distribution are subject to the "New BSD License"
// as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.

package protohx;

import haxe.io.Output;
import haxe.io.Bytes;
import haxe.Utf8;
import protohx.Protohx;
import haxe.io.BytesOutput;

class WritingBuffer {
    private var slices:Array<PT_UInt>;
    private var buf:BytesOutput;
    public var position(default, null):Int;

    public function new() {
        slices = new Array<PT_UInt>();
        buf = new BytesOutput();
        Protohx.setOutputEndian(buf);
        position = 0;
    }


    public function writeDouble(v):Void {
        buf.writeDouble(v);
        position += 8;
    }

    public function writeFloat(v):Void {
        buf.writeFloat(v);
        position += 4;
    }
    public function writeBytes(v:Bytes):Void {
        buf.write(v);
        position += v.length;
    }
    public function writeUTFBytes(v:String):Void {
        var b = haxe.io.Bytes.ofString(v);
        buf.write(b);
        position += b.length;
    }

    public function writeInt32(v:Int):Void {
        buf.writeInt32(v);
        position += 4;
    }

//    public function writeUnsignedInt(v:Int):Void {
//        buf.writeInt32(v);
//        position += 4;
//    }

    public function writeByte(v:Int):Void {
        buf.writeByte(v);
        position += 1;
    }

    public function beginBlock():PT_UInt {
        slices.push(position);
        var beginSliceIndex:PT_UInt = slices.length;
        slices.push(0);slices.push(0);//slices.length += 2;
        slices.push(position);
        return beginSliceIndex;
    }
    public function endBlock(beginSliceIndex:PT_UInt):Void {
        slices.push(position);
        var beginPosition:PT_UInt = slices[beginSliceIndex + 2];
        slices[beginSliceIndex] = position;
        WriteUtils.write__TYPE_UINT32(this, position - beginPosition);
        slices[beginSliceIndex + 1] = position;
        slices.push(position);
    }
    public function toNormal(output:Output):Void {
        var i:PT_Int = 0;
        var begin:PT_UInt = 0;
        var bytes = buf.getBytes();
        while (i < slices.length) {
            var end:PT_UInt = slices[i];
            ++i;
            if (end > begin) {
                output.writeFullBytes(bytes, begin, end - begin);
            } else if (end < begin) {
                throw new PT_IllegalOperationError("");
            }
            begin = slices[i];
            ++i;
        }
        output.writeFullBytes(bytes, begin, bytes.length - begin);
    }
}

