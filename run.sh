#!/bin/bash
set -e
cd "$(dirname "$0")"

# run.sh always builds debug with --skip-window
# Window is launched from source dir at runtime in dev mode
./build.sh --debug --skip-window

exec Porch.app/Contents/MacOS/Porch
