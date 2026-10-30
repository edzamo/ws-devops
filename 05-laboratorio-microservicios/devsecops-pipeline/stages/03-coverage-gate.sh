#!/usr/bin/env bash
# Etapa 3 — Quality gate de cobertura: el pipeline se detiene si la cobertura de líneas baja del mínimo
source "$(dirname "$0")/lib/common.sh"
etapa "3. Cobertura mínima: $COBERTURA_MINIMA %"

falla=0
for svc in "${BACKENDS[@]}"; do
  csv="$APP_DIR/$svc/target/site/jacoco/jacoco.csv"
  [[ -f "$csv" ]] || fail "$svc: no existe $csv (¿corrió la etapa 2?)"
  # Columnas del CSV de JaCoCo: 8 = LINE_MISSED, 9 = LINE_COVERED
  pct="$(awk -F, 'NR>1 {m+=$8; c+=$9} END {printf "%.1f", (m+c) ? 100*c/(m+c) : 0}' "$csv")"
  if awk -v p="$pct" -v min="$COBERTURA_MINIMA" 'BEGIN {exit !(p >= min)}'; then
    info "$svc: $pct % ✓"
  else
    echo "  ✗ $svc: $pct % (mínimo $COBERTURA_MINIMA %)"; falla=1
  fi
  cp -r "$APP_DIR/$svc/target/site/jacoco" "$OUT_DIR/reportes/cobertura-$svc"
done
[[ "$falla" -eq 0 ]] || fail "cobertura por debajo del mínimo"
