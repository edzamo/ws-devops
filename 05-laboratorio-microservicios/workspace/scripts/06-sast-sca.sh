#!/usr/bin/env bash
# Etapa 6 — Seguridad del código:
#   SAST (Semgrep): busca patrones inseguros en NUESTRO código (inyección, criptografía débil, Dockerfiles como root...).
#   SCA (Trivy): busca CVE conocidos en las LIBRERÍAS de terceros. Analiza los jars reales que Maven resolvió en
#   target/quarkus-app/lib (el pom.xml solo no basta: las versiones vienen del BOM de Quarkus) y el
#   package-lock.json generado en la etapa 2.
source "$(dirname "$0")/lib.sh"
etapa "6. SAST (Semgrep) + SCA (Trivy)"

set +e
herramienta -w "$APP_DIR" -e SEMGREP_SEND_METRICS=off "$IMG_SEMGREP" \
  semgrep scan --config p/java --config p/typescript --config p/dockerfile \
  --severity ERROR --error --sarif --output "$OUT_DIR/reportes/semgrep.sarif" "$APP_DIR"
sast=$?
set -e
resultado_seguridad "SAST (Semgrep)" "$sast"

TRIVY=(herramienta -e TRIVY_CACHE_DIR="$OUT_DIR/.cache/trivy" "$IMG_TRIVY")
OPCIONES=(--scanners vuln --severity HIGH,CRITICAL --no-progress --exit-code 10 --format table)
peor=0
for svc in "${SERVICIOS[@]}"; do
  set +e
  if [[ " ${BACKENDS[*]} " == *" $svc "* ]]; then
    "${TRIVY[@]}" rootfs "${OPCIONES[@]}" --output "$OUT_DIR/reportes/trivy-dependencias-$svc.txt" "$APP_DIR/$svc/target/quarkus-app"
  else
    "${TRIVY[@]}" fs "${OPCIONES[@]}" --skip-dirs "**/node_modules" --output "$OUT_DIR/reportes/trivy-dependencias-$svc.txt" "$APP_DIR/$svc"
  fi
  codigo=$?
  set -e
  [[ "$codigo" -eq 0 || "$codigo" -eq 10 ]] || fail "Trivy terminó con error (código $codigo)"
  info "$svc: $(resumen_trivy "$OUT_DIR/reportes/trivy-dependencias-$svc.txt")"
  [[ "$codigo" -eq 0 ]] || peor=10
done
resultado_seguridad "SCA (Trivy)" "$peor" 10
