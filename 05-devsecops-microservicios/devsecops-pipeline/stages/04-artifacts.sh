#!/usr/bin/env bash
# Etapa 4 — Verificar que se generaron los artefactos y guardarlos con su checksum.
# En una empresa estos artefactos irían a un repositorio de artefactos (Nexus, Artifactory, AWS CodeArtifact).
source "$(dirname "$0")/lib/common.sh"
etapa "4. Verificar artefactos"

for svc in "${BACKENDS[@]}"; do
  app="$APP_DIR/$svc/target/quarkus-app"
  [[ -f "$app/quarkus-run.jar" && -d "$app/lib" ]] || fail "$svc: no se generó target/quarkus-app/quarkus-run.jar"
  tar -czf "$OUT_DIR/artefactos/$svc-$(tag_de "$svc").tar.gz" -C "$APP_DIR/$svc/target" quarkus-app
  info "$svc: quarkus-run.jar + $(ls "$app/lib/main" | wc -l) dependencias"
done

dist="$APP_DIR/$FRONTEND/dist/$FRONTEND/browser"
[[ -f "$dist/index.html" ]] || fail "$FRONTEND: no se generó dist/$FRONTEND/browser/index.html"
tar -czf "$OUT_DIR/artefactos/$FRONTEND-$(tag_de "$FRONTEND").tar.gz" -C "$APP_DIR/$FRONTEND/dist/$FRONTEND" browser
info "$FRONTEND: $(find "$dist" -type f | wc -l) archivos estáticos"

(cd "$OUT_DIR/artefactos" && sha256sum ./*.tar.gz | tee SHA256SUMS)
