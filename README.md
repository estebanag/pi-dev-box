# pi-dev-box
A self-contained dev Docker setup for running the [pi coding
agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) entirely
on local hardware. Key features:
1. No cloud APIs or API keys required.
1. The agent is backed by
[Ollama](https://ollama.com), which serves open-weight models (such as
`phi4-mini` or `gemma4`) from your own machine.
1. Both services run in hardened, network-isolated containers so that
neither the agent nor the model server can reach:
    - the Internet, or
    - files on your host machine (other than those specified in a shared
workspace directory).

---

# Deployment

## 1. Start Ollama and pull the model(s)
Pull whichever models you want to use:
```sh
docker compose -f docker-compose.ollama.yml --profile pull run --rm ollama-pull pull phi4-mini
docker compose -f docker-compose.ollama.yml --profile pull run --rm ollama-pull pull gemma4:e2b-it-q4_K_M
docker compose -f docker-compose.ollama.yml --profile pull run --rm ollama-pull pull gemma4:e4b-it-q4_K_M
docker compose -f docker-compose.ollama.yml --profile pull run --rm ollama-pull pull gemma4:26b-a4b-it-q4_K_M
docker compose -f docker-compose.ollama.yml --profile pull run --rm ollama-pull pull gemma4:31b-it-q4_K_M
```

## 2. Build pi
Build the `pi` image the first time (or after any change to `Dockerfile.pi`).
This bakes your host UID/GID into the image.

```sh
DOCKER_UID=$(id -u) DOCKER_GID=$(id -g) docker compose -f docker-compose.pi.build.yml build pi
```

---

# Daily use

## 1. Configure the models to be used by pi
As per [pi's documentation](https://pi.dev/docs/latest), available models are declared
in `pi-config/agent/models.json` and the default is set in `pi-config/agent/settings.json`.
These files are copied into the agent's config directory at container startup.

## 2. Set your workspace directory
Create a file called `.env` and set `WORKSPACE_DIR` to the directory you
want to share with the pi agent.
> **NOTE**: the agent will be able to modify and delete at will
in this shared directory!

**File**: `.env`
```
WORKSPACE_DIR=/path/to/your/project
```


## 3. Start Ollama and run pi
```sh
docker compose -f docker-compose.pi.yml run --rm pi
```

## 4. Stop and remove containers
```sh
docker compose -f docker-compose.pi.yml down
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

## Networks

| Network | Type | Purpose |
|---|---|---|
| `pi_net` | internal bridge | Runtime communication between `pi` and `ollama`; no Internet access |
| `ollama_ext` | bridge | Used only by `ollama-pull` to reach the Ollama model registry |


