# 会話履歴（PREEMPT_RT ビルド & Pi セットアップ）

**作成日:** 2025-11-22

以下は、このセッションで行ったやり取り・操作・重要なコマンドの記録です。

---

## 目次
- 会話の概要
- 実施した作業と追加したファイル
- 重要コマンドと出力の抜粋
- VS Code Server トラブルシュートの記録
- 次のアクション

---

## 会話の概要

- ユーザが提示した Qiita 記事（Raspberry Pi 用 PREEMPT_RT カーネルのビルド手順）を読み取り、内容を要約しました。
- Docker を使ったクロスビルド用のスクリプトやコンテナ内スクリプト（`pi4_64/docker_build.sh` など）を作成しました。
- ユーザはビルドを実行して成功を報告しました。出力は `rpi_rt_output/` に保存されました。
- SD カード（Windows の D: 経由、WSL）へ書き込み手順を案内し、`kernel8.img` や `.dtb` をコピーしました。
- モジュール転送時にシンボリックリンクが原因で `scp` が失敗したため、シンボリックリンク削除で対処しました。
- Pi 上でモジュールを `/lib/modules` に配置し `depmod -a` 後に再起動。`uname -a` で PREEMPT_RT カーネルが起動していることを確認しました。
- `rt-tests`（`cyclictest`）でレイテンシを確認。Min=3µs, Avg=14µs, Max=52µs の結果が得られ、良好なリアルタイム性能を確認しました。
- リポジトリを初期化し、`.gitignore` と `README.md`、サンプルの C ソース（`sample/`）を追加してコミットしました。
- VS Code Remote‑SSH のサーバインストールが不完全（`~/.vscode-server/bin` が存在しない）で止まる問題を調査中です。バックアップ `~/.vscode-server.bak_20251122_125700` を作成済みです。

## 実施した作業と追加したファイル

- 追加・作成した主なファイル:
  - `pi4_64/Dockerfile`
  - `pi4_64/build_rt_kernel.sh`
  - `pi4_64/docker_build.sh`
  - `pi4_64/install_rt_kernel.sh`
  - `.gitignore`
  - `README.md` (ワークスペースルート)
  - `sample/hello.c`, `sample/blink.c`, `sample/Makefile`, `sample/myapp.service`, `sample/README.md`

## 重要コマンドと出力の抜粋

- SD へカーネルと dtb をコピー（WSL 上で実行）:
```
sudo mount -t drvfs D: /mnt/d
OUT="$PWD/rpi_rt_output"
BOOT_MNT="/mnt/d"
sudo cp -v "$OUT/boot/kernel8.img" "$BOOT_MNT/"
sudo cp -v "$OUT/boot/"*.dtb "$BOOT_MNT/" 2>/dev/null || true
sync
```
コピー後のログ抜粋（例）:
```
'/home/hara4/PREEMPT_RT/pi4_64/rpi_rt_output/boot/kernel8.img' -> '/mnt/d/kernel8.img'
'/home/hara4/PREEMPT_RT/pi4_64/rpi_rt_output/boot/bcm2711-rpi-4-b.dtb' -> '/mnt/d/bcm2711-rpi-4-b.dtb'
... (省略)
```

- モジュール転送で発生した問題: `rpi_rt_output/modules` 内に `build -> /build/linux` のようなシンボリックリンクが存在し、`scp -r` が失敗しました。対処:
```
find ./rpi_rt_output/modules -type l -delete
```

- Pi 上での確認と導入:
```
ssh hara41@192.168.10.117
sudo cp -a ~/modules/* /lib/modules/
sudo depmod -a
sudo reboot
```
再起動後 `uname -a` による確認:
```
Linux raspberrypi 6.12.58-v8+ #1 SMP PREEMPT_RT ... aarch64
```

- `cyclictest` の実行例:
```
sudo apt install -y rt-tests
sudo cyclictest -t1 -p 80 -i 1000 -l 10000 -m

結果の抜粋: Min=3µs, Avg=14µs, Max=52µs
```

## VS Code Server トラブルシュート記録

- 問題: Remote‑SSH で接続するとサーバが "Listening on 127.0.0.1:XXXXX" を出力するが、プロセスが残らず `~/.vscode-server/bin` が存在しない不完全なインストールとなる。
- 既に実行済みの安全対処:
  - `~/.vscode-server` をバックアップ: `mv ~/.vscode-server ~/.vscode-server.bak_20251122_125700`
  - 再接続してインストールを再試行する手順を案内。

- ユーザによる現在の `~/.vscode-server` の状態（接続後）:
```
合計 19660
drwxr-x---  5 hara41 hara41     4096 11月 22 13:00 .
drwx------ 23 hara41 hara41     4096 11月 22 13:00 ..
-rw-------  1 hara41 hara41      559 11月 22 13:00 .cli.ac4cbdf48759c7d8c3eb91ffe6bb04316e263c57.log
drwxrwxr-x  3 hara41 hara41     4096 11月 22 13:00 cli
-rwxrwxr-x  1 hara41 hara41 20106904 11月 12 01:15 code-ac4cbdf48759c7d8c3eb91ffe6bb04316e263c57
drwx------  7 hara41 hara41     4096 11月 22 13:00 data
drwx------  4 hara41 hara41     4096 11月 22 13:00 extensions
ls: '/home/hara41/.vscode-server/bin' にアクセスできません: そのようなファイルやディレクトリはありません
```

- 推奨された追加確認コマンド（Pi 上での実行）:
```
ps aux | egrep 'vscode|code-server|server.sh' | grep -v grep || true
df -h ~
which tar xz curl || true
tar --version 2>/dev/null || true
xz --version 2>/dev/null || true
curl --version 2>/dev/null || true
stat -c '%A %U %G %n' ~/.vscode-server || true
tail -n 400 ~/.vscode-server/*.log 2>/dev/null || true
```

- 手動インストール（必要な場合）の手順（aarch64 の例）:
```
COMMIT=$(basename ~/.vscode-server/code-* 2>/dev/null | sed 's/^code-//')
mkdir -p ~/.vscode-server/bin/"$COMMIT"
cd /tmp
curl -fL "https://update.code.visualstudio.com/commit:${COMMIT}/server-linux-arm64/stable" -o /tmp/vscode-server.tar.gz
tar -xzf /tmp/vscode-server.tar.gz -C ~/.vscode-server/bin/"$COMMIT" --strip-components=1
chown -R $(id -u):$(id -g) ~/.vscode-server
ls -la ~/.vscode-server/bin/"$COMMIT"
```

## 次のアクション

- ユーザ側: 再接続してログ（`~/.vscode-server/*.log`）と `ls -la ~/.vscode-server/bin` の出力を貼る。
- 当方: ログ内容に基づき、必要なら `tar/xz` のインストールや手動展開、パーミッション修正の具体コマンドを提示します。

---

ファイル作成元: このファイルはユーザとの対話ログ・操作履歴・重要なコマンド抜粋を元に作成されました。
