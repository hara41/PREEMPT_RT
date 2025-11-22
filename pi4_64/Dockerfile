FROM ubuntu:22.04

# 非対話的インストールのため
ENV DEBIAN_FRONTEND=noninteractive

# 必要なパッケージをインストール
RUN apt-get update && apt-get install -y \
    git \
    bc \
    bison \
    flex \
    libssl-dev \
    make \
    libc6-dev \
    libncurses5-dev \
    crossbuild-essential-arm64 \
    gcc-aarch64-linux-gnu \
    wget \
    xz-utils \
    device-tree-compiler \
    python3 \
    rsync \
    kmod \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /build

# クロスコンパイル用の環境変数（64bit ARM用）
ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-
ENV KERNEL=kernel8

# Raspberry Pi カーネルソースをクローン（6.12系 - RPi4対応）
RUN git clone --depth=1 --branch rpi-6.12.y https://github.com/raspberrypi/linux

# カーネル設定（6.12系メインラインPREEMPT_RT - RPi4用）
RUN cd linux && \
    echo "Configuring PREEMPT_RT kernel for Raspberry Pi 4 (6.12+)" && \
    make bcm2711_defconfig && \
    echo "Enabling mainline PREEMPT_RT features..." && \
    # エキスパートモードを有効化
    scripts/config --enable CONFIG_EXPERT && \
    # プリエンプションモデルを確実に設定
    scripts/config --disable CONFIG_PREEMPT_NONE && \
    scripts/config --disable CONFIG_PREEMPT_VOLUNTARY && \
    scripts/config --disable CONFIG_PREEMPT && \
    scripts/config --enable CONFIG_PREEMPT_RT && \
    # 基本RT設定
    scripts/config --enable CONFIG_HIGH_RES_TIMERS && \
    scripts/config --set-val CONFIG_HZ 1000 && \
    scripts/config --enable CONFIG_IRQ_FORCED_THREADING && \
    # RPi4では安全なRCU設定も有効化可能
    scripts/config --enable CONFIG_RCU_BOOST && \
    scripts/config --enable CONFIG_NO_HZ_FULL && \
    # 設定を適用
    make olddefconfig && \
    echo "=== RPi4 PREEMPT_RT Configuration Check ===" && \
    if grep -q "CONFIG_PREEMPT_RT=y" .config && ! grep -q "CONFIG_PREEMPT=y" .config; then \
        echo "✓ SUCCESS: PREEMPT_RT is properly configured for RPi4!"; \
    else \
        echo "✗ FAILED: PREEMPT_RT configuration failed!"; \
        grep -E "CONFIG_PREEMPT.*=" .config; \
        exit 1; \
    fi

# ビルドスクリプトをコピー
COPY docker_build.sh /build/
RUN chmod +x /build/docker_build.sh

CMD ["/build/docker_build.sh"]
