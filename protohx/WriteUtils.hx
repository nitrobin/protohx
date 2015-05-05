// vim: tabstop=4 shiftwidth=4

// Copyright (c) 2010 , NetEase.com,Inc. All rights reserved.
// Copyright (c) 2012 , Yang Bo. All rights reserved.
//
// Author: Yang Bo (pop.atry@gmail.com)
//
// Use, modification and distribution are subject to the "New BSD License"
// as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.

package protohx;
import protohx.Protohx;
using haxe.Int64;

class WriteUtils {
    private static function writeSingleUnknown(output:PT_OutputStream, tag:PT_UInt, value:Dynamic):Void {
        WriteUtils.write__TYPE_UINT32(output, tag);
        switch (tag & 7) {
        case WireType.VARINT:
            WriteUtils.write__TYPE_UINT64(output, value);
        case WireType.FIXED_64_BIT:
            WriteUtils.write__TYPE_FIXED64(output, value);
        case WireType.LENGTH_DELIMITED:
            WriteUtils.write__TYPE_BYTES(output, value);
        case WireType.FIXED_32_BIT:
            WriteUtils.write__TYPE_FIXED32(output, value);
        default:
            throw new PT_IOError("Invalid wire type: " + (tag & 7));
        }
    }

    public static function writeUnknownPair(output:PT_OutputStream, tag:PT_UInt, value:Dynamic):Void {
        //TODO check
        var repeated:Array<Dynamic> = if(Std.is(value, Array)) cast (value, Array<Dynamic> ) else null;
        if (repeated!=null) {
            for (element in repeated) {
                writeSingleUnknown(output, tag, element);
            }
        } else {
            writeSingleUnknown(output, tag, value);
        }
    }

    private static function writeVarint64(output:PT_OutputStream, low:PT_Int, high:PT_Int):Void {
        if (high == 0) {
            write__TYPE_UINT32(output, low);
        } else {
            for (i in 0...4) {
                output.writeByte((low & 0x7F) | 0x80);
                low >>>= 7;
            }
            if ((high & (0xffffffff << 3)) == 0) {
                output.writeByte((high << 4) | low);
            } else {
                output.writeByte((((high << 4) | low) & 0x7F) | 0x80);
                write__TYPE_UINT32(output, high >>> 3);
            }
        }
    }
    public static function writeTag(output:PT_OutputStream, wireType:PT_UInt, number:PT_UInt):Void {
        write__TYPE_UINT32(output, (number << 3) | wireType);
    }
    public static function write__TYPE_DOUBLE(output:PT_OutputStream, value:PT_Double):Void {
        output.writeDouble(value);
    }
    public static function write__TYPE_FLOAT(output:PT_OutputStream, value:PT_Float):Void {
        output.writeFloat(value);
    }
    public static function write__TYPE_INT64(output:PT_OutputStream, value:PT_Int64):Void {
        writeVarint64(output, Protohx.getLow(value), Protohx.getHigh(value));
    }
    public static function write__TYPE_UINT64(output:PT_OutputStream, value:PT_UInt64):Void {
        writeVarint64(output, Protohx.getLow(value), Protohx.getHigh(value));
    }
    public static function write__TYPE_INT32(output:PT_OutputStream, value:PT_Int):Void {
        if (value < 0) {
            writeVarint64(output, value, 0xFFFFFFFF);
        } else {
            write__TYPE_UINT32(output, value);
        }
    }
    public static function write__TYPE_FIXED64(output:PT_OutputStream, value:PT_UInt64):Void {
        output.writeInt32(Protohx.getLow(value));
        output.writeInt32(Protohx.getHigh(value));
    }
    public static function write__TYPE_FIXED32(output:PT_OutputStream, value:PT_UInt):Void {
        output.writeInt32(value);
    }
    public static function write__TYPE_BOOL(output:PT_OutputStream, value:PT_Bool):Void {
        output.writeByte(value ? 1 : 0);
    }
    public static function write__TYPE_STRING(output:PT_OutputStream, value:PT_String):Void {
        var i:PT_UInt = output.beginBlock();
        if(value != null){//TODO check
            output.writeUTFBytes(value);
        }
        output.endBlock(i);
    }
    public static function write__TYPE_BYTES(output:PT_OutputStream, value:PT_Bytes):Void {
        if(value!=null){
            write__TYPE_UINT32(output, value.length);
            output.writeBytes(value);
        }else{
            write__TYPE_UINT32(output, 0);
        }
    }
    public static function write__TYPE_UINT32(output:PT_OutputStream, value:PT_UInt):Void {
        while (true) {
            if ((value & (0xffffffff << 7)) == 0) {
                output.writeByte(value);
                return;
            } else {
                output.writeByte((value & 0x7F) | 0x80);
                value >>>= 7;
            }
        }
    }
    public static function write__TYPE_ENUM(output:PT_OutputStream, value:PT_Int):Void {
        write__TYPE_INT32(output, value);
    }
    public static function write__TYPE_SFIXED32(output:PT_OutputStream, value:PT_Int):Void {
        output.writeInt32(value);
    }
    public static function write__TYPE_SFIXED64(output:PT_OutputStream, value:PT_Int64):Void {
        output.writeInt32(Protohx.getLow(value));
        output.writeInt32(Protohx.getHigh(value));
    }
    public static function write__TYPE_SINT32(output:PT_OutputStream, value:PT_Int):Void {
        write__TYPE_UINT32(output, ZigZag.encode32(value));
    }
    public static function write__TYPE_SINT64(output:PT_OutputStream, value:PT_Int64):Void {
        writeVarint64(output,
                ZigZag.encode64low(Protohx.getLow(value), Protohx.getHigh(value)),
                ZigZag.encode64high(Protohx.getLow(value), Protohx.getHigh(value)));
    }
    public static function write__TYPE_MESSAGE(output:PT_OutputStream, value:Message):Void {
        var i:PT_UInt = output.beginBlock();
        value.writeToBuffer(output);
        output.endBlock(i);
    }
    public static function writePackedRepeated<T>(output:PT_OutputStream, writeFunction:PT_WriteFunction<T>, value:Array<T>):Void {
        var i:PT_UInt = output.beginBlock();
        for (j in 0...value.length) {
            Reflect.callMethod(null, writeFunction, [output, value[j]]);
        }
        output.endBlock(i);
    }
}

