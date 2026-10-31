#!/usr/bin/env bash
# Etapa 2 — Compilar, ejecutar tests y empaquetar.
# `mvn verify` recorre el ciclo de Maven en orden: compile → test (unitarios) → package (jar) → verify (integración).
# JaCoCo se engancha como agente a la JVM de los tests para medir la cobertura, sin modificar el pom.xml.
source "$(dirname "$0")/lib/common.sh"
etapa "2. Build + tests"

JACOCO="org.jacoco:jacoco-maven-plugin:$JACOCO_VERSION"
for svc in "${BACKENDS[@]}"; do
  info "$svc $(version_de "$svc")"
  mvn -B -ntp -f "$APP_DIR/$svc/pom.xml" "$JACOCO:prepare-agent" verify "$JACOCO:report"
done

# Frontend: no tiene tests (*.spec.ts = 0) y el repo no versiona package-lock.json,
# por eso se usa `npm install` en vez de `npm ci`. Ambos son hallazgos para corregir en el repo.
info "$FRONTEND $(version_de "$FRONTEND") (sin tests en el repo)"
herramienta -w "$APP_DIR/$FRONTEND" -e npm_config_cache=/tmp/.npm "$IMG_NODE" \
  sh -c "npm install --legacy-peer-deps --no-audit --no-fund && npm run build -- --configuration=production"
