curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json -o v-m.json
jq. v-m.json > version.json
