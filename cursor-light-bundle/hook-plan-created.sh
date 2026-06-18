#!/bin/bash
# CreatePlan 工具成功后会进入 Review Plan / 等 Build
DIR="$(cd "$(dirname "$0")" && pwd)"
_stdin="$(cat)"
[[ -n "$_stdin" ]] && export HOOK_INPUT="$_stdin"
exec "$DIR/agent-light.sh" plan-created
