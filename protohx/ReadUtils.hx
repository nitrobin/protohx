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
import haxe.Int64;
using haxe.Int64;

class ReadUtils {
    public static function skip(input:PT_InputStream, wireType:PT_UInt):Void {
        switch (wireType) {
        case WireType.VARINT:
            while (input.readUnsignedByte() >= 0x80) {}
        case WireType.FIXED_64_BIT:
            input.readInt32();
            input.readInt32();
        case WireType.LENGTH_DELIMITED:
            var i:PT_UInt = read__TYPE_UINT32(input);
            while (i != 0) {
                input.readUnsignedByte();
                i--;
            }
        case WireType.FIXED_32_BIT:
            input.readInt32();
        default:
            throw new PT_IOError("Invalid wire type: " + wireType);
        }
    }
    public static function read__TYPE_DOUBLE(input:PT_InputStream):PT_Double {
        return input.readDouble();
    }
    public static function read__TYPE_FLOAT(input:PT_InputStream):PT_Float {
        return input.readFloat();
    }
    public static function read__TYPE_INT64(input:PT_InputStream):PT_Int64 {
        var low:PT_Int = 0;
        var high:PT_Int = 0;
        var b:PT_Int = 0;
        var i:PT_Int = 0;
        while ( true) {
            b = input.readUnsignedByte();
            if (i == 28) {
                break;
            } else {
                if (b >= 0x80) {
                    low |= ((b & 0x7f) << i);
                } else {
                    low |= (b << i);
                    return Protohx.newInt64(high, low);
                }
            }
            i += 7;
        }
        if (b >= 0x80) {
            b &= 0x7f;
            low |= (b << i);
            high = b >>> 4;
        } else {
            low |= (b << i);
            high = b >>> 4;
            return Protohx.newInt64(high, low);
        }
        i = 3;
        while ( true ) {
            b = input.readUnsignedByte();
            if (i < 32) {
                if (b >= 0x80) {
                    high |= ((b & 0x7f) << i);
                } else {
                    high |= (b << i);
                    break;
                }
            }
            i += 7;
        }
        return Protohx.newInt64(high, low);
    }
    public static function read__TYPE_UINT64(input:PT_InputStream):PT_UInt64 {
        var tmp = read__TYPE_INT64(input);
        return Protohx.newUInt64(Protohx.getHigh(tmp), Protohx.getLow(tmp));
    }
    public static function read__TYPE_INT32(input:PT_InputStream):PT_Int {
        return cast read__TYPE_UINT32(input) ;
    }
    public static function read__TYPE_FIXED64(input:PT_InputStream):PT_UInt64 {
        var low = input.readInt32();
        var high = input.readInt32();
        return Protohx.newUInt64(high, low);
    }
    public static function read__TYPE_FIXED32(input:PT_InputStream):PT_UInt {
        return cast(input.readInt32(), PT_UInt);
    }
    public static function read__TYPE_BOOL(input:PT_InputStream):PT_Bool {
        return read__TYPE_UINT32(input) != 0;
    }
    public static function read__TYPE_STRING(input:PT_InputStream):PT_String {
        var length:PT_UInt = read__TYPE_UINT32(input);
        return cast input.readUTFBytes(length);
    }
    public static function read__TYPE_BYTES(input:PT_InputStream):PT_Bytes {
        var result:PT_Bytes = null;
        var length:PT_UInt = read__TYPE_UINT32(input);
        if (length > 0) {
            result = input.readBytes(length);
        }
        return result;
    }
    public static function read__TYPE_UINT32(input:PT_InputStream):PT_UInt {
        var result:PT_Int = 0;
        var i:PT_UInt = 0;
        while ( true ) {
            var b:PT_Int = input.readUnsignedByte();
            if (i < 32) {
                if (b >= 0x80) {
                    result |= ((b & 0x7f) << i);
                } else {
                    result |= (b << i);
                    break;
                }
            } else {
                while (input.readUnsignedByte() >= 0x80) {}
                break;
            }
            i += 7;
        }
        return result;
    }
    public static function read__TYPE_ENUM(input:PT_InputStream):PT_Int {
        return read__TYPE_INT32(input);
    }
    public static function read__TYPE_SFIXED32(input:PT_InputStream):PT_Int {
        return input.readInt32();
    }
    public static function read__TYPE_SFIXED64(input:PT_InputStream):PT_Int64 {
        var low = input.readInt32();
        var high = input.readInt32();
        return Protohx.newInt64(high, low);
    }
    public static function read__TYPE_SINT32(input:PT_InputStream):PT_Int {
        return ZigZag.decode32(read__TYPE_UINT32(input));
    }
    public static function read__TYPE_SINT64(input:PT_InputStream):PT_Int64 {
        var result:PT_Int64 = read__TYPE_INT64(input);
        var low:PT_Int = Protohx.getLow(result);
        var high:PT_Int = Protohx.getHigh(result);
        var lowNew = ZigZag.decode64low(low, high);
        var highNew = ZigZag.decode64high(low, high);
        return Protohx.newInt64(highNew, lowNew);
    }
    //TODO check types
    public static function read__TYPE_MESSAGE<T:Message>(input:PT_InputStream, message:T):T {
        var length:PT_UInt = read__TYPE_UINT32(input);
        if (input.bytesAvailable < cast length) {
            throw new PT_IOError("Invalid message length: " + length);
        }
        var bytesAfterSlice:PT_UInt = input.bytesAvailable - length;
        message.readFromSlice(input, bytesAfterSlice);
        if (input.bytesAvailable != cast bytesAfterSlice) {
            throw new PT_IOError("Invalid nested message");
        }
        return message;
    }
    public static function readPackedRepeated<T>(input:PT_InputStream, readFuntion:PT_ReadFunction<T>, value:Array<T>):Void {
        var length:PT_UInt = read__TYPE_UINT32(input);
        if (input.bytesAvailable < cast length) {
            throw new PT_IOError("Invalid message length: " + length);
        }
        var bytesAfterSlice:PT_UInt = input.bytesAvailable - length;
        while (input.bytesAvailable > cast bytesAfterSlice) {
            value.push(readFuntion(input));
        }
        if (input.bytesAvailable != cast bytesAfterSlice) {
            throw new PT_IOError("Invalid packed repeated data");
        }
    }
}

