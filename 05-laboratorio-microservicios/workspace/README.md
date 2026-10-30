# 🏭 Pipeline CI/CD simulado — `poc-credit-evaluation`

Documentación técnica del pipeline del Laboratorio 05. Simula el proceso que exige una entidad regulada (banca) para llevar 3 servicios (Angular y 2 microservicios Quarkus) desde el repositorio hasta un registro de imágenes y un ambiente de despliegue, con controles de calidad y seguridad en cada paso.

| Sección | Contenido |
|---|---|
| [A](#a-visión-general) | Visión general y principios de diseño |
| [B](#b-estructura-de-la-carpeta) | Estructura de la carpeta |
| [C](#c-orden-de-las-etapas-y-por-qué) | Orden de las etapas y por qué |
| [D](#d-detalle-de-cada-etapa-scripting) | Detalle de cada etapa (scripting) |
| [E](#e-parámetros-y-secretos) | Parámetros y secretos (detalle en [VARIABLES.md](VARIABLES.md)) |
| [F](#f-gobernanza) | Gobernanza |
| [G](#g-cómo-ejecutarlo) | Cómo ejecutarlo: GitHub Actions y Jenkins |
| [H](#h-llevarlo-a-aws-o-azure) | Llevarlo a AWS o Azure |
| [I](#i-resultados-de-referencia-y-hallazgos-conocidos) | Resultados de referencia y hallazgos conocidos |

---

## A. Visión general

```text
 ┌──────────────────────────────── CI ─────────────────────────────────┐   ┌─────────────── CD ───────────────┐
 Repo ─► 0 Descargar ─► 1 Secretos ─► 2 Build+tests ─► 3 Cobertura ─► 4 Artefactos ─► 5 Sonar ─► 6 SAST/SCA ─► 7 Imágenes ─► 8 Escaneo ─► Aprobación ─► 9 Publicar ─► 10 Deploy + DAST
```

**Principios de diseño:**

1. **La lógica vive en scripts, no en la herramienta de CI.** Cada etapa es un script Bash en [`scripts/`](scripts/). GitHub Actions y Jenkins solo los llaman en orden. Cambiar de herramienta (Azure DevOps, GitLab CI, AWS CodeBuild) es reescribir el archivo que orquesta, no la lógica. Los scripts se pueden ejecutar también en una laptop.
2. **Construir una vez, desplegar muchas.** El jar se compila una sola vez en la etapa 2. La imagen de la etapa 7 copia **ese** jar, el que pasó los tests, y no lo recompila. El CD despliega **esa** imagen.
3. **La línea se detiene sola.** Cada control tiene un criterio de falla. Nadie tiene que acordarse de revisar.
4. **Evidencia de cada ejecución.** Reportes, jars, SBOM y logs se guardan como artefactos del pipeline: es lo que pide un auditor.
5. **Herramientas en contenedores y con versión fija.** Trivy, Semgrep, Gitleaks, ZAP y Node corren en contenedores con versión fija (nunca `latest`). El runner solo necesita Java 21, Maven, Python 3 y Docker.

> ¿Bash o Python? Cualquiera sirve. Bash es la opción natural cuando el trabajo es encadenar CLIs (`mvn`, `docker`, `trivy`). Python conviene cuando hay lógica de datos (parsear JSON, llamar APIs, reglas complejas). Aquí el 90 % es llamar herramientas, por eso Bash.

---

## B. Estructura de la carpeta

`workspace/` es el área de trabajo del pipeline: todo lo que hace falta para construir, probar, publicar y desplegar, **sin** el código de la aplicación.

```text
.github/workflows/
└── pipeline-poc-credit-evaluation.yml   Orquestador GitHub Actions (GitHub exige esta ruta)

05-laboratorio-microservicios/workspace/
├── README.md                    Este documento
├── VARIABLES.md                 Cada variable y secreto, y dónde se configura en GitHub, Jenkins y local
├── ejecutar-local.sh            Corre el pipeline completo (o un rango de etapas) en la laptop
├── scripts/                     La lógica del pipeline: un script por etapa
│   ├── lib.sh                   Variables, versiones de herramientas y funciones comunes
│   ├── 00-descargar-codigo.sh   Descarga REPO_URL @ RAMA (solo local; en CI lo hace la herramienta)
│   └── 01-secretos.sh … 10-deploy-dast.sh
├── docker/                      Dockerfiles del pipeline (empaquetan artefactos ya construidos)
│   ├── Dockerfile.quarkus
│   └── Dockerfile.frontend
├── deploy/
│   └── docker-compose.yml       Ambiente simulado que levanta la etapa 10
└── jenkins/                     Orquestador Jenkins + su infraestructura local
    ├── Jenkinsfile
    ├── docker-compose.yml       Jenkins + SonarQube
    ├── Dockerfile, plugins.txt, casc.yaml   Jenkins preconfigurado (Configuration as Code)
    └── .env.example             Plantilla de secretos locales (el .env real no se versiona)
```

**El código de la aplicación no vive aquí.** El pipeline lo descarga en cada ejecución desde [`edzamo/poc-credit-evaluation`](https://github.com/edzamo/poc-credit-evaluation), en la rama indicada, a una carpeta de trabajo **fuera** del repositorio (`TRABAJO_DIR`). Así se construye siempre desde lo que está en Git, como en un banco, y no desde la copia de alguien.

---

## C. Orden de las etapas y por qué

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

## D. Detalle de cada etapa (scripting)

Cada script carga [`lib.sh`](scripts/lib.sh), que define las rutas (`APP_DIR` código, `OUT_DIR` salida), los parámetros y las versiones de las herramientas.

| # | Script | Qué hace | Herramienta | Falla si… | Evidencia (`salida/`) |
|---|---|---|---|---|---|
| 1 | [`01-secretos.sh`](scripts/01-secretos.sh) | Revisa **todo el historial** de commits buscando contraseñas, tokens y llaves | Gitleaks | Encuentra un secreto ¹ | `reportes/gitleaks.json` |
| 2 | [`02-build-test.sh`](scripts/02-build-test.sh) | `mvn verify` en los 2 backends con el agente de JaCoCo (sin tocar el `pom.xml`); `npm install` + `ng build` del frontend | Maven, JaCoCo, Node | No compila o falla un test | `target/surefire-reports` |
| 3 | [`03-cobertura.sh`](scripts/03-cobertura.sh) | Calcula la cobertura de líneas desde `jacoco.csv` y la compara con el mínimo | awk | Cobertura < `COBERTURA_MINIMA` | `reportes/cobertura-*/index.html` |
| 4 | [`04-artefactos.sh`](scripts/04-artefactos.sh) | Comprueba que existan `quarkus-run.jar` y el `dist/` de Angular; los empaqueta con checksum SHA-256 | tar, sha256sum | Falta un artefacto | `artefactos/*.tar.gz`, `SHA256SUMS` |
| 5 | [`05-sonar.sh`](scripts/05-sonar.sh) | Análisis de calidad con la cobertura de JaCoCo; espera el veredicto del quality gate | SonarQube Community | El quality gate no pasa | Tablero de SonarQube |
| 6 | [`06-sast-sca.sh`](scripts/06-sast-sca.sh) | **SAST:** patrones inseguros en nuestro código y Dockerfiles. **SCA:** CVE en los jars de terceros resueltos y en `package-lock.json` | Semgrep CE, Trivy | Hallazgos ERROR / HIGH-CRITICAL ¹ | `reportes/semgrep.sarif`, `reportes/trivy-dependencias-*.txt` |
| 7 | [`07-imagenes.sh`](scripts/07-imagenes.sh) | Construye las 3 imágenes **copiando** los artefactos de la etapa 2, con labels OCI (versión, commit, origen, fecha) | Docker | Falla el build | Imágenes locales |
| 8 | [`08-escaneo-imagenes.sh`](scripts/08-escaneo-imagenes.sh) | Escanea cada imagen (sistema base + librerías) y genera el SBOM | Trivy | CVE HIGH/CRITICAL con parche disponible ¹ | `reportes/trivy-imagen-*.txt`, `reportes/sbom-*.cdx.json` |
| 9 | [`09-publicar.sh`](scripts/09-publicar.sh) | Login con el token, rechaza tags que ya existen (inmutables), publica y registra el **digest** | Docker Hub | El tag ya existe o falta la credencial | `reportes/imagenes-publicadas.txt` |
| 10 | [`10-deploy-dast.sh`](scripts/10-deploy-dast.sh) | Levanta el stack (Postgres + 3 servicios), espera *healthy*, smoke tests (`/q/health`, frontend, POST de una evaluación) y escaneo ZAP baseline | Docker Compose, curl, OWASP ZAP | Un servicio no queda healthy, falla el smoke test o hay alertas FAIL de ZAP ¹ | `reportes/zap-*.html`, `reportes/deploy-logs.txt` |

¹ Controles de seguridad: con `MODO_ESTRICTO=false` (por defecto) **reportan sin detener** el pipeline (modo auditoría); con `true` lo detienen. Si la herramienta misma falla (red, configuración), el pipeline se detiene siempre: un escáner que no corrió no es un escáner en verde.

**Nomenclatura de imágenes:** `edzamo13/austro-<servicio>:<versión del código>-<commit>`, por ejemplo `edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.0-SNAPSHOT-3915239`. El tag es inmutable y trazable a un commit exacto. Nunca se usa `latest`.

**Dockerfiles del pipeline vs. los del repo:** los `Dockerfile` del repo de la aplicación compilan dentro de la imagen (sirven para un desarrollador sin Java instalado). Los de [`docker/`](docker/) solo copian el artefacto ya probado: así se garantiza que lo que se publica es exactamente lo que pasó los controles.

---

## E. Parámetros y secretos

El catálogo completo, y el paso a paso para configurarlos en GitHub, Jenkins y local, está en **[VARIABLES.md](VARIABLES.md)**. Resumen:

| Parámetro | Por defecto | Para qué |
|---|---|---|
| `REPO_URL` / `RAMA` | `poc-credit-evaluation` / `main` | Qué código se construye |
| `COBERTURA_MINIMA` | `30` | Umbral de cobertura (%). Es la línea base actual del proyecto. Lo normal en banca es 80 % sobre código nuevo |
| `MODO_ESTRICTO` | `false` | Si los hallazgos de seguridad detienen el pipeline |
| `PUBLICAR` | `false` | `true` publica en Docker Hub; `false` es un *dry run* |

| Secreto | Cuándo |
|---|---|
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | Solo para publicar |
| `REPO_TOKEN` | Solo si el repo del código es privado |
| `SONAR_TOKEN` | Opcional: en la simulación se genera uno temporal |

---

## F. Gobernanza

| Control | GitHub Actions | Jenkins | Qué demuestra |
|---|---|---|---|
| Aprobación humana antes de publicar y desplegar | Environment `simulacion-produccion` con *required reviewers* (Settings → Environments) | Etapa `Aprobación` (`input`) | Segregación de funciones |
| Mínimo privilegio | `permissions: contents: read` | Credenciales solo dentro de `withCredentials` | El pipeline no puede modificar el repo, y los secretos solo existen en la etapa que los usa |
| Rama protegida | Settings → Branches: PR obligatorio y check del pipeline en verde | — | Nadie fusiona sin pasar el pipeline |
| Mismo commit en CI y CD | El job de CD descarga el SHA exacto que pasó el CI | El workspace es el mismo | Lo que se aprobó es lo que se despliega |
| Trazabilidad | Labels OCI + digest publicado + artefactos de cada ejecución | `archiveArtifacts` + resultados JUnit | Responder "¿de qué commit salió esta imagen?" |

---

## G. Cómo ejecutarlo

### GitHub Actions

| Evento | Qué corre | Ambiente |
|---|---|---|
| **Push a `feature/...`** que toca `workspace/` o el workflow | CI (0-8) + CD (9 en *dry run*, 10) | `test`, sin aprobación |
| **Pull request** | Solo CI | — |
| **Run workflow** manual (desde `main`) | CI + CD con los parámetros elegidos | `simulacion-produccion`, con aprobación |

1. Crear los environments `test` y `simulacion-produccion` (Settings → Environments). En el segundo, agregarte como *required reviewer*.
2. Solo para publicar: crear los secrets `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN`.
3. Push a una rama `feature/...`, o Actions → **pipeline-poc-credit-evaluation** → *Run workflow*.
4. Descargar la evidencia desde la ejecución: `ci-reportes-y-artefactos` y `cd-reportes`.

### Jenkins (local con Docker)

```bash
cd 05-laboratorio-microservicios/workspace/jenkins
cp .env.example .env                      # completar: contraseña admin, DOCKER_GID, token si se publica
docker compose up -d --build              # Jenkins en http://localhost:8085, SonarQube en http://localhost:9000
```

El job `pipeline-poc-credit-evaluation` ya aparece creado: lee el `Jenkinsfile` desde este repo en GitHub (rama `main`, configurable con `WS_DEVOPS_RAMA` en `.env`). *Build with Parameters* → aprobar en la etapa `Aprobación` → ver reportes en *Artifacts*.

Requisitos de la máquina: Docker con Compose v2 y ~6 GB de RAM libres (Jenkins + SonarQube + el stack de la etapa 10).

### En la laptop

```bash
cd 05-laboratorio-microservicios/workspace
./ejecutar-local.sh              # etapas 0 a 10: descarga main, compila en /tmp, deja reportes en /tmp/.../salida
./ejecutar-local.sh 2 4          # solo build, cobertura y artefactos (el código ya descargado)
RAMA=feature/x ./ejecutar-local.sh
```

Requisitos: Java 21, Maven, Python 3 y Docker. La etapa 5 necesita un SonarQube en `localhost:9000` (el comando está en la cabecera de [`ejecutar-local.sh`](ejecutar-local.sh)).

---

## H. Llevarlo a AWS o Azure

Las etapas y los scripts no cambian. Cambian el orquestador y los servicios a los que se conectan:

| Pieza | Esta simulación | AWS | Azure |
|---|---|---|---|
| Orquestador del pipeline | GitHub Actions / Jenkins | CodePipeline + CodeBuild (o GitHub Actions con OIDC) | Azure DevOps Pipelines (o GitHub Actions con OIDC) |
| Repositorio de artefactos (jars) | Artefactos del pipeline | CodeArtifact o S3 | Azure Artifacts |
| Registro de imágenes | Docker Hub | ECR | ACR |
| Secretos | Secrets de GitHub / credenciales Jenkins | Secrets Manager / Parameter Store | Key Vault |
| Autenticación del pipeline con la nube | Token de Docker Hub | Rol IAM asumido por OIDC (sin llaves de larga duración) | Workload identity federation |
| Calidad | SonarQube efímero | SonarQube en EC2/ECS o SonarCloud | SonarQube en VM/AKS o SonarCloud |
| Escaneo de imágenes | Trivy | Trivy o ECR image scanning (Inspector) | Trivy o Defender for Containers |
| Ambiente de despliegue | Docker Compose en el runner | EKS o ECS | AKS o Container Apps |
| Aprobación | Environment / `input` | Manual approval de CodePipeline | Approvals and checks del environment |

En la práctica, migrar significa cambiar la etapa 9 (login y push al registro de la nube) y la etapa 10 (desplegar en el clúster en lugar de Compose). La siguiente parada de este curso es justamente esa etapa 10 en **Minikube**.

---

## I. Resultados de referencia y hallazgos conocidos

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
