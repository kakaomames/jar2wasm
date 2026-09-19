#!/bin/bash
set -e

# 1. 引数からバージョンを受け取る（指定がなければデフォルトで 26.3）
TARGET_VERSION=${1:-"26.3"}

echo "========================================="
echo " Target Version: $TARGET_VERSION"
echo "========================================="

# 2. id.json の中から、指定したバージョンが「何行目」にあるかを grep -n で探す
# 例: "26.3" が含まれる行が 5行目なら「5:  "26.3"」のようになるので、コロンの前を切り出す
LINE_NUM=$(grep -n "\"$TARGET_VERSION\"" id.json | head -n 1 | cut -d: -f1 || true)

if [ -z "$LINE_NUM" ]; then
    echo "Error: 指定されたバージョン '$TARGET_VERSION' が id.json 内に見つかりませんでした。"
    exit 1
fi

echo "Version found at line number: $LINE_NUM"

# 3. url.json から、全く同じ行番号（LINE_NUM）のURLを head と tail でピンポイントでブチ抜く！
# ① まず head で上から LINE_NUM 行目までを切り出す
# ② 次に tail -n 1 で、その切り出した中の一番最後の行（＝目的の行）だけを取得する
RAW_URL=$(head -n "$LINE_NUM" url.json | tail -n 1)

# 前後の余計な文字（ダブルクォーテーション、スペース、カンマ）を綺麗にお掃除
V_JSON_URL=$(echo "$RAW_URL" | tr -d '"' | tr -d ' ' | tr -d ',')

echo "Extracted URL: $V_JSON_URL"

# 4. そのURLから個別メタデータをダウンロード
echo "=== Downloading v.json ==="
curl -sSL "$V_JSON_URL" -o v.json

# (この後に client.jar やライブラリのダウンロード・一括マージ処理が続きます)
