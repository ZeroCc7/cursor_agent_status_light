#!/bin/bash
# Cursor AskQuestion / Questions 弹窗：等你选选项
DIR="$(cd "$(dirname "$0")" && pwd)"
cat >/dev/null
exec "$DIR/agent-light.sh" await-user
