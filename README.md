## 1. Overview
The objective of this project was to create a minimal, self-contained bootloader capable of running on x86 hardware immediately after the BIOS Power-On Self-Test (POST). The design follows a linear execution flow starting with environment initialization where the CPU starts in Real Mode (16-bit) and the bootloader must manually normalize segment registers and establish a stack to ensure predictable memory addressing. Next comes BIOS interaction, where lacking an operating system or drivers, the program relies on BIOS interrupts (specifically `INT 0x10`) to handle video output. The core payload execution is a string iteration routine that prints characters to the teletype. Finally, once the task is complete, the CPU is placed in a low-power, non-executing state to prevent undefined behavior.

## 2. Implementation

### Memory Organization and Stack Safety
The code is explicitly org'd at `0x7C00`, the standard load address for BIOS boot sectors. A key implementation detail is the stack initialization:

```nasm
mov sp, 0x7C00
```

By setting the Stack Pointer (`SP`) to `0x7C00`, the stack grows downwards from the beginning of the bootloader code. This design choice prevents stack collisions, ensuring that push/pop operations do not overwrite the executing code or data located at `0x7C00` and above.

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

## 3. Testing with QEMU

### Why QEMU?
QEMU (Quick Emulator) is an open-source virtualization tool that emulates x86 hardware, making it ideal for testing bootloaders without requiring physical hardware or USB drives. The main advantages include safety since there's no risk of overwriting actual boot sectors on physical drives, speed with instant boot times compared to physical hardware, easy debugging integration with tools like GDB, and it works cross-platform on Windows, macOS, and Linux.

### QEMU Boot Process
When testing the bootloader with QEMU, the process works as follows. QEMU emulates a complete x86 system including BIOS firmware. The BIOS performs POST and searches for bootable media. QEMU loads your 512-byte binary into memory at address `0x7C00`. The BIOS verifies the boot signature (`0xAA55`) and transfers control to your code. Your bootloader then executes in the emulated 16-bit Real Mode environment.

### Basic QEMU Command
```bash
qemu-system-x86_64 -drive format=raw,file=bootloader.bin
```

This command boots the compiled binary (`bootloader.bin`) as if it were written to a physical disk's boot sector.

## 4. Assumptions and Shortcomings

### Assumptions
The code assumes an x86 architecture starting in 16-bit Real Mode and will not function on ARM or other architectures. It relies on legacy BIOS interrupt vectors (specifically Video Services) and does not support UEFI booting without a Compatibility Support Module (CSM). The implementation assumes that the low memory addresses (specifically `0x0000` to `0x7C00`) are free for stack usage and segment zeroing.

### Shortcomings
The logic is strictly confined to 512 bytes, so to add significant logic like a kernel loader or filesystem driver, this code would need to implement "chain loading" to read further sectors from the disk. The code runs in 16-bit mode, limiting access to 1MB of RAM and lacking modern memory protection or multitasking features found in Protected (32-bit) or Long (64-bit) modes. There's also a lack of error handling since the video interrupt `INT 0x10` is assumed to always succeed, with no feedback mechanism if the video hardware is incompatible or the display mode is unsupported.

## 5. How to Run This Program

### Prerequisites
You'll need two tools to assemble and test the bootloader:

1. **NASM** (Netwide Assembler) to compile the assembly code
2. **QEMU** to emulate the x86 hardware and test the bootloader

### Step 1: Install NASM

1. Download NASM from the official website: https://www.nasm.us/pub/nasm/releasebuilds/
2. Download the latest Windows installer (e.g., `nasm-2.16.01-installer-x64.exe`)
3. Run the installer and follow the prompts
4. Add NASM to your system PATH:
   * Right-click "This PC" and select Properties, then Advanced System Settings
   * Click "Environment Variables"
   * Under "System Variables", find "Path" and click "Edit"
   * Click "New" and add: `C:\Program Files\NASM`
5. Verify installation by opening Command Prompt and typing: `nasm -v`

### Step 2: Install QEMU

1. Download QEMU from: https://www.qemu.org/download/#windows
2. Download the Windows installer (e.g., `qemu-w64-setup-20231224.exe`)
3. Run the installer with default settings
4. Add QEMU to your PATH:
   * Add `C:\Program Files\qemu` to your system PATH (same process as NASM)
5. Verify installation: `qemu-system-x86_64 --version`

### Step 3: Project Files

This repository contains two files:
* `bootloader.asm` - The bootloader source code
* `build.ps1` - PowerShell build script for Windows

### Step 4: Update Build Script Paths

**Windows (PowerShell - build.ps1)**

Open `build.ps1` and update the paths at the top to match your installation locations:

```powershell
# Hardcoded paths - update these to match your installation locations
$nasmPath = "C:\Users\YourUsername\AppData\Local\bin\NASM\nasm.exe"
$qemuPath = "C:\Program Files\qemu\qemu-system-x86_64.exe"
$asmFile = "bootloader.asm"
$binFile = "bootloader.bin"

# Check if assembly file exists
if (-Not (Test-Path $asmFile)) {
    Write-Host "Error: $asmFile not found!" -ForegroundColor Red
    Write-Host "Make sure you're in the correct directory." -ForegroundColor Yellow
    pause
    exit 1
}

# Assemble the bootloader
Write-Host "Assembling $asmFile..." -ForegroundColor Yellow
& $nasmPath -f bin $asmFile -o $binFile

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Assembly failed!" -ForegroundColor Red
    pause
    exit 1
}

# Verify output file was created
if (-Not (Test-Path $binFile)) {
    Write-Host ""
    Write-Host "Error: $binFile was not created!" -ForegroundColor Red
    pause
    exit 1
}

# Check file size
$fileSize = (Get-Item $binFile).Length
Write-Host "Assembly successful! Binary size: $fileSize bytes" -ForegroundColor Green

if ($fileSize -ne 512) {
    Write-Host "Warning: Bootloader should be exactly 512 bytes!" -ForegroundColor Yellow
}

# Run QEMU
Write-Host ""
Write-Host "Starting QEMU..." -ForegroundColor Yellow
Write-Host "(Close the QEMU window when done)" -ForegroundColor Cyan
Write-Host ""

& $qemuPath -drive format=raw,file=$binFile

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
```

To find your NASM path:
1. Open PowerShell and run: `Get-Command nasm` (if NASM is in PATH)
2. Or navigate to where you installed NASM and copy the full path to `nasm.exe`
3. Common locations:
   * `C:\Users\YourUsername\AppData\Local\bin\NASM\nasm.exe`
   * `C:\Program Files\NASM\nasm.exe`

To find your QEMU path:
* Default installation: `C:\Program Files\qemu\qemu-system-x86_64.exe`
* Or check your QEMU installation directory

Run the script:
```powershell
.\build.ps1
```

Note: If you get a "script execution disabled" error, run this command once:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 4: Run the Build Script

Open `build.ps1` and update the paths at the top to match your installation locations:

```powershell
$nasmPath = "C:\Users\YourUsername\AppData\Local\bin\NASM\nasm.exe"
$qemuPath = "C:\Program Files\qemu\qemu-system-x86_64.exe"
```

To find your NASM path, open PowerShell and run `Get-Command nasm` (if NASM is in PATH), or navigate to where you installed NASM and copy the full path to `nasm.exe`. Common locations are `C:\Users\YourUsername\AppData\Local\bin\NASM\nasm.exe` or `C:\Program Files\NASM\nasm.exe`.

To find your QEMU path, check the default installation at `C:\Program Files\qemu\qemu-system-x86_64.exe` or check your QEMU installation directory.

Run the script:
```powershell
.\build.ps1
```

Note: If you get a "script execution disabled" error, run this command once:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 5: Expected Output

When you run the build script, you should see:

1. NASM compiles `bootloader.asm` into `bootloader.bin` (exactly 512 bytes)
2. QEMU opens a window displaying your bootloader's output
3. The message appears on screen
4. The bootloader enters the halt state

### Advanced Testing Options

For more detailed debugging, you can use additional QEMU flags:

```bash
# See BIOS messages
qemu-system-x86_64 -drive format=raw,file=bootloader.bin -monitor stdio

# Enable serial output debugging
qemu-system-x86_64 -drive format=raw,file=bootloader.bin -serial stdio

# Run without GUI (useful for automated testing)
qemu-system-x86_64 -drive format=raw,file=bootloader.bin -nographic
```
