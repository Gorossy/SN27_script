#!/bin/bash
set -euo pipefail

# --------------------------------------------------------------
# Uso:
#   ./wallet_creator.sh <COLDKEY_SEED> <HOTKEY_SEED>
#
# Ejemplo de llamada:
#   ./wallet_creator.sh "seed coldkey..." "seed hotkey..."
#
# Requisitos:
#   - Bittensor instalado en /home/ubuntu/venv/bin/btcli
#   - NO se usa "expect". Simplemente se envían las líneas
#     necesarias para contestar los prompts de "btcli".
# --------------------------------------------------------------

COLDKEY_SEED="${1:-}"
HOTKEY_SEED="${2:-}"

# Ajusta esta ruta si tu venv o btcli está en otro lugar
BTCLI="/home/ubuntu/venv/bin/btcli"

echo "==> Starting wallet creation..."

############################################################
# COLDKEY (con password)
############################################################
if [[ -n "$COLDKEY_SEED" ]]; then
  echo "==> Creating coldkey with seed: $COLDKEY_SEED"
  
  # Orden que btcli pide en "regen_coldkey":
  #   1) Enter wallet name (ENTER)
  #   2) Specify password for key encryption (Undertaker2025123)
  #   3) Retype your password (Undertaker2025123)
  printf "\nUndertaker2025123\nUndertaker2025123\n" \
    | "$BTCLI" wallet regen_coldkey --mnemonic $COLDKEY_SEED
  
  echo "==> Coldkey creation done."
else
  echo "==> No COLDKEY_SEED provided; skipping coldkey creation."
fi

############################################################
# HOTKEY (sin password)
############################################################
if [[ -n "$HOTKEY_SEED" ]]; then
  echo "==> Creating hotkey with seed: $HOTKEY_SEED"

  # Orden que btcli pide en "regen_hotkey":
  #   1) Enter wallet name (default) -> ENTER
  #   2) Enter hotkey name (default) -> ENTER
  # (No password prompts, según tus logs)
  printf "\n\n" \
    | "$BTCLI" wallet regen_hotkey --mnemonic $HOTKEY_SEED

  echo "==> Hotkey creation done."
else
  echo "==> No HOTKEY_SEED provided; skipping hotkey creation."
fi

echo "==> wallet_creator.sh finished."
