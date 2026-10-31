#!/usr/bin/env bash
# Etapa 9 — Publicar en el registro. Solo si PUBLICAR=true; si no, es un "dry run" que muestra qué publicaría.
# Docker Hub: requiere DOCKERHUB_USERNAME y DOCKERHUB_TOKEN (secrets del pipeline, nunca en el código).
# ECR / ACR: REGISTRY_AUTH=plataforma; el login ya lo hizo el orquestador con la identidad de la nube.
source "$(dirname "$0")/lib/common.sh"
etapa "9. Publicar en el registro ($REGISTRY)"

if [[ "${PUBLICAR:-false}" != "true" ]]; then
  for svc in "${SERVICIOS[@]}"; do info "(dry run) publicaría $(imagen_de "$svc")"; done
  exit 0
fi

if [[ "$REGISTRY_AUTH" == "dockerhub" ]]; then
  : "${DOCKERHUB_USERNAME:?falta el secret DOCKERHUB_USERNAME}" "${DOCKERHUB_TOKEN:?falta el secret DOCKERHUB_TOKEN}"
  echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
  trap 'docker logout >/dev/null' EXIT
else
  info "login al registro hecho por la plataforma (REGISTRY_AUTH=$REGISTRY_AUTH)"
fi

: > "$OUT_DIR/reportes/imagenes-publicadas.txt"
for svc in "${SERVICIOS[@]}"; do
  imagen="$(imagen_de "$svc")"
  # Tags inmutables: si ya existe en el registro, no se sobrescribe
  docker manifest inspect "$imagen" >/dev/null 2>&1 && fail "$imagen ya existe en el registro"
  docker push -q "$imagen" >/dev/null
  docker inspect --format '{{index .RepoDigests 0}}' "$imagen" | tee -a "$OUT_DIR/reportes/imagenes-publicadas.txt"
done
