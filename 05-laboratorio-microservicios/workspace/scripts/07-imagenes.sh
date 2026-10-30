#!/usr/bin/env bash
# Etapa 7 — Construir las imágenes a partir de los artefactos YA generados en la etapa 2
# ("construir una vez"): la imagen contiene exactamente el jar que pasó los tests, no uno recompilado.
source "$(dirname "$0")/lib.sh"
etapa "7. Imágenes Docker"

for svc in "${SERVICIOS[@]}"; do
  if [[ " ${BACKENDS[*]} " == *" $svc "* ]]; then
    dockerfile="$WORKSPACE_DIR/docker/Dockerfile.quarkus"; contexto="$APP_DIR/$svc/target/quarkus-app"
  else
    # Contexto mínimo: el build de Angular + nginx.conf (el .dockerignore del repo excluye dist/)
    dockerfile="$WORKSPACE_DIR/docker/Dockerfile.frontend"; contexto="$OUT_DIR/contexto-$svc"
    rm -rf "$contexto" && mkdir -p "$contexto"
    cp -r "$APP_DIR/$svc/dist/$svc/browser" "$APP_DIR/$svc/nginx.conf" "$contexto/"
  fi
  imagen="$(imagen_de "$svc")"
  info "$imagen"
  docker build -q -f "$dockerfile" -t "$imagen" \
    --label "org.opencontainers.image.title=$PREFIX-$svc" \
    --label "org.opencontainers.image.version=$(tag_de "$svc")" \
    --label "org.opencontainers.image.revision=$(git -C "$APP_DIR" rev-parse HEAD)" \
    --label "org.opencontainers.image.source=$(git -C "$APP_DIR" remote get-url origin 2>/dev/null || echo desconocido)" \
    --label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "$contexto" >/dev/null
done
