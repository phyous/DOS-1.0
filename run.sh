#!/bin/bash
#
# Boot 86-DOS 1.00 using DOSBox-X
#
# Requirements: DOSBox-X (brew install dosbox-x)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check for DOSBox-X
if ! command -v dosbox-x &> /dev/null; then
    echo "DOSBox-X is required but not installed."
    echo ""
    echo "  macOS:   brew install dosbox-x"
    echo "  Linux:   https://dosbox-x.com"
    echo "  Windows: https://dosbox-x.com"
    exit 1
fi

# Use the source-compiled image if available, otherwise fall back to base
IMG="$SCRIPT_DIR/86-DOS_1.00.img"
if [ ! -f "$IMG" ]; then
    IMG="$SCRIPT_DIR/86-DOS_1.00_base.img"
fi
if [ ! -f "$IMG" ]; then
    echo "No disk image found. Run ./build.sh first."
    exit 1
fi

# Create DOSBox-X config
CONF=$(mktemp /tmp/dosbox-86dos-XXXXXXXX)
trap "rm -f $CONF" EXIT

cat > "$CONF" << EOF
[sdl]
output=opengl
windowresolution=800x600

[dosbox]
machine=cga
memsize=256
title=86-DOS 1.00 (1981) - Compiled from Source

[cpu]
core=normal
cputype=8086
cycles=3000

[autoexec]
IMGMOUNT 0 "$IMG" -t floppy -fs none
BOOT -l a
EOF

echo "=============================================="
echo "  86-DOS 1.00 - Tim Paterson's Original DOS"
echo "  Copyright 1980,81 Seattle Computer Products"
echo "=============================================="
echo ""
echo "  Booting from: $IMG"
echo ""
echo "  Date prompt: enter a date like 1-1-81"
echo "  (86-DOS only accepts years 1980-1999)"
echo ""
echo "  Commands to try:"
echo "    DIR        - List files on disk"
echo "    CHKDSK     - Check disk integrity"
echo "    DEBUG      - Enter the debugger"
echo "    TYPE file  - Display a file"
echo "    ASM file   - Run the SCP assembler"
echo "    EDLIN file - Line editor"
echo ""

dosbox-x -conf "$CONF" 2>/dev/null
