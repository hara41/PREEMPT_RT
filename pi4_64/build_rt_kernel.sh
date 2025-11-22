#!/bin/bash

# Raspberry Pi 4 64-bit PREEMPT_RT Kernel Build Script for Docker
# 6.12+ Mainline PREEMPT_RT Version (Raspberry Pi 4 optimized)
# Usage: ./build_rt_kernel.sh

set -e

# 色付きの出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Raspberry Pi 4 64-bit PREEMPT_RT Kernel Builder${NC}"
echo "6.12+ Mainline PREEMPT_RT (RPi4 optimized!)"
echo "============================================="

# 出力ディレクトリを作成
OUTPUT_DIR="$(pwd)/rpi_rt_output"
echo -e "${YELLOW}Cleaning previous build...${NC}"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo -e "${YELLOW}Output directory: $OUTPUT_DIR${NC}"

# 必要なファイルの確認
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}Error: Dockerfile not found in current directory${NC}"
    exit 1
fi

if [ ! -f "docker_build.sh" ]; then
    echo -e "${RED}Error: docker_build.sh not found in current directory${NC}"
    exit 1
fi

# Dockerイメージをビルド
echo -e "${YELLOW}Building Docker image for RPi4 6.12+ kernel...${NC}"
docker build -t rpi4-rt-builder-6.12 .

if [ $? -ne 0 ]; then
    echo -e "${RED}Docker image build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Docker image built successfully!${NC}"

# カーネルをビルド
echo -e "${YELLOW}Starting RPi4 PREEMPT_RT kernel build process...${NC}"
echo "This may take 30-60 minutes..."

docker run --rm \
    -v "$OUTPUT_DIR:/output" \
    rpi4-rt-builder-6.12

if [ $? -ne 0 ]; then
    echo -e "${RED}Kernel build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}RPi4 PREEMPT_RT kernel build completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Installation Instructions for Raspberry Pi 4:${NC}"
echo "1. Mount your RPi4 SD card"
echo "2. Backup current kernel:"
echo "   sudo cp /Volumes/bootfs/kernel8.img /Volumes/bootfs/kernel8.img.backup"
echo "   sudo cp /Volumes/bootfs/config.txt /Volumes/bootfs/config.txt.backup"
echo ""
echo "3. Copy the new files:"
echo "   sudo cp $OUTPUT_DIR/boot/kernel8.img /Volumes/bootfs/"
echo "   sudo cp $OUTPUT_DIR/boot/*.dtb /Volumes/bootfs/"
echo "   sudo cp $OUTPUT_DIR/boot/overlays/*.dtb* /Volumes/bootfs/overlays/"
echo ""
echo "4. Install kernel modules:"
echo "   sudo cp -r $OUTPUT_DIR/modules/lib/modules/* /Volumes/rootfs/lib/modules/"
echo ""
echo "5. Update /boot/config.txt by adding:"
echo "   cat $OUTPUT_DIR/boot/config_snippet.txt"
echo ""
echo "6. Update cmdline.txt with RT optimizations:"
echo "   # Replace PARTUUID with your actual partition UUID"
echo "   sudo cp $OUTPUT_DIR/boot/cmdline_rt.txt /Volumes/bootfs/cmdline.txt"
echo ""
echo "7. Reboot your Raspberry Pi 4"
echo ""
echo -e "${YELLOW}Verification commands (after reboot):${NC}"
echo "   uname -r                    # Should show RT version"
echo "   uname -m                    # Should show 'aarch64'"
echo "   cat /sys/kernel/realtime    # Should show '1'"
echo "   sudo cyclictest -t1 -p 80 -i 1000 -l 10000 -h 100 -m"
echo ""
echo -e "${GREEN}This kernel uses mainline PREEMPT_RT (6.12+)${NC}"
echo -e "${GREEN}Optimized for Raspberry Pi 4 - No RCU issues!${NC}"
echo ""
echo -e "${GREEN}Files are ready in: $OUTPUT_DIR${NC}"
