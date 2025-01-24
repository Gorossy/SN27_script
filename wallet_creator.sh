#!/bin/bash
set -euo pipefail

COLDKEY_SEED="${COLDKEY_SEED:-}"
HOTKEY_SEED="${HOTKEY_SEED:-}"

# Absolute path to `btcli` in the venv
BTCLI="/home/ubuntu/venv/bin/btcli"

echo "==> Installing expect"
sudo apt-get update -y
sudo apt-get install -y expect

##############################################
# Coldkey
##############################################
if [[ -z "$COLDKEY_SEED" ]]; then
  echo "No COLDKEY_SEED provided; skipping coldkey creation."
else
  echo "Creating /tmp/coldkey.expect..."
  cat <<EOF >/tmp/coldkey.expect
#!/usr/bin/expect -f

spawn $BTCLI wallet regen_coldkey --mnemonic $COLDKEY_SEED

# 1) "Enter wallet name (default):"
expect -re "Enter wallet name.*"
send "\r"

# 2) "Specify password for key encryption"
expect -re "Specify password for key encryption.*"
send "Undertaker2025123\r"

# 3) "Retype your password"
expect -re "Retype your password.*"
send "Undertaker2025123\r"
send "\r"
# Let user continue if there's anything left (EOF or additional lines)
interact
EOF

  chmod +x /tmp/coldkey.expect

  echo "==> Running coldkey.expect..."
  /tmp/coldkey.expect || echo "Failed to create coldkey"
  rm -f /tmp/coldkey.expect
fi

##############################################
# Hotkey
##############################################
if [[ -z "$HOTKEY_SEED" ]]; then
  echo "No HOTKEY_SEED provided; skipping hotkey creation."
else
  echo "Creating /tmp/hotkey.expect..."
  cat <<EOF >/tmp/hotkey.expect
#!/usr/bin/expect -f

spawn $BTCLI wallet regen_hotkey --mnemonic $HOTKEY_SEED

# 1) "Enter wallet name (default):"
expect -re "Enter wallet name.*"
send "\r"

# 2) "Enter hotkey name (default):"
# Some versions prompt for the hotkey name too
expect -re "Enter hotkey name.*"
send "\r"

# 3) "Specify password for key encryption"
expect -re "Specify password for key encryption.*"
send "Undertaker2025123\r"

# 4) "Retype your password"
expect -re "Retype your password.*"
send "Undertaker2025123\r"
send "\r"
interact
EOF

  chmod +x /tmp/hotkey.expect

  echo "==> Running hotkey.expect..."
  /tmp/hotkey.expect || echo "Failed to create hotkey"
  rm -f /tmp/hotkey.expect
fi

echo "==> wallet_creator.sh done"
