#!/bin/bash
set -e

# 引数からバージョンを受け取る
TARGET_VERSION=${1:-"26.3"}

echo "========================================="
echo " Minecraft WASM Pipeline: Step 4"
echo " Transforming Class Mountain to LLVM IR"
echo "========================================="

if [ ! -d "./workspace/flat_classes" ]; then
    echo "Error: ./workspace/flat_classes が見つかりません。先に 3.sh を動かしてください。"
    exit 1
fi

echo "=== Step 4-1: Preparing TeaVM Compiler ==="

# --- URLコンポーネントの完全分解 (スラッシュ分割スタイル) ---
PROTO="https:"
HOST="repo.maven.apache.org"
P1="maven2"
P2="org"
P3="teavm"
P4="cli"
TEAVM_VERSION="0.15.0"

# 各パーツを個別に定義して最後に組み立てる
TEAVM_JAR="cli-${TEAVM_VERSION}-all.jar"
TEAVMg_URL="${PROTO}//${HOST}/${P1}/${P2}/${P3}/${P4}/${TEAVM_VERSION}/${TEAVM_JAR}"
TEAVM_URL="https://repo1.maven.org/maven2/org/teavm/teavm-cli/0.13.1/teavm-cli-0.13.1-all.jar"

echo "Target URL: $TEAVM_URL"

if [ ! -f "$TEAVM_JAR" ]; then
    echo "Downloading TeaVM CLI..."
    curl -sSL "$TEAVM_URL" -o "$TEAVM_JAR"
fi

mkdir -p ./target/teavm-c
mkdir -p ./dist/ll_files

echo "=== Step 4-2: Transpiling Java Classes to C Code ==="
java -jar "$TEAVM_JAR" \
    -target c \
    -cp ./workspace/flat_classes \
    -main net.minecraft.client.main.Main \
    -d ./target/teavm-c \
    --minified false

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
