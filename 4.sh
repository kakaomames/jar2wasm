#!/bin/bash
set -e

TARGET_VERSION=${1:-"26.3"}

echo "========================================="
echo " Minecraft WASM Pipeline: Step 4"
echo " Transforming Class Mountain to LLVM IR"
echo "========================================="

if [ ! -d "./workspace/flat_classes" ]; then
    echo "Error: ./workspace/flat_classes が見つかりません。先に 3.sh を動かしてください。"
    exit 1
fi

echo "=== Step 4-1: Preparing TeaVM and Commons-CLI ==="

PROTO="https:"
HOST="repo1.maven.org"
P1="maven2"

P2_TV="org"
P3_TV="teavm"
P4_TV="teavm-cli"
TEAVM_VERSION="0.13.1"
TEAVM_JAR="teavm-cli-${TEAVM_VERSION}-all.jar"
TEAVM_URL="${PROTO}//${HOST}/${P1}/${P2_TV}/${P3_TV}/${P4_TV}/${TEAVM_VERSION}/${TEAVM_JAR}"

P2_CC="commons-cli"
P3_CC="commons-cli"
CLI_VERSION="1.9.0"
CLI_JAR="commons-cli-${CLI_VERSION}.jar"
CLI_URL="${PROTO}//${HOST}/${P1}/${P2_CC}/${P3_CC}/${CLI_VERSION}/${CLI_JAR}"

if [ ! -f "$TEAVM_JAR" ]; then
    echo "Downloading TeaVM CLI..."
    curl -sSL "$TEAVM_URL" -o "$TEAVM_JAR"
fi

if [ ! -f "$CLI_JAR" ]; then
    echo "Downloading Missing Dependency (Commons-CLI)..."
    curl -sSL "$CLI_URL" -o "$CLI_JAR"
fi

mkdir -p ./target/teavm-c
mkdir -p ./dist/ll_files

echo "=== Step 4-2: Transpiling Java Classes to C Code ==="
# 【修正ポイント】
# -t C          : ターゲットにC言語を指定
# -p ...        : クラスパスを指定
# -d ...        : 出力先ディレクトリを指定
# 一番最後      : マイクラのメインクラスを直接配置
java -Xmx4g -cp "${TEAVM_JAR}:${CLI_JAR}" \
    org.teavm.cli.TeaVMRunner \
    -t C \
    -p ./workspace/flat_classes \
    -d ./target/teavm-c \
    net.minecraft.client.main.Main

echo "=== Step 4-3: Compiling C Code to LLVM IR (.ll) ==="
if [ -f "./target/teavm-c/main.c" ]; then
    clang -S -emit-llvm ./target/teavm-c/main.c -o ./dist/ll_files/minecraft_${TARGET_VERSION}.ll
    echo "=================================================="
    echo " 🎉 🎉 🎉 SUCCESS !!! 🎉 🎉 🎉"
    echo " ./dist/ll_files/minecraft_${TARGET_VERSION}.ll"
    echo "=================================================="
else
    echo "Error: TeaVM が main.c の生成に失敗しました。"
    exit 1
fi
