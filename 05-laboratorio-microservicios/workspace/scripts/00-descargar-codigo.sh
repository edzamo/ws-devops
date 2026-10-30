#!/usr/bin/env bash
# Etapa 0 — Descargar el código a construir: REPO_URL en la rama RAMA, dentro de APP_DIR (fuera del repo).
# En GitHub Actions (actions/checkout) y Jenkins (paso `git`) esto lo hace la propia herramienta;
# este script es para ejecutar el pipeline en una máquina local con ejecutar-local.sh.
source "$(dirname "$0")/lib.sh"
etapa "0. Descargar código: $REPO_URL @ $RAMA → $APP_DIR"

rm -rf "$APP_DIR"
# Historial completo: Gitleaks (etapa 1) revisa todos los commits
git clone --quiet --branch "$RAMA" "$REPO_URL" "$APP_DIR"
info "commit $(git -C "$APP_DIR" rev-parse --short=7 HEAD): $(git -C "$APP_DIR" log -1 --format=%s)"
