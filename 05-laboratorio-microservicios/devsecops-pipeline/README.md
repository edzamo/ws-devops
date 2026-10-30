# 🏭 devsecops-pipeline — `poc-credit-evaluation`

Pipeline CI/CD con controles de seguridad integrados (DevSecOps) para `poc-credit-evaluation`: 1 frontend Angular y 2 microservicios Quarkus. Lleva el código desde el repositorio hasta un registro de imágenes y un ambiente desplegado, con tests, cobertura, calidad, SAST, SCA, escaneo de imágenes, aprobación y DAST.

Un solo conjunto de scripts y cuatro orquestadores intercambiables:

| Orquestador | Archivo | Estado |
|---|---|---|
| GitHub Actions | [`.github/workflows/poc-credit-evaluation-cicd.yml`](../../.github/workflows/poc-credit-evaluation-cicd.yml) | Listo para ejecutarse con un push a `feature/*` |
| Jenkins | [`orchestrators/jenkins/Jenkinsfile`](orchestrators/jenkins/Jenkinsfile) | Listo, con Jenkins y SonarQube locales preconfigurados |
| Azure DevOps | [`orchestrators/azure-devops/`](orchestrators/azure-devops/) | Ejemplo de referencia con el modelo de banco: pipeline corto en la app que extiende una plantilla central (`extends`), GitFlow, ACR, Key Vault |
| AWS | [`orchestrators/aws-codepipeline/`](orchestrators/aws-codepipeline/) | Ejemplo de referencia: CodePipeline + CodeBuild + ECR, infraestructura en CloudFormation |

## 📚 Documentación

| # | Documento | Para quién | Contenido |
|---|---|---|---|
| 1 | [Arquitectura](docs/01-ARQUITECTURA.md) | Arquitectos | Capas, responsabilidades, flujo, secretos, Bash vs. Python, modelo de banco, glosario |
| 2 | [Etapas](docs/02-ETAPAS.md) | DevOps, desarrollo | Orden y detalle de las 11 etapas, resultados y hallazgos |
| 3 | [Configuración](docs/03-CONFIGURACION.md) | DevOps, operaciones | Cada variable y secreto, y dónde se configura en GitHub, Jenkins y local |
| 4 | [Gobernanza y nube](docs/04-GOBERNANZA-Y-NUBE.md) | Arquitectos, seguridad, auditoría | Controles de gobernanza y equivalencias en AWS y Azure |
| 5 | [DevSecOps: aprendizaje](docs/05-DEVSECOPS-APRENDIZAJE.md) | Todos (estudio) | SAST, SCA, DAST/ZAP y demás controles, herramientas libres y de pago, píldoras de junior a arquitecto |

## 🗂️ Estructura

```text
.github/workflows/
└── poc-credit-evaluation-cicd.yml      Orquestador GitHub Actions (GitHub exige esta ruta)

devsecops-pipeline/
├── README.md                           Este documento
├── docs/                               Documentación (01 a 05)
├── orchestrators/                      CAPA DE ORQUESTACIÓN: el qué y el cuándo
│   ├── github-actions/README.md        Dónde está y cómo se dispara el workflow
│   ├── azure-devops/                   caller/ (pipeline corto de la app) + templates/ (plantilla central) + guía
│   ├── aws-codepipeline/               pipeline.yml (CloudFormation) + buildspec-ci/cd.yml + guía
│   └── jenkins/
│       ├── Jenkinsfile                 Orquestador Jenkins
│       └── docker-compose.yml, Dockerfile, plugins.txt, casc.yaml, .env.example
│                                       Jenkins + SonarQube locales, preconfigurados (Configuration as Code)
├── stages/                             CAPA DE LÓGICA: el cómo (un script por etapa)
│   ├── lib/common.sh                   Configuración común: rutas, parámetros, versiones de herramientas
│   ├── 00-checkout.sh                  Descargar el código (solo local; en CI lo hace el orquestador)
│   ├── 01-secret-scan.sh               Secretos en el historial (Gitleaks)
│   ├── 02-build-test.sh                Compilar + tests + empaquetar (Maven, JaCoCo, Angular)
│   ├── 03-coverage-gate.sh             Cobertura mínima
│   ├── 04-artifacts.sh                 Verificar y guardar los jars con checksum
│   ├── 05-code-quality.sh              SonarQube + quality gate
│   ├── 06-sast-sca.sh                  SAST (Semgrep) + SCA (Trivy)
│   ├── 07-image-build.sh               Imágenes desde los jars ya probados
│   ├── 08-image-scan.sh                Escaneo de imágenes + SBOM (Trivy)
│   ├── 09-image-publish.sh             Publicar en Docker Hub
│   └── 10-deploy-dast.sh               Deploy simulado + smoke test + DAST (ZAP)
├── container-images/                   Dockerfiles de las imágenes que se publican
├── environments/simulated/             Definición del ambiente simulado (etapa 10)
└── run-local.sh                        Ejecutar el pipeline en la laptop
```

El código de la aplicación **no** vive aquí: el pipeline lo descarga en cada ejecución desde [`edzamo/poc-credit-evaluation`](https://github.com/edzamo/poc-credit-evaluation), en la rama indicada, a una carpeta de trabajo fuera del repositorio.

## ▶️ Cómo ejecutarlo

## GitHub Actions

| Evento | Qué corre | Ambiente |
|---|---|---|
| **Push a `feature/...`** que toca `devsecops-pipeline/` o el workflow | CI (0-8) + CD (9 en *dry run*, 10) | `test`, sin aprobación |
| **Pull request** | Solo CI | — |
| **Run workflow** manual (desde `main`) | CI + CD con los parámetros elegidos | `simulacion-produccion`, con aprobación |

1. Crear los environments `test` y `simulacion-produccion` (Settings → Environments). En el segundo, agregarte como *required reviewer*.
2. Solo para publicar: crear los secrets `DOCKERHUB_USERNAME` y `DOCKERHUB_TOKEN`.
3. Push a una rama `feature/...`, o Actions → **poc-credit-evaluation-cicd** → *Run workflow*.
4. Descargar la evidencia desde la ejecución: `ci-reportes-y-artefactos` y `cd-reportes`.

## Jenkins (local con Docker)

```bash
cd 05-laboratorio-microservicios/devsecops-pipeline/orchestrators/jenkins
cp .env.example .env                      # completar: contraseña admin, DOCKER_GID, token si se publica
docker compose up -d --build              # Jenkins en http://localhost:8085, SonarQube en http://localhost:9000
```

El job `poc-credit-evaluation-cicd` ya aparece creado: lee el `Jenkinsfile` desde este repo en GitHub (rama `main`, configurable con `WS_DEVOPS_RAMA` en `.env`). *Build with Parameters* → aprobar en la etapa `Aprobación` → ver reportes en *Artifacts*.

Requisitos de la máquina: Docker con Compose v2 y ~6 GB de RAM libres (Jenkins + SonarQube + el stack de la etapa 10).

## En la laptop

```bash
cd 05-laboratorio-microservicios/devsecops-pipeline
./run-local.sh              # etapas 0 a 10: descarga main, compila en /tmp, deja reportes en /tmp/.../salida
./run-local.sh 2 4          # solo build, cobertura y artefactos (el código ya descargado)
RAMA=feature/x ./run-local.sh
```

Requisitos: Java 21, Maven, Python 3 y Docker. La etapa 5 necesita un SonarQube en `localhost:9000` (el comando está en la cabecera de [`run-local.sh`](run-local.sh)).
