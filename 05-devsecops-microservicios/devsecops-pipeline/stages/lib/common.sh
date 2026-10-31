#!/usr/bin/env bash
# Funciones y variables comunes a todas las etapas del pipeline.
# Cada etapa hace `source lib/common.sh`. Las variables se pueden sobrescribir desde GitHub Actions o Jenkins.
set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Código a construir (lo usa 00-checkout.sh; en GitHub Actions y Jenkins lo descarga la herramienta)
REPO_URL="${REPO_URL:-https://github.com/edzamo/poc-credit-evaluation.git}"
RAMA="${RAMA:-main}"

# Carpeta de trabajo FUERA del repositorio: ahí se descarga el código, se compila y quedan los reportes.
# Nada de lo que se compila queda dentro de ws-devops.
TRABAJO_DIR="${TRABAJO_DIR:-${TMPDIR:-/tmp}/poc-credit-evaluation-pipeline}"
APP_DIR="$(realpath -m "${APP_DIR:-$TRABAJO_DIR/app}")"
OUT_DIR="$(realpath -m "${OUT_DIR:-$TRABAJO_DIR/salida}")"
mkdir -p "$OUT_DIR"/{reportes,artefactos}

# Parámetros del pipeline
# Registro de imágenes. Docker Hub: la cuenta (edzamo13). AWS ECR: <cuenta>.dkr.ecr.<región>.amazonaws.com.
# Azure ACR: <nombre>.azurecr.io. DOCKER_USER se acepta por compatibilidad.
REGISTRY="${REGISTRY:-${DOCKER_USER:-edzamo13}}"
# Quién hace el login al registro: "dockerhub" (la etapa 9, con DOCKERHUB_USERNAME/TOKEN) o
# "plataforma" (el orquestador ya autenticó con la identidad de la nube: rol IAM en AWS, service connection en Azure)
REGISTRY_AUTH="${REGISTRY_AUTH:-dockerhub}"
PREFIX="${PREFIX:-austro}"
COBERTURA_MINIMA="${COBERTURA_MINIMA:-30}"  # línea base actual del proyecto: la cobertura nunca debe bajar de aquí
MODO_ESTRICTO="${MODO_ESTRICTO:-false}"   # false: los escáneres de seguridad reportan sin detener el pipeline

BACKENDS=(ms-risk-mock-credit-evaluation ms-orchestrator-credit-evaluation)
FRONTEND=mms-ux-credit-evaluation
SERVICIOS=("${BACKENDS[@]}" "$FRONTEND")

# Versiones fijas de las herramientas (nunca `latest` en un pipeline)
IMG_NODE="node:22-alpine"
IMG_GITLEAKS="zricethezav/gitleaks:v8.30.1"
IMG_SEMGREP="semgrep/semgrep:1.183.0"
IMG_TRIVY="aquasec/trivy:0.76.1"
IMG_ZAP="zaproxy/zap-stable:2.17.0"
JACOCO_VERSION="0.8.16"
SONAR_PLUGIN_VERSION="5.8.0.7211"

# Montaje para los contenedores de herramientas. La ruta dentro del contenedor es la misma que fuera,
# así funciona igual en GitHub Actions (-v) y en Jenkins con Docker del host (--volumes-from jenkins).
DOCKER_MOUNT="${DOCKER_MOUNT:--v $APP_DIR:$APP_DIR -v $OUT_DIR:$OUT_DIR}"

etapa() { echo; echo "════════ $* ════════"; }
info()  { echo "  → $*"; }
fail()  { echo "  ✗ ERROR: $*" >&2; exit 1; }

# Ejecuta una herramienta en contenedor con el código y la salida montados
herramienta() {
  # shellcheck disable=SC2086
  docker run --rm $DOCKER_MOUNT --user "$(id -u):$(id -g)" -e HOME=/tmp "$@"
}

# Resultado de un escáner de seguridad. Cada herramienta usa un código de salida propio para "encontré hallazgos";
# cualquier otro código distinto de 0 es un error de la herramienta y siempre detiene el pipeline.
# Con hallazgos: en modo estricto se detiene, en modo auditoría solo avisa.
resultado_seguridad() {
  local nombre="$1" codigo="$2" codigo_hallazgos="${3:-1}"
  if [[ "$codigo" -eq 0 ]]; then info "$nombre: sin hallazgos bloqueantes"
  elif [[ "$codigo" -ne "$codigo_hallazgos" ]]; then fail "$nombre terminó con error (código $codigo), revisa el log"
  elif [[ "$MODO_ESTRICTO" == "true" ]]; then fail "$nombre encontró hallazgos (modo estricto)"
  else echo "  ⚠ $nombre encontró hallazgos (modo auditoría: se reportan sin detener el pipeline)"
  fi
}

# Suma las líneas "Total: N (HIGH: a, CRITICAL: b)" de un reporte de Trivy en formato tabla
resumen_trivy() {
  awk -F'[:,()]' '/^Total: / {t+=$2; h+=$4; c+=$6} END {printf "%d hallazgos (HIGH: %d, CRITICAL: %d)", t, h, c}' "$1"
}

pom_version() {
  python3 - "$1" <<'PY'
import sys, xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
v = root.find('{http://maven.apache.org/POM/4.0.0}version')
print((v if v is not None else root.find('version')).text.strip())
PY
}

version_de() {
  local svc="$1"
  if [[ -f "$APP_DIR/$svc/pom.xml" ]]; then pom_version "$APP_DIR/$svc/pom.xml"
  else python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['version'])" "$APP_DIR/$svc/package.json"
  fi
}

COMMIT="$(git -C "$APP_DIR" rev-parse --short=7 HEAD 2>/dev/null || echo sin-codigo)"

# Tag inmutable y trazable: <versión del código>-<commit>. Nunca `latest`.
tag_de() { echo "$(version_de "$1")-$COMMIT"; }
imagen_de() { echo "$REGISTRY/$PREFIX-$1:$(tag_de "$1")"; }
