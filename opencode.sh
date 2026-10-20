#!/usr/bin/env bash
# Compila e avvia il container opencode montando la directory corrente
set -euo pipefail

# Trova la directory dello script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
BUILD_DIR="$SCRIPT_DIR"

# 1. Carica le variabili dal file .env
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
else
  echo "Errore: File $ENV_FILE non trovato." >&2
  echo "Copia .env.template in .env e configuralo prima di proseguire." >&2
  exit 1
fi

# Imposta il nome dell'immagine o usa un default
IMAGE="${OPENCODE_IMAGE:-opencode-local:latest}"
VOLUME_NAME="${OPENCODE_VOLUME:-opencode-data}"

# Assicuriamoci che i parametri per LiteLLM siano presenti
if [[ -z "${LLM_API_BASE:-}" ]] || [[ -z "${LLM_API_KEY:-}" ]]; then
  echo "Errore: LLM_API_BASE o LLM_API_KEY non sono definite nel file .env" >&2
  exit 1
fi

# Configura la versione, il modello di default e i modelli disponibili
OPENCODE_VERSION="$(echo "${OPENCODE_VERSION:-latest}" | xargs)"
MODEL="$(echo "${MODEL:-gemini/gemini-4-argon}" | xargs)"
AVAILABLE_MODELS="$(echo "${AVAILABLE_MODELS:-$MODEL}" | xargs)"
OPENCODE_MODEL="litellm/${MODEL#litellm/}"

# 2. Compila l'immagine Docker se non esiste, se i parametri di build sono cambiati, o se forzato con REBUILD=1
CURRENT_MODELS="$(docker image inspect -f '{{ index .Config.Labels "opencode.available_models" }}' "$IMAGE" 2>/dev/null || true)"
CURRENT_DEFAULT_MODEL="$(docker image inspect -f '{{ index .Config.Labels "opencode.default_model" }}' "$IMAGE" 2>/dev/null || true)"
CURRENT_VERSION="$(docker image inspect -f '{{ index .Config.Labels "opencode.version" }}' "$IMAGE" 2>/dev/null || true)"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1 \
  || [[ "${REBUILD:-0}" == "1" ]] \
  || [[ "$CURRENT_MODELS" != "$AVAILABLE_MODELS" ]] \
  || [[ "$CURRENT_DEFAULT_MODEL" != "$MODEL" ]] \
  || [[ "$CURRENT_VERSION" != "$OPENCODE_VERSION" ]]; then
  echo "Compilazione dell'immagine Docker '$IMAGE' in corso..."
  # Il build usa la cartella corrente che contiene il Dockerfile
  docker build \
    --build-arg OPENCODE_VERSION="$OPENCODE_VERSION" \
    --build-arg AVAILABLE_MODELS="$AVAILABLE_MODELS" \
    --build-arg DEFAULT_MODEL="$MODEL" \
    --label "opencode.version=$OPENCODE_VERSION" \
    --label "opencode.available_models=$AVAILABLE_MODELS" \
    --label "opencode.default_model=$MODEL" \
    -t "$IMAGE" "$BUILD_DIR"
fi

# Rileva se è un terminale interattivo (TUI)
TTY_FLAGS=()
[[ -t 0 && -t 1 ]] && TTY_FLAGS=(-it)

# 3. Avvia il container
# - Passiamo LLM_API_BASE e LLM_API_KEY come variabili d'ambiente al container,
#   così opencode.json le leggerà tramite {env:...}
# - Montiamo la cartella corrente ($PWD) in /work
exec docker run --rm "${TTY_FLAGS[@]}" \
  -e LLM_API_BASE="$LLM_API_BASE" \
  -e LLM_API_KEY="$LLM_API_KEY" \
  -v "$PWD":/work \
  -v "$VOLUME_NAME":/home/opencode \
  -v "$HOME/.gitconfig:/home/opencode/.gitconfig:ro" \
  "$IMAGE" --model "$OPENCODE_MODEL" "$@"