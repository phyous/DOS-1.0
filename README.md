# 86-DOS 1.00 — The Original DOS, Running Again

Build and boot Tim Paterson's **86-DOS 1.00** (April 28, 1981) from the original assembly source code. This is the operating system Microsoft purchased and shipped as MS-DOS — the OS that launched the PC revolution.

![86-DOS Boot Screen](images/boot-screen.png)

## What is this?

In 1980-81, Tim Paterson at Seattle Computer Products wrote an operating system for the Intel 8086 called **86-DOS** (originally "QDOS" — Quick and Dirty Operating System). Microsoft licensed it in 1981, and it became **MS-DOS 1.0** — the foundation of the IBM PC software ecosystem.

This project takes Paterson's [original source code listings](https://github.com/DOS-History/Paterson-Listings), cross-assembles the kernel using a modern reimplementation of the SCP assembler, and boots the result in an emulator. You're running the actual code that started it all.

## Quick Start

### Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop/)
- [DOSBox-X](https://dosbox-x.com/) — `brew install dosbox-x` on macOS
- Python 3 (for disk image patching)
- `git`, `gh` CLI (or `curl`)

### Build & Run

```bash
git clone https://github.com/phyous/DOS-1.0.git
cd DOS-1.0

# Compile the kernel from original source (uses Docker)
./build.sh

# Boot 86-DOS in DOSBox-X
./run.sh
```

When prompted for a date, enter something like `1-1-81` (86-DOS only accepts years 1980–1999).

![86-DOS Directory Listing](images/dir-listing.png)

## How It Works

### 1. Cross-Assembly in Docker

The original source (`86DOS.ASM`) uses the **SCP assembler syntax** — a non-standard 8086 assembly dialect that no modern assembler understands. The [pts-86-dos-reconstruction](https://github.com/pts/pts-86-dos-reconstruction) project provides `asm244l`, a faithful reimplementation of Tim Paterson's SCP ASM v2.44 that runs natively on Linux x86.

`build.sh` spins up a Docker container to:
1. Compile `asm244l` from NASM source
2. Assemble `86DOS.ASM` → `86DOS.bin` (the 5,446-byte kernel)
3. Verify the compiled kernel matches the one in the bootable disk image (99.1% identical — the 49-byte difference is IBM PC keyboard escape mappings vs. original SCP mappings)
4. Download a bootable 160KB floppy image with IBM PC BIOS adaptation

### 2. Booting with DOSBox-X

86-DOS runs on an Intel 8086 with CGA display. DOSBox-X emulates this hardware accurately. The floppy image contains:

| File | Size | Description |
|------|------|-------------|
| `COMMAND.COM` | 1,842 | Command interpreter (shell) |
| `ASM.COM` | 6,389 | SCP 8086 assembler |
| `DEBUG.COM` | 5,153 | Machine-level debugger |
| `EDLIN.COM` | 2,144 | Line editor |
| `CHKDSK.COM` | 1,110 | Disk integrity checker |
| `HEX2BIN.COM` | 483 | Intel HEX to binary converter |
| `TRANS.COM` | 3,088 | File transfer utility |

### 3. What's in the Kernel

The entire operating system fits in **5,446 bytes**. It implements:

- **FAT12 filesystem** with 12-bit allocation table
- **INT 21h API** — 36 system calls for file I/O, console, memory
- **FCB-based file access** (File Control Blocks, inherited from CP/M)
- **Console line editing** with escape-key command shortcuts
- **Device driver interface** for console, printer, and auxiliary I/O

## Things to Try

Once booted to the `A:` prompt:

```
DIR                    — List all files on the floppy
CHKDSK                 — Check disk and show memory
TYPE NEWS.DOC          — Read the 86-DOS release notes
TYPE CPMTAB.ASM        — View assembly source code
ASM CPMTAB             — Assemble it with the original assembler
DEBUG                  — Enter the debugger, then:
  D 0:0                  — Dump the interrupt vector table
  U 60:0                 — Disassemble the running DOS kernel
  Q                      — Quit debugger
EDLIN TEST.TXT         — Create a file with the line editor
  I                      — Insert mode
  Hello from 1981!       — Type some text
  ^C                     — Exit insert mode
  E                      — Save and exit
```

## Credits & Sources

- **[DOS-History/Paterson-Listings](https://github.com/DOS-History/Paterson-Listings)** — Transcription of Tim Paterson's original DOS source code printouts (MIT License)
- **[pts/pts-86-dos-reconstruction](https://github.com/pts/pts-86-dos-reconstruction)** — SCP cross-assembler reimplementation and build tools
- **[TheBrokenPipe/86-DOS_PCAdaptation](https://github.com/TheBrokenPipe/86-DOS_PCAdaptation)** — IBM PC adaptation of 86-DOS (boot sector, BIOS layer, COMMAND.COM)
- **[DOSBox-X](https://dosbox-x.com/)** — Accurate DOS/PC emulator

## License

The 86-DOS source code in the [Paterson-Listings](https://github.com/DOS-History/Paterson-Listings) repository is released under the MIT License. The build tooling in this repository is also MIT.
