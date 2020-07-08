const std = @import("std");
const builtin = std.builtin;

pub fn dsb() void {
    if (!builtin.is_test) {
        asm volatile ("dsb 0xf"
            :
            :
            : "memory"
        );
    }
}

pub fn isb() void {
    if (!builtin.is_test) {
        asm volatile ("isb 0xf"
            :
            :
            : "memory"
        );
    }
}

pub fn dmb() void {
    if (!builtin.is_test) {
        asm volatile ("dmb 0xf"
            :
            :
            : "memory"
        );
    }
}

pub fn nop() void {
    if (!builtin.is_test) {
        asm volatile ("nop"
            :
            :
            : "memory"
        );
    }
}

pub fn wfi() void {
    if (!builtin.is_test) {
        asm volatile ("wfi"
            :
            :
            : "memory"
        );
    }
}

pub fn wfe() void {
    if (!builtin.is_test) {
        asm volatile ("wfe"
            :
            :
            : "memory"
        );
    }
}

pub fn sev() void {
    if (!builtin.is_test) {
        asm volatile ("sev"
            :
            :
            : "memory"
        );
    }
}

pub fn __get_APSR() usize {
    var result: u32 = 0;
    if (!builtin.is_test) {
        result = asm volatile ("MRS %[result], apsr"
            : [result] "=r" (-> usize)
        );
    }
    return result;
}

pub fn __get_xPSR() usize {
    var result: u32 = 0;
    if (!builtin.is_test) {
        result = asm volatile ("MRS %[result], xpsr"
            : [result] "=r" (-> usize)
        );
    }
    return result;
}

pub fn bitmask(comptime T: type, bits: u8) T {
    switch (T) {
        comptime_int => {
            var accum: comptime_int = 0;
            var count = bits;
            while (count > 0) {
                accum <<= 1;
                accum |= 1;
                count -= 1;
            }
            return accum;
        },
        else => {
            return std.math.maxInt(T) >> (std.meta.bitCount(T) - bits);
        },
    }
}
