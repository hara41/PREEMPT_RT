#!/bin/bash

# Raspberry Pi 4 PREEMPT_RT Kernel Installation Script
# For 6.12+ Mainline PREEMPT_RT Kernels
# Usage: ./install_rt_kernel.sh

set -e

# 色付きの出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# スクリプトの場所を取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}Raspberry Pi 4 PREEMPT_RT Kernel Installer${NC}"
echo -e "${BLUE}6.12+ Mainline PREEMPT_RT Version${NC}"
echo "============================================"

# RTカーネルの出力ディレクトリを確認
RT_OUTPUT_DIR="$SCRIPT_DIR/rpi_rt_output"
if [ ! -d "$RT_OUTPUT_DIR" ]; then
    echo -e "${RED}Error: $RT_OUTPUT_DIR not found!${NC}"
    echo "Please run the build script first: ./build_rt_kernel.sh"
    exit 1
fi

# 必要なファイルの存在確認
echo -e "${YELLOW}Checking RT kernel files...${NC}"
REQUIRED_FILES=(
    "boot/kernel8.img"
    "boot/config_snippet.txt"
    "boot/cmdline_rt.txt"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$RT_OUTPUT_DIR/$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${RED}Error: Missing required files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo "  - $file"
    done
    echo "Please rebuild the kernel with: ./build_rt_kernel.sh"
    exit 1
fi

if [ ! -d "$RT_OUTPUT_DIR/modules/lib/modules" ]; then
    echo -e "${RED}Error: kernel modules not found!${NC}"
    exit 1
fi

echo -e "${GREEN}RT kernel files found!${NC}"

# カーネル情報を表示
KERNEL_SIZE=$(stat -c%s "$RT_OUTPUT_DIR/boot/kernel8.img" 2>/dev/null || echo "0")
MODULE_COUNT=$(find "$RT_OUTPUT_DIR/modules/lib/modules" -name "*.ko" 2>/dev/null | wc -l)
KERNEL_VERSION=$(ls "$RT_OUTPUT_DIR/modules/lib/modules/" | head -1)

echo "Kernel size: $(( KERNEL_SIZE / 1024 / 1024 ))MB"
echo "Kernel version: $KERNEL_VERSION"
echo "Module count: $MODULE_COUNT"

# SDカードの自動検出（Parallels/Mac環境対応）
echo ""
echo -e "${YELLOW}Detecting SD card...${NC}"
BOOT_MOUNT=""
ROOT_MOUNT=""

# 環境変数で指定されている場合はそれを使用
if [ -n "$BOOT_MOUNT" ] && [ -n "$ROOT_MOUNT" ]; then
    echo "Using environment variables:"
    echo "  BOOT_MOUNT=$BOOT_MOUNT"
    echo "  ROOT_MOUNT=$ROOT_MOUNT"
elif [ -d "/media/parallels/bootfs" ] && [ -d "/media/parallels/rootfs" ]; then
    # Parallels環境の場合
    BOOT_MOUNT="/media/parallels/bootfs"
    ROOT_MOUNT="/media/parallels/rootfs"
    echo "Parallels environment detected"
else
    # その他の環境での検出
    MOUNT_PATTERNS=("/Volumes/bootfs" "/Volumes/boot" "/media/*/bootfs" "/media/*/boot")
    for pattern in "${MOUNT_PATTERNS[@]}"; do
        for mount_point in $pattern; do
            if [ -d "$mount_point" ]; then
                # bootfsらしいディレクトリの確認
                if [ -f "$mount_point/config.txt" ] || [ -f "$mount_point/kernel8.img" ]; then
                    BOOT_MOUNT="$mount_point"
                    break 2
                fi
            fi
        done
    done

    ROOT_PATTERNS=("/Volumes/rootfs" "/Volumes/root" "/media/*/rootfs" "/media/*/root")
    for pattern in "${ROOT_PATTERNS[@]}"; do
        for mount_point in $pattern; do
            if [ -d "$mount_point" ]; then
                # rootfsらしいディレクトリの確認
                if [ -d "$mount_point/lib/modules" ] || [ -d "$mount_point/home" ]; then
                    ROOT_MOUNT="$mount_point"
                    break 2
                fi
            fi
        done
    done
fi

if [ -z "$BOOT_MOUNT" ] || [ -z "$ROOT_MOUNT" ]; then
    echo -e "${RED}Error: SD card not detected or not mounted!${NC}"
    echo ""
    echo "Please ensure your Raspberry Pi 4 SD card is connected and mounted."
    echo "Current mount points detected:"
    echo "Available mounts:"
    df -h | grep -E "(bootfs|rootfs|boot|root)"
    echo ""
    echo "Expected mount points:"
    echo "  - Boot partition: /media/parallels/bootfs or /Volumes/bootfs"
    echo "  - Root partition: /media/parallels/rootfs or /Volumes/rootfs"
    echo ""
    echo "You can run with manual specification:"
    echo "  BOOT_MOUNT=/your/boot/path ROOT_MOUNT=/your/root/path $0"
    exit 1
fi

echo -e "${GREEN}SD card detected:${NC}"
echo "  Boot partition: $BOOT_MOUNT"
echo "  Root partition: $ROOT_MOUNT"

# Raspberry Pi OS の確認
if [ ! -f "$BOOT_MOUNT/config.txt" ]; then
    echo -e "${RED}Error: This doesn't appear to be a Raspberry Pi OS SD card${NC}"
    echo "Missing config.txt file"
    exit 1
fi

# アーキテクチャの確認（64-bit推奨）
if grep -q "arm_64bit=1" "$BOOT_MOUNT/config.txt" 2>/dev/null || [ -f "$BOOT_MOUNT/kernel8.img" ]; then
    echo -e "${GREEN}64-bit Raspberry Pi OS detected${NC}"
else
    echo -e "${YELLOW}Warning: May not be 64-bit Raspberry Pi OS${NC}"
    echo "This RT kernel is optimized for 64-bit RPi4"
fi

# 確認プロンプト
echo ""
echo -e "${YELLOW}This script will install PREEMPT_RT kernel for Raspberry Pi 4:${NC}"
echo "1. Backup current kernel and configuration files"
echo "2. Install RT kernel (kernel8.img)"
echo "3. Copy device tree files and kernel modules"
echo "4. Update config.txt for RT kernel with optimizations"
echo "5. Create RT-optimized cmdline.txt template"
echo ""
echo -e "${RED}Warning: This will replace your current kernel!${NC}"
echo "Make sure you have backups and can access the SD card if issues occur."
echo ""
read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
fi

# バックアップの作成
echo ""
echo -e "${YELLOW}Creating backups...${NC}"
BACKUP_DIR="$BOOT_MOUNT/backup_rt_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 元のカーネルファイルをバックアップ
if [ -f "$BOOT_MOUNT/kernel8.img" ]; then
    cp "$BOOT_MOUNT/kernel8.img" "$BACKUP_DIR/"
    echo "Backed up kernel8.img"
fi

if [ -f "$BOOT_MOUNT/config.txt" ]; then
    cp "$BOOT_MOUNT/config.txt" "$BACKUP_DIR/"
    echo "Backed up config.txt"
fi

if [ -f "$BOOT_MOUNT/cmdline.txt" ]; then
    cp "$BOOT_MOUNT/cmdline.txt" "$BACKUP_DIR/"
    echo "Backed up cmdline.txt"
fi

echo -e "${GREEN}Backups created in: $BACKUP_DIR${NC}"

# RTカーネルのインストール
echo ""
echo -e "${YELLOW}Installing RT kernel...${NC}"
cp "$RT_OUTPUT_DIR/boot/kernel8.img" "$BOOT_MOUNT/"
echo "RT kernel installed ($(ls -lh "$BOOT_MOUNT/kernel8.img" | awk '{print $5}'))"

# デバイスツリーファイルのコピー
echo -e "${YELLOW}Installing device tree files...${NC}"
cp "$RT_OUTPUT_DIR/boot/"*.dtb "$BOOT_MOUNT/" 2>/dev/null || echo "No DTB files to copy"
cp "$RT_OUTPUT_DIR/boot/overlays/"*.dtb* "$BOOT_MOUNT/overlays/" 2>/dev/null || echo "No overlay files to copy"
echo "Device tree files installed"

# カーネルモジュールのインストール
echo -e "${YELLOW}Installing kernel modules...${NC}"
cp -r "$RT_OUTPUT_DIR/modules/lib/modules/"* "$ROOT_MOUNT/lib/modules/"
echo "Kernel modules installed"

# config.txtの更新
echo -e "${YELLOW}Updating config.txt...${NC}"
cat "$RT_OUTPUT_DIR/boot/config_snippet.txt" >> "$BOOT_MOUNT/config.txt"
echo "config.txt updated for RT kernel"

# cmdline.txtテンプレートの作成
echo -e "${YELLOW}Creating RT cmdline.txt template...${NC}"
# 元のPARTUUIDを保持
ORIGINAL_PARTUUID=$(grep -o 'root=PARTUUID=[^ ]*' "$BACKUP_DIR/cmdline.txt" 2>/dev/null || echo 'root=PARTUUID=YOUR_PARTUUID')

sed "s/root=PARTUUID=PLACEHOLDER/$ORIGINAL_PARTUUID/" "$RT_OUTPUT_DIR/boot/cmdline_rt.txt" > "$BOOT_MOUNT/cmdline_rt_template.txt"
echo "RT cmdline template created: cmdline_rt_template.txt"
echo "Review and replace cmdline.txt if you want RT optimizations"

# 同期と完了メッセージ
echo -e "${YELLOW}Syncing files...${NC}"
sync

echo ""
echo -e "${GREEN}Installation completed successfully for Raspberry Pi 4!${NC}"
echo ""
echo -e "${BLUE}Installation Summary:${NC}"
echo "- RT kernel: $(ls -lh "$BOOT_MOUNT/kernel8.img" | awk '{print $5}')"
echo "- Modules: $(ls "$ROOT_MOUNT/lib/modules/" | grep -E '^6\.' | tail -1)"
echo "- Backup: $BACKUP_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Safely eject the SD card"
echo "2. Insert into Raspberry Pi 4 and boot"
echo "3. After boot, verify RT kernel with:"
echo "   uname -r"
echo "   cat /sys/kernel/realtime"
echo "   sudo cyclictest -t1 -p 80 -i 1000 -l 1000"
echo ""
echo -e "${YELLOW}Optional RT optimizations:${NC}"
echo "Replace /boot/cmdline.txt with /boot/cmdline_rt_template.txt for:"
echo "- CPU isolation (cores 1,2,3 for RT tasks)"
echo "- IRQ affinity (core 0 for interrupts)"
echo "- Tickless operation on isolated cores"
echo ""
echo -e "${YELLOW}If boot fails, restore from backup:${NC}"
echo "   cp $BACKUP_DIR/kernel8.img $BOOT_MOUNT/"
echo "   cp $BACKUP_DIR/config.txt $BOOT_MOUNT/"
echo ""
echo -e "${GREEN}Happy real-time computing on Raspberry Pi 4!${NC}"
