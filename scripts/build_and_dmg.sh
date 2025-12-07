#!/usr/bin/env bash
# 自动化构建并生成 DMG 的脚本
# Usage: ./build_and_dmg.sh [-p project] [-s scheme] [-c configuration] [-o output_dir] [--app-name name] [--dry-run] [--clean]
# 默认会尝试构建 SwiftBmo/SwiftBmo.xcodeproj 的 SwiftBmo scheme，Release 配置

set -euo pipefail

PROG_NAME=$(basename "$0")
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# Try to auto-detect a top-level project/workspace. Prefer .xcworkspace then .xcodeproj.
PROJECT_DEFAULT=""
if [[ -d "$ROOT_DIR" ]]; then
  # prefer workspace
  if compgen -G "$ROOT_DIR/*.xcworkspace" >/dev/null; then
    PROJECT_DEFAULT=$(ls "$ROOT_DIR"/*.xcworkspace | head -n1)
  elif compgen -G "$ROOT_DIR/*.xcodeproj" >/dev/null; then
    PROJECT_DEFAULT=$(ls "$ROOT_DIR"/*.xcodeproj | head -n1)
  fi
fi
if [[ -z "$PROJECT_DEFAULT" ]]; then
  # fallback to previous nested location (compat)
  PROJECT_DEFAULT="$ROOT_DIR/SwiftBmo/SwiftBmo.xcodeproj"
fi
# Prefer the known top-level SwiftBmo.xcodeproj if it exists; otherwise try to find any .xcworkspace or .xcodeproj
if [[ -d "$ROOT_DIR/SwiftBmo.xcodeproj" ]]; then
  PROJECT_DEFAULT="$ROOT_DIR/SwiftBmo.xcodeproj"
elif compgen -G "$ROOT_DIR/*.xcworkspace" >/dev/null; then
  PROJECT_DEFAULT=$(ls "$ROOT_DIR"/*.xcworkspace | head -n1)
elif compgen -G "$ROOT_DIR/*.xcodeproj" >/dev/null; then
  PROJECT_DEFAULT=$(ls "$ROOT_DIR"/*.xcodeproj | head -n1)
else
  PROJECT_DEFAULT="$ROOT_DIR/SwiftBmo/SwiftBmo.xcodeproj"
fi

SCHEME_DEFAULT="SwiftBmo"
CONFIG_DEFAULT="Release"
OUTPUT_DIR_DEFAULT="$ROOT_DIR/dist"
DRY_RUN=0
CLEAN=0
APP_NAME="SwiftBmo"

print_help() {
  cat <<EOF
$PROG_NAME - 自动构建并生成 macOS 应用的 DMG

用法:
  $PROG_NAME [-p project] [-s scheme] [-c configuration] [-o output_dir] [--app-name name] [--dry-run] [--clean]

选项:
  -p PATH        Xcode project (.xcodeproj) 路径，默认: $PROJECT_DEFAULT
  -s SCHEME      Xcode scheme，默认: $SCHEME_DEFAULT
  -c CONFIG      Build 配置 (Debug/Release)，默认: $CONFIG_DEFAULT
  -o DIR         输出目录，默认: $OUTPUT_DIR_DEFAULT
  --app-name     生成的 .app 名称（不带 .app），默认: $APP_NAME
  --dry-run      仅打印将要执行的命令，不实际运行
  --clean        在构建前执行 xcodebuild clean
  -h, --help     显示此帮助并退出

示例:
  $PROG_NAME -p SwiftBmo/SwiftBmo.xcodeproj -s SwiftBmo -c Release

注意:
  - 该脚本依赖 xcodebuild 与 hdiutil。若你使用自动签名/导出，需要在环境中配置签名相关设置。
  - 如果你需要签名并生成可分发的 DMG，请在 Xcode 项目中配置好签名或扩展此脚本以传入导出选项 plist。
EOF
}

# Parse options
PROJECT="$PROJECT_DEFAULT"
SCHEME="$SCHEME_DEFAULT"
CONFIG="$CONFIG_DEFAULT"
OUTPUT_DIR="$OUTPUT_DIR_DEFAULT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p) PROJECT="$2"; shift 2;;
    -s) SCHEME="$2"; shift 2;;
    -c) CONFIG="$2"; shift 2;;
    -o) OUTPUT_DIR="$2"; shift 2;;
    --app-name) APP_NAME="$2"; shift 2;;
    --dry-run) DRY_RUN=1; shift 1;;
    --clean) CLEAN=1; shift 1;;
    -h|--help) print_help; exit 0;;
    *) echo "未知选项: $1"; print_help; exit 1;;
  esac
done

run_cmd() {
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "+ $*"
  else
    echo "+ $*"
    eval "$@"
  fi
}

# sanity checks
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "错误: xcodebuild 未找到，请在 macOS 上安装 Xcode 或命令行工具。"
  exit 2
fi
if ! command -v hdiutil >/dev/null 2>&1; then
  echo "错误: hdiutil 未找到。该脚本只能在 macOS 上运行。"
  exit 2
fi

echo "项目: $PROJECT"
echo "Scheme: $SCHEME"
echo "配置: $CONFIG"
echo "输出: $OUTPUT_DIR"
echo "App 名称: $APP_NAME"

mkdir -p "$OUTPUT_DIR"

# Build locations
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
BUILD_PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIG"
APP_PATH="$BUILD_PRODUCTS_DIR/$APP_NAME.app"

# Optional clean
if [[ $CLEAN -eq 1 ]]; then
  run_cmd "xcodebuild -project '$PROJECT' -scheme '$SCHEME' clean"
fi

# Build
run_cmd "xcodebuild -project '$PROJECT' -scheme '$SCHEME' -configuration '$CONFIG' -derivedDataPath '$DERIVED_DATA' build"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry-run) 构建完成，若实际执行，.app 位置: $APP_PATH"
  exit 0
fi

if [[ ! -d "$APP_PATH" ]]; then
  # 有时 Products 路径中 scheme 名称可能不同或是使用 workspace，尝试在 DerivedData/Build/Products 下查找第一个 .app
  echo "未在预期位置找到 .app ($APP_PATH)。尝试在 DerivedData 中搜索 .app..."
  FOUND_APP=$(find "$DERIVED_DATA/Build/Products" -maxdepth 3 -type d -name "*.app" | head -n 1 || true)
  if [[ -z "$FOUND_APP" ]]; then
    echo "错误: 无法找到构建产物 (.app)。请检查 scheme 名称或使用 workspace 而非 project。"
    exit 3
  else
    APP_PATH="$FOUND_APP"
    echo "找到 .app: $APP_PATH"
  fi
fi

# Prepare staging
TMPDIR=$(mktemp -d)
STAGING="$TMPDIR/Volume"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"

# Create DMG
VOLNAME="$APP_NAME"
OUT_DMG="$OUTPUT_DIR/${APP_NAME}.dmg"

# Remove existing output
if [[ -f "$OUT_DMG" ]]; then
  echo "移除已存在的 DMG: $OUT_DMG"
  rm -f "$OUT_DMG"
fi

echo "开始生成 DMG -> $OUT_DMG"
run_cmd "hdiutil create -volname '$VOLNAME' -srcfolder '$STAGING' -ov -format UDZO '$OUT_DMG'"

if [[ $DRY_RUN -eq 0 ]]; then
  echo "DMG 已生成: $OUT_DMG"
fi

# Cleanup
rm -rf "$TMPDIR"

exit 0
