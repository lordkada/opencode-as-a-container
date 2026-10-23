# Opencode Environment

## Scopo

Questo repository contiene un `Dockerfile` e lo script `opencode.sh` per eseguire **Opencode** (`@opencode/cli`) all'interno di un container Docker isolato, configurato per utilizzare un proxy compatibile con OpenAI / LiteLLM e montando la directory di lavoro corrente.

## Prerequisiti

Prima di eseguire lo script, assicurati di avere installato i seguenti prerequisiti:

-   **Bash:** Lo script è scritto in Bash e richiede un ambiente shell compatibile.
-   **Git:** Necessario per clonare il repository e utilizzato all'interno del container.
-   **Docker (o Rancher Desktop):** Obbligatorio per compilare ed eseguire il container. Per l'installazione, segui la [guida ufficiale di Docker](https://docs.docker.com/get-docker/) o il [sito di Rancher Desktop](https://rancherdesktop.io/).

## Come iniziare

Segui questi passaggi per configurare e avviare Opencode.

### 1. Clona il repository

Apri un terminale e clona questo repository nella tua macchina locale:

```bash
git clone <URL_DEL_TUO_REPOSITORY>
cd <NOME_DELLA_CARTELLA>
```

### 2. Configura le variabili d'ambiente

Lo script richiede un file `.env` nella stessa directory di `opencode.sh`. Copia il file di template `.env.template` in `.env` e personalizza i parametri:

```bash
cp .env.template .env
# Modifica il file .env con il tuo editor preferito
```

#### Variabili supportate nel file `.env`

| Variabile | Obbligatoria | Default | Descrizione |
| :--- | :---: | :--- | :--- |
| `LLM_API_BASE` | Sì | - | URL base del server LiteLLM o proxy compatibile OpenAI (es. `http://host.docker.internal:4000`). |
| `LLM_API_KEY` | Sì | - | Chiave API per autenticarsi sul server LiteLLM. |
| `OLLAMA_API_BASE` | No | `http://host.docker.internal:11434/v1` | URL base del server Ollama in esecuzione sull'host (per la discovery automatica dei modelli locali). |
| `OPENCODE_VERSION` | No | `latest` | Versione del pacchetto npm `@opencode/cli` da installare nel container. |
| `MODEL` | No | `gemini/gemini-4-argon` | Modello predefinito da utilizzare all'avvio (es. `gemini/gemini-4-argon` o `ollama/LFM2.5:24b`). |
| `AVAILABLE_MODELS` | No | Valore di `MODEL` | Lista di modelli disponibili (separati da virgola) configurati in `opencode.json`. |
| `OPENCODE_IMAGE` | No | `opencode-local:latest` | Nome e tag dell'immagine Docker locale. |
| `OPENCODE_DATA_DIR` | No | `<SCRIPT_DIR>/opencode-data` | Percorso locale usato per persistere stato, configurazione, plugin e skill in `/home/opencode`. |
| `OPENCODE_SERVER_PASSWORD` | No | *(casuale)* | Password fissa per la modalità server (`opencode serve`). Se non impostata, OpenCode ne genera una casuale a ogni avvio. |

### 3. Rendi eseguibile lo script

Assicurati che lo script `opencode.sh` abbia i permessi di esecuzione:

```bash
chmod +x opencode.sh
```

## Utilizzo

Puoi eseguire `opencode.sh` da qualsiasi directory del tuo sistema (anche aggiungendolo al tuo `PATH`, tramite un alias o creando un symlink es. `ln -s /percorso/a/opencode.sh ~/.local/bin/opencode`). Lo script monterà automaticamente la directory di lavoro corrente (`$PWD`) in `/work` e la propria cartella `opencode-data/` in `/home/opencode`:

```bash
/percorso/a/opencode.sh [argomenti-opzionali-per-opencode]
```

### Modalità Server (es. integrazione con Obsidian)

È possibile avviare OpenCode in modalità server HTTP/API passando il comando `serve` (o l'alias `server`) e specificando `--port`.  
Quando è presente il parametro `--port`, `opencode.sh` espone automaticamente la porta corrispondente sul container Docker (`-p <porta>:<porta>`) e imposta `--hostname 0.0.0.0` nel container per consentire le connessioni dall'host:

```bash
/percorso/a/opencode.sh serve --port 4096 --cors app://obsidian.md
```

> **Nota:** Se non hai impostato `OPENCODE_SERVER_PASSWORD` nel file `.env`, OpenCode stamperà a terminale la password generata per l'autenticazione all'avvio del server.

#### Usare la CLI/TUI mentre il server è attivo

Il comando `serve` avvia esclusivamente il server HTTP/API in foreground (il terminale rimane in ascolto per Obsidian o altri client e non apre la TUI). Mentre il server è attivo, puoi comunque usare la CLI/TUI da un **secondo terminale** in due modi:

1. **Istanza TUI indipendente (classica):**
   Eseguendo semplicemente `opencode` (senza `serve` e senza `--port`), viene avviato un nuovo container con l'interfaccia TUI interattiva senza alcun conflitto di porta, poiché la porta viene esposta su Docker solo quando è specificato `--port`:
   ```bash
   /percorso/a/opencode.sh
   ```

2. **Collegare la TUI allo stesso server di Obsidian:**
   Se vuoi visualizzare e continuare da terminale le **stesse sessioni in tempo reale** che stai usando su Obsidian, puoi collegare la TUI al server già in ascolto sulla porta `4096` usando il flag `--server`:
   ```bash
   /percorso/a/opencode.sh --server http://host.docker.internal:4096
   ```
   *(Si utilizza `host.docker.internal:4096` perché anche il client TUI gira in un container Docker e raggiunge così la porta `4096` esposta sull'host dal container server).*

### Cosa fa lo script all'avvio:

1.  **Carica la configurazione:** Risolve il percorso reale dello script (anche se invocato tramite symlink), legge il file `.env` e verifica la presenza di `LLM_API_BASE` e `LLM_API_KEY`.
2.  **Compila l'immagine Docker (se necessario):** Costruisce l'immagine `opencode-local:latest` solo se l'immagine non esiste ancora o se sono cambiati il `Dockerfile`, `OPENCODE_VERSION`, `MODEL` o `AVAILABLE_MODELS`.
3.  **Avvia il container:** Esegue Opencode con l'utente `node` del container, montando:
    -   La directory di lavoro corrente dell'utente (`$PWD`) in `/work`.
    -   La cartella locale `opencode-data/` (nella directory dello script) in `/home/opencode` (`HOME` del container).
    -   Il file `~/.gitconfig` dell'host in `/home/opencode/.gitconfig` (in sola lettura, se presente).

### Installare Skill, Plugin, Agent e Command

La cartella `opencode-data/` (montata in `/home/opencode` con permessi di lettura abilitati su `external_directory`) permette di installare componenti condivisi tra tutti i progetti:

-   **Skill (`opencode-data/skills/` o `opencode-data/plugins/`):** Qualsiasi file `SKILL.md` (e relativi file di supporto o script) posizionato dentro `opencode-data/skills/<nome>/SKILL.md` o all'interno di repository clonati in `opencode-data/plugins/` (es. `opencode-data/plugins/karness/...`) viene rilevato ricorsivamente in automatico.
-   **Configurazione globale Opencode (`opencode-data/.config/opencode/`):**
    -   `opencode.json` / `opencode.jsonc`: configurazione globale utente.
    -   `agents/<nome>.md`: agent globali.
    -   `commands/<nome>.md`: slash command globali.
    -   `plugins/*.{ts,js}`: plugin JS/TS globali.

### Persistenza dello stato

Lo stato di Opencode (sessioni, cronologia delle conversazioni, cache e impostazioni utente in `opencode-data/.local/share/opencode` e `opencode-data/.config/opencode`) viene salvato direttamente nella cartella locale `opencode-data/`.

### Forzare la ricompilazione dell'immagine

Se desideri forzare la ricompilazione dell'immagine Docker (ad esempio dopo aver modificato il `Dockerfile`), esegui:

```bash
REBUILD=1 ./opencode.sh
```
