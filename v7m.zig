const std = @import("std");
const testing = std.testing;
const cfg = @import("config.zig");
pub usingnamespace @import("common.zig");

/// ARM DUI 0646C Table 4-17
const SCB_AIRCR_PRIGROUP_Pos: u32 = 8;
const SCB_AIRCR_PRIGROUP_Mask: u32 = 0x7 << SCB_AIRCR_PRIGROUP_Pos;
const SCB_AIRCR_VECTKEYSTAT_Pos: u32 = 16;
const SCB_AIRCR_VECTKEYSTAT_Mask: u32 = 0xffff << SCB_AIRCR_VECTKEYSTAT_Pos;
const SCB_AIRCR_VECTKEY: u32 = 0x5FA << SCB_AIRCR_VECTKEYSTAT_Pos;
const SCB_AIRCR_SYSRESETREQ_Pos: u32 = 2;
const SCB_AIRCR_SYSRESETREQ_Mask: u32 = 0x1 << SCB_AIRCR_SYSRESETREQ_Pos;

pub const FloatingPoint = struct {
    /// ARM DDI 0403E.b Section B3.3.20
    pub fn enable() void {
        // Set CP10 and CP11 Full Access
        SCB.CPACR |= @as(u32, 0xF) << 20;
    }
};

pub fn systemReset() noreturn {
    dsb();
    SCB.AIRCR = SCB_AIRCR_VECTKEY |
        (SCB.AIRCR & SCB_AIRCR_PRIGROUP_Mask) |
        SCB_AIRCR_SYSRESETREQ_Mask;
    dsb();
    while (true) {}
}

pub const Interrupts = struct {
    // TODO: arch ref manual says irq_number can go up to 495
    pub fn enable(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC.ISER[irq_number >> 5] = irq_bit;
    }

    pub fn getEnabled(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((NVIC.ISER[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn disable(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC.ICER[irq_number >> 5] = irq_bit;
        dsb();
        isb();
    }

    pub fn getPending(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((NVIC.ISPR[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn setPending(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC.ISPR[irq_number >> 5] = irq_bit;
    }

    pub fn clearPending(irq_number: u8) void {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        NVIC.ICPR[irq_number >> 5] = irq_bit;
    }

    pub fn getActive(irq_number: u8) bool {
        const irq_bit = @as(u32, 1) << @truncate(u5, irq_number);
        return if ((NVIC.IABR[irq_number >> 5] & irq_bit) == 0) false else true;
    }

    pub fn setPriority(irq_number: u8, priority: u8) void {
        const prio_shift = 8 - cfg.nvic_priority_bits;
        if (irq_number >= NVIC.IPR.len) return;

        NVIC.IPR[irq_number] = priority << prio_shift;
    }

    pub fn getPriority(irq_number: u8, priority: u8) u8 {
        const prio_shift = 8 - cfg.nvic_priority_bits;
        assert(irq_number >= NVIC.IPR.len);

        return (NVIC.IPR[irq_number] >> prio_shift);
    }
};

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
        SYSTICK.RVR = reload_value;
        Exceptions.SysTickHandler.setPriority((1 << cfg.nvic_priority_bits) - 1);
        SYSTICK.CVR = 0;
        const clock_setting = if (clock == .Processor) CSR_CLKSOURCE_Mask else 0;
        const interrupt_setting = if (interrupt) CSR_TICKINT_Mask else 0;
        const enable_setting = if (enable) CSR_ENABLE_Mask else 0;
        SYSTICK.CSR = clock_setting | interrupt_setting | enable_setting;
    }

    pub fn getTenMsCalibratedTicks() u24 {
        return @truncate(u24, SYSTICK.CALIB);
    }
};

pub const PriorityBitsGrouping = enum(u3) {
    GroupPriorityBits_7,
    GroupPriorityBits_6,
    GroupPriorityBits_5,
    GroupPriorityBits_4,
    GroupPriorityBits_3,
    GroupPriorityBits_2,
    GroupPriorityBits_1,
    GroupPriorityBits_0,

    const Self = @This();

    pub fn set(priority_group: Self) void {
        const iarcr = SCB.AIRCR & ~@as(u32, SCB_AIRCR_VECTKEYSTAT_Mask | SCB_AIRCR_PRIGROUP_Mask);
        SCB.AIRCR = iarcr |
            SCB_AIRCR_VECTKEY |
            @as(u32, @enumToInt(priority_group)) << SCB_AIRCR_PRIGROUP_Pos;
    }

    pub fn get() Self {
        return @intToEnum(@truncate(@TagType(PriorityBitsGrouping), SCB.AIRCR >> SCB_AIRCR_PRIGROUP_Pos));
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
        const prio_shift = 8 - cfg.nvic_priority_bits;
        const exception_number = @enumToInt(exception);

        SCB.SHPR[exception_number - 4] = priority << prio_shift;
    }

    pub fn getPriority(exception: Self, priority: u8) u8 {
        const prio_shift = 8 - cfg.nvic_priority_bits;
        const exception_number = @enumToInt(exception);

        return SCB.SHPR[exception_number - 4] >> prio_shift;
    }
};

pub const ICache = struct {
    const SCB_CCR_IC_Mask: u32 = 1 << 17;

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

/// ARM DDI 0403E.b Section B3.2
/// Table B3-3
const SCS_BASE = 0xE000E000;
const SYSTICK_BASE = SCS_BASE + 0x010;
const NVIC_BASE = SCS_BASE + 0x100;
const SCB_BASE = SCS_BASE + 0xD00;
const MPU_BASE = SCS_BASE + 0xD90;
const DBC_BASE = SCS_BASE + 0xDF0;
const CACHE_MAINTENANCE_BASE = SCS_BASE + 0xF50;
const MCU_ID_BASE = SCS_BASE + 0xFD0;

/// ARM DDI 0403E.b Section B3.2
/// Table B3-6
const STIR_BASE = SCS_BASE + 0xF00;

/// ARM DDI 0403E.b Section B3.2
/// Table B3-5
const FPU_BASE = SCS_BASE + 0xF34;

/// ARM DDI 0403E.b Section C1.1
/// Table C1-1
const DEBUG_BASE = 0xE0000000;
const ITM_BASE = DEBUG_BASE + 0x0000;
const DWT_BASE = DEBUG_BASE + 0x1000;
const FPB_BASE = DEBUG_BASE + 0x2000;
const TPIU_BASE = DEBUG_BASE + 0x40000;
const ETM_BASE = DEBUG_BASE + 0x41000; // TODO
const ROM_TABLE_BASE = DEBUG_BASE + 0xFF000;

pub const SCS = @intToPtr(*align(4) volatile SCS_Regs, SCS_BASE);
pub const SYSTICK = @intToPtr(*align(4) volatile SYSTICK_Regs, SYSTICK_BASE);
pub const NVIC = @intToPtr(*align(4) volatile NVIC_Regs, NVIC_BASE);
pub const SCB = @intToPtr(*align(4) volatile SCB_Regs, SCB_BASE);
pub const MPU = @intToPtr(*align(4) volatile MPU_Regs, MPU_BASE);
pub const DBC = @intToPtr(*align(4) volatile DBC_Regs, DBC_BASE);
pub const CACHE_MAINTENANCE = @intToPtr(*align(4) volatile CACHE_MAINTENANCE_Regs, CACHE_MAINTENANCE_BASE);
pub const MCU_ID = @intToPtr(*align(4) volatile MCU_ID_Regs, MCU_ID_BASE);

pub const ITM = @intToPtr(*align(4) volatile ITM_Regs, ITM_BASE);
pub const DWT = @intToPtr(*align(4) volatile DWT_Regs, DWT_BASE);
pub const FPB = @intToPtr(*align(4) volatile FPB_Regs, FPB_BASE);
pub const TPIU = @intToPtr(*align(4) volatile TPIU_Regs, TPIU_BASE);
pub const FPU = @intToPtr(*align(4) volatile FPU_Regs, FPU_BASE);

/// ARM DDI 0403E.b Section B3.2
/// Table B3-4
/// and
/// ARM DDI 0403E.b Section B4.1
/// Table B4-1 For CPUID
pub const SCB_Regs = extern struct {
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
    // CPUID
    ID_PFR: [2]u32,
    ID_DFR: u32,
    ID_AFR: u32,
    ID_MMFR: [4]u32,
    ID_ISAR: [5]u32,
    padding0: [1]u32, // ID_ISAR5 reserved
    CLIDR: u32,
    CTR: u32,
    CCSIDR: u32,
    CSSELR: u32,
    // end CPUID
    CPACR: u32,
    padding1: [1]u32,
};

/// ARM DDI 0403E.b Section B3.2
/// Table B3-6
pub const SCS_Regs = extern struct {
    padding0: [1]u32,
    ICTR: u32,
    ACTLR: u32,
    padding1: [1]u32,
};

/// ARM DDI 0403E.b Section C1.11
/// Table C1-23
pub const FPB_Regs = extern struct {
    CTRL: u32,
    REMAP: u32,
    COMP: [142]u32,
};

/// ARM DDI 0403E.b Section B3.3
/// Table B3-7
pub const SYSTICK_Regs = extern struct {
    CSR: u32,
    RVR: u32,
    CVR: u32,
    CALIB: u32,
    padding0: [(0x100 - 0x20) / 4]u32,
};

/// ARM DDI 0403E.b Section B3.4
/// Table B3-8
pub const NVIC_Regs = extern struct {
    ISER: [16]u32,
    padding0: [16]u32,
    ICER: [16]u32,
    RSERVED1: [16]u32,
    ISPR: [16]u32,
    padding2: [16]u32,
    ICPR: [16]u32,
    padding3: [16]u32,
    IABR: [16]u32,
    padding4: [(0x400 - 0x340) / 4]u32,
    IPR: [496]u8,
    padding5: [STIR_BASE - 0xE000E5F0]u8,
    STIR: u32,
};

/// ARM DDI 0403E.b Section C1.7.3
const ItmStimPort = packed union {
    FIFOREADY: u1,
    asByte: u8,
    asHword: u16,
    asWord: u32,
};

/// ARM DDI 0403E.b Section C1.7
/// Table C1-11
pub const ITM_Regs = extern struct {
    ITM_STIM: [256]ItmStimPort,
    padding0: [0xE00 - 0x400]u8,
    ITM_TER: [8]u32,
    padding1: [0xE40 - 0xE20]u8,
    ITM_TPR: u32,
    padding2: [60]u8,
    ITM_TCR: u32,
};

/// ARM DDI 0403E.b Section C1.8
/// Table C1-21
const DwtComparatorControl = packed struct {
    COMP: u32,
    MASK: u32,
    FUNCTION: u32,
    padding0: u32,
};

/// ARM DDI 0403E.b Section C1.8.7
const DWT_CTRL_NUMCOMP_Pos = 28;
const DWT_CTRL_NUMCOMP_Width = 31 - 28 + 1;
const DWT_CTRL_NUMCOMP_Mask = bitmask(u32, DWT_CTRL_NUMCOMP_Width) << DWT_CTRL_NUMCOMP_Pos;

/// ARM DDI 0403E.b Section C1.8
/// Table C1-21
pub const DWT_Regs = extern struct {
    CTRL: u32,
    CYCCNT: u32,
    CPICNT: u32,
    EXCCNT: u32,
    SLEEPCNT: u32,
    LSUCNT: u32,
    FOLDCNT: u32,
    PCSR: u32,
    COMP: [DWT_CTRL_NUMCOMP_Mask >> DWT_CTRL_NUMCOMP_Pos]DwtComparatorControl,
};

/// ARM DDI 0403E.b Section C1.10
/// Table C1-22
pub const TPIU_Regs = extern struct {
    SSPSR: u32,
    CSPSR: u32,
    padding0: [0x10 - 0x08]u8,
    ACPR: u32,
    padding1: [0xF0 - 0x14]u8,
    SPPR: u32,
    padding2: [0xFC8 - 0xF4]u8,
    TYPE: u32,
};

/// ARM DDI 0403E.b Section C1.6
/// Table C1-10
pub const DBC_Regs = extern struct {
    DHCSR: u32,
    DCRSR: u32,
    DCRDR: u32,
    DEMCR: u32,
    padding0: [0xF00 - 0xE00]u8,
};

/// ARM DDI 0403E.b Section B3.5
/// Table B3-11
pub const MPU_Regs = extern struct {
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
    padding0: [0xDF0 - 0xDBC]u8,
};

/// ARM DDI 0403E.b Section B3.2
/// Table B3-5
pub const FPU_Regs = extern struct {
    FPCCR: u32,
    FPCAR: u32,
    FPDSCR: u32,
    MVFR0: u32,
    MVFR1: u32,
    MVFR2: u32,
};

/// ARM DDI 0403E.b Section B2.2
/// Table B2-1
pub const CACHE_MAINTENANCE_Regs = extern struct {
    ICIALLU: u32,
    padding0: u32,
    ICIMVAU: u32,
    DCIMVAC: u32,
    DCISW: u32,
    DCCMVAU: u32,
    DCCMVAC: u32,
    DCCSW: u32,
    DCCIMVAC: u32,
    DCCISW: u32,
    BPIALL: u32,
    padding1: [2]u32,
};

/// ARM DDI 0403E.b Section B3.2
/// Table B3-6
pub const MCU_ID_Regs = extern struct {
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

fn bitmask(comptime T: type, bits: u8) T {
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

test "Force compiler checks" {
    std.meta.refAllDecls(@This());
}

test "Spot checking register locations" {
    std.testing.expectEqual(@sizeOf(ItmStimPort), 0x4);
    std.testing.expectEqual(@sizeOf(SCS_Regs), 0x10);
    std.testing.expectEqual(@ptrToInt(&NVIC.STIR), STIR_BASE);
    std.testing.expectEqual(@ptrToInt(&ITM.ITM_TPR), ITM_BASE + 0xE40);
    std.testing.expectEqual(@byteOffsetOf(ITM_Regs, "ITM_TCR"), 0xE80);
    std.testing.expectEqual(@byteOffsetOf(ITM_Regs, "padding0"), 0x400);
    std.testing.expectEqual(@sizeOf(DWT_Regs), 0x020 + (16 * bitmask(comptime_int, DWT_CTRL_NUMCOMP_Width)));
    std.testing.expectEqual(@byteOffsetOf(TPIU_Regs, "TYPE"), 0xFC8);
    std.testing.expectEqual(@byteOffsetOf(FPU_Regs, "MVFR2"), 0xF48 - 0xF34);
}
