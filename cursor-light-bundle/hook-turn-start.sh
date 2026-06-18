#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cat >/dev/null
exec "$DIR/agent-light.sh" turn-start
