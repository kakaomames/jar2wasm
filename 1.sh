curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json -o v-m.json
jq . v-m.json > version.json
echo "[" > id.json
echo "[" > type.json
echo "[" > url.json
jq .versions[].id version.json >> id.json
jq .versions[].url version.json >> url.json
jq .versions[].type version.json >> type.json


echo "]" >> id.json
echo "]" >> type.json
echo "]" >> url.json
