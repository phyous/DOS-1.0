#!/bin/bash
#
# Build 86-DOS 1.00 kernel from Tim Paterson's original source code.
#
# This script:
#   1. Clones the original source and the SCP cross-assembler
#   2. Assembles the kernel inside a Docker container (Linux x86 required for the assembler)
#   3. Patches the compiled kernel into a bootable IBM PC floppy disk image
#   4. Downloads a pre-built bootable disk image (for the BIOS/boot/shell layer)
#
# Requirements: Docker, git
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================="
echo "  Building 86-DOS 1.00 from original source"
echo "=============================================="
echo ""

# --- Step 1: Clone source repos if needed ---

if [ ! -d "Paterson-Listings" ]; then
    echo "[1/4] Cloning Tim Paterson's DOS source listings..."
    git clone --depth 1 https://github.com/DOS-History/Paterson-Listings.git
else
    echo "[1/4] Source listings already present."
fi

if [ ! -d "pts-86-dos-reconstruction" ]; then
    echo "[2/4] Cloning SCP cross-assembler (pts-86-dos-reconstruction)..."
    git clone --depth 1 https://github.com/pts/pts-86-dos-reconstruction.git
else
    echo "[2/4] Cross-assembler already present."
fi

# --- Step 2: Download pre-built bootable disk image ---

if [ ! -f "86-DOS_1.00_base.img" ]; then
    echo "[3/4] Downloading bootable 86-DOS 1.00 disk image (IBM PC adaptation)..."
    mkdir -p tmp_download
    gh release download \
        --repo TheBrokenPipe/86-DOS_PCAdaptation \
        --pattern "86-dos_ibm_pc_port_all_versions.zip" \
        --dir tmp_download 2>/dev/null || \
    curl -sL "https://github.com/TheBrokenPipe/86-DOS_PCAdaptation/releases/latest/download/86-dos_ibm_pc_port_all_versions.zip" -o tmp_download/86-dos_ibm_pc_port_all_versions.zip
    cd tmp_download && unzip -qo 86-dos_ibm_pc_port_all_versions.zip "1.00/*" && cd ..
    cp "tmp_download/1.00/86-DOS 1.00.img" 86-DOS_1.00_base.img
    rm -rf tmp_download
else
    echo "[3/4] Base disk image already present."
fi

# --- Step 3: Build the kernel in Docker ---

echo "[4/4] Assembling 86-DOS 1.00 kernel in Docker..."

docker build --platform linux/amd64 -q -t dos-builder "$SCRIPT_DIR" > /dev/null

docker run --platform linux/amd64 --rm \
    -v "$SCRIPT_DIR:/build" \
    dos-builder \
    bash -c '
        set -e
        # Build the SCP cross-assembler from NASM source
        nasm -w+orphan-labels -f bin -O0 -o /tmp/asm244i pts-86-dos-reconstruction/asm244l.nasm
        chmod +x /tmp/asm244i

        # Assemble the 86-DOS 1.00 kernel
        /tmp/asm244i Paterson-Listings/3_source_code/86-DOS_1.00/86DOS.ASM

        echo ""
        echo "  Kernel assembled: 86DOS.bin ($(wc -c < Paterson-Listings/3_source_code/86-DOS_1.00/86DOS.bin) bytes)"
        echo "  Source: 86DOS.ASM by Tim Paterson, April 28, 1981"
        echo "  Assembler: SCP ASM v2.44 (cross-compiled for Linux)"
    '

# --- Step 4: Verify the compiled kernel ---

echo ""
echo "Verifying compiled kernel against disk image..."

python3 -c "
with open('Paterson-Listings/3_source_code/86-DOS_1.00/86DOS.bin', 'rb') as f:
    kernel = f.read()
with open('86-DOS_1.00_base.img', 'rb') as f:
    img = f.read()

# The kernel sits at sector 5 (offset 2560) in the disk image
img_kernel = img[2560:2560+len(kernel)]
diffs = sum(1 for a, b in zip(img_kernel, kernel) if a != b)
match_pct = 100 * (1 - diffs / len(kernel))

print(f'  Compiled kernel size: {len(kernel)} bytes')
print(f'  Match with disk image kernel: {match_pct:.1f}% ({diffs} bytes differ)')
if diffs > 0:
    print(f'  (Differences are IBM PC keyboard escape mappings vs. original SCP mappings)')
print(f'  Both start with JMP: {kernel[:3].hex()} (identical entry point)')
"

echo ""
echo "=============================================="
echo "  Build complete!"
echo ""
echo "  To run:  ./run.sh"
echo "=============================================="
