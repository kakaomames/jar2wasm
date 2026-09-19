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

# 💡 Mavenが完全に納得する、TeaVMの依存関係を書き込んだ pom.xml をその場で錬成する
cat << 'EOF' > pom.xml
<project xmlns="http://apache.org" xmlns:xsi="http://w3.org"
  xsi:schemaLocation="http://apache.org http://apache.org">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>teavm-dependency-resolver</artifactId>
  <version>1.0-SNAPSHOT</version>

  <dependencies>
    <!-- TeaVM CLI 本体と、それに紐づくすべての内部プラグインを引きずり出す -->
    <dependency>
      <groupId>org.teavm</groupId>
      <artifactId>teavm-cli</artifactId>
      <version>0.13.1</version>
    </dependency>
  </dependencies>
</project>
EOF

# 依存JARを格納するフォルダをクリアして作成
rm -rf libs
mkdir -p libs

# 【修正ポイント】pom.xmlの定義に従って、必要な全依存ライブラリを自動収集！
mvn dependency:copy-dependencies -DoutputDirectory=libs

# 使い終わった pom.xml は綺麗にお掃除
rm pom.xml

echo "All dependencies successfully downloaded to ./libs/"

mkdir -p ./target/teavm-c
mkdir -p ./dist/ll_files

echo "=== Step 4-2: Transpiling Java Classes to C Code ==="
# フォルダ内の全JARをクラスパスに繋いで TeaVMRunner を起動
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
