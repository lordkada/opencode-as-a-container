#!/usr/bin/env bash
# Compila e avvia il container opencode montando la directory corrente
set -euo pipefail

# Trova la directory reale dello script (risolvendo eventuali symlink)
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
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

# Imposta il nome dell'immagine e la cartella locale dei dati/plugin/skill
IMAGE="${OPENCODE_IMAGE:-opencode-local:latest}"
DATA_DIR="${OPENCODE_DATA_DIR:-$SCRIPT_DIR/opencode-data}"

# Assicura che la struttura della cartella dati locale esista
mkdir -p "$DATA_DIR/skills" "$DATA_DIR/plugins" "$DATA_DIR/.config/opencode"

# Disabilita il background service condiviso di Opencode 2.x (incompatibile con container isolati che condividono $DATA_DIR)
SERVICE_CONFIG="$DATA_DIR/.config/opencode/service.json"
if ! grep -q '"disabled"[[:space:]]*:[[:space:]]*true' "$SERVICE_CONFIG" 2>/dev/null; then
  printf '{\n  "disabled": true\n}\n' > "$SERVICE_CONFIG"
fi
rm -f "$DATA_DIR/.local/state/opencode/service.json"

# Assicuriamoci che i parametri per LiteLLM siano presenti
if [[ -z "${LLM_API_BASE:-}" ]] || [[ -z "${LLM_API_KEY:-}" ]]; then
  echo "Errore: LLM_API_BASE o LLM_API_KEY non sono definite nel file .env" >&2
  exit 1
fi

# Configura la versione, il modello di default, i modelli disponibili e l'endpoint Ollama
OPENCODE_VERSION="$(echo "${OPENCODE_VERSION:-latest}" | xargs)"
MODEL="$(echo "${MODEL:-gemini/gemini-4-argon}" | xargs)"
AVAILABLE_MODELS="$(echo "${AVAILABLE_MODELS:-$MODEL}" | xargs)"
OLLAMA_API_BASE="$(echo "${OLLAMA_API_BASE:-http://host.docker.internal:11434/v1}" | xargs)"

# 2. Compila l'immagine Docker se non esiste, se i parametri di build o il Dockerfile sono cambiati, o se forzato con REBUILD=1
DOCKERFILE_HASH="$(shasum -a 256 "$BUILD_DIR/Dockerfile" 2>/dev/null | awk '{print $1}' || sha256sum "$BUILD_DIR/Dockerfile" 2>/dev/null | awk '{print $1}' || true)"
CURRENT_MODELS="$(docker image inspect -f '{{ index .Config.Labels "opencode.available_models" }}' "$IMAGE" 2>/dev/null || true)"
CURRENT_DEFAULT_MODEL="$(docker image inspect -f '{{ index .Config.Labels "opencode.default_model" }}' "$IMAGE" 2>/dev/null || true)"
CURRENT_VERSION="$(docker image inspect -f '{{ index .Config.Labels "opencode.version" }}' "$IMAGE" 2>/dev/null || true)"
CURRENT_DOCKERFILE_HASH="$(docker image inspect -f '{{ index .Config.Labels "opencode.dockerfile_hash" }}' "$IMAGE" 2>/dev/null || true)"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1 \
  || [[ "${REBUILD:-0}" == "1" ]] \
  || [[ "$CURRENT_MODELS" != "$AVAILABLE_MODELS" ]] \
  || [[ "$CURRENT_DEFAULT_MODEL" != "$MODEL" ]] \
  || [[ "$CURRENT_VERSION" != "$OPENCODE_VERSION" ]] \
  || [[ "$CURRENT_DOCKERFILE_HASH" != "$DOCKERFILE_HASH" ]]; then
  echo "Compilazione dell'immagine Docker '$IMAGE' in corso..."
  # Il build usa la cartella dello script che contiene il Dockerfile
  docker build \
    --build-arg OPENCODE_VERSION="$OPENCODE_VERSION" \
    --build-arg AVAILABLE_MODELS="$AVAILABLE_MODELS" \
    --build-arg DEFAULT_MODEL="$MODEL" \
    --label "opencode.version=$OPENCODE_VERSION" \
    --label "opencode.available_models=$AVAILABLE_MODELS" \
    --label "opencode.default_model=$MODEL" \
    --label "opencode.dockerfile_hash=$DOCKERFILE_HASH" \
    -t "$IMAGE" "$BUILD_DIR"
fi

# Rileva se è un terminale interattivo (TUI)
TTY_FLAGS=()
[[ -t 0 && -t 1 ]] && TTY_FLAGS=(-it)

# Monta .gitconfig dell'host se presente
GITCONFIG_MOUNT=()
[[ -f "$HOME/.gitconfig" ]] && GITCONFIG_MOUNT=(-v "$HOME/.gitconfig:/home/opencode/.gitconfig:ro")

# 3. Avvia il container
# - Passiamo LLM_API_BASE e LLM_API_KEY come variabili d'ambiente al container,
#   così opencode.json le leggerà tramite {env:...}
# - Montiamo la cartella corrente dell'utente ($PWD) in /work
# - Montiamo la cartella dati/plugin/skill di opencode ($DATA_DIR) in /home/opencode
exec docker run --rm "${TTY_FLAGS[@]}" \
  -e LLM_API_BASE="$LLM_API_BASE" \
  -e LLM_API_KEY="$LLM_API_KEY" \
  -e OLLAMA_API_BASE="$OLLAMA_API_BASE" \
  -v "$PWD":/work \
  -v "$DATA_DIR":/home/opencode \
  "${GITCONFIG_MOUNT[@]}" \
  "$IMAGE" "$@"