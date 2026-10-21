FROM node:22-slim

ARG OPENCODE_VERSION=latest
ARG AVAILABLE_MODELS="gemini/gemini-4-argon"
ARG DEFAULT_MODEL="gemini/gemini-4-argon"

RUN npm install -g "@opencode/cli@${OPENCODE_VERSION}" \
 && apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates ripgrep python3 \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/opencode /home/opencode \
 && chown -R node:node /home/opencode \
 && chmod 755 /home/opencode

RUN export MODELS="${AVAILABLE_MODELS}" && \
    export DEFAULT_MODEL="${DEFAULT_MODEL}" && \
    node -e ' \
      const models = process.env.MODELS.split(",").map(m => m.trim()).filter(Boolean); \
      const rawDefault = process.env.DEFAULT_MODEL.trim(); \
      const defaultModel = rawDefault.startsWith("litellm/") ? rawDefault : `litellm/${rawDefault}`; \
      const config = { \
        "$schema": "https://opencode.ai/config.json", \
        "enabled_providers": ["litellm"], \
        "provider": { \
          "litellm": { \
            "npm": "@ai-sdk/openai-compatible", \
            "name": "LiteLLM", \
            "options": { \
              "baseURL": "{env:LLM_API_BASE}", \
              "apiKey": "{env:LLM_API_KEY}" \
            }, \
            "models": models.reduce((acc, m) => ({...acc, [m]: {name: m}}), {}) \
          } \
        }, \
        "model": defaultModel, \
        "small_model": defaultModel, \
        "skills": { \
          "paths": [ \
            "/home/opencode/skills", \
            "/home/opencode/plugins" \
          ] \
        }, \
        "permission": { \
          "external_directory": { \
            "/home/opencode/**": "allow", \
            "/etc/opencode/**": "allow" \
          } \
        } \
      }; \
      require("fs").writeFileSync("/etc/opencode/opencode.json", JSON.stringify(config, null, 2)); \
    '

ENV OPENCODE_CONFIG=/etc/opencode/opencode.json \
    HOME=/home/opencode

WORKDIR /work
USER node
ENTRYPOINT ["opencode"]