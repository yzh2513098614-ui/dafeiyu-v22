#!/usr/bin/env bash
set -e
cd -- "$(dirname -- "$0")"
exec "${GODOT_BIN:-godot}" --path "$PWD"
