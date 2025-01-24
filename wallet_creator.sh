#!/bin/bash
set -euo pipefail

# --------------------------------------------------------------------------
# Usage: wallet_creator.sh <coldkey_seed> <hotkey_seed>
# Ejemplo de llamada:
#     ./wallet_creator.sh "mi coldkey seed ..." "mi hotkey seed ..."
#
# Este script crea automáticamente coldkey y hotkey usando `btcli` + `expect`.
# --------------------------------------------------------------------------

# Toma los argumentos (o en blanco si no se han pasado)
COLDKEY_SEED="${1:-}"
HOTKEY_SEED="${2:-}"

# Ruta absoluta a btcli dentro del entorno virtual
BTCLI="/home/ubuntu/venv/bin/btcli"

echo "==> Installing expect (para manejar prompts automáticamente)"
sudo apt-get update -y
sudo apt-get install -y expect

##############################################
# Coldkey
##############################################
if [[ -z "$COLDKEY_SEED" ]]; then
  echo "No COLDKEY_SEED provided; skipping coldkey creation."
else
  echo "==> Creando /tmp/coldkey.expect..."
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

  echo "==> Ejecutando coldkey.expect..."
  /tmp/coldkey.expect || echo "==> Error: Falló la creación de coldkey"
  rm -f /tmp/coldkey.expect
fi


##############################################
# Hotkey
##############################################
if [[ -z "$HOTKEY_SEED" ]]; then
  echo "No HOTKEY_SEED provided; skipping hotkey creation."
else
  echo "==> Creando /tmp/hotkey.expect..."
  cat <<EOF >/tmp/hotkey.expect
#!/usr/bin/expect -f

spawn $BTCLI wallet regen_hotkey --mnemonic $HOTKEY_SEED


expect "Enter wallet name (default):"
send "\r"

expect -re "Enter hotkey name (default):"
send "\r"

expect "Specify password for key encryption"
send "Undertaker2025123\r"

expect "Retype your password"
send "Undertaker2025123\r"

interact

EOF

  chmod +x /tmp/hotkey.expect

  echo "==> Ejecutando hotkey.expect..."
  /tmp/hotkey.expect || echo "==> Error: Falló la creación de hotkey"
  rm -f /tmp/hotkey.expect
fi

echo "==> wallet_creator.sh done"
