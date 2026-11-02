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
| `GH_TOKEN` | No | - | Personal Access Token di GitHub per autenticare automaticamente `gh` all'interno del container. |

### 3. Rendi eseguibile lo script

Assicurati che lo script `opencode.sh` abbia i permessi di esecuzione:

```bash
chmod +x opencode.sh
```

## Utilizzo

Puoi eseguire `opencode.sh` da qualsiasi directory del tuo sistema (anche aggiungendolo al tuo `PATH`, tramite un alias o creando un symlink es. `ln -s /percorso/a/opencode.sh ~/.local/bin/opencode`). Lo script monterà automaticamente la directory di lavoro corrente (`$PWD`) nello stesso percorso all'interno del container (`-v "$PWD":"$PWD" -w "$PWD"`) e la propria cartella `opencode-data/` in `/home/opencode`:

```bash
/percorso/a/opencode.sh [argomenti-opzionali-per-opencode]
```

### Cosa fa lo script all'avvio:

1.  **Carica la configurazione:** Risolve il percorso reale dello script (anche se invocato tramite symlink), legge il file `.env` e verifica la presenza di `LLM_API_BASE` e `LLM_API_KEY`.
2.  **Prepara la cartella dati (`opencode-data/`):** Assicura la presenza delle sottocartelle necessarie, disabilita il background service condiviso e genera (se non esiste già) un file `opencode-data/.config/opencode/AGENTS.md` globale che istruisce l'agente sul fatto di trovarsi in un container Linux isolato con visibilità limitata alla sola cartella di lavoro e di utilizzare percorsi relativi nelle note.
3.  **Compila l'immagine Docker (se necessario):** Costruisce l'immagine `opencode-local:latest` solo se l'immagine non esiste ancora o se sono cambiati il `Dockerfile`, `OPENCODE_VERSION`, `MODEL` o `AVAILABLE_MODELS`.
4.  **Avvia il container:** Esegue Opencode con l'utente `node` del container, montando:
    -   La directory di lavoro corrente dell'utente (`$PWD`) nello stesso percorso (`$PWD`) all'interno del container, preservando così il path dell'host e separando correttamente le sessioni di progetti diversi.
    -   La cartella locale `opencode-data/` (nella directory dello script) in `/home/opencode` (`HOME` del container).
    -   Il file `~/.gitconfig` dell'host in `/home/opencode/.gitconfig` (in sola lettura, se presente).

### Installare Skill, Plugin, Agent e Command

La cartella `opencode-data/` (montata in `/home/opencode` con permessi di lettura abilitati su `external_directory`) permette di installare componenti condivisi tra tutti i progetti:

-   **Skill (`opencode-data/skills/` o `opencode-data/plugins/`):** Qualsiasi file `SKILL.md` (e relativi file di supporto o script) posizionato dentro `opencode-data/skills/<nome>/SKILL.md` o all'interno di repository clonati in `opencode-data/plugins/` (es. `opencode-data/plugins/karness/...`) viene rilevato ricorsivamente in automatico.
-   **Configurazione globale Opencode (`opencode-data/.config/opencode/`):**
    -   `AGENTS.md`: istruzioni globali caricate in tutte le sessioni (preconfigurato per informare l'agente dell'ambiente containerizzato e dell'uso di percorsi relativi).
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

## Guida per gli sviluppatori

### Pacchetti inclusi nell'immagine Docker

L'immagine è basata su **`node:22-slim`** (Debian 12 Bookworm) e include i seguenti strumenti preinstallati a disposizione dell'agente e dello sviluppatore:

| Pacchetto / Tool | Descrizione e utilizzo nel container |
| :--- | :--- |
| **Node.js 22 & npm** | Runtime JavaScript/TypeScript, gestione pacchetti ed esecuzione di script/test di progetto. |
| **`@opencode/cli`** | L'agente CLI/TUI Opencode (versione configurabile tramite `OPENCODE_VERSION`). |
| **`git`** | Gestione del controllo versione, branch, diff, commit e operazioni sui repository. |
| **`gh` (GitHub CLI)** | Interazione diretta con GitHub (Pull Request, Issue, code review, Actions, release e push/fetch autenticati). |
| **`ripgrep` (`rg`)** | Ricerca testuale ultraveloce nel codice sorgente, utilizzata anche internamente da Opencode. |
| **`python3`** | Esecuzione di script Python, automazioni e script di supporto delle skill (es. raccolta dati o analisi). |
| **`ca-certificates`** | Certificati root SSL/TLS per connessioni HTTPS sicure verso API, GitHub e registry. |

---

### Use Case: Sviluppo e Code Review tra IDE locale, Container e GitHub

Grazie al modo in cui `opencode.sh` monta i volumi, puoi affiancare **Opencode nel container** al tuo **IDE locale** (VS Code, Cursor, IntelliJ, Zed, ecc.) lavorando sugli stessi file in tempo reale e interagendo continuamente con GitHub.

#### 1. Sincronia in tempo reale con l'IDE locale
- **Stesso filesystem, stessi percorsi:** Lo script monta la directory del progetto corrente con `-v "$PWD":"$PWD" -w "$PWD"`. Qualsiasi modifica effettuata da Opencode nel container (creazione file, refactoring, checkout di un branch) è **immediatamente visibile nel tuo IDE locale** e viceversa.
- **Zero conflitti sui path:** Poiché il percorso assoluto dentro il container coincide con quello dell'host, i riferimenti ai file, i worktree Git e la cronologia delle sessioni di Opencode rimangono coerenti.

#### 2. Configurazione una-tantum di GitHub CLI (`gh`) e Git
Poiché la `$HOME` del container (`/home/opencode`) è persistita nella cartella `opencode-data/` sull'host, puoi autenticare `gh` in due modi:

1. **Tramite variabile `GH_TOKEN` (nel file `.env` o nell'ambiente):**
   Imposta `GH_TOKEN=ghp_...` nel file `.env`; `opencode.sh` la passerà automaticamente al container e `gh` risulterà subito autenticato senza dover eseguire il login interattivo.
2. **Tramite login interattivo persistente (`gh auth login`):**
   Avvia Opencode ed esegui `!gh auth login` per effettuare il login via browser o token.
   - Le credenziali verranno salvate in `opencode-data/.config/gh/` e **rimarranno persistenti** in tutte le sessioni future e su tutti i progetti.
   - Configura `gh` come credential helper per Git (`!gh auth setup-git`) così anche `git push`, `git pull` e `git fetch` su repository HTTPS useranno automaticamente l'autenticazione di `gh`.
3. **Identità Git e firme GPG:**
   - Il file `~/.gitconfig` dell'host viene montato automaticamente in sola lettura (`/home/opencode/.gitconfig`).
   - *Nota su GPG:* Se sull'host hai `commit.gpgsign=true` nel tuo `.gitconfig`, all'interno del container i commit possono essere eseguiti passando `--no-gpg-sign` (oppure lasciando che sia l'IDE locale a firmare i commit quando preferisci).

#### 3. Flusso di lavoro consigliato (Sviluppo + PR Review)

- **Sviluppo assistito su una feature:**
  1. Apri il progetto nel tuo IDE locale e avvia `opencode` nel terminale integrato dell'IDE (o in un terminale separato nella stessa cartella).
  2. Chiedi a Opencode di creare un branch, implementare una modifica o scrivere test.
  3. Controlla le modifiche in tempo reale dal tab *Source Control* / *Git Diff* del tuo IDE, rifinisci il codice se necessario e chiedi a Opencode di fare commit, push e aprire la Pull Request tramite `gh pr create`.

- **Code Review interattiva di una Pull Request:**
  1. Chiedi a Opencode di elencare o ispezionare le PR aperte (`gh pr list`, `gh pr view <num>`, `gh pr diff <num>`).
  2. Per testare o navigare il codice della PR nel tuo IDE locale, chiedi a Opencode di fare il checkout della PR (`gh pr checkout <num>`): l'IDE locale si aggiornerà istantaneamente sul branch della PR, permettendoti di usare il go-to-definition, il debugger e i tool dell'IDE mentre discuti il codice con l'agente.
  3. Chiedi a Opencode di verificare lo stato della CI (`gh pr checks`), analizzare eventuali fallimenti nei log (`gh run view --log-failed`) o pubblicare commenti e review direttamente su GitHub (`gh pr review` / `gh pr comment`).
