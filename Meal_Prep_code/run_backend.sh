#!/usr/bin/env bash
# Starts the FastAPI backend on http://0.0.0.0:8000 (reachable from emulators and phones on your Wi-Fi).
cd "$(dirname "$0")/backend" || exit 1
exec .venv/bin/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
