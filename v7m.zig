const std = @import("std");
const testing = std.testing;

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
