#!/bin/bash
set -e
cd "$(dirname "$0")"

if [ "$1" = "--dev" ]; then
    ./build.sh --debug
else
    ./build.sh
fi

exec Porch.app/Contents/MacOS/Porch
