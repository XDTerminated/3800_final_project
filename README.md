## 1\. Overview

The objective of this project was to create a minimal, self-contained bootloader capable of running on x86 hardware immediately after the BIOS Power-On Self-Test (POST).

The design follows a linear execution flow:

1.  **Environment Initialization:** The CPU starts in Real Mode (16-bit). The bootloader must manually normalize segment registers and establish a stack to ensure predictable memory addressing.
2.  **BIOS Interaction:** Lacking an operating system or drivers, the program relies on BIOS interrupts (specifically `INT 0x10`) to handle video output.
3.  **Payload Execution:** The core payload is a string iteration routine that prints characters to the teletype.
4.  **Safe Termination:** Once the task is complete, the CPU is placed in a low-power, non-executing state to prevent undefined behavior.

## 2\. Implementation

### Memory Organization & Stack Safety

The code is explicitly org'd at `0x7C00`, the standard load address for BIOS boot sectors. A key implementation detail is the stack initialization:

```nasm
mov sp, 0x7C00
```

By setting the Stack Pointer (`SP`) to `0x7C00`, the stack grows **downwards** from the beginning of the bootloader code. This design choice prevents stack collisions, ensuring that push/pop operations do not overwrite the executing code or data located at `0x7C00` and above.

### Efficient String Processing

The `print_string` routine utilizes the `LODSB` (Load String Byte) instruction.

  * **Efficiency:** Instead of manually moving memory and incrementing counters, `LODSB` loads the byte at `DS:SI` into `AL` and automatically increments the Source Index (`SI`) in a single cycle.
  * **Control Flow:** The routine uses a null-terminator check (`OR AL, AL`) to determine the end of the string, allowing for variable-length messages without hardcoded lengths.

### CPU Halt State

Rather than a simple infinite loop, the termination routine uses the `HLT` instruction:

```nasm
hang:
    cli
    hlt
    jmp hang
```

  * `CLI` (Clear Interrupts) prevents hardware interrupts from waking the CPU.
  * `HLT` puts the processor into a low-power state.
  * The subsequent `jmp hang` acts as a fail-safe in the unlikely event a non-maskable interrupt (NMI) forces execution to resume.

### Boot Signature

The code utilizes the `times` directive to dynamically calculate padding, ensuring the file is exactly 512 bytes. The final two bytes are hardcoded to `0xAA55`. This "Magic Number" is required for the BIOS to recognize the storage medium as a valid bootable device.

## 3\. Assumptions and Shortcomings

### Assumptions

  * **Hardware Architecture:** The code assumes an x86 architecture starting in 16-bit Real Mode. It will not function on ARM or other architectures.
  * **BIOS Presence:** The code relies on legacy BIOS interrupt vectors (specifically Video Services). It does not support UEFI booting without a Compatibility Support Module (CSM).
  * **Memory Availability:** It assumes that the low memory addresses (specifically `0x0000` to `0x7C00`) are free for stack usage and segment zeroing.

### Shortcomings

  * **Size Limitation:** The logic is strictly confined to 512 bytes. To add significant logic (like a kernel loader or filesystem driver), this code would need to implement "chain loading" to read further sectors from the disk.
  * **Real Mode Limitations:** The code runs in 16-bit mode, limiting access to 1MB of RAM and lacking modern memory protection or multitasking features found in Protected (32-bit) or Long (64-bit) modes.
  * **Lack of Error Handling:** The video interrupt `INT 0x10` is assumed to always succeed. There is no feedback mechanism if the video hardware is incompatible or the display mode is unsupported.
