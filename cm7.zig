const std = @import("std");
const config = @import("config.zig");
const assert = std.debug.assert;
const builtin = std.builtin;

const SCS_BASE = 0xE000E000;
const ITM_BASE = 0xE0000000;
const DWT_BASE = 0xE0001000;
const TPI_BASE = 0xE0040000;
const FPU_BASE = 0xE000EF34;
const CoreDebug_BASE = 0xE000EDF0;
const SysTick_BASE = SCS_BASE + 0x0010;
const NVIC_BASE = SCS_BASE + 0x0100;
const SCB_BASE = SCS_BASE + 0x0D00;
const MPU_BASE = SCS_BASE + 0x0D90;

const SCnSCB_Regs = @intToPtr(*align(4) volatile SCnSCB_Type, SCS_BASE);
const SCB_Regs = @intToPtr(*align(4) volatile SCB_Type, SCB_BASE);
const SysTick_Regs = @intToPtr(*align(4) volatile SysTick_Type, SysTick_BASE);
const NVIC_Regs = @intToPtr(*align(4) volatile NVIC_Type, NVIC_BASE);
const ITM_Regs = @intToPtr(*align(4) volatile ITM_Type, ITM_BASE);
const DWT_Regs = @intToPtr(*align(4) volatile DWT_Type, DWT_BASE);
const TPI_Regs = @intToPtr(*align(4) volatile TPI_Type, TPI_BASE);
const CoreDebug_Regs = @intToPtr(*align(4) volatile CoreDebug_Type, CoreDebug_BASE);
const MPU_Regs = @intToPtr(*align(4) volatile MPU_Type, MPU_BASE);
const FPU_Regs = @intToPtr(*align(4) volatile FPU_Type, FPU_BASE);

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
            const iarcr = SCB_Regs.AIRCR & ~@as(u32, SCB_AIRCR_VECTKEYSTAT_Mask | SCB_AIRCR_PRIGROUP_Mask);
            SCB_Regs.AIRCR = iarcr |
                SCB_AIRCR_VECTKEY |
                @as(u32, @enumToInt(priority_group)) << SCB_AIRCR_PRIGROUP_Pos;
        }

        pub fn get() PriGroup {
            return @intToEnum(@truncate(@TagType(PriorityBitsGrouping), SCB_Regs.AIRCR >> SCB_AIRCR_PRIGROUP_Pos));
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

            SCB_Regs.SHPR[exception_number - 4] = priority << prio_shift;
        }

        pub fn getPriority(exception: Self, priority: u8) u8 {
            const prio_shift = 8 - config.nvic_priority_bits;
            const exception_number = @enumToInt(exception);

            return SCB_Regs.SHPR[exception_number - 4] >> prio_shift;
        }
    };

    pub const ICache = struct {
        pub fn invalidate() void {
            __DSB();
            __ISB();
            SCB_Regs.ICIALLU = 0;
            __DSB();
            __ISB();
        }

        pub fn enable() void {
            invalidate();
            SCB_Regs.CCR |= SCB_CCR_IC_Mask;
            __DSB();
            __ISB();
        }

        pub fn disable() void {
            __DSB();
            __ISB();
            SCB_Regs.CCR &= ~(SCB_CCR_IC_Mask);
            SCB_Regs.ICIALLU = 0;
            __DSB();
            __ISB();
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

            const ccsidr = SCB_Regs.CCSIDR;

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
                    SCB_Regs.DCISW = ((assoc.sets << SCB_DCISW_SET_Pos) & SCB_DCISW_SET_Mask) |
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
                    SCB_Regs.DCCSW = ((assoc.sets << SCB_DCCSW_SET_Pos) & SCB_DCCSW_SET_Mask) |
                        ((ways_inner << SCB_DCCSW_WAY_Pos) & SCB_DCCSW_WAY_Mask);
                    if (ways_inner == 0) break;
                    ways_inner -= 1;
                }
                if (assoc.sets == 0) break;
                assoc.sets -= 1;
            }
        }

        pub fn invalidate() void {
            SCB_Regs.CSSELR = 0;
            __DSB();
            invalidateSetsAndWays();
            __DSB();
            __ISB();
        }

        pub fn enable() void {
            const SCB_CCR_DC_Pos = 16;
            const SCB_CCR_DC_Mask = (1 << SCB_CCR_DC_Pos);
            SCB_Regs.CSSELR = 0;
            __DSB();
            invalidateSetsAndWays();
            __DSB();
            SCB_Regs.CCR |= SCB_CCR_DC_Mask;
            __DSB();
            __ISB();
        }

        pub fn disable() void {
            const SCB_CCR_DC_Pos = 16;
            const SCB_CCR_DC_Mask: u32 = (1 << SCB_CCR_DC_Pos);
            SCB_Regs.CSSELR = 0;
            __DSB();
            SCB_Regs.CCR &= ~SCB_CCR_DC_Mask;
            __DSB();
            invalidateSetsAndWays();
            __DSB();
            __ISB();
        }

        pub fn clean() void {
            SCB_Regs.CSSELR = 0;
            __DSB();
            cleanSetsAndWays();
            __DSB();
            __ISB();
        }

        pub fn invalidateByAddress(addr: *allowzero u32, len: i32) void {
            const line_size = 32;
            var data_size = len;
            var data_addr = @ptrToInt(addr);
            __DSB();
            while (data_size > 0) {
                SCB_Regs.DCIMVAC = data_addr;
                data_addr +%= line_size;
                data_size -= line_size;
            }
            __DSB();
            __ISB();
        }

        pub fn cleanByAddress(addr: *allowzero u32, len: i32) void {
            const line_size = 32;
            var data_size = len;
            var data_addr = @ptrToInt(addr);
            __DSB();
            while (data_size > 0) {
                SCB_Regs.DCCMVAC = data_addr;
                data_addr +%= line_size;
                data_size -= line_size;
            }
            __DSB();
            __ISB();
        }

        pub fn cleanInvalidateByAddress(addr: *allowzero u32, len: i32) void {
            invalidateByAddress(addr, len);
        }
    };

    pub fn systemReset() noreturn {
        __DSB();
        SCB_Regs.AIRCR = SCB_AIRCR_VECTKEY |
            (SCB_Regs.AIRCR & SCB_AIRCR_PRIGROUP_Mask) |
            SCB_AIRCR_SYSRESETREQ_Mask;
        __DSB();
        while (true) {}
    }
};

test "Semantic Analyze ConfigurablePriorityExceptions" {
    std.meta.refAllDecls(SCB);
}

pub const NVIC = struct {
    pub fn enableIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC_Regs.ISER[irq_number >> 5] = irq_bit;
    }

    pub fn getEnableIrq(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((NVIC_Regs.ISER[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn disableIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC_Regs.ICER[irq_number >> 5] = irq_bit;
        __DSB();
        __ISB();
    }

    pub fn getPendingIrq(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((NVIC_Regs.ISPR[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn setPendingIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC_Regs.ISPR[irq_number >> 5] = irq_bit;
    }

    pub fn clearPendingIrq(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC_Regs.ICPR[irq_number >> 5] = irq_bit;
    }

    pub fn getActive(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((NVIC_Regs.IABR[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn setIrqPriority(irq_number: u8, priority: u8) void {
        const prio_shift = 8 - config.nvic_priority_bits;
        if (irq_number >= NVIC_Regs.IP.len) return;

        NVIC_Regs.IP[irq_number] = priority << prio_shift;
    }

    pub fn getIrqPriority(irq_number: u8, priority: u8) u8 {
        const prio_shift = 8 - config.nvic_priority_bits;
        assert(irq_number >= NVIC_Regs.IP.len);

        return (NVIC_Regs.IP[irq_number] >> prio_shift);
    }
};

test "NVIC Semantic Analysis" {
    std.meta.refAllDecls(NVIC);
}

pub const SysTick = struct {
    pub const CTRL_COUNTFLAG_Pos = 16;
    pub const CTRL_COUNTFLAG_Mask = 1 << CTRL_COUNTFLAG_Pos;
    pub const CTRL_CLKSOURCE_Pos = 2;
    pub const CTRL_CLKSOURCE_Mask = 1 << CTRL_CLKSOURCE_Pos;
    pub const CTRL_TICKINT_Pos = 1;
    pub const CTRL_TICKINT_Mask = 1 << CTRL_TICKINT_Pos;
    pub const CTRL_ENABLE_Mask = 1;
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
        SysTick_Regs.LOAD = reload_value;
        SCB.Exceptions.SysTickHandler.setPriority((1 << config.nvic_priority_bits) - 1);
        SysTick_Regs.VAL = 0;
        const clock_setting = if (clock == .Processor) CTRL_CLKSOURCE_Mask else 0;
        const interrupt_setting = if (interrupt) CTRL_TICKINT_Mask else 0;
        const enable_setting = if (enable) CTRL_ENABLE_Mask else 0;
        SysTick_Regs.CTRL = clock_setting | interrupt_setting | enable_setting;
    }

    pub fn getTenMsCalibratedTicks() u24 {
        return @truncate(u24, SysTick_Regs.CALIB);
    }
};

test "SysTick Semantic Analysis" {
    std.meta.refAllDecls(SysTick);
}

pub inline fn __DSB() void {
    asm volatile ("dsb"
        :
        :
        : "memory"
    );
}

pub inline fn __ISB() void {
    asm volatile ("isb"
        :
        :
        : "memory"
    );
}

pub inline fn __DMB() void {
    asm volatile ("dmb"
        :
        :
        : "memory"
    );
}

pub inline fn __NOP() void {
    asm volatile ("nop");
}

pub inline fn __WFI() void {
    asm volatile ("wfi");
}

pub inline fn __WFE() void {
    asm volatile ("wfe");
}

pub inline fn __SEV() void {
    asm volatile ("sev");
}

pub inline fn __get_APSR() usize {
    var result = asm volatile ("MRS %[result], apsr"
        : [result] "=r" (-> usize)
    );
    return result;
}

pub inline fn __get_xPSR() usize {
    var result = asm volatile ("MRS %[result], xpsr"
        : [result] "=r" (-> usize)
    );
    return result;
}

pub const SCB_Type = packed struct {
    CPUID: u32,
    ICSR: u32,
    VTOR: u32,
    AIRCR: u32,
    SCR: u32,
    CCR: u32,
    SHPR: [12]u8,
    SHCSR: u32,
    CFSR: u32,
    HFSR: u32,
    DFSR: u32,
    MMFAR: u32,
    BFAR: u32,
    AFSR: u32,
    ID_PFR: [2]u32,
    ID_DFR: u32,
    ID_AFR: u32,
    ID_MFR: [4]u32,
    ID_ISAR: [5]u32,
    padding0: [1]u32,
    CLIDR: u32,
    CTR: u32,
    CCSIDR: u32,
    CSSELR: u32,
    CPACR: u32,
    padding3: [93]u32,
    STIR: u32,
    padding4: [15]u32,
    MVFR0: u32,
    MVFR1: u32,
    MVFR2: u32,
    padding5: [1]u32,
    ICIALLU: u32,
    padding6: [1]u32,
    ICIMVAU: u32,
    DCIMVAC: u32,
    DCISW: u32,
    DCCMVAU: u32,
    DCCMVAC: u32,
    DCCSW: u32,
    DCCIMVAC: u32,
    DCCISW: u32,
    padding7: [6]u32,
    ITCMCR: u32,
    DTCMCR: u32,
    AHBPCR: u32,
    CACR: u32,
    AHBSCR: u32,
    padding8: [1]u32,
    ABFSR: u32,
};

pub const SCnSCB_Type = packed struct {
    padding0: [1]u32,
    ICTR: u32,
    ACTLR: u32,
};

pub const SysTick_Type = packed struct {
    CTRL: u32,
    LOAD: u32,
    VAL: u32,
    CALIB: u32,
};

pub const NVIC_Type = packed struct {
    ISER: [8]u32,
    padding0: [24]u32,
    ICER: [8]u32,
    RSERVED1: [24]u32,
    ISPR: [8]u32,
    padding2: [24]u32,
    ICPR: [8]u32,
    padding3: [24]u32,
    IABR: [8]u32,
    padding4: [56]u32,
    IP: [240]u8,
    padding5: [644]u32,
    STIR: u32,
};

const ITM_Stim_Port_Access_Type = packed union {
    asU8: u8,
    asU16: u16,
    asU32: u32,
};

pub const ITM_Type = packed struct {
    PORT: [32]ITM_Stim_Port_Access_Type,
    padding0: [864]u32,
    TER: u32,
    padding1: [15]u32,
    TPR: u32,
    padding2: [15]u32,
    TCR: u32,
    padding3: [29]u32,
    IWR: u32,
    IRR: u32,
    IMCR: u32,
    padding4: [43]u32,
    LAR: u32,
    LSR: u32,
    padding5: [6]u32,
    PID4: u32,
    PID5: u32,
    PID6: u32,
    PID7: u32,
    PID0: u32,
    PID1: u32,
    PID2: u32,
    PID3: u32,
    CID0: u32,
    CID1: u32,
    CID2: u32,
    CID3: u32,
};

pub const DWT_Type = packed struct {
    CTRL: u32,
    CYCCNT: u32,
    CPICNT: u32,
    EXCCNT: u32,
    SLEEPCNT: u32,
    LSUCNT: u32,
    FOLDCNT: u32,
    PCSR: u32,
    COMP0: u32,
    MASK0: u32,
    FUNCTION0: u32,
    padding0: [1]u32,
    COMP1: u32,
    MASK1: u32,
    FUNCTION1: u32,
    padding1: [1]u32,
    COMP2: u32,
    MASK2: u32,
    FUNCTION2: u32,
    padding2: [1]u32,
    COMP3: u32,
    MASK3: u32,
    FUNCTION3: u32,
    padding3: [981]u32,
    LAR: u32,
    LSR: u32,
};

pub const TPI_Type = packed struct {
    SSPSR: u32,
    CSPSR: u32,
    padding0: [2]u32,
    ACPR: u32,
    padding1: [55]u32,
    SPPR: u32,
    padding2: [131]u32,
    FFSR: u32,
    FFCR: u32,
    FSCR: u32,
    padding3: [759]u32,
    TRIGGER: u32,
    FIFO0: u32,
    ITATBCTR2: u32,
    padding4: [1]u32,
    ITATBCTR0: u32,
    FIFO1: u32,
    ITCTRL: u32,
    padding5: [39]u32,
    CLAIMSET: u32,
    CLAIMCLR: u32,
    padding7: [8]u32,
    DEVID: u32,
    DEVTYPE: u32,
};

pub const CoreDebug_Type = packed struct {
    DHCSR: u32,
    DCRSR: u32,
    DCRDR: u32,
    DEMCR: u32,
};

pub const MPU_Type = packed struct {
    TYPE: u32,
    CTRL: u32,
    RNR: u32,
    RBAR: u32,
    RASR: u32,
    RBAR_A1: u32,
    RASR_A1: u32,
    RBAR_A2: u32,
    RASR_A2: u32,
    RBAR_A3: u32,
    RASR_A3: u32,
};

pub const FPU_Type = packed struct {
    FPCCR: u32,
    FPCAR: u32,
    FPDSCR: u32,
    MVFR0: u32,
    MVFR1: u32,
    MVFR2: u32,
};

test "Offset of last field" {
    comptime {
        assert(@byteOffsetOf(SCB_Type, "ABFSR") == 0x2A8);
        assert(@byteOffsetOf(SCnSCB_Type, "ACTLR") == 0x8);
        assert(@byteOffsetOf(SysTick_Type, "CALIB") == 0xC);
        assert(@byteOffsetOf(NVIC_Type, "STIR") == 0xE00);
        assert(@byteOffsetOf(ITM_Type, "CID3") == 0xFFC);
        assert(@byteOffsetOf(DWT_Type, "LSR") == 0xFB4);
        assert(@byteOffsetOf(TPI_Type, "DEVTYPE") == 0xFCC);
        assert(@byteOffsetOf(CoreDebug_Type, "DEMCR") == 0xC);
        assert(@byteOffsetOf(MPU_Type, "RASR_A3") == 0x28);
        assert(@byteOffsetOf(FPU_Type, "MVFR2") == 0x14);
    }
}
