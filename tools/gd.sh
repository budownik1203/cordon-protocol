#!/bin/bash
# Uruchamia skrypt testowy w trybie headless z limitem czasu: tools/gd.sh tests/gen_test.gd [sekundy] [args...]
GODOT=${GODOT:-godot}
SCRIPT=$1; T=${2:-120}; shift 2
timeout "$T" "$GODOT" --headless --fixed-fps 60 --path "$(dirname "$0")/.." --script "res://$SCRIPT" -- "$@" 2>&1
