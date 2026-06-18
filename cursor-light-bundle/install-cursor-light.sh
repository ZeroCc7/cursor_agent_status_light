#!/bin/bash
# 在新 Mac 上安装 Cursor × CursorLight BLE 联动
# 用法：bash install-cursor-light.sh
# 可选：bash install-cursor-light.sh /path/to/cursor-light-bundle

set -euo pipefail

SRC="${1:-$(cd "$(dirname "$0")" && pwd)}"
CURSOR_DIR="${HOME}/.cursor"
DEST="${CURSOR_DIR}/hooks/cursor-light"
HOOKS_JSON="${CURSOR_DIR}/hooks.json"

echo "==> 源目录: $SRC"
echo "==> 目标:   $DEST"

mkdir -p "$DEST"

for f in agent-light.sh ble_gate.py cursor_light_ble_enhanced.py hook-*.sh; do
  if [[ -f "$SRC/$f" ]]; then
    cp "$SRC/$f" "$DEST/"
    chmod +x "$DEST/$f"
  fi
done

# 不覆盖已有调试状态
touch "$DEST/ble.log" 2>/dev/null || true
[[ -f "$DEST/state.json" ]] || echo '{}' >"$DEST/state.json"

if [[ -f "$SRC/hooks.json.snippet" ]]; then
  if [[ -f "$HOOKS_JSON" ]]; then
    echo ""
    echo "已存在 $HOOKS_JSON — 请手动合并 hooks.json.snippet 中的 hooks 段，或备份后覆盖。"
    cp "$SRC/hooks.json.snippet" "$DEST/hooks.json.snippet"
  else
    cp "$SRC/hooks.json.snippet" "$HOOKS_JSON"
    echo "已写入 $HOOKS_JSON"
  fi
else
  echo "未找到 hooks.json.snippet，请按 PDF 手册手动配置 hooks.json"
fi

echo ""
echo "==> 安装 Python 依赖 bleak ..."
python3 -m pip install --user bleak

echo ""
echo "==> 测试 BLE（需 CursorLight 已开机且在旁）..."
if python3 "$DEST/cursor_light_ble_enhanced.py" green; then
  echo "BLE 测试通过。"
else
  echo "BLE 测试未通过，请检查蓝牙权限与硬件（见 PDF 手册）。"
fi

echo ""
echo "完成。请完全退出并重启 Cursor，在 Settings → Hooks 确认已加载。"
echo "日志: $DEST/ble.log"
