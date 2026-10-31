#!/usr/bin/env bash
# Etapa 8 — Escanear las imágenes (CVE del sistema operativo base y de las librerías) y generar el SBOM
# (la "lista de ingredientes" de cada imagen). Se hace ANTES de publicar: lo que no pasa, no sale.
source "$(dirname "$0")/lib/common.sh"
etapa "8. Escaneo de imágenes + SBOM (Trivy)"

TRIVY=(herramienta -v /var/run/docker.sock:/var/run/docker.sock --group-add "$(stat -c %g /var/run/docker.sock)"
       -e TRIVY_CACHE_DIR="$OUT_DIR/.cache/trivy" "$IMG_TRIVY" image --no-progress)
peor=0
for svc in "${SERVICIOS[@]}"; do
  imagen="$(imagen_de "$svc")"
  info "$imagen"
  set +e
  "${TRIVY[@]}" --severity HIGH,CRITICAL --ignore-unfixed --exit-code 10 \
    --format table --output "$OUT_DIR/reportes/trivy-imagen-$svc.txt" "$imagen"
  codigo=$?
  set -e
  [[ "$codigo" -eq 0 || "$codigo" -eq 10 ]] || fail "Trivy terminó con error (código $codigo)"
  [[ "$codigo" -eq 0 ]] || peor=10
  "${TRIVY[@]}" --format cyclonedx --output "$OUT_DIR/reportes/sbom-$svc.cdx.json" "$imagen"
done
resultado_seguridad "Trivy (imágenes)" "$peor" 10
