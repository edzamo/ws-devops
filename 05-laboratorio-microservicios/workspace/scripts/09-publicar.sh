#!/usr/bin/env bash
# Etapa 9 — Publicar en el registro. Solo si PUBLICAR=true; si no, es un "dry run" que muestra qué publicaría.
# Requiere DOCKERHUB_USERNAME y DOCKERHUB_TOKEN (secrets del pipeline, nunca en el código).
source "$(dirname "$0")/lib.sh"
etapa "9. Publicar en Docker Hub"

if [[ "${PUBLICAR:-false}" != "true" ]]; then
  for svc in "${SERVICIOS[@]}"; do info "(dry run) publicaría $(imagen_de "$svc")"; done
  exit 0
fi

: "${DOCKERHUB_USERNAME:?falta el secret DOCKERHUB_USERNAME}" "${DOCKERHUB_TOKEN:?falta el secret DOCKERHUB_TOKEN}"
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
trap 'docker logout >/dev/null' EXIT

: > "$OUT_DIR/reportes/imagenes-publicadas.txt"
for svc in "${SERVICIOS[@]}"; do
  imagen="$(imagen_de "$svc")"
  # Tags inmutables: si ya existe en el registro, no se sobrescribe
  docker manifest inspect "$imagen" >/dev/null 2>&1 && fail "$imagen ya existe en el registro"
  docker push -q "$imagen" >/dev/null
  docker inspect --format '{{index .RepoDigests 0}}' "$imagen" | tee -a "$OUT_DIR/reportes/imagenes-publicadas.txt"
done
