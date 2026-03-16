#!/bin/bash
set -euo pipefail

cd "/Users/wamg/Documents/test3/CRS-local"
bash scripts/dev-status.sh

echo
read -r -p "Press Enter to close..."
