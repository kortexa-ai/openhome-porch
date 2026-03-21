#!/bin/bash
set -e
cd /Users/francip/src/openhome-porch
swift build -c release 2>&1
exec .build/release/Porch
