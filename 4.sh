#!/bin/bash
set -e

# 引数からバージョンを受け取る（指定がなければデフォルトで 26.3）
TARGET_VERSION=${1:-"26.3"}

echo "========================================="
echo " Minecraft WASM Pipeline: Step 4"
echo " Transforming Class Mountain to LLVM IR"
echo "========================================="

# 1. 前段の flat_classes がちゃんと作られているか防衛チェック
if [ ! -d "./workspace/flat_classes" ]; then
    echo "Error: ./workspace/flat_classes が見つかりません。先に 3.sh を動かしてください。"
    exit 1
fi

# 2. TeaVM CLI のスタンドアロン JAR を Maven リポジトリから落としてくる
echo "=== Step 4-1: Preparing TeaVM Compiler ==="
TEAVM_VERSION="0.15.0"
TEAVM_JAR="cli-${TEAVM_VERSION}-all.jar"
TEAVM_URL="https://apache.org{TEAVM_VERSION}/${TEAVM_JAR}"

if [ ! -f "$TEAVM_JAR" ]; then
    echo "Downloading TeaVM CLI..."
    curl -sSL "$TEAVM_URL" -o "$TEAVM_JAR"
fi

# 出力先フォルダの作成
mkdir -p ./target/teavm-c
mkdir -p ./dist/ll_files

# 3. 合体フォルダを TeaVM に食わせて、一撃で Cコード に翻訳する
echo "=== Step 4-2: Transpiling Java Classes to C Code ==="
# -cp: 3.shが作ったクラスの山を指定
# -main: 1.shが暴いたマイクラの起動メインクラスを指定
java -jar "$TEAVM_JAR" \
    -target c \
    -cp ./workspace/flat_classes \
    -main net.minecraft.client.main.Main \
    -d ./target/teavm-c \
    --minified false

echo "TeaVM: C Code successfully emitted."

# 4. 【本番】生成された Cコード に Clang をぶち込んで LLVM IR を抽出する！
echo "=== Step 4-3: Compiling C Code to LLVM IR (.ll) ==="
if [ -f "./target/teavm-c/main.c" ]; then
    # 以前のハック経験を活かせる場所です。
    # 必要に応じて最適化フラグ (-O2 や -O3) や、Wasm向けのターゲット指定を仕込めます
    clang -S -emit-llvm ./target/teavm-c/main.c -o ./dist/ll_files/minecraft_${TARGET_VERSION}.ll
    
    echo "=================================================="
    echo " 🎉 🎉 🎉 SUCCESS !!! 🎉 🎉 🎉"
    echo " Your Minecraft LLVM IR is ready at:"
    echo " ./dist/ll_files/minecraft_${TARGET_VERSION}.ll"
    echo "=================================================="
else
    echo "Error: TeaVM が main.c の生成に失敗しました。"
    exit 1
fi
