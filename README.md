# Raspberry Pi 4 向け PREEMPT_RT カーネル導入ガイド

## 概要

このプロジェクトは、[Qiita 記事「【たぶん一番簡単】ほぼスクリプトでRaspberry Piのリアルタイムカーネル導入」](https://qiita.com/ring2/items/7a7fc00280f4e8ba6990)に基づき、Raspberry Pi 4 に mainline PREEMPT_RT カーネル（6.12.58+）を導入するプロセスをドキュメント化したものです。

このドキュメントの作成も含めてGithub Copilot

## 環境

- **開発環境**: WSL 上の Ubuntu 24.04
- **ターゲット**: Raspberry Pi 4 64-bit
- **カーネルバージョン**: 6.12.58-v8+（PREEMPT_RT 有効）
- **アーキテクチャ**: aarch64（ARM64）

## ディレクトリ構成

```
pi4_64/
  ├── Dockerfile              # Docker イメージ定義（RPi4 用）
  ├── docker_build.sh         # コンテナ内で実行するカーネルビルドスクリプト
  ├── build_rt_kernel.sh      # ホスト側からビルド実行スクリプト
  ├── install_rt_kernel.sh    # SD カード へのインストールスクリプト（参考用）
  └── rpi_rt_output/          # ビルド成果物（自動生成）
      ├── boot/               # カーネルイメージ、DTB、overlays
      └── modules/lib/modules # カーネルモジュール
```
## Qiita記事より作成したファイル

これらのファイルは記事のままです。

1. `Dockerfile`
2. `build_rt_kernel.sh`
3. `install_rt_kernel.sh`


## 実装したファイル

### 1. `docker_build.sh` — コンテナ内ビルドスクリプト

Docker コンテナ内で実行され、以下を行います:

- カーネルソースの `defconfig` 適用（RPi4: `bcm2711_defconfig`）
- `scripts/config` を使った PREEMPT_RT 設定の有効化
- `make Image dtbs modules` によるビルド
- モジュールインストール
- ビルド成果物を `/output`（ホストマウント）にコピー

**主な PREEMPT_RT 設定**:
```bash
scripts/config --enable CONFIG_PREEMPT_RT
scripts/config --enable CONFIG_HIGH_RES_TIMERS
scripts/config --set-val CONFIG_HZ 1000
scripts/config --enable CONFIG_IRQ_FORCED_THREADING
scripts/config --enable CONFIG_RCU_BOOST
scripts/config --enable CONFIG_NO_HZ_FULL
```

## ビルドプロセス

### ステップ 1: Docker イメージのビルド

```bash
cd pi4_64
docker build -t rpi4-rt-builder-6.12 .
```

### ステップ 2: カーネルビルド（ホスト側）

```bash
./build_rt_kernel.sh
```

このスクリプトが以下を実行します:
1. Docker イメージのビルド
2. コンテナを起動し、`docker_build.sh` を実行
3. ビルド成果物を `rpi_rt_output/` に取得

**ビルド時間**: 約 30 〜 60 分

**出力ディレクトリ**:
```
rpi_rt_output/
  ├── boot/
  │   ├── kernel8.img          # RPi4 用カーネルイメージ
  │   ├── *.dtb                # デバイスツリーバイナリ
  │   ├── cmdline_rt.txt       # RT 最適化向け cmdline テンプレート
  │   ├── config_snippet.txt   # config.txt 追記スニペット
  │   └── overlays/            # デバイスツリーオーバーレイ
  └── modules/lib/modules/6.12.58-v8+/   # カーネルモジュール
```

## インストール手順

### Phase 1: Boot ファイルの SD カードへのコピー（WSL）

#### 1.1 Dドライブをマウント

```bash
sudo mkdir -p /mnt/d
sudo mount -t drvfs D: /mnt/d
```

#### 1.2 Boot ファイルをバックアップしてコピー

```bash
OUT="$PWD/rpi_rt_output"
BOOT_MNT="/mnt/d"
TS=$(date +%Y%m%d_%H%M%S)

# バックアップ
sudo mkdir -p "$BOOT_MNT/backup_rt_$TS"
sudo cp -v "$BOOT_MNT"/kernel* "$BOOT_MNT"/config.txt "$BOOT_MNT"/cmdline.txt "$BOOT_MNT/backup_rt_$TS/" 2>/dev/null || true

# Boot ファイルをコピー
sudo cp -v "$OUT/boot/kernel8.img" "$BOOT_MNT/"
sudo cp -v "$OUT/boot/"*.dtb "$BOOT_MNT/" 2>/dev/null || true

# overlays をコピー
if [ -d "$OUT/boot/overlays" ] && [ -d "$BOOT_MNT/overlays" ]; then
  sudo cp -av "$OUT/boot/overlays/"* "$BOOT_MNT/overlays/" 2>/dev/null || true
fi

# cmdline テンプレートをコピー
sudo cp -v "$OUT/boot/cmdline_rt.txt" "$BOOT_MNT/cmdline_rt_template.txt"

# 同期
sync
```

### Phase 2: Module の Raspberry Pi への転送と インストール

#### 2.1 Symlink 削除（重要）

Docker のビルド過程で生成されたシンボリックリンク（/build/linux を指す）を削除します:

```bash
find ./rpi_rt_output/modules -type l -delete
```

#### 2.2 SCP で Raspberry Pi に転送

```bash
scp -r ./rpi_rt_output/modules/lib/modules hara41@192.168.10.117:/home/hara41/
```

（ユーザー名・IP アドレス・パスワードは環境に応じて変更してください）

#### 2.3 Raspberry Pi 上でモジュールをインストール

```bash
# Module が転送されたか確認
ls -la ~/modules/6.12.58-v8+

# システムにコピー
sudo cp -a ~/modules/* /lib/modules/

# Module 依存関係を更新
sudo depmod -a

# 同期
sudo sync

# 再起動
sudo reboot
```

## 検証

### カーネルバージョン確認

```bash
uname -r
# 出力例: 6.12.58-v8+

uname -a
# 出力例: Linux raspberrypi 6.12.58-v8+ #1 SMP PREEMPT_RT Fri Nov 21 19:12:08 UTC 2025 aarch64 GNU/Linux
```

### PREEMPT_RT 有効化確認

```bash
dmesg | grep -i preempt
# 出力例: [    0.000000] Linux version 6.12.58-v8+ ... #1 SMP PREEMPT_RT ...

# または
uname -a | grep PREEMPT_RT
```

### リアルタイム性能測定（cyclictest）

```bash
# rt-tests のインストール
sudo apt update
sudo apt install -y rt-tests

# 性能テスト実行
sudo cyclictest -t1 -p 80 -i 1000 -l 10000 -m
```

**出力例**:
```
T: 0 ( 1806) P:80 I:1000 C:  10000 Min:      3 Act:   22 Avg:   14 Max:      52
```

| 項目 | 値 | 意味 |
|------|-----|------|
| **Min** | 3 µs | 最小遅延 |
| **Avg** | 14 µs | 平均遅延 |
| **Max** | 52 µs | 最大遅延（重要） ✅ |

- **評価**: Max 52 µs は非常に良好。リアルタイム用途に適している。

## トラブルシューティング

＊作者が

### 問題: SCP でシンボリックリンクエラー
**原因**: Docker のビルド時に生成された symlink が WSL 環境で無効

**解決**:
```bash
find ./rpi_rt_output/modules -type l -delete
```

### 問題: SSH 接続時のパスワード入力エラー
**原因**: SSH キー認証未設定またはパスワード入力ミス

**解決**:
- Raspberry Pi の SSH パスワード認証が有効になっているか確認
- または SSH キーペアを生成して設定

### 問題: 新しいカーネルが起動しない
**原因**: `/boot/firmware/` のファイルが最新ではない、または cmdline.txt の PARTUUID が不正

**解決**:
1. SD を Windows に戻して `/mnt/d/kernel8.img` が最新か確認
2. 必要なら再コピー
3. PARTUUID が正しいか `/boot/firmware/cmdline_rt_template.txt` を確認
4. 再起動

## 参考資料

- [Qiita: 【たぶん一番簡単】ほぼスクリプトでRaspberry Piのリアルタイムカーネル導入](https://qiita.com/ring2/items/7a7fc00280f4e8ba6990)
- [Raspberry Pi Linux カーネル公式リポジトリ](https://github.com/raspberrypi/linux)
- [PREEMPT_RT 公式ドキュメント](https://wiki.linuxfoundation.org/realtime/start)

## ファイル一覧

| ファイル | 役割 |
|---------|------|
| `Dockerfile` | Docker イメージ定義（PREEMPT_RT 設定含む） |
| `docker_build.sh` | コンテナ内カーネルビルドスクリプト |
| `build_rt_kernel.sh` | ホスト側からのビルド実行・制御スクリプト |
| `install_rt_kernel.sh` | 参考用：SD カードへのインストール手順（記事掲載版） |
| `rpi_rt_output/boot/` | ビルド成果物：kernel、dtb、overlays |
| `rpi_rt_output/modules/` | ビルド成果物：カーネルモジュール |

## まとめ

このセットアップにより、Raspberry Pi 4 上で以下が実現できます:

✅ PREEMPT_RT カーネル（6.12.58+）の導入  
✅ リアルタイム性能の確保（遅延 ~50 µs 以下）  
✅ ロボット制御やセンサーデータ収集などのリアルタイム用途に対応  
✅ Docker を使った再現性のあるクロスビルド  

新しいカーネルバージョンが必要な場合は、`Dockerfile` の `--branch rpi-6.12.y` を別のブランチ（例: `rpi-6.13.y`）に変更してビルドプロセスを繰り返すだけです。


## 謝辞
### Github Copilot
ほとんどのトラブルはすべて解決してくれました。
自力でやっていた前回に対して、1時間ほどで動作までたどり着けたのはCopilotのおかげです。

### Raspberry Pi 財団

---

**作成日**: 2025-11-22  
**対応環境**: WSL Ubuntu 24.04 + Raspberry Pi 4 64-bit  
**カーネルバージョン**: 6.12.58-v8+ PREEMPT_RT
