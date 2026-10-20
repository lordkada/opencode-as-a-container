# Opencode Environment

## Scopo

Questo repository contiene un `Dockerfile` e lo script `opencode.sh` per eseguire **Opencode** (`opencode-ai`) all'interno di un container Docker isolato, configurato per utilizzare un proxy compatibile con OpenAI / LiteLLM e montando la directory di lavoro corrente.

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
| `OPENCODE_VERSION` | No | `latest` | Versione del pacchetto npm `opencode-ai` da installare nel container. |
| `MODEL` | No | `gemini/gemini-4-argon` | Modello predefinito da utilizzare all'avvio. |
| `AVAILABLE_MODELS` | No | Valore di `MODEL` | Lista di modelli disponibili (separati da virgola) configurati in `opencode.json`. |
| `OPENCODE_IMAGE` | No | `opencode-local:latest` | Nome e tag dell'immagine Docker locale. |
| `OPENCODE_VOLUME` | No | `opencode-data` | Nome del volume Docker usato per persistere i dati in `/home/opencode`. |

### 3. Rendi eseguibile lo script

Assicurati che lo script `opencode.sh` abbia i permessi di esecuzione:

```bash
chmod +x opencode.sh
```

## Utilizzo

Puoi eseguire `opencode.sh` da qualsiasi directory del tuo sistema (anche aggiungendolo al tuo `PATH` o tramite un alias). Lo script monterà automaticamente la directory corrente (`$PWD`) in `/work` all'interno del container:

```bash
./opencode.sh [argomenti-opzionali-per-opencode]
```

### Cosa fa lo script all'avvio:

1.  **Carica la configurazione:** Legge il file `.env` situato nella directory dello script e verifica la presenza di `LLM_API_BASE` e `LLM_API_KEY`.
2.  **Compila l'immagine Docker (se necessario):** Costruisce l'immagine `opencode-local:latest` (con Node 22, `opencode-ai`, `git`, `ripgrep`, `python3` e la configurazione `/etc/opencode/opencode.json`) solo se l'immagine non esiste ancora o se sono cambiati `OPENCODE_VERSION`, `MODEL` o `AVAILABLE_MODELS`.
3.  **Avvia il container:** Esegue Opencode con l'utente corrente (`uid:gid`), montando:
    -   La directory di lavoro corrente (`$PWD`) in `/work`.
    -   Il volume Docker `opencode-data` in `/home/opencode` (`HOME` del container).
    -   Il file `~/.gitconfig` dell'host in `/home/opencode/.gitconfig` (in sola lettura).

### Persistenza dello stato

Lo stato di Opencode (sessioni, cronologia delle conversazioni, cache e impostazioni utente in `/home/opencode/.local/share/opencode` e `/home/opencode/.config/opencode`) viene salvato nel volume Docker `opencode-data` (configurabile tramite `OPENCODE_VOLUME`) ed è quindi persistente tra un avvio e l'altro.

Per azzerare completamente lo stato salvato o risolvere eventuali problemi di permessi su volumi creati con versioni precedenti, rimuovi il volume Docker:

```bash
docker volume rm opencode-data
```

### Forzare la ricompilazione dell'immagine

Se desideri forzare la ricompilazione dell'immagine Docker (ad esempio dopo aver modificato il `Dockerfile`), esegui:

```bash
REBUILD=1 ./opencode.sh
```
