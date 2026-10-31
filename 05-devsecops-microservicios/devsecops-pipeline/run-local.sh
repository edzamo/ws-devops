#!/usr/bin/env bash
# Ejecuta el pipeline completo en la máquina local, en el mismo orden que GitHub Actions y Jenkins.
#   ./run-local.sh                 # todas las etapas (0 a 10)
#   ./run-local.sh 2 4             # solo de la etapa 2 a la 4 (el código ya descargado)
#   RAMA=feature/x ./run-local.sh  # otra rama (ver docs/03-CONFIGURACION.md)
# La etapa 5 necesita un SonarQube en SONAR_HOST_URL (por defecto http://localhost:9000):
#   docker run -d --name sonarqube -p 9000:9000 -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true sonarqube:26.10.0.133078-community
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)/stages"
desde="${1:-0}"; hasta="${2:-10}"
for script in "$DIR"/[0-9][0-9]-*.sh; do
  n=$((10#$(basename "$script" | cut -c1-2)))
  (( n >= desde && n <= hasta )) && "$script"
done
echo; echo "Pipeline local terminado. Reportes y artefactos en: ${TRABAJO_DIR:-${TMPDIR:-/tmp}/poc-credit-evaluation-pipeline}/salida"
