// vim: tabstop=4 shiftwidth=4

// Copyright (c) 2010 , NetEase.com,Inc. All rights reserved.
// Copyright (c) 2012 , Yang Bo. All rights reserved.
//
// Author: Yang Bo (pop.atry@gmail.com)
//
// Use, modification and distribution are subject to the New BSD License
// as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.

package protohx;


import haxe.io.Output;
import haxe.io.Bytes;
import protohx.Protohx;

class Message {
    private var otherFields:IntMap<Dynamic>;

    public function new():Void {

    }
    /**
     * Parse data as a message of this type and merge it with this.
     *
     * @param input The source where data are reading from. <p>After calling
     * this method, <code>input.endian</code> will be changed to <code>
     * flash.utils.Endian.LITTLE_ENDIAN</code>. If <code>input</code> is a
     * <code>flash.utils.PT_Bytes</code>, input.position will increase by
     * number of bytes being read.</p>
     */
    public function mergeFrom(input:Bytes):Void {
        readFromSlice(ReadingBuffer.fromBytes(input), 0);
    }
    /**
     * Like <code>mergeFrom()</code>, but does not read until EOF. Instead,
     * the size of the message (encoded as a varint) is read first, then
     * the message data. Use <code>writeDelimitedTo()</code> to write
     * messages in this format.
     *
     * @param input The source where data are reading from. <p>After calling
     * this method, <code>input.endian</code> will be changed to <code>
     * flash.utils.Endian.LITTLE_ENDIAN</code>. If <code>input</code> is a
     * <code>flash.utils.ByteArray</code>, input.position will increase by
     * number of bytes being read.</p>
     *
     * @see #mergeFrom()
     * @see #writeDelimitedTo()
     */
    public function mergeDelimitedFrom(input:Bytes):Void {
        ReadUtils.read__TYPE_MESSAGE(ReadingBuffer.fromBytes(input), this);
    }
    /**
     * Serializes the message and writes it to <code>output</code>.
     *
     * <p>
     * NOTE: Protocol Buffers are not self-delimiting. Therefore, if you
     * write any more data to the stream after the message, you must
     * somehow ensure that the parser on the receiving end does not
     * interpret this as being * part of the protocol message. This can be
     * done e.g. by writing the size of the message before the data, then
     * making sure to limit the input to that size on the receiving end
     * (e.g. by wrapping the InputStream in one which limits the input).
     * Alternatively, just use <code>writeDelimitedTo()</code>.
     * </p>
     *
     * @param output The destination where data are writing to. <p>If <code>
     * output</code> is a <code>flash.utils.ByteArray</code>, <code>
     * output.position</code> will increase by number of bytes being
     * written.</p>
     *
     * @see #writeDelimitedTo()
     */
    public function writeTo(output:Output):Void {
        var buffer:PT_OutputStream = new PT_OutputStream();
        writeToBuffer(buffer);
        buffer.toNormal(output);
    }

    /**
     * Like <code>writeTo()</code>, but writes the size of the message as
     * a varint before writing the data. This allows more data to be
     * written to the stream after the message without the need to delimit
     * the message data yourself. Use <code>mergeDelimitedFrom()</code> to
     * parse messages written by this method.
     *
     * @param output The destination where data are writing to. <p>If <code>
     * output</code> is a <code>flash.utils.ByteArray</code>, <code>
     * output.position</code> will increase by number of bytes being
     * written.</p>
     *
     * @see #writeTo()
     * @see #mergeDelimitedFrom()
     */
    public function writeDelimitedTo(output:Output):Void {
        var buffer:PT_OutputStream = new PT_OutputStream();
        WriteUtils.write__TYPE_MESSAGE(buffer, this);
        buffer.toNormal(output);
    }

    /**
     * @private
     */
    public function readFromSlice(input:PT_InputStream, bytesAfterSlice:PT_UInt):Void {
        while (hasBytes(input, bytesAfterSlice)) {
            var tag:PT_UInt = protohx.ReadUtils.read__TYPE_UINT32(input);
            readUnknown(input, tag);
        }
//        throw new PT_IllegalOperationError("Not implemented!");
    }

    public inline function hasBytes(input:PT_InputStream, bytesAfterSlice:PT_UInt):Bool {
        return input.bytesAvailable > cast bytesAfterSlice;
    }
    /**
    * @private
    */
    public function writeToBuffer(output:PT_OutputStream):Void {
        writeExtensionOrUnknownFields(output);
//        throw new PT_IllegalOperationError("Not implemented!");
    }

    private function writeSingleUnknown(output:PT_OutputStream, tag:PT_UInt,  value:Dynamic):Void {
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

    /**
     * @private
     */
    function writeUnknown(output:PT_OutputStream,
                          tag:PT_UInt):Void {
        if (tag == 0) {
            throw new PT_ArgumentError(
                    "Attemp to write an undefined string filed: " +
                    tag);
        }
        WriteUtils.writeUnknownPair(output, tag, getByTag(tag));
    }

    /**
     * @private
     */
    function readUnknown(input:PT_InputStream, tag:PT_UInt):Void {
        var value:Dynamic;
        switch (tag & 7) {
        case WireType.VARINT:
            value = ReadUtils.read__TYPE_UINT64(input);
        case WireType.FIXED_64_BIT:
            value = ReadUtils.read__TYPE_FIXED64(input);
        case WireType.LENGTH_DELIMITED:
            value = ReadUtils.read__TYPE_BYTES(input);
        case WireType.FIXED_32_BIT:
            value = ReadUtils.read__TYPE_FIXED32(input);
        default:
            throw new PT_IOError("Invalid wire type: " + (tag & 7));
        }
        var currentValue:Dynamic = this.getByTag(tag);
        if (currentValue == null) {
            this.setByTag(tag, value);
        } else if (Std.is(currentValue, Array)) {
            currentValue.push(value);
        } else {
            this.setByTag(tag, [currentValue, value]);
        }
    }

    public function getByTag(tag:PT_UInt):Dynamic {
        return otherFields != null ? otherFields.get(tag) : null;
    }

    public function setByTag(tag:PT_UInt, value:Dynamic):Void {
        if(otherFields == null){
            otherFields = new IntMap<Dynamic>();
        }
        otherFields.set(tag, value);
    }

//    public function toString():String {
//        throw new PT_IllegalOperationError("");
//        return null;
////        return TextFormat.printToString(this);
//    }
/**
     * @private
     */
    public function defaultBytes():PT_Bytes {
        return null;
    }
    public function defaultInt64():PT_Int64 {
        return Protohx.newInt64(0, 0);
    }
    public function defaultUInt64():PT_UInt64 {
        return Protohx.newUInt64(0, 0);
    }

    public static function stringToByteArray(s:String):PT_Bytes {
        return Bytes.ofString(s);
    }

    function writeExtensionOrUnknownFields(output:PT_OutputStream):Void {
        if(otherFields != null){
            for(tag in otherFields.keys()){
                writeUnknown(output, tag);
            }
        }
    }

    public function forEachFields(fn:String->Dynamic->Void):Void{}
}
