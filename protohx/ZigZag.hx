// vim: tabstop=4 shiftwidth=4

// Copyright (c) 2010 , NetEase.com,Inc. All rights reserved.
//
// Author: Yang Bo (pop.atry@gmail.com)
//
// Use, modification and distribution are subject to the "New BSD License"
// as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.

package protohx;
/**
 * @private
 */
import protohx.Protohx;

class ZigZag {
    public static function encode32(n:PT_Int):PT_Int {
        return (n << 1) ^ (n >> 31);
    }
    public static function decode32(n:PT_Int):PT_Int {
        return (n >>> 1) ^ -(n & 1);
    }
    public static function encode64low(low:PT_Int, high:PT_Int):PT_Int {
        return (low << 1) ^ (high >> 31);
    }
    public static function encode64high(low:PT_Int, high:PT_Int):PT_Int {
        return (low >>> 31) ^ (high << 1) ^ (high >> 31);
    }
    public static function decode64low(low:PT_Int, high:PT_Int):PT_Int {
        return (high << 31) ^ (low >>> 1) ^ -(low & 1);
    }
    public static function decode64high(low:PT_Int, high:PT_Int):PT_Int {
        return (high >>> 1) ^ -(low & 1);
    }
}

