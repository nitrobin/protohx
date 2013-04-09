// vim: tabstop=4 shiftwidth=4

// Copyright (c) 2010 , NetEase.com,Inc. All rights reserved.
//
// Author: Yang Bo (pop.atry@gmail.com)
//
// Use, modification and distribution are subject to the "New BSD License"
// as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.

package protohx;
import protohx.Protohx;
class WireType {
    public static inline var VARINT:PT_UInt = 0;
    public static inline var FIXED_64_BIT:PT_UInt = 1;
    public static inline var LENGTH_DELIMITED:PT_UInt = 2;
    public static inline var FIXED_32_BIT:PT_UInt = 5;
}

