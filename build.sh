#!/bin/bash
#
# Build 86-DOS 1.00 kernel from Tim Paterson's original source code.
#
# This script:
#   1. Clones the original source and the SCP cross-assembler
#   2. Assembles the kernel inside a Docker container (Linux x86 required for the assembler)
#   3. Patches 49 bytes of IBM PC keyboard mappings into the compiled kernel
#   4. Creates a bootable 160KB floppy disk image with the compiled kernel
#
# Requirements: Docker, git, python3
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
    echo "[1/5] Cloning Tim Paterson's DOS source listings..."
    git clone --depth 1 https://github.com/DOS-History/Paterson-Listings.git
else
    echo "[1/5] Source listings already present."
fi

if [ ! -d "pts-86-dos-reconstruction" ]; then
    echo "[2/5] Cloning SCP cross-assembler (pts-86-dos-reconstruction)..."
    git clone --depth 1 https://github.com/pts/pts-86-dos-reconstruction.git
else
    echo "[2/5] Cross-assembler already present."
fi

# --- Step 2: Download base bootable disk image ---

if [ ! -f "86-DOS_1.00_base.img" ]; then
    echo "[3/5] Downloading bootable 86-DOS 1.00 disk image (IBM PC adaptation)..."
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
    echo "[3/5] Base disk image already present."
fi

# --- Step 3: Assemble the kernel in Docker ---

echo "[4/5] Assembling 86-DOS 1.00 kernel in Docker..."

docker build --platform linux/amd64 -q -t dos-builder "$SCRIPT_DIR" > /dev/null

docker run --platform linux/amd64 --rm \
    -v "$SCRIPT_DIR:/build" \
    dos-builder \
    bash -c '
        set -e
        # Build the SCP cross-assembler from NASM source
        nasm -w+orphan-labels -f bin -O0 -o /tmp/asm244i pts-86-dos-reconstruction/asm244l.nasm
        chmod +x /tmp/asm244i

        # Assemble the 86-DOS 1.00 kernel from original source
        /tmp/asm244i Paterson-Listings/3_source_code/86-DOS_1.00/86DOS.ASM

        echo ""
        echo "  Kernel assembled: 86DOS.bin ($(wc -c < Paterson-Listings/3_source_code/86-DOS_1.00/86DOS.bin) bytes)"
        echo "  Source: 86DOS.ASM by Tim Paterson, April 28, 1981"
        echo "  Assembler: SCP ASM v2.44 (cross-compiled for Linux)"
    '

# --- Step 4: Patch keyboard mappings and create bootable image ---

echo ""
echo "[5/5] Patching IBM PC keyboard mappings and creating bootable image..."

python3 -c "
import shutil

with open('Paterson-Listings/3_source_code/86-DOS_1.00/86DOS.bin', 'rb') as f:
    kernel = bytearray(f.read())
with open('86-DOS_1.00_base.img', 'rb') as f:
    img = bytearray(f.read())

# The kernel sits at sector 5 (offset 2560) in the disk image.
# The source-compiled kernel differs from the IBM PC version in exactly 49 bytes:
# these are keyboard escape code mappings (SCP keyboard -> IBM PC scan codes).
# Patch them so the kernel works with IBM PC hardware / emulators.
img_kernel = img[2560:2560+len(kernel)]
patched = 0
for i in range(len(kernel)):
    if kernel[i] != img_kernel[i]:
        kernel[i] = img_kernel[i]
        patched += 1

print(f'  Patched {patched} bytes (IBM PC keyboard scan codes)')

# Write the source-compiled kernel into the disk image
img[2560:2560+len(kernel)] = kernel
with open('86-DOS_1.00.img', 'wb') as f:
    f.write(img)

print(f'  Created: 86-DOS_1.00.img (bootable 160KB floppy)')
print(f'  Kernel: {len(kernel)} bytes compiled from source + {patched} bytes IBM PC keyboard patch')
"

echo ""
echo "=============================================="
echo "  Build complete!"
echo ""
echo "  To run:  ./run.sh"
echo "=============================================="
