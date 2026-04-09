#!/bin/bash
set -euo pipefail

# Keep setup.sh aligned with setup1.sh so both public entry points are protected.
exec bash "$(dirname "$0")/setup1.sh"
