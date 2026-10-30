# 🏗️ Arquitectura del pipeline DevSecOps

Documento para arquitectos de soluciones y arquitectos DevOps. Explica **cómo funciona un pipeline por dentro**, en abstracto. El detalle técnico está en los demás documentos de esta carpeta.

| Documento | Para quién | Contenido |
|---|---|---|
| **01-ARQUITECTURA.md** (este) | Arquitectos | Capas, responsabilidades, flujo, decisiones y glosario |
| [02-ETAPAS.md](02-ETAPAS.md) | DevOps, desarrollo | Qué hace cada etapa, en qué orden, y los hallazgos |
| [03-CONFIGURACION.md](03-CONFIGURACION.md) | DevOps, operaciones | Variables y secretos, y dónde se configuran en GitHub y Jenkins |
| [04-GOBERNANZA-Y-NUBE.md](04-GOBERNANZA-Y-NUBE.md) | Arquitectos, seguridad, auditoría | Controles de gobernanza y cómo llevarlo a AWS o Azure |
| [05-DEVSECOPS-APRENDIZAJE.md](05-DEVSECOPS-APRENDIZAJE.md) | Todos (estudio) | Cada control explicado, herramientas libres y de pago, ruta de junior a arquitecto |

---

## 1. Qué es y qué no es

Un **pipeline CI/CD** es la línea de producción del software. Toma código de un repositorio y entrega un producto probado, escaneado y desplegado, sin pasos manuales. **DevSecOps** significa que los controles de seguridad van **dentro** de esa línea, en cada etapa, y no como una revisión al final.

| Concepto | Qué es | En este proyecto |
|---|---|---|
| **El pipeline (la definición)** | El código que describe la línea: orquestador + scripts + Dockerfiles | Esta carpeta, `devsecops-pipeline/` |
| **Una ejecución** | Cada vez que la línea corre | Un *run* en GitHub Actions o un *build* en Jenkins |
| **El resultado** | Lo que produce cada ejecución | Jars, imágenes en Docker Hub, reportes, SBOM, ambiente desplegado |

> El YAML no es el resultado: es parte de la **receta**. El resultado son artefactos, imágenes, evidencia y un despliegue.

---

## 2. Las capas y sus responsabilidades

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ 1. PLATAFORMA DE CI/CD (motor)                GitHub Actions · Jenkins · Azure │
│    Presta la máquina (runner / agente), guarda los secretos, ejecuta,          │
│    pide aprobaciones, guarda la evidencia                                      │
└───────────────┬──────────────────────────────────────────────────────────────┘
                │ lee
┌───────────────▼──────────────────────────────────────────────────────────────┐
│ 2. ORQUESTACIÓN: el QUÉ y el CUÁNDO                     orchestrators/          │
│    Disparadores (push, PR, manual), parámetros, orden de etapas,              │
│    qué secreto entra en qué etapa, aprobaciones                                │
│    GitHub Actions → YAML  ·  Jenkins → Jenkinsfile (Groovy)  ·  Azure → YAML  │
└───────────────┬──────────────────────────────────────────────────────────────┘
                │ llama, pasando parámetros y secretos como variables de entorno
┌───────────────▼──────────────────────────────────────────────────────────────┐
│ 3. LÓGICA DE ETAPAS: el CÓMO                             stages/              │
│    Un script por etapa: compilar, medir, escanear, construir, publicar,        │
│    desplegar. Bash aquí; podría ser Python                                     │
└───────────────┬──────────────────────────────────────────────────────────────┘
                │ ejecuta
┌───────────────▼──────────────────────────────────────────────────────────────┐
│ 4. HERRAMIENTAS                                                                │
│    Maven, Docker, SonarQube, Semgrep, Trivy, Gitleaks, ZAP                     │
│    + container-images/ (Dockerfiles: la receta de las imágenes a publicar)     │
│    + environments/ (definición de los ambientes de despliegue)                │
└──────────────────────────────────────────────────────────────────────────────┘

FUERA de esta carpeta, a propósito:
  • Código de la aplicación → su propio repositorio (poc-credit-evaluation)
  • Secretos                → la bóveda de la plataforma (GitHub Secrets, Jenkins Credentials,
                              AWS Secrets Manager, Azure Key Vault)
```

| Capa | Responsable típico en un banco | Cambia cuando… |
|---|---|---|
| Plataforma | Equipo de plataforma / infraestructura | Se cambia de proveedor (Jenkins → GitHub, on-premise → nube) |
| Orquestación | DevOps | Cambian los disparadores, ambientes o aprobaciones |
| Lógica de etapas | DevOps / DevSecOps | Cambia **cómo** se hace un control (otra herramienta de SAST, otro umbral) |
| Herramientas | Seguridad, calidad, DevOps | Sale una versión nueva o se reemplaza una herramienta |

**La regla de diseño:** el orquestador es **delgado** (solo decide el qué y el cuándo) y la lógica es **gruesa** (scripts). Por eso:

- Los cuatro orquestadores llaman **los mismos scripts en el mismo orden**:

  | Orquestador | Lenguaje | Cómo llama a la etapa 2 |
  |---|---|---|
  | GitHub Actions | YAML | `run: "$SCRIPTS/02-build-test.sh"` |
  | Jenkins | Groovy (`Jenkinsfile`) | `sh '$SCRIPTS/02-build-test.sh'` |
  | Azure DevOps | YAML (plantilla central + `extends`) | `- script: "$(SCRIPTS)/02-build-test.sh"` |
  | AWS CodeBuild | YAML (`buildspec`) | `- '"$SCRIPTS/02-build-test.sh"'` |
- Migrar de plataforma es escribir **un archivo de orquestación nuevo**: así se hicieron los ejemplos de [Azure DevOps](../orchestrators/azure-devops/) y [AWS](../orchestrators/aws-codepipeline/). Lo único que se ajustó en los scripts fue que la etapa 9 acepte un login al registro hecho por la nube (`REGISTRY_AUTH=plataforma`).
- Cualquier etapa se puede ejecutar y depurar en una laptop ([`run-local.sh`](../run-local.sh)).

El costo: se aprovechan menos las funciones nativas de cada plataforma (caché, paralelismo, plugins). Por eso lo nativo se deja en el orquestador: checkout, secretos, aprobaciones, guardar evidencia.

---

## 3. Cómo viajan los secretos

Un error común es pensar que los scripts "van a buscar" las credenciales. **No lo hacen**, y no deben:

```text
 Bóveda de la plataforma ──► Orquestador ──► variable de entorno ──► script (solo la usa)
 (GitHub Secrets,             inyecta SOLO en     $DOCKERHUB_TOKEN       docker login --password-stdin
  Jenkins Credentials,        la etapa que la
  Secrets Manager…)           necesita
```

| Principio | Cómo se cumple |
|---|---|
| El código nunca contiene secretos | Solo variables (`$DOCKERHUB_TOKEN`); el `.env` local está en `.gitignore` |
| Mínimo alcance | El secreto existe solo en la etapa 9 (`withCredentials` en Jenkins, `env` del job de CD en GitHub) |
| No quedan en logs | La plataforma los enmascara (`***`) y el script los pasa por `stdin`, nunca como argumento |
| Se pueden rotar | Se usa un *access token* revocable, no la contraseña de la cuenta |
| Cambiar de bóveda no cambia el código | Mañana el token viene de AWS Secrets Manager y el script sigue leyendo `$DOCKERHUB_TOKEN` |

El detalle de cada variable y dónde se configura está en [03-CONFIGURACION.md](03-CONFIGURACION.md).

---

## 4. El flujo de punta a punta

```text
 Desarrollador ── push / PR ──► Repositorio
                                    │ dispara
                                    ▼
 ┌──────────────────────────── CI: "¿es apto?" ───────────────────────────────┐
 │ 0 Checkout → 1 Secretos → 2 Build + tests → 3 Cobertura → 4 Artefactos     │
 │ → 5 Calidad (Sonar) → 6 SAST + SCA → 7 Imágenes → 8 Escaneo + SBOM         │
 └────────────────────────────────────┬────────────────────────────────────────┘
                                      │ (aprobación humana en producción)
 ┌──────────────────────────── CD: "¿se entrega?" ────────────────────────────┐
 │ 9 Publicar en el registro → 10 Desplegar en el ambiente + smoke + DAST     │
 └────────────────────────────────────┬────────────────────────────────────────┘
                                      ▼
            Resultado: imagen inmutable en el registro + ambiente desplegado + evidencia
```

| Rama / evento | Ambiente | Aprobación |
|---|---|---|
| Push a `feature/*` | `test` | No |
| Pull request | Ninguno (solo CI) | — |
| Ejecución manual desde `main` | `simulacion-produccion` | Sí |

Por qué este orden, etapa por etapa: [02-ETAPAS.md](02-ETAPAS.md).

---

## 5. Principios de diseño

1. **Construir una vez, desplegar muchas.** El jar se compila una sola vez. La imagen copia **ese** jar, el que pasó los tests, y cada ambiente despliega **esa** imagen. Lo que se aprobó es lo que llega a producción.
2. **La línea se detiene sola.** Cada control tiene un criterio de falla automático (tests, cobertura, quality gate, CVE). Nadie tiene que acordarse de revisar.
3. **Inmutabilidad y trazabilidad.** Cada imagen lleva un tag `<versión>-<commit>`, que nunca se sobrescribe y nunca es `latest`. Con eso se responde la pregunta del auditor: ¿de qué commit salió lo que está en producción?
4. **Evidencia de cada ejecución.** Reportes, jars, SBOM y logs se guardan con cada ejecución.
5. **Herramientas con versión fija.** Cada herramienta tiene su versión exacta en [`common.sh`](../stages/lib/common.sh). Una actualización es un cambio revisado, no una sorpresa.
6. **Modo auditoría antes que modo bloqueo.** Los escáneres de seguridad empiezan **reportando** (`MODO_ESTRICTO=false`) y se vuelven bloqueantes cuando el equipo ya resolvió los hallazgos. Así se adopta en la práctica.

---

## 6. ¿Bash o Python?

Las dos son válidas. La decisión depende de qué hace el script:

| Usar **Bash** cuando… | Usar **Python** cuando… |
|---|---|
| El trabajo es encadenar comandos (`mvn`, `docker`, `trivy`) | Hay lógica: parsear JSON, comparar versiones, reglas de negocio |
| El script es corto y lineal | Hay que llamar APIs (AWS boto3, Azure SDK, Jira, Slack) |
| Se quiere cero dependencias en el runner | Se necesitan pruebas unitarias del propio pipeline |

En este pipeline casi todo es llamar herramientas, por eso Bash. Las partes con lógica (leer la versión del `pom.xml`) ya usan Python embebido. En equipos grandes es común una mezcla: Bash para orquestar comandos y Python para la lógica y las integraciones.

---

## 7. Cómo se organiza en un banco

Este laboratorio tiene el pipeline en un repositorio central (`ws-devops`) que descarga el código de la aplicación. Con muchos microservicios, la práctica es separar el pipeline en dos partes:

```text
Repo de PLATAFORMA (dueño: DevOps)               Repo de CADA MICROSERVICIO (dueño: el equipo)
devsecops-pipeline-templates/                    ms-orchestrator-credit-evaluation/
├── stages/        lógica estándar               ├── src/ …
├── templates/     GitHub "reusable workflows"   └── .github/workflows/cicd.yml   ← ~10 líneas:
│                  Jenkins "Shared Library"            "usa la plantilla v2 del banco,
└── versionado v1, v2…                                  lenguaje java, cobertura 80 %"
```

| Beneficio | Por qué importa en banca |
|---|---|
| Un único estándar | Todos los servicios pasan los mismos controles; nadie puede saltarse uno borrando una etapa |
| El pipeline corre con cada cambio | El archivo corto vive en el repo de la aplicación: cada PR y cada push lo dispara |
| Control central | Un control nuevo se agrega una vez en la plantilla y aplica a todos |
| Versionado | Los equipos adoptan la plantilla v3 cuando están listos, sin romper la v2 |

`devsecops-pipeline/` ya cumple el papel de ese repositorio de plataforma. El ejemplo de [Azure DevOps](../orchestrators/azure-devops/) ya está armado así: un [pipeline corto](../orchestrators/azure-devops/caller/azure-pipelines.yml) para el repo de la aplicación que extiende una [plantilla central](../orchestrators/azure-devops/templates/java/quarkus/maven/devsecops.yml) fijada a un tag. Es el mismo patrón de pipelines reales de banca: el pipeline de la aplicación tiene unas 20 líneas y todo lo demás viene de la plantilla.

Dos detalles que separan una implementación madura de una que no lo es:

| Práctica madura | Antipatrón frecuente |
|---|---|
| La plantilla se fija a un **tag** (`v1.0.0`) y los equipos suben de versión cuando están listos | La plantilla se toma de `master`: un cambio rompe a todos los equipos a la vez |
| El ambiente exige que el pipeline **extienda** la plantilla aprobada (*Required template* en Azure) | La plantilla se "incluye", y un equipo puede agregar o quitar etapas a su gusto |

---

## 8. Convenciones de nombres

| Elemento | Convención | Ejemplo |
|---|---|---|
| Carpeta del pipeline | `devsecops-pipeline` | — |
| Pipeline / workflow / job | `<aplicación>-cicd` | `poc-credit-evaluation-cicd` |
| Scripts de etapa | `NN-<acción>.sh`, en inglés y en orden | `06-sast-sca.sh` |
| Imágenes | `<cuenta>/<proyecto>-<servicio>:<versión>-<commit>` | `edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.0-SNAPSHOT-3915239` |
| Ambientes | Nombre del ambiente, en minúsculas | `test`, `simulacion-produccion` |
| Ramas | `feature/<tema>`, `main` | `feature/pipeline-github-actions` |
| Identificadores técnicos | Inglés (carpetas, archivos, scripts) | `stages/`, `container-images/` |
| Documentación | Español | Esta carpeta `docs/` |

---

## 9. Glosario

| Término | Significado |
|---|---|
| **CI** (Integración Continua) | Compilar, testear y validar cada cambio automáticamente |
| **CD** (Entrega/Despliegue Continuo) | Publicar y desplegar automáticamente lo que pasó el CI |
| **Pipeline** | La secuencia completa de etapas |
| **Etapa** (*stage*) | Un paso con un objetivo y un criterio de falla |
| **Job** | Grupo de etapas que corre en una misma máquina (GitHub Actions) |
| **Runner / agente** | La máquina temporal que ejecuta el pipeline |
| **Workspace** (en Jenkins) | La carpeta temporal del agente donde corre un build. **No** es el repositorio del pipeline |
| **Artefacto** | Producto de una compilación: un jar, el `dist/` de Angular |
| **Registro** | Almacén de imágenes de contenedor: Docker Hub, ECR, ACR |
| **Ambiente** (*environment*) | Destino del despliegue con sus reglas: test, producción |
| **Quality gate** | Conjunto de umbrales de calidad que el código debe cumplir |
| **SAST** | Análisis de seguridad del código fuente, sin ejecutarlo |
| **SCA** | Análisis de vulnerabilidades conocidas (CVE) en librerías de terceros |
| **DAST** | Pruebas de seguridad contra la aplicación en ejecución (detalle y OWASP ZAP en [05-DEVSECOPS-APRENDIZAJE.md](05-DEVSECOPS-APRENDIZAJE.md#28-dast--dynamic-application-security-testing--etapa-10)) |
| **SBOM** | Inventario de componentes de una imagen ("lista de ingredientes") |
| **CVE** | Identificador público de una vulnerabilidad conocida |
| **Digest** | Huella `sha256:...` que identifica una imagen de forma exacta e inmutable |
| **Smoke test** | Prueba mínima de que lo desplegado responde |
| **Pipeline as code** | El pipeline se define en archivos versionados, revisados por PR como cualquier código |
