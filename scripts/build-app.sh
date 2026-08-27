#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="$project_root/dist/蛛网小英雄.app"
binary_path="$project_root/.build/release/SpideyCursor"

swift build -c release --package-path "$project_root"

if [[ -d "$app_path" ]]; then
  rm -rf "$app_path"
fi

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_path" "$app_path/Contents/MacOS/SpideyCursor"
cp "$project_root/Resources/Info.plist" "$app_path/Contents/Info.plist"
codesign --force --deep --sign - "$app_path"

"$binary_path" --render-preview "$project_root/CharacterOptions.png"
echo "$app_path"
