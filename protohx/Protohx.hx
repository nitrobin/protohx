package protohx;


typedef PT_Int = Int;
#if flash
typedef PT_UInt = UInt;
#else
typedef PT_UInt = Int;
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

#if haxe3
typedef IntMap<T> = haxe.ds.IntMap<T>;
#else
typedef IntMap<T> = IntHash<T>;
#end

class Protohx {

#if haxe3

    public static inline function getLow(i:haxe.Int64):PT_Int {
        return  cast(haxe.Int64.getLow(i), PT_Int);
    }

    public static inline function getHigh(i:haxe.Int64):PT_Int {
        return  cast(haxe.Int64.getHigh(i), PT_Int);
    }

    public static function newInt64(h:PT_Int, l:PT_Int):PT_Int64 {
        // workaround bug https://code.google.com/p/haxe/issues/detail?id=1674
        #if java
        var hh = haxe.Int64.make(h, 0);
        var ll = haxe.Int64.make(l, 0);
        return cast haxe.Int64.or(hh, haxe.Int64.ushr(ll, 32));
        #else
        return PT_Int64.make(h, l);
        #end
    }

    public static function newUInt64(h:PT_Int, l:PT_Int):PT_UInt64 {
        // workaround bug https://code.google.com/p/haxe/issues/detail?id=1674
        #if java
        var hh = haxe.Int64.make(h, 0);
        var ll = haxe.Int64.make(l, 0);
        return cast haxe.Int64.or(hh, haxe.Int64.ushr(ll, 32));
        #else
        return PT_UInt64.make(h, l);
        #end
    }

#else

    public static inline function getLow(i:haxe.Int64):PT_Int {
        return  cast(haxe.Int32.toInt(haxe.Int64.getLow(i)), PT_Int);
    }

    public static inline function getHigh(i:haxe.Int64):PT_Int {
        return  cast(haxe.Int32.toInt(haxe.Int64.getHigh(i)), PT_Int);
    }

    public static function newInt64(h:PT_Int, l:PT_Int):PT_Int64 {
        return PT_Int64.make(haxe.Int32.ofInt(h), haxe.Int32.ofInt(l));
    }

    public static function newUInt64(h:PT_Int, l:PT_Int):PT_UInt64 {
        return PT_UInt64.make(haxe.Int32.ofInt(h), haxe.Int32.ofInt(l));
    }

#end

    public static function setOutputEndian(out:haxe.io.Output):Void {
        out.bigEndian = false;
    }

    public static function setInputEndian(out:haxe.io.Input):Void {
        out.bigEndian = false;
    }
}





