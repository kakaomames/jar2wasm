#!/bin/bash
set -e

# 1. 引数からバージョンを受け取る（指定がなければデフォルトで 26.3）
TARGET_VERSION=${1:-"26.3"}

echo "========================================="
echo " Minecraft WASM Pipeline: Step 2"
echo " Target Version: $TARGET_VERSION"
echo "========================================="

if [ ! -f "id.json" ] || [ ! -f "url.json" ]; then
    echo "Error: id.json または url.json が見つかりません。先に 1.sh を実行してください。"
    exit 1
fi

# 2. id.json から行番号を特定
LINE_NUM=$(grep -n "\"$TARGET_VERSION\"" id.json | head -n 1 | cut -d: -f1 || true)

if [ -z "$LINE_NUM" ]; then
    echo "Error: 指定されたバージョン '$TARGET_VERSION' が見つかりませんでした。"
    exit 1
fi

# 3. url.json から URL を抜き出す
RAW_URL=$(head -n "$LINE_NUM" url.json | tail -n 1)
V_JSON_URL=$(echo "$RAW_URL" | tr -d '"' | tr -d ' ' | tr -d ',')

# 4. バージョン名がついた JSON ファイルとしてダウンロード！
echo "=== Step 2-2: Downloading ${TARGET_VERSION}.json ==="
curl -sSL "$V_JSON_URL" -o "${TARGET_VERSION}.json"

echo "Success: ${TARGET_VERSION}.json downloaded."
echo "Next: run ./3.sh $TARGET_VERSION to modify and download jars."
