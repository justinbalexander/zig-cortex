const std = @import("std");
pub const config = @import("config.zig");
const assert = std.debug.assert;
const builtin = std.builtin;
pub usingnamespace @import("common.zig");
const v7m = @import("v7m.zig");

pub const SCB = struct {
    /// ARM DUI 0646C Table 4-17
    const SCB_AIRCR_PRIGROUP_Pos: u32 = 8;
    const SCB_AIRCR_PRIGROUP_Mask: u32 = 0x7 << SCB_AIRCR_PRIGROUP_Pos;
    const SCB_AIRCR_VECTKEYSTAT_Pos: u32 = 16;
    const SCB_AIRCR_VECTKEYSTAT_Mask: u32 = 0xffff << SCB_AIRCR_VECTKEYSTAT_Pos;
    const SCB_AIRCR_VECTKEY: u32 = 0x5FA << SCB_AIRCR_VECTKEYSTAT_Pos;
    const SCB_AIRCR_SYSRESETREQ_Pos: u32 = 2;
    const SCB_AIRCR_SYSRESETREQ_Mask: u32 = 0x1 << SCB_AIRCR_SYSRESETREQ_Pos;
    const SCB_CCR_IC_Mask: u32 = 1 << 17;

    pub const PriorityBitsGrouping = enum(u3) {
        GroupPriorityBits_7,
        GroupPriorityBits_6,
        GroupPriorityBits_5,
        GroupPriorityBits_4,
        GroupPriorityBits_3,
        GroupPriorityBits_2,
        GroupPriorityBits_1,
        GroupPriorityBits_0,

        pub fn set(priority_group: PriorityBitsGrouping) void {
            const iarcr = v7m.SCB.AIRCR & ~@as(u32, SCB_AIRCR_VECTKEYSTAT_Mask | SCB_AIRCR_PRIGROUP_Mask);
            v7m.SCB.AIRCR = iarcr |
                SCB_AIRCR_VECTKEY |
                @as(u32, @enumToInt(priority_group)) << SCB_AIRCR_PRIGROUP_Pos;
        }

        pub fn get() PriGroup {
            return @intToEnum(@truncate(@TagType(PriorityBitsGrouping), v7m.SCB.AIRCR >> SCB_AIRCR_PRIGROUP_Pos));
        }
    };

    pub const Exceptions = enum(u4) {
        MemManageHandler = 4,
        BusHandler = 5,
        UsageFaultHandler = 6,
        SystemHandler7 = 7,
        SystemHandler8 = 8,
        SystemHandler9 = 9,
        SystemHandler10 = 10,
        SVCallHandler = 11,
        DebugMonitorHandler = 12,
        SystemHandler13 = 13,
        PendSVHandler = 14,
        SysTickHandler = 15,

        const Self = @This();

        pub fn setPriority(exception: Self, priority: u8) void {
            const prio_shift = 8 - config.nvic_priority_bits;
            const exception_number = @enumToInt(exception);

            SCB.SHPR[exception_number - 4] = priority << prio_shift;
        }

        pub fn getPriority(exception: Self, priority: u8) u8 {
            const prio_shift = 8 - config.nvic_priority_bits;
            const exception_number = @enumToInt(exception);

            return SCB.SHPR[exception_number - 4] >> prio_shift;
        }
    };

    pub const ICache = struct {
        pub fn invalidate() void {
            dsb();
            isb();
            CACHE_MAINTENANCE.ICIALLU = 0;
            dsb();
            isb();
        }

        pub fn enable() void {
            invalidate();
            SCB.CCR |= SCB_CCR_IC_Mask;
            dsb();
            isb();
        }

        pub fn disable() void {
            dsb();
            isb();
            SCB.CCR &= ~(SCB_CCR_IC_Mask);
            CACHE_MAINTENANCE.ICIALLU = 0;
            dsb();
            isb();
        }
    };

    pub const DCache = struct {
        const Associativity = struct {
            sets: u32,
            ways: u32,
        };

        fn getAssociativity() Associativity {
            const SCB_CCSIDR_NUMSETS_Pos = (13);
            const SCB_CCSIDR_NUMSETS_Mask = (0x7FFF << SCB_CCSIDR_NUMSETS_Pos);
            const SCB_CCSIDR_ASSOCIATIVITY_Pos = (3);
            const SCB_CCSIDR_ASSOCIATIVITY_Mask = (0x3FF << SCB_CCSIDR_ASSOCIATIVITY_Pos);

            const ccsidr = SCB.CCSIDR;

            return .{
                .sets = (ccsidr & SCB_CCSIDR_NUMSETS_Mask) >> SCB_CCSIDR_NUMSETS_Pos,
                .ways = (ccsidr & SCB_CCSIDR_ASSOCIATIVITY_Mask) >> SCB_CCSIDR_ASSOCIATIVITY_Pos,
            };
        }

        fn invalidateSetsAndWays() void {
            const SCB_DCISW_WAY_Pos = (30);
            const SCB_DCISW_WAY_Mask = (3 << SCB_DCISW_WAY_Pos);
            const SCB_DCISW_SET_Pos = (5);
            const SCB_DCISW_SET_Mask = (0x1FF << SCB_DCISW_SET_Pos);

            var assoc = getAssociativity();
            while (true) {
                var ways_inner = assoc.ways;
                while (true) {
                    CACHE_MAINTENANCE.DCISW = ((assoc.sets << SCB_DCISW_SET_Pos) & SCB_DCISW_SET_Mask) |
                        ((ways_inner << SCB_DCISW_WAY_Pos) & SCB_DCISW_WAY_Mask);
                    if (ways_inner == 0) break;
                    ways_inner -= 1;
                }
                if (assoc.sets == 0) break;
                assoc.sets -= 1;
            }
        }

        fn cleanSetsAndWays() void {
            const SCB_DCCSW_WAY_Pos = (30);
            const SCB_DCCSW_WAY_Mask = (3 << SCB_DCCSW_WAY_Pos);
            const SCB_DCCSW_SET_Pos = (5);
            const SCB_DCCSW_SET_Mask = (0x1FF << SCB_DCCSW_SET_Pos);

            var assoc = getAssociativity();
            while (true) {
                var ways_inner = assoc.ways;
                while (true) {
                    CACHE_MAINTENANCE.DCCSW = ((assoc.sets << SCB_DCCSW_SET_Pos) & SCB_DCCSW_SET_Mask) |
                        ((ways_inner << SCB_DCCSW_WAY_Pos) & SCB_DCCSW_WAY_Mask);
                    if (ways_inner == 0) break;
                    ways_inner -= 1;
                }
                if (assoc.sets == 0) break;
                assoc.sets -= 1;
            }
        }

        pub fn invalidate() void {
            SCB.CSSELR = 0;
            dsb();
            invalidateSetsAndWays();
            dsb();
            isb();
        }

        pub fn enable() void {
            const SCB_CCR_DC_Pos = 16;
            const SCB_CCR_DC_Mask = (1 << SCB_CCR_DC_Pos);
            SCB.CSSELR = 0;
            dsb();
            invalidateSetsAndWays();
            dsb();
            SCB.CCR |= SCB_CCR_DC_Mask;
            dsb();
            isb();
        }

        pub fn disable() void {
            const SCB_CCR_DC_Pos = 16;
            const SCB_CCR_DC_Mask: u32 = (1 << SCB_CCR_DC_Pos);
            SCB.CSSELR = 0;
            dsb();
            SCB.CCR &= ~SCB_CCR_DC_Mask;
            dsb();
            invalidateSetsAndWays();
            dsb();
            isb();
        }

        pub fn clean() void {
            SCB.CSSELR = 0;
            dsb();
            cleanSetsAndWays();
            dsb();
            isb();
        }

        pub fn invalidateByAddress(addr: *allowzero u32, len: i32) void {
            const line_size = 32;
            var data_size = len;
            var data_addr = @ptrToInt(addr);
            dsb();
            while (data_size > 0) {
                CACHE_MAINTENANCE.DCIMVAC = data_addr;
                data_addr +%= line_size;
                data_size -= line_size;
            }
            dsb();
            isb();
        }

        pub fn cleanByAddress(addr: *allowzero u32, len: i32) void {
            const line_size = 32;
            var data_size = len;
            var data_addr = @ptrToInt(addr);
            dsb();
            while (data_size > 0) {
                CACHE_MAINTENANCE.DCCMVAC = data_addr;
                data_addr +%= line_size;
                data_size -= line_size;
            }
            dsb();
            isb();
        }

        pub fn cleanInvalidateByAddress(addr: *allowzero u32, len: i32) void {
            invalidateByAddress(addr, len);
        }
    };

    pub fn systemReset() noreturn {
        dsb();
        v7m.SCB.AIRCR = SCB_AIRCR_VECTKEY |
            (v7m.SCB.AIRCR & SCB_AIRCR_PRIGROUP_Mask) |
            SCB_AIRCR_SYSRESETREQ_Mask;
        dsb();
        while (true) {}
    }
};

test "Semantic Analyze ConfigurablePriorityExceptions" {
    std.meta.refAllDecls(SCB);
}

pub const NVIC = struct {
    // TODO: arch ref manual says irq_number can go up to 495
    pub fn enableIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        v7m.NVIC.ISER[irq_number >> 5] = irq_bit;
    }

    pub fn getEnableIrq(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((v7m.NVIC.ISER[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn disableIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        v7m.NVIC.ICER[irq_number >> 5] = irq_bit;
        dsb();
        isb();
    }

    pub fn getPendingIrq(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((v7m.NVIC.ISPR[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn setPendingIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        v7m.NVIC.ISPR[irq_number >> 5] = irq_bit;
    }

    pub fn clearPendingIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        v7m.NVIC.ICPR[irq_number >> 5] = irq_bit;
    }

    pub fn getActive(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((v7m.NVIC.IABR[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn setIrqPriority(irq_number: u8, priority: u8) void {
        const prio_shift = 8 - config.nvic_priority_bits;
        if (irq_number >= v7m.NVIC.IPR.len) return;

        v7m.NVIC.IPR[irq_number] = priority << prio_shift;
    }

    pub fn getIrqPriority(irq_number: u8, priority: u8) u8 {
        const prio_shift = 8 - config.nvic_priority_bits;
        assert(irq_number >= v7m.NVIC.IPR.len);

        return (v7m.NVIC.IPR[irq_number] >> prio_shift);
    }
};

test "NVIC Semantic Analysis" {
    std.meta.refAllDecls(NVIC);
}

pub const SysTick = struct {
    pub const CSR_COUNTFLAG_Pos = 16;
    pub const CSR_COUNTFLAG_Mask = 1 << CSR_COUNTFLAG_Pos;
    pub const CSR_CLKSOURCE_Pos = 2;
    pub const CSR_CLKSOURCE_Mask = 1 << CSR_CLKSOURCE_Pos;
    pub const CSR_TICKINT_Pos = 1;
    pub const CSR_TICKINT_Mask = 1 << CSR_TICKINT_Pos;
    pub const CSR_ENABLE_Mask = 1;
    pub const LOAD_RELOAD_Mask = 0xFFFFFF;
    pub const VAL_CURRENT_Mask = 0xFFFFFF;
    pub const CALIB_NOREF_Pos = 31;
    pub const CALIB_NOREF_Mask = 1 << CALIB_NOREF_Pos;
    pub const CALIB_SKEW_Pos = 30;
    pub const CALIB_SKEW_Mask = 1 << CALIB_SKEW_Pos;
    pub const CALIB_TENMS_Mask = 0xFFFFFF;

    pub const ClockSource = enum(u1) {
        External,
        Processor,
    };

    pub fn config(comptime clock: ClockSource, comptime interrupt: bool, comptime enable: bool, reload_value: u24) void {
        v7m.SYSTICK.RVR = reload_value;
        SCB.Exceptions.SysTickHandler.setPriority((1 << config.nvic_priority_bits) - 1);
        SYSTICK.CVR = 0;
        const clock_setting = if (clock == .Processor) CTRL_CLKSOURCE_Mask else 0;
        const interrupt_setting = if (interrupt) CTRL_TICKINT_Mask else 0;
        const enable_setting = if (enable) CTRL_ENABLE_Mask else 0;
        SYSTICK.CSR = clock_setting | interrupt_setting | enable_setting;
    }

    pub fn getTenMsCalibratedTicks() u24 {
        return @truncate(u24, v7m.SYSTICK.CALIB);
    }
};

test "SysTick Semantic Analysis" {
    std.meta.refAllDecls(SysTick);
}

pub fn __get_APSR() usize {
    var result = 0;
    if (!builtin.is_test) {
        result = asm volatile ("MRS %[result], apsr"
            : [result] "=r" (-> usize)
        );
    }
    return result;
}

pub fn __get_xPSR() usize {
    var result = 0;
    if (!builtin.is_test) {
        result = asm volatile ("MRS %[result], xpsr"
            : [result] "=r" (-> usize)
        );
    }
    return result;
}
