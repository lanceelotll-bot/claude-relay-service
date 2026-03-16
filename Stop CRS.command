#!/bin/bash
set -euo pipefail

cd "/Users/wamg/Documents/test3/CRS-local"
bash scripts/dev-stop.sh

echo
echo "CRS local services stopped."
echo
read -r -p "Press Enter to close..."
