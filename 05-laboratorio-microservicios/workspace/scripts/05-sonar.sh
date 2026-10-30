#!/usr/bin/env bash
# Etapa 5 — Calidad de código con SonarQube. Va después de los tests porque necesita las clases compiladas
# y el reporte de cobertura de JaCoCo. `sonar.qualitygate.wait=true` hace que el pipeline espere el veredicto
# del quality gate y falle si no pasa.
source "$(dirname "$0")/lib.sh"
SONAR_HOST_URL="${SONAR_HOST_URL:-http://localhost:9000}"
etapa "5. Calidad (SonarQube en $SONAR_HOST_URL)"

# En una empresa SONAR_TOKEN es un secret del pipeline. En la simulación, si no viene, se genera uno
# temporal contra el SonarQube efímero usando el usuario admin por defecto.
if [[ -z "${SONAR_TOKEN:-}" ]]; then
  for _ in $(seq 60); do
    curl -fs "$SONAR_HOST_URL/api/system/status" | grep -q '"status":"UP"' && break
    sleep 5
  done
  SONAR_TOKEN="$(curl -fs -u "admin:${SONAR_ADMIN_PASSWORD:-admin}" -X POST \
    "$SONAR_HOST_URL/api/user_tokens/generate" -d "name=pipeline-$COMMIT-$RANDOM" -d "type=GLOBAL_ANALYSIS_TOKEN" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')" || fail "no se pudo generar un token de SonarQube"
fi

for svc in "${BACKENDS[@]}"; do
  info "$svc"
  mvn -B -ntp -f "$APP_DIR/$svc/pom.xml" \
    "org.sonarsource.scanner.maven:sonar-maven-plugin:$SONAR_PLUGIN_VERSION:sonar" \
    -Dsonar.host.url="$SONAR_HOST_URL" -Dsonar.token="$SONAR_TOKEN" \
    -Dsonar.projectKey="$PREFIX-$svc" -Dsonar.projectVersion="$(tag_de "$svc")" \
    -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml \
    -Dsonar.qualitygate.wait=true
done
info "Tablero: $SONAR_HOST_URL/projects"
