#!/usr/bin/env bash
# Etapa 10 — Deploy simulado + DAST. Levanta el stack con las imágenes del pipeline, comprueba que
# responde (smoke test) y lo ataca con OWASP ZAP (DAST: pruebas de seguridad con la app corriendo).
source "$(dirname "$0")/lib/common.sh"
etapa "10. Deploy simulado + smoke test + DAST (ZAP)"

export TAG_RISK="$(imagen_de ms-risk-mock-credit-evaluation)"
export TAG_ORCH="$(imagen_de ms-orchestrator-credit-evaluation)"
export TAG_UX="$(imagen_de mms-ux-credit-evaluation)"
COMPOSE=(docker compose -p credit-simulacion -f "$PIPELINE_DIR/environments/simulated/docker-compose.yml")
trap '"${COMPOSE[@]}" logs --no-color > "$OUT_DIR/reportes/deploy-logs.txt" 2>&1; "${COMPOSE[@]}" down -v' EXIT

"${COMPOSE[@]}" up -d --wait --wait-timeout 300 || fail "el stack no quedó healthy"
info "stack healthy"

# Smoke test: desde dentro de la red del stack (no depende de puertos publicados en el host)
RED=credit-simulacion_default
docker run --rm --network "$RED" curlimages/curl:8.23.0 -fsS http://ms-orchestrator:8080/q/health >/dev/null || fail "orquestador /q/health no responde"
info "orquestador /q/health OK"
docker run --rm --network "$RED" curlimages/curl:8.23.0 -fsS http://mms-ux/ | grep -q '<app-root' || fail "el frontend no sirve la app"
info "frontend responde"
docker run --rm --network "$RED" curlimages/curl:8.23.0 -fsS -X POST http://ms-orchestrator:8080/v1/credit-evaluations \
  -H 'Content-Type: application/json' -d '{"cedula":"1713175071","requestedAmount":5000,"years":3,"salary":1500}' \
  -o /dev/null -w '  → POST evaluación: HTTP %{http_code}\n' || echo "  ⚠ el POST de evaluación no respondió 2xx"

# DAST: escaneo baseline (pasivo) contra el frontend y la API
set +e
peor=0
for objetivo in http://mms-ux/ http://ms-orchestrator:8080/q/openapi; do
  nombre="$(echo "$objetivo" | sed -E 's#https?://##; s#[/:]+#-#g; s#-$##')"
  docker run --name "zap-$nombre" --user 0 -v /zap/wrk --network "$RED" "$IMG_ZAP" zap-baseline.py -t "$objetivo" -I -r reporte.html
  codigo=$?
  docker cp "zap-$nombre:/zap/wrk/reporte.html" "$OUT_DIR/reportes/zap-$nombre.html" 2>/dev/null
  docker rm -v "zap-$nombre" >/dev/null
  # zap-baseline: 0 = limpio, 1 = alertas FAIL (con -I los WARN no cuentan), otro = error del escaneo
  [[ "$codigo" -le 1 ]] || fail "ZAP terminó con error (código $codigo)"
  [[ "$codigo" -eq 0 ]] || peor=1
done
set -e
resultado_seguridad "DAST (ZAP)" "$peor"
