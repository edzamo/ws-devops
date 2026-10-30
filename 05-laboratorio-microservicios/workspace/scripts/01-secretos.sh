#!/usr/bin/env bash
# Etapa 1 — Detección de secretos (va primero: es lo más barato y un secreto filtrado es lo más grave)
source "$(dirname "$0")/lib.sh"
etapa "1. Secretos (Gitleaks) — commit $COMMIT"

set +e
herramienta "$IMG_GITLEAKS" git "$APP_DIR" --redact --no-banner --exit-code 10 \
  --report-format json --report-path "$OUT_DIR/reportes/gitleaks.json"
codigo=$?
set -e
resultado_seguridad "Gitleaks" "$codigo" 10
