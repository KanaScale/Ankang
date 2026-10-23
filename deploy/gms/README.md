# Ankang GMS Deployment

GMS is deployed as a local sidecar for the Spring backend. MySQL remains the
source of truth for structured health data; GMS only stores and retrieves
agent semantic memory.

## Server Layout

```text
/opt/ankang-assistant/gms/
  mem-interface-layer/
  mem0/
  .venv/
  history.db

/etc/ankang-assistant/backend.env
/etc/ankang-assistant/gms.env
/etc/systemd/system/ankang-gms.service
```

The service listens on `127.0.0.1:8091`. The public Nginx entry does not need a
route for GMS because only the backend should call it.

## Required Environment

The GMS config loader can reuse these existing backend env values:

```text
AGENT_API_KEY
AGENT_BASE_URL
AGENT_MODEL_NAME
EMBEDDING_API_KEY
EMBEDDING_BASE_URL
EMBEDDING_MODEL
EMBEDDING_DIMENSIONS
QDRANT_HOST
QDRANT_PORT
```

Recommended `/etc/ankang-assistant/gms.env`:

```text
GMS_QDRANT_COLLECTION=ankang_agent_memory_v1
GMS_ENABLE_GRAPH=false
GMS_HISTORY_DB_PATH=/opt/ankang-assistant/gms/history.db
GMS_MINER_ENABLED=false
GMS_MINER_WORKERS=1
```

Backend env additions:

```text
GMS_ENABLED=true
GMS_WRITE_ENABLED=true
GMS_BASE_URL=http://127.0.0.1:8091
GMS_TIMEOUT_MILLIS=800
GMS_READ_LIMIT=5
```

## Install On Cloud Host

From the local project root:

```bash
scp deploy/gms/ankang-gms.service root@10.119.8.172:/etc/systemd/system/ankang-gms.service
```

On the cloud host, after `mem-interface-layer/` and `mem0/` have been synced
under `/opt/ankang-assistant/gms/`:

```bash
mkdir -p /opt/ankang-assistant/gms
python3 -m venv /opt/ankang-assistant/gms/.venv
/opt/ankang-assistant/gms/.venv/bin/python -m pip install --upgrade pip
/opt/ankang-assistant/gms/.venv/bin/python -m pip install -r /opt/ankang-assistant/gms/mem-interface-layer/requirements.txt
systemctl daemon-reload
systemctl enable --now ankang-gms
curl -s http://127.0.0.1:8091/health
```

`requirements.txt` installs the sibling `/opt/ankang-assistant/gms/mem0` source
tree in editable mode, which is required because this mem0 checkout reads the
`mem0ai` package metadata at import time.

After GMS is healthy, restart the Spring backend so it picks up
`GMS_ENABLED=true`.
