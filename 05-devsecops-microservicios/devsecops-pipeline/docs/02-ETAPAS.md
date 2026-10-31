# 🔁 Etapas del pipeline

Qué hace cada etapa, en qué orden y por qué, y los resultados de la ejecución de referencia. Visión general en [01-ARQUITECTURA.md](01-ARQUITECTURA.md).

## 1. Orden de las etapas y por qué

| Orden | Regla | Motivo |
|---|---|---|
| Secretos primero | Lo más barato y lo más grave | Si hay una contraseña en el repo, no tiene sentido seguir: hay que rotarla ya |
| Compilar → tests → empaquetar | Es una sola etapa (`mvn verify`) | No se puede testear código que no compila, y no se empaqueta código que no pasó los tests. Maven recorre ese orden solo: `compile → test → package → verify` |
| Cobertura después de tests | La cobertura se mide **mientras** corren los tests | JaCoCo se engancha a la JVM de los tests y genera el reporte al terminar |
| Sonar después de cobertura | Sonar necesita clases compiladas y el reporte de JaCoCo | Sin eso, Sonar no puede mostrar cobertura ni analizar bytecode |
| SAST/SCA antes de las imágenes | Encontrar problemas en el código antes de gastar en empaquetar | En un pipeline con jobs paralelos, 5 y 6 pueden correr al mismo tiempo |
| Escanear imágenes antes de publicar | Lo que no pasa, no sale | La imagen agrega el sistema operativo base y sus CVE: hay que escanearla aparte del código |
| Aprobación antes de publicar | Segregación de funciones | Quien escribe el código no decide solo que sale a producción |
| Deploy y DAST al final | DAST necesita la aplicación corriendo | Prueba la app desde afuera, como lo haría un atacante |

---

## 2. Detalle de cada etapa

Cada script de [`stages/`](../stages/) carga [`lib/common.sh`](../stages/lib/common.sh), que define las rutas (`APP_DIR` código, `OUT_DIR` salida), los parámetros y las versiones de las herramientas.

| # | Script | Qué hace | Herramienta | Falla si… | Evidencia (`salida/`) |
|---|---|---|---|---|---|
| 1 | [`01-secret-scan.sh`](../stages/01-secret-scan.sh) | Revisa **todo el historial** de commits buscando contraseñas, tokens y llaves | Gitleaks | Encuentra un secreto ¹ | `reportes/gitleaks.json` |
| 2 | [`02-build-test.sh`](../stages/02-build-test.sh) | `mvn verify` en los 2 backends con el agente de JaCoCo (sin tocar el `pom.xml`); `npm install` + `ng build` del frontend | Maven, JaCoCo, Node | No compila o falla un test | `target/surefire-reports` |
| 3 | [`03-coverage-gate.sh`](../stages/03-coverage-gate.sh) | Calcula la cobertura de líneas desde `jacoco.csv` y la compara con el mínimo | awk | Cobertura < `COBERTURA_MINIMA` | `reportes/cobertura-*/index.html` |
| 4 | [`04-artifacts.sh`](../stages/04-artifacts.sh) | Comprueba que existan `quarkus-run.jar` y el `dist/` de Angular; los empaqueta con checksum SHA-256 | tar, sha256sum | Falta un artefacto | `artefactos/*.tar.gz`, `SHA256SUMS` |
| 5 | [`05-code-quality.sh`](../stages/05-code-quality.sh) | Análisis de calidad con la cobertura de JaCoCo; espera el veredicto del quality gate | SonarQube Community | El quality gate no pasa | Tablero de SonarQube |
| 6 | [`06-sast-sca.sh`](../stages/06-sast-sca.sh) | **SAST:** patrones inseguros en nuestro código y Dockerfiles. **SCA:** CVE en los jars de terceros resueltos y en `package-lock.json` | Semgrep CE, Trivy | Hallazgos ERROR / HIGH-CRITICAL ¹ | `reportes/semgrep.sarif`, `reportes/trivy-dependencias-*.txt` |
| 7 | [`07-image-build.sh`](../stages/07-image-build.sh) | Construye las 3 imágenes **copiando** los artefactos de la etapa 2, con labels OCI (versión, commit, origen, fecha) | Docker | Falla el build | Imágenes locales |
| 8 | [`08-image-scan.sh`](../stages/08-image-scan.sh) | Escanea cada imagen (sistema base + librerías) y genera el SBOM | Trivy | CVE HIGH/CRITICAL con parche disponible ¹ | `reportes/trivy-imagen-*.txt`, `reportes/sbom-*.cdx.json` |
| 9 | [`09-image-publish.sh`](../stages/09-image-publish.sh) | Login con el token, rechaza tags que ya existen (inmutables), publica y registra el **digest** | Docker Hub | El tag ya existe o falta la credencial | `reportes/imagenes-publicadas.txt` |
| 10 | [`10-deploy-dast.sh`](../stages/10-deploy-dast.sh) | Levanta el stack (Postgres + 3 servicios), espera *healthy*, smoke tests (`/q/health`, frontend, POST de una evaluación) y escaneo ZAP baseline | Docker Compose, curl, OWASP ZAP | Un servicio no queda healthy, falla el smoke test o hay alertas FAIL de ZAP ¹ | `reportes/zap-*.html`, `reportes/deploy-logs.txt` |

¹ Controles de seguridad: con `MODO_ESTRICTO=false` (por defecto) **reportan sin detener** el pipeline (modo auditoría); con `true` lo detienen. Si la herramienta misma falla (red, configuración), el pipeline se detiene siempre: un escáner que no corrió no es un escáner en verde.

**Nomenclatura de imágenes:** `edzamo13/austro-<servicio>:<versión del código>-<commit>`, por ejemplo `edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.0-SNAPSHOT-3915239`. El tag es inmutable y trazable a un commit exacto. Nunca se usa `latest`.

**Dockerfiles del pipeline vs. los del repo:** los `Dockerfile` del repo de la aplicación compilan dentro de la imagen (sirven para un desarrollador sin Java instalado). Los de [`container-images/`](../container-images/) solo copian el artefacto ya probado: así se garantiza que lo que se publica es exactamente lo que pasó los controles.

---

## 3. Resultados de referencia y hallazgos conocidos

Ejecución completa de los 10 scripts en local el 2026-10-30, sobre `poc-credit-evaluation@3915239` (`main`):

| Etapa | Resultado |
|---|---|
| 1. Secretos | 5 commits revisados, sin secretos |
| 2. Build + tests | `ms-risk-mock`: 5 tests ✓ · `ms-orchestrator`: 34 tests ✓ · frontend compila (sin tests) |
| 3. Cobertura | `ms-orchestrator` 63.6 % · `ms-risk-mock` **32.1 %** (falla con un umbral de 60 %) |
| 4. Artefactos | 2 `quarkus-run.jar` (107 y 167 dependencias) y `dist/` de Angular, con SHA-256 |
| 5. SonarQube | Quality gate PASSED en ambos · orquestador: 0 bugs, 0 vulnerabilidades, 1 code smell |
| 6. SAST / SCA | Semgrep: 1 hallazgo · Trivy: 32-33 HIGH/CRITICAL por backend (Quarkus 3.8.4), 0 en el frontend |
| 7-8. Imágenes | 3 imágenes · CVE: 35, 36 y **60** (frontend, por la base `nginx:1.27-alpine`) · 3 SBOM |
| 9. Publicar | Dry run |
| 10. Deploy + DAST | Stack healthy · POST de evaluación HTTP 201 · ZAP: 0 FAIL, 12 WARN |

**Hallazgos para corregir en el repo de la aplicación** (en modo estricto detendrían el pipeline):

| Hallazgo | Origen | Corrección |
|---|---|---|
| Quarkus 3.8.4 con ~33 CVE HIGH/CRITICAL | Trivy SCA | Actualizar a una versión LTS vigente de Quarkus |
| Nginx corre como root en el frontend | Semgrep | Usar `nginx-unprivileged` y puerto 8080 |
| Base `nginx:1.27-alpine` desactualizada (60 CVE) | Trivy imagen | Subir de versión y fijarla por digest |
| Cobertura de `ms-risk-mock` en 32 % | JaCoCo | Agregar tests; subir el umbral gradualmente |
| Frontend sin tests y sin `package-lock.json` versionado | Etapa 2 | Versionar el lockfile (usar `npm ci`) y agregar tests |
| Faltan cabeceras de seguridad (CSP, Permissions-Policy, CORP) | ZAP | Agregarlas en `nginx.conf` |
| Credenciales de Postgres en texto plano en `docker-compose.yml` | Revisión | `Secret` de Kubernetes en la siguiente etapa |
