#!/bin/sh
# Authz service has main.py in root directory, not in app/ subdirectory
exec uvicorn main:app --host 0.0.0.0 --port ${SERVICE_PORT}
