#!/bin/bash
# Cursor Agent BLE 红绿灯 — 核心逻辑（ble_gate.py 原子去重）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLE_LOG="${SCRIPT_DIR}/ble.log"
PYTHON="${CURSOR_LIGHT_PYTHON:-python3}"
BLE_SCRIPT="${SCRIPT_DIR}/cursor_light_ble_enhanced.py"
GATE="${SCRIPT_DIR}/ble_gate.py"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  exit 0
fi

if [[ -n "${HOOK_INPUT:-}" ]]; then
  INPUT="$HOOK_INPUT"
else
  INPUT="$(cat)"
fi

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] action=$ACTION $*" >>"$BLE_LOG"
}

gate_send() {
  local gate_action="$1"
  local mode="$2"
  local result
  result="$("$PYTHON" "$GATE" "$gate_action" "$mode" 2>/dev/null || echo "no:gate-fail")"
  if [[ "$result" != yes:* ]]; then
    log "skip ${result#no:} (want $mode)"
    return 0
  fi
  mode="${result#yes:}"
  log "send mode=$mode"
  nohup "$PYTHON" "$BLE_SCRIPT" "$mode" >>"$BLE_LOG" 2>&1 &
  disown 2>/dev/null || true
}

looks_like_plan_awaiting() {
  local text="$1"
  [[ -z "$text" ]] && return 1
  "$PYTHON" -c 'import re, sys
text = sys.stdin.read()
if not text.strip():
    raise SystemExit(1)
if re.search(
    r"已全部|全部完成|实施完成|落地完成|搞定了吗|"
    r"completed all|todos.*completed|Do not create them again",
    text,
    re.I,
):
    raise SystemExit(1)
has_artifact = bool(re.search(r"[\w./-]+\.plan\.md|\.cursor/plans/", text, re.I))
has_plan_boilerplate = bool(
    re.search(
        r"Do NOT edit the plan file|attached for your reference|"
        r"Do NOT edit the plan|计划文件本身",
        text,
        re.I,
    )
)
has_wait_cta = bool(
    re.search(
        r"回复[「\s\*]*执行计划|若认可.*(方案|计划).{0,40}(回复|执行)|"
        r"说[「\s]*执行计划[」\s]*即可|方可开始.*(实施|落地)|"
        r"unambiguously.*execute the plan",
        text,
        re.I,
    )
)
has_impl_attach = bool(
    re.search(r"Implement the plan as specified", text, re.I) and has_plan_boilerplate
)
if has_impl_attach and (has_artifact or has_plan_boilerplate):
    raise SystemExit(0)
if (has_artifact or has_plan_boilerplate) and has_wait_cta:
    raise SystemExit(0)
if has_artifact and re.search(r"执行计划", text) and re.search(
    r"回复|若认可|点\s*Build|Build\s*即可", text, re.I
):
    raise SystemExit(0)
# Plan 模式 Review Plan / 中文行程说明（未必带 .plan.md 正文）
if re.search(r"Review\s*Plan|CreatePlan", text, re.I):
    raise SystemExit(0)
if re.search(r"点\s*Build|点击\s*Build|Build\s*即可|等你.*Build", text, re.I):
    raise SystemExit(0)
if re.search(r"(一日游|行程|路线|攻略).{0,80}(计划|方案)", text, re.I):
    raise SystemExit(0)
raise SystemExit(1)
' <<<"$text"
}

is_plan_file_path() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  echo "$path" | grep -qiE '\.plan\.md$|/\.cursor/plans/'
}

set_awaiting_build() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, fcntl
from pathlib import Path
p = Path(__import__("sys").argv[1])
lock = p.parent / "state.lock"
lock.parent.mkdir(parents=True, exist_ok=True)
with open(lock, "w") as lf:
    fcntl.flock(lf, fcntl.LOCK_EX)
    data = json.loads(p.read_text()) if p.exists() else {}
    data["awaiting_build"] = True
    p.write_text(json.dumps(data, ensure_ascii=False))
    fcntl.flock(lf, fcntl.LOCK_UN)
PY
}

is_awaiting_build() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    d = json.loads(p.read_text())
    print("yes" if d.get("awaiting_build") else "no")
except Exception:
    print("no")
PY
}

state_get_phase() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    d = json.loads(p.read_text())
    print(d.get("turn_phase", "") or "")
except Exception:
    print("")
PY
}

clear_awaiting_build() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, fcntl
from pathlib import Path
p = Path(__import__("sys").argv[1])
lock = p.parent / "state.lock"
with open(lock, "w") as lf:
    fcntl.flock(lf, fcntl.LOCK_EX)
    data = json.loads(p.read_text()) if p.exists() else {}
    data.pop("awaiting_build", None)
    p.write_text(json.dumps(data, ensure_ascii=False))
    fcntl.flock(lf, fcntl.LOCK_UN)
PY
}

set_build_started() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, fcntl
from pathlib import Path
p = Path(__import__("sys").argv[1])
lock = p.parent / "state.lock"
with open(lock, "w") as lf:
    fcntl.flock(lf, fcntl.LOCK_EX)
    data = json.loads(p.read_text()) if p.exists() else {}
    data["build_started"] = True
    p.write_text(json.dumps(data, ensure_ascii=False))
    fcntl.flock(lf, fcntl.LOCK_UN)
PY
}

is_build_started() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    d = json.loads(p.read_text())
    print("yes" if d.get("build_started") else "no")
except Exception:
    print("no")
PY
}

set_plan_touched() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, fcntl
from pathlib import Path
p = Path(__import__("sys").argv[1])
lock = p.parent / "state.lock"
with open(lock, "w") as lf:
    fcntl.flock(lf, fcntl.LOCK_EX)
    data = json.loads(p.read_text()) if p.exists() else {}
    data["plan_touched"] = True
    p.write_text(json.dumps(data, ensure_ascii=False))
    fcntl.flock(lf, fcntl.LOCK_UN)
PY
}

is_plan_touched() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    d = json.loads(p.read_text())
    print("yes" if d.get("plan_touched") else "no")
except Exception:
    print("no")
PY
}

tool_target_path() {
  if ! command -v jq >/dev/null 2>&1 || [[ -z "${HOOK_INPUT:-}" ]]; then
    return 0
  fi
  jq -r '
    .tool_input.path // .tool_input.file_path // .tool_input.filePath //
    .tool_input.target_file // empty
  ' <<<"$HOOK_INPUT" 2>/dev/null || true
}

# 写 plan 文件不算「已 Build」；仅 Shell/删改等或写入非 plan 路径才算执行
is_exec_tool() {
  case "${1:-}" in
    Shell|Delete|ApplyPatch|EditNotebook|NotebookEdit|run_terminal_cmd|Task)
      return 0
      ;;
    Write|StrReplace)
      local p
      p="$(tool_target_path)"
      [[ -n "$p" ]] && ! is_plan_file_path "$p"
      ;;
    *)
      return 1
      ;;
  esac
}

tool_is_plan_write() {
  case "${1:-}" in
    Write|StrReplace) ;;
    *) return 1 ;;
  esac
  local p
  p="$(tool_target_path)"
  is_plan_file_path "$p"
}

# 本轮已写 plan 且尚未 Build 执行（用于 stop 早于 plan-detect 的兜底）
has_recent_plan_awaiting() {
  "$PYTHON" - "$SCRIPT_DIR/state.json" <<'PY'
import json, os, time
from pathlib import Path

state_path = Path(__import__("sys").argv[1])
try:
    data = json.loads(state_path.read_text())
except Exception:
    data = {}

now_ms = int(time.time() * 1000)
turn_ms = int(data.get("turn_started_ms") or 0)
window_ms = 8 * 60 * 1000
plans_dir = Path.home() / ".cursor" / "plans"
if not plans_dir.is_dir():
    raise SystemExit(1)

best_ms = 0
best_name = ""
for p in plans_dir.glob("*.plan.md"):
    try:
        mtime_ms = int(p.stat().st_mtime * 1000)
    except OSError:
        continue
    if now_ms - mtime_ms > window_ms:
        continue
    if turn_ms and mtime_ms < turn_ms - 3000:
        continue
    if mtime_ms > best_ms:
        best_ms = mtime_ms
        best_name = p.name

if best_ms:
    print(best_name)
    raise SystemExit(0)
raise SystemExit(1)
PY
}

# 仅「明显需要用户点 Allow」的终端命令才亮 alarm（只读类不亮）
needs_shell_confirmation() {
  local cmd="$1"
  [[ -z "$cmd" ]] && return 1
  "$PYTHON" -c 'import re, sys
cmd = sys.stdin.read().strip()
if not cmd:
    raise SystemExit(1)

parts = re.split(r"\s*&&\s*|\s*\|\|\s*|\s*;\s*", cmd)

RISKY = [
    r"^(mysql|psql|mongosh|redis-cli)\b",
    r"\b(curl|wget|nc|ssh|scp|rsync)\b",
    r"\b(rm|rmdir|chmod|chown|chgrp|kill|pkill|sudo)\b",
    r"\b(npm|npx|pnpm|yarn)\b",
    r"\bpip3?(\s+install|\s+uninstall)\b",
    r"\bgit\s+(commit|push|pull|fetch|reset|checkout|rebase|merge|stash|clean)\b",
    r"\b(bash|sh|zsh|fish)\b",
    r"\b(docker|kubectl|helm)\b",
    r"^\./",
    r"\b(mvn|gradle)\b",
    r"\b(java|node)\s+",
    r"python3?\s+[^\s-]",
    r">\s*",
    r">>\s*",
    r"\bsed\b.*-i",
    r"\btee\b",
]

SAFE = [
    r"^(ls|ll|pwd|echo|printf|cat|head|tail|less|more|wc|sort|uniq|file|stat|du|df|which|command|type)\b",
    r"^(grep|rg|find|awk)\b",
    r"^(test|true|false)\b",
    r"^git\s+(status|log|diff|show|branch|rev-parse|describe|shortlog)\b",
    r"^jq\b",
    r"^cd\s+",
    r"^sleep\s+",
]

def strip_env(s):
    return re.sub(r"^(\s*\w+=\S*\s*)+", "", s.strip())

def part_risky(part):
    core = strip_env(part)
    if not core:
        return False
    for p in RISKY:
        if re.search(p, core, re.I):
            return True
    for p in SAFE:
        if re.match(p, core, re.I):
            return False
    return False

if any(part_risky(p) for p in parts):
    raise SystemExit(0)
raise SystemExit(1)
' <<<"$cmd"
}

case "$ACTION" in
  idle)
    if [[ "$(is_awaiting_build)" == "yes" ]]; then
      gate_send stop-alarm alarm
      log "idle -> alarm (still awaiting Build)"
      exit 0
    fi
    gate_send idle green
    ;;
  turn-start)
    gate_send turn-start thinking
    ;;
  thinking)
    gate_send thinking thinking
    ;;
  await-user)
    gate_send await-user alarm
    log "await-user -> alarm (AskQuestion / Questions UI)"
    ;;
  busy)
    tool_name=""
    tool_path=""
    if command -v jq >/dev/null 2>&1 && [[ -n "${HOOK_INPUT:-}" ]]; then
      tool_name="$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
      tool_path="$(tool_target_path)"
    fi
    if tool_is_plan_write "$tool_name"; then
      set_plan_touched
      set_awaiting_build
      log "busy: plan write -> awaiting Build (tool=${tool_name}, path=${tool_path##*/})"
    # 用户已点 Build 开始执行：清除「等 Build」标记（非 CreatePlan 的工具）
    elif [[ "$(is_awaiting_build)" == "yes" && "$tool_name" != "CreatePlan" ]]; then
      clear_awaiting_build
      set_build_started
      log "busy: cleared awaiting_build, build_started (tool=${tool_name:-unknown})"
    elif is_exec_tool "$tool_name"; then
      set_build_started
      log "busy: build_started (exec tool=${tool_name}, path=${tool_path##*/})"
    fi
    gate_send busy busy
    ;;
  alarm-shell)
    # 已禁用：beforeShellExecution 无法区分「真弹 Allow」与「自动批准」
    log "alarm-shell disabled (no hook registered)"
    exit 0
    ;;
  plan-detect)
    if [[ "$(is_build_started)" == "yes" ]]; then
      log "plan-detect skip (build already started)"
      exit 0
    fi
    text=""
    if command -v jq >/dev/null 2>&1; then
      text="$(echo "$INPUT" | jq -r '.text // empty' 2>/dev/null || true)"
    else
      text="$("$PYTHON" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("text",""))' <<<"$INPUT" 2>/dev/null || true)"
    fi
    if looks_like_plan_awaiting "$text"; then
      set_plan_touched
      set_awaiting_build
      gate_send await-user alarm
      log "plan-detect awaiting_build=true -> alarm"
    fi
    ;;
  plan-file)
    if [[ "$(is_build_started)" == "yes" ]]; then
      log "plan-file skip (build already started)"
      exit 0
    fi
    fpath=""
    if command -v jq >/dev/null 2>&1; then
      fpath="$(echo "$INPUT" | jq -r '.file_path // empty' 2>/dev/null || true)"
    else
      fpath="$("$PYTHON" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("file_path",""))' <<<"$INPUT" 2>/dev/null || true)"
    fi
    if is_plan_file_path "$fpath"; then
      set_plan_touched
      set_awaiting_build
      gate_send await-user alarm
      log "plan-file awaiting_build=true path=${fpath##*/} -> alarm"
    fi
    ;;
  plan-created)
    set_plan_touched
    set_awaiting_build
    gate_send await-user alarm
    pname=""
    if command -v jq >/dev/null 2>&1; then
      pname="$(echo "$INPUT" | jq -r '.tool_input.name // .tool_input.plan // empty' 2>/dev/null | head -c 80 || true)"
    fi
    log "plan-created (CreatePlan) awaiting_build=true name=${pname:-unknown} -> alarm"
    ;;
  stop)
    status=""
    if command -v jq >/dev/null 2>&1; then
      status="$(echo "$INPUT" | jq -r '.status // empty' 2>/dev/null || true)"
    else
      status="$("$PYTHON" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("status",""))' <<<"$INPUT" 2>/dev/null || true)"
    fi
    log "stop status=$status stdin_len=${#INPUT}"
    case "$status" in
      completed)
        if [[ "$(is_build_started)" == "yes" ]]; then
          gate_send stop-success success
          log "stop -> success (build started)"
        elif [[ "$(is_awaiting_build)" == "yes" ]]; then
          gate_send stop-alarm alarm
          log "stop -> alarm (awaiting Build)"
        elif [[ "$(is_plan_touched)" == "yes" ]] || has_recent_plan_awaiting; then
          recent_plan=""
          recent_plan="$(has_recent_plan_awaiting 2>/dev/null || true)"
          set_awaiting_build
          gate_send stop-alarm alarm
          log "stop -> alarm (plan ready, await Build${recent_plan:+, file=$recent_plan})"
        else
          gate_send stop-success success
          log "stop -> success"
        fi
        ;;
      error|aborted)
        gate_send stop-error error
        ;;
      *)
        log "stop no mode change"
        ;;
    esac
    ;;
  denied)
    failure_type=""
    if command -v jq >/dev/null 2>&1; then
      failure_type="$(echo "$INPUT" | jq -r '.failure_type // empty' 2>/dev/null || true)"
    else
      failure_type="$("$PYTHON" -c 'import json,sys; d=json.load(sys.stdin); print(d.get("failure_type",""))' <<<"$INPUT" 2>/dev/null || true)"
    fi
    if [[ "$failure_type" == "permission_denied" ]]; then
      gate_send denied-thinking thinking
    else
      gate_send denied-error error
    fi
    ;;
  *)
    log "unknown action=$ACTION"
    ;;
esac

exit 0
