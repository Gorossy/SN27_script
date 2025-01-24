#!/bin/bash
set -euo pipefail

# We can store or check environment variables from $COLDKEY_SEED, $HOTKEY_SEED, etc.
COLDKEY_SEED="${COLDKEY_SEED:-}"
HOTKEY_SEED="${HOTKEY_SEED:-}"

# Absolute path to `btcli` in the venv:
BTCLI="/home/ubuntu/venv/bin/btcli"

# 1) Install `expect` if not installed:
echo "==> Installing expect"
sudo apt-get update
sudo apt-get install -y expect

# 2) Check if seeds are provided:
if [[ -z "$COLDKEY_SEED" ]]; then
  echo "No COLDKEY_SEED provided; skipping coldkey creation."
else
  echo "Creating /tmp/coldkey.expect"
  cat <<EOF >/tmp/coldkey.expect
#!/usr/bin/expect -f

spawn $BTCLI wallet regen_coldkey --mnemonic $COLDKEY_SEED

expect "Enter wallet name (default):"
send "\r"

expect "Specify password for key encryption"
send "Undertaker2025123\r"

expect "Retype your password"
send "Undertaker2025123\r"

interact
EOF

  chmod +x /tmp/coldkey.expect

  echo "==> Running coldkey.expect"
  /tmp/coldkey.expect || echo "Failed to create coldkey"
  rm -f /tmp/coldkey.expect
fi