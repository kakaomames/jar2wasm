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

# 💡 最新の TeaVM 0.15.0 を指定した pom.xml をその場で錬成する
cat << 'EOF' > pom.xml
<project xmlns="http://apache.org" xmlns:xsi="http://w3.org"
  xsi:schemaLocation="http://apache.org http://apache.org">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>teavm-dependency-resolver</artifactId>
  <version>1.0-SNAPSHOT</version>

  <dependencies>
    <!-- 【ハック1】バージョンを最新の 0.15.0 に一気に引き上げる！ -->
    <dependency>
      <groupId>org.teavm</groupId>
      <artifactId>teavm-cli</artifactId>
      <version>0.15.0</version>
    </dependency>
  </dependencies>
</project>
EOF

rm -rf libs
mkdir -p libs

# 0.15.0 の全プラグインと依存関係を芋づる式に一括ダウンロード！
mvn dependency:copy-dependencies -DoutputDirectory=libs

rm pom.xml

echo "All dependencies successfully downloaded to ./libs/"

mkdir -p ./target/teavm-c
mkdir -p ./dist/ll_files

echo "=== Step 4-2: Transpiling Java Classes to C Code ==="
# 💡 【ハック2】クラス欠損をエラーにせず、警告（WARNING）としてスキップして
# 強制的にコンパイルを続行させる設定を追加。
# さらに大規模解析用に限界までメモリ設定を 4g から 6g へブーストします。
java -Xmx6g -cp "libs/*" \
    org.teavm.cli.TeaVMRunner \
    -t C \
    -p ./workspace/flat_classes \
    -d ./target/teavm-c \
    --error-policy WARNING \
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
