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
