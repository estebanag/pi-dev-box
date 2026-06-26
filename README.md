# pi-dev-box
A self-contained dev Docker setup for running the [pi coding
agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent).
Key features:
1. The agent is backed by:
    - [Ollama](https://ollama.com) for local models.
    - [LiteLLM](https://github.com/BerriAI/litellm) for cloud models.
1. The agent cannot reach:
    - the Internet, or
    - files on your host machine (other than those specified in a shared
workspace directory).

---

# Deployment

## 1. Start Ollama and pull local model(s)
Pull whichever models you want to use:
```sh
docker compose -f docker-compose.ollama.yml --profile pull run --rm ollama-pull pull [MODEL-NAME]
```

## 2. Build pi
Build the `pi` image the first time (or after any change to `Dockerfile.pi`).
This bakes your host UID/GID into the image.

```sh
DOCKER_UID=$(id -u) DOCKER_GID=$(id -g) docker compose -f docker-compose.pi.build.yml build pi
```

---

# Daily use (local models)

## 1. Configure the models to be used by pi
As per [pi's documentation](https://pi.dev/docs/latest), available models are declared
in `pi-config/agent/models.json` and the default is set in `pi-config/agent/settings.json`.
These files are copied into the agent's config directory at container startup.

## 2. Set env variables
### Set your workspace directory
Run
```sh
cp .env.example .env
```
to create a file called `.env` and set `WORKSPACE_DIR` to the directory you
want to share with the pi agent.
> **NOTE**: the agent will be able to modify and delete at will
in this shared directory!

**File**: `.env`
```
WORKSPACE_DIR=/path/to/your/project
```

### Tune Ollama
Create `.env.ollama`:

```sh
cp .env.ollama.example .env.ollama
```

## 3. Run pi with Ollama
```sh
docker compose -f docker-compose.pi.yml run --rm pi
```

## 4. Stop and remove containers
```sh
docker compose -f docker-compose.pi.yml down
```

---


# Daily use (local and cloud models)

## 1. Configure the models to be used by pi
1. Configure local models in `pi-config/agent/models.json`.
1. Configure cloud models in `pi-config/agent/models.proxy.json`,
which gets merged into `models.json` automatically.
1. Set the default in `pi-config/agent/settings.json`.
1. Configure models in LiteLLM in `proxy-config/litellm_config.yaml`.

## 2. Set env variables
### Set your workspace directory
Run
```sh
cp .env.example .env
```
to create a file called `.env` and set `WORKSPACE_DIR` to the directory you
want to share with the pi agent.
> **NOTE**: the agent will be able to modify and delete at will
in this shared directory!

**File**: `.env`
```
WORKSPACE_DIR=/path/to/your/project
```

### Configure your API keys
```sh
cp .env.proxy.example .env.proxy
```

## 3. Run pi
```sh
docker compose -f docker-compose.proxy.yml -f docker-compose.pi.yml run --rm pi
```
If you need to authenticate your device, see the output of:
```sh
docker logs -f litellm
```

## 4. Stop and remove containers
```sh
docker compose -f docker-compose.proxy.yml -f docker-compose.pi.yml down
```

---

# Docker setup

## Services

### `ollama` (`docker-compose.ollama.yml`)
Runs the Ollama inference server. It lives exclusively on
the internal `pi_net` bridge network; it has no Internet access at runtime.
Model data is persisted in the `ollama_data` named volume.

### `pi` (`docker-compose.pi.yml`)
Runs the pi coding agent (`Dockerfile.pi`). It only starts once `ollama` is
healthy and communicates with it over `pi_net`.

Your project is bind-mounted to `/workspace` via `WORKSPACE_DIR` (see `.env` file).
Agent state is persisted across runs in the `pi_agents` named volume.

### `ollama-pull` (`docker-compose.ollama.yml`, `pull` profile)
A one-shot helper used only for downloading models. It uses the `ollama_ext`
network (has Internet access) and exits after the pull completes. It is never
part of the runtime stack.

### `litellm` (`docker-compose.proxy.yml`, optional)
Runs the LiteLLM proxy server. It is attached to both `pi_net` (so pi can reach
it) and `proxy_ext` (so it can reach cloud APIs). The pi container itself never
joins `proxy_ext` and therefore never has direct Internet access.

## Networks

| Network | Type | Purpose |
|---|---|---|
| `pi_net` | internal bridge | Runtime communication between `pi`, `ollama`, and `litellm`; no Internet access |
| `ollama_ext` | bridge | Used only by `ollama-pull` to reach the Ollama model registry |
| `proxy_ext` | bridge | Used only by `litellm` to reach cloud APIs |


