package protohx;


typedef PT_Int = Int;

#if (as3||cs)
typedef PT_UInt = Int;
#else
typedef PT_UInt = UInt;
#end

typedef PT_Int64 = haxe.Int64;
typedef PT_UInt64 = haxe.Int64;

typedef PT_String = String;

typedef PT_Double = Float;
typedef PT_Float = Float;
typedef PT_Bool = Bool;

typedef PT_Bytes = haxe.io.Bytes;
typedef PT_IDataInput = haxe.io.Input;
typedef PT_IDataOutput = haxe.io.Output;

typedef PT_OutputStream = protohx.WritingBuffer;
typedef PT_InputStream = protohx.ReadingBuffer;

typedef PT_ReadFunction<T> = PT_InputStream -> T;
typedef PT_WriteFunction<T> = PT_OutputStream -> T -> Void;

typedef PT_IOError = protohx.CommonError;
typedef PT_ArgumentError = protohx.CommonError;
typedef PT_IllegalOperationError = protohx.CommonError;

typedef IntMap<T> = haxe.ds.IntMap<T>;

class Protohx {

    public static inline function getLow(i:haxe.Int64):PT_Int {
        return  cast(haxe.Int64.getLow(i), PT_Int);
    }

    public static inline function getHigh(i:haxe.Int64):PT_Int {
        return  cast(haxe.Int64.getHigh(i), PT_Int);
    }

    public static inline function newInt64(h:PT_Int, l:PT_Int):PT_Int64 {
        return PT_Int64.make(h, l);
    }

    public static inline function newUInt64(h:PT_Int, l:PT_Int):PT_UInt64 {
        return PT_UInt64.make(h, l);
    }

    public static inline function setOutputEndian(out:haxe.io.Output):Void {
        out.bigEndian = false;
    }

    public static inline function setInputEndian(out:haxe.io.Input):Void {
        out.bigEndian = false;
    }
}





