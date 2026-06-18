#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
_stdin="$(cat)"
[[ -n "$_stdin" ]] && export HOOK_INPUT="$_stdin"
exec "$DIR/agent-light.sh" plan-detect
