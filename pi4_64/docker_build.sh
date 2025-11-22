#!/usr/bin/env bash
set -euo pipefail

# This script runs inside the Docker container. It configures and builds
# a mainline PREEMPT_RT kernel for Raspberry Pi (4/5) and copies
# the build outputs to the host-mounted `/output` directory.

export ARCH=${ARCH:-arm64}
export CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
KERNEL=${KERNEL:-kernel8}
BUILD_DIR=${BUILD_DIR:-/build/linux}
OUTPUT_DIR=${OUTPUT_DIR:-/output}

JOBS=${JOBS:-$(nproc)}

mkdir -p "$OUTPUT_DIR"

if [ ! -d "$BUILD_DIR" ]; then
    echo "Expected kernel source at $BUILD_DIR not found. Exiting."
    exit 1
fi

cd "$BUILD_DIR"

echo "Building in: $(pwd)"
echo "ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE KERNEL=$KERNEL"

# Choose a defconfig suitable for RPi4 or RPi5 if available
DEFCONFIG=bcm2711_defconfig
if make help | grep -q "bcm2712_defconfig"; then
    # prefer bcm2712_defconfig when available (RPi5)
    DEFCONFIG=bcm2712_defconfig
fi

echo "Using defconfig: $DEFCONFIG"
make "$DEFCONFIG"

# Ensure scripts/config is executable
if [ -f scripts/config ]; then
    chmod +x scripts/config || true
else
    echo "scripts/config not found - make sure kernel source has been cloned correctly"
fi

# Enable/disable PREEMPT_RT related settings
scripts/config --enable CONFIG_EXPERT || true
scripts/config --disable CONFIG_PREEMPT_NONE || true
scripts/config --disable CONFIG_PREEMPT_VOLUNTARY || true
scripts/config --disable CONFIG_PREEMPT || true
scripts/config --enable CONFIG_PREEMPT_RT || true
scripts/config --enable CONFIG_HIGH_RES_TIMERS || true
scripts/config --set-val CONFIG_HZ 1000 || true
scripts/config --enable CONFIG_IRQ_FORCED_THREADING || true
scripts/config --enable CONFIG_RCU_BOOST || true
scripts/config --enable CONFIG_NO_HZ_FULL || true

# For bcm2712 (RPi5) enable 16K page support if options exist
if [ "$DEFCONFIG" = "bcm2712_defconfig" ]; then
    scripts/config --set-val CONFIG_ARM64_PAGE_SHIFT 14 || true
    scripts/config --enable CONFIG_ARM64_16K_PAGES || true
    scripts/config --disable CONFIG_ARM64_4K_PAGES || true
    scripts/config --disable CONFIG_ARM64_64K_PAGES || true
fi

echo "Applying defaults (olddefconfig)"
make olddefconfig

echo "Start kernel build (Image, dtbs, modules) - jobs=$JOBS"
make -j"$JOBS" Image dtbs modules

echo "Installing modules to temporary staging area"
TMP_MODS=/tmp/rpi_modules
rm -rf "$TMP_MODS"
mkdir -p "$TMP_MODS"
make INSTALL_MOD_PATH="$TMP_MODS" modules_install

echo "Collecting outputs to $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/boot"
mkdir -p "$OUTPUT_DIR/boot/overlays"
mkdir -p "$OUTPUT_DIR/modules/lib"

# Kernel image: copy arch/arm64/boot/Image as kernel8.img (RPi expects kernel8.img for 64-bit)
if [ -f arch/arm64/boot/Image ]; then
    cp -a arch/arm64/boot/Image "$OUTPUT_DIR/boot/kernel8.img"
fi

# Also copy any built zImage / fitImage if present (best-effort)
for f in arch/arm64/boot/*Image* arch/arm64/boot/zImage; do
    [ -e "$f" ] || continue
    cp -a "$f" "$OUTPUT_DIR/boot/" || true
done

# Device tree blobs
if [ -d arch/arm64/boot/dts/broadcom ]; then
    cp -a arch/arm64/boot/dts/broadcom/*.dtb "$OUTPUT_DIR/boot/" 2>/dev/null || true
fi
if [ -d arch/arm64/boot/dts/overlays ]; then
    cp -a arch/arm64/boot/dts/overlays/* "$OUTPUT_DIR/boot/overlays/" 2>/dev/null || true
fi

# Modules
if [ -d "$TMP_MODS/lib/modules" ]; then
    cp -a "$TMP_MODS/lib" "$OUTPUT_DIR/modules/"
fi

# Create small helper files the installer script expects
cat > "$OUTPUT_DIR/boot/config_snippet.txt" <<'EOF'
# PREEMPT_RT recommended config snippet
# Add to /boot/config.txt to apply RT-friendly boot options
# Example:
# dtparam=audio=on
# disable_overscan=1
EOF

cat > "$OUTPUT_DIR/boot/cmdline_rt.txt" <<'EOF'
root=PARTUUID=PLACEHOLDER rw rootwait console=serial0,115200 console=tty1
isolcpus=1-3 nohz_full=1 rcu_nocbs=1-3
EOF

echo "Build finished. Outputs placed under $OUTPUT_DIR (boot/, modules/)"
echo "You can now exit; files will be available on the host at the mounted output directory."

exit 0
