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

echo "=== Step 4-1: Resolving TeaVM Dependencies via Maven ==="

# 依存関係を一時的に集めるフォルダを作成
mkdir -p libs

# 【ここが核心】Mavenを使って teavm-cli とその内部プラグイン(classlib等)をすべて一括ダウンロード！
# 0.13.1 をターゲットにして、必要な関連JARを全部 libs フォルダに叩き込みます
mvn dependency:copy-dependencies \
  -Dartifact=org.teavm:teavm-cli:0.13.1:jar \
  -DoutputDirectory=libs \
  -Dtransitive=true

echo "All dependencies downloaded to ./libs/"

mkdir -p ./target/teavm-c
mkdir -p ./dist/ll_files

echo "=== Step 4-2: Transpiling Java Classes to C Code ==="
# ドキュメントの指示通り、"libs/*" でフォルダ内の全JARをクラスパスに繋いで一気呵成に起動！
java -Xmx4g -cp "libs/*" \
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
