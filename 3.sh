#!/bin/bash
set -e

# 引数からバージョンを受け取る（指定がなければデフォルトで 26.3）
TARGET_VERSION=${1:-"26.3"}
JSON_FILE="${TARGET_VERSION}.json"

echo "========================================="
echo " Minecraft WASM Pipeline: Step 3 (with jq)"
echo " Target Version: $TARGET_VERSION"
echo " Target File:    $JSON_FILE"
echo "========================================="

# 2.sh が落とした JSON ファイルが存在するか確認
if [ ! -f "$JSON_FILE" ]; then
    echo "Error: $JSON_FILE が見つかりません。先に 2.sh を実行してください。"
    exit 1
fi

# -------------------------------------------------------------
# 💡 【フェーズ1】ダウンロードした JSON を jq でいじる・加工する
# -------------------------------------------------------------
echo "=== Step 3-1: Modifying ${JSON_FILE} ==="
cp "$JSON_FILE" "${JSON_FILE}.bak"


# -------------------------------------------------------------
# 📦 【フェーズ2】jq で URL を抽出して一括ダウンロード＆マージ
# -------------------------------------------------------------
# 全クラスを1箇所に平坦化して集めるための作業フォルダ
MERGE_DIR="./workspace/flat_classes"
mkdir -p "$MERGE_DIR"

# ① "downloads" タグから client.jar の URL を正確にピンポイント抽出
echo "=== Step 3-2: Processing 'downloads' (client.jar) ==="
CLIENT_JAR_URL=$(jq -r '.downloads.client.url // empty' "$JSON_FILE")

if [ -n "$CLIENT_JAR_URL" ]; then
    echo "Downloading client.jar from: $CLIENT_JAR_URL"
    curl -sSL "$CLIENT_JAR_URL" -o client.jar
    
    echo "Extracting client.jar to flat workspace..."
    unzip -q -o client.jar -d "$MERGE_DIR"
    rm client.jar
else
    echo "Warning: client.jar の URL が見つかりませんでした。"
fi

# ② "libraries" タグから、外部Javaライブラリの URL を配列から全自動で抽出
echo "=== Step 3-3: Processing 'libraries' (External JARs) ==="
jq -r '.libraries[].downloads.artifact | select(. != null) | .url // empty' "$JSON_FILE" | while read -r lib_url; do
    echo "Merging library: $lib_url"
    
    # 一時ファイルとしてダウンロードしてその場で上書き解凍
    curl -sSL "$lib_url" -o temp_lib.jar
    unzip -q -o temp_lib.jar -d "$MERGE_DIR"
    rm temp_lib.jar
done

echo "========================================="
echo " SUCCESS! All program classes are merged into:"
echo " $MERGE_DIR"
echo "========================================="
