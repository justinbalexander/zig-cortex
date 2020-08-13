# zig-cortex

Zig functions for Arm Cortex processors

# Purpose

To simplify and streamline development in Zig across Arm Cortex architectures
by creating a simple and easy to use library to access common functionality of
Arm Cortex processors.

# Overview

The functionality contained within is similar to CMSIS (Cortex Microcontroller
Software Interface Standard) except written in Zig.

Unlike CMSIS, the organization of the project is by architecture (v6m, v7m) instead of by processor series (M0, M3, M4, M7) and follows as
closely as possible the naming conventions of the architecture reference
manuals. All functionality must have a doc comment explaining where it was found
in the architecture reference manual and which revision of the architecture
manual it was found in.

# Usage

`nvic_priority_bits` is an implementation (in silicon) defined value and
defaults to 4 in zig-cortex, which differs from CMSIS which defaults to 3 if the
preprocessor define is not found. The value for your device can be found in the
datasheet and must be a public constant defined in the root file to the correct
value for your project if your project differs from the default.

Usage example:

```zig
const cpu = @import("zig-cortex/v7m.zig");

// zig-cortex configuration variables
pub const nvic_priority_bits = 3;

pub const xtal = 8000000;

pub export fn main() noreturn {
    cm.ICache.enable();
    cm.DCache.enable();

    cm.PriorityBitsGrouping.set(.GroupPriorityBits_4);

    cm.SysTick.config(.External, true, true, (xtal / 1000) - 1);
    cm.Exceptions.SysTickHandler.setPriority(sys_tick_priority);

    while (true) {}
}
```

# Documentation

Auto-generated html documentation using Zig's documentation generation can be
built by issuing:

```
zig build
```

in the zig-cortex directory. Then open the html file in your browser.

NOTE: Currently a bug(?) in the Zig auto-generated docs requires you to select
"root" in the left hand panel before you can click on the links in the document.
Otherwise you get a 404 not found error.
