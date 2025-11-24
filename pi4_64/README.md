# 使用方法
下記のスクリプトを実行してください。ビルドまで完了します。

```bash
./run_docker.sh
```

## 実行時の問題

docker buildを実行しますが、ここでエラーが出ます。

``` docker
docker build -t rpi-rt-builder .
```

原因はビルド用のシェルスクリプトが無いことです。

``` bash
hara4@ghostbear7:~/PREEMPT_RT/pi4_64$ docker build -t rpi-rt-builder .
[+] Building 0.9s (10/11)                                                               
 => => transferring context: 2B                                                                                                                                                             0.0s
 => CACHED [2/7] RUN apt-get update && apt-get install -y     git     bc     bison     flex     libssl-dev     make     libc6-dev     libncurses5-dev     crossbuild-essential-arm64     g  0.0s
 => CACHED [3/7] WORKDIR /build                                                                                                                                                             0.0s
 => CACHED [4/7] RUN git clone --depth=1 --branch rpi-6.12.y https://github.com/raspberrypi/linux                                                                                           0.0s
 => CACHED [5/7] RUN cd linux &&     echo "Configuring PREEMPT_RT kernel for Raspberry Pi 4 (6.12+)" &&     make bcm2711_defconfig &&     echo "Enabling mainline PREEMPT_RT features..."   0.0s
 => ERROR [6/7] COPY docker_build.sh /build/                  
```
