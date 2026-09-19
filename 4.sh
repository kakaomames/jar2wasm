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

# 💡 0.15.0 の正しい最新アーティファクト名「teavm-tooling-cli」を指定した pom.xml を錬成
cat << 'EOF' > pom.xml
<project xmlns="http://apache.org" xmlns:xsi="http://w3.org"
  xsi:schemaLocation="http://apache.org http://apache.org">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>teavm-dependency-resolver</artifactId>
  <version>1.0-SNAPSHOT</version>

  <dependencies>
    <!-- 真の最新版を Maven Central から芋づる式に引きずり出す -->
    <dependency>
      <groupId>org.teavm</groupId>
      <artifactId>teavm-tooling-cli</artifactId>
      <version>0.15.0</version>
    </dependency>
  </dependencies>
</project>
EOF

rm -rf libs
mkdir -p libs

# 最新版の依存関係をすべて libs フォルダへ自動収集
mvn dependency:copy-dependencies -DoutputDirectory=libs

rm pom.xml

echo "All dependencies successfully downloaded to ./libs/"

mkdir -p ./target/teavm-c
mkdir -p ./dist/ll_files

echo "=== Step 4-2: Transpiling Java Classes to C Code ==="
# 💡 最新の 0.15.0 解析エンジンが走ります。
# 最新版なら --error-policy WARNING もしっかり受け付けてくれます！
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
