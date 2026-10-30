# 🔧 Variables, secretos y dónde se configuran

Todas las etapas ([`stages/`](../stages/)) leen su configuración de **variables de entorno**, definidas en [`stages/lib/common.sh`](../stages/lib/common.sh). Cada herramienta (GitHub Actions, Jenkins, la laptop) solo cambia **dónde** se definen esas variables. Los scripts son los mismos.

Hay tres tipos:

| Tipo | Qué es | Ejemplo | Regla |
|---|---|---|---|
| **Parámetro** | Lo que se elige al lanzar una ejecución | Rama, cobertura mínima, publicar o no | Visible, con valor por defecto |
| **Secreto** | Credencial | Token de Docker Hub | **Nunca** en el código ni en logs; solo en el gestor de secretos |
| **Interna** | Rutas y configuración técnica | `APP_DIR`, `DOCKER_MOUNT` | La define el orquestador; normalmente no se toca |

---

## 1. Catálogo de variables

### Parámetros

| Variable | Por defecto | Para qué | Etapas |
|---|---|---|---|
| `REPO_URL` | `https://github.com/edzamo/poc-credit-evaluation.git` | Repositorio del código a construir | 0 |
| `RAMA` | `main` | Rama a construir (`main`, `feature/...`) | 0 |
| `COBERTURA_MINIMA` | `30` | Cobertura mínima de líneas (%). Es la línea base actual: la cobertura nunca debe bajar de ahí | 3 |
| `MODO_ESTRICTO` | `false` | `true`: los hallazgos de seguridad detienen el pipeline. `false`: modo auditoría, solo los reporta | 1, 6, 8, 10 |
| `PUBLICAR` | `false` | `true`: publica en Docker Hub. `false`: *dry run* | 9 |
| `DOCKER_USER` | `edzamo13` | Cuenta de Docker Hub dueña de las imágenes | 7, 8, 9, 10 |
| `PREFIX` | `austro` | Prefijo de proyecto en el nombre de la imagen (`edzamo13/austro-<servicio>`) | 5, 7, 9 |

### Secretos

| Variable | Para qué | Cuándo es obligatoria |
|---|---|---|
| `DOCKERHUB_USERNAME` | Usuario de Docker Hub | Solo con `PUBLICAR=true` |
| `DOCKERHUB_TOKEN` | **Access token** de Docker Hub (no la contraseña) | Solo con `PUBLICAR=true` |
| `SONAR_TOKEN` | Token de análisis de SonarQube | Opcional: si falta, la etapa 5 genera uno temporal contra el SonarQube efímero |
| `SONAR_ADMIN_PASSWORD` | Contraseña de admin de SonarQube, solo para generar ese token temporal | Solo si cambiaste la de por defecto (`admin`) |
| `REPO_TOKEN` (GitHub) / credencial `github` (Jenkins) | Leer el repo del código | Solo si el repo es privado |
| `JENKINS_ADMIN_PASSWORD` | Contraseña del usuario `admin` del Jenkins local | Siempre, en el Jenkins local |

Cómo crear el token de Docker Hub: hub.docker.com → *Account settings* → *Personal access tokens* → *Generate new token*, permiso **Read & Write**. Un token se revoca sin tocar la contraseña de la cuenta, y deja registro de su uso.

### Internas

| Variable | Por defecto | Para qué |
|---|---|---|
| `TRABAJO_DIR` | `/tmp/poc-credit-evaluation-pipeline` | Carpeta de trabajo, **fuera** del repositorio |
| `APP_DIR` | `$TRABAJO_DIR/app` | Dónde se descarga y compila el código |
| `OUT_DIR` | `$TRABAJO_DIR/salida` | Dónde quedan los reportes (`reportes/`) y los artefactos (`artefactos/`) |
| `SONAR_HOST_URL` | `http://localhost:9000` | URL de SonarQube |
| `DOCKER_MOUNT` | `-v $APP_DIR:$APP_DIR -v $OUT_DIR:$OUT_DIR` | Cómo los contenedores de herramientas ven el código. En Jenkins es `--volumes-from jenkins` |
| `DB_PASSWORD` | `solo-para-simulacion` | Contraseña de Postgres en el ambiente simulado de la etapa 10 |

---

## 2. GitHub Actions

### Parámetros → formulario de *Run workflow*

Actions → **poc-credit-evaluation-cicd** → *Run workflow*. El formulario sale de `on.workflow_dispatch.inputs` del [workflow](../../../.github/workflows/poc-credit-evaluation-cicd.yml):

| Campo del formulario | Variable |
|---|---|
| `repositorio` | Repo a descargar (formato `owner/nombre`) |
| `rama` | `RAMA` |
| `cobertura_minima` | `COBERTURA_MINIMA` |
| `modo_estricto` | `MODO_ESTRICTO` |
| `publicar` | `PUBLICAR` |

> El botón *Run workflow* solo aparece cuando el workflow ya está en la rama por defecto (`main`). En una rama `feature/...` el pipeline se dispara con cada **push** y usa los valores por defecto.

### Secretos → Settings → Secrets and variables → Actions

1. En el repo `ws-devops`: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
2. Crear `DOCKERHUB_USERNAME` (`edzamo13`) y `DOCKERHUB_TOKEN` (el access token).
3. Solo con repo privado: `REPO_TOKEN`, un *fine-grained token* con permiso *Contents: Read* sobre ese repo.

En el workflow se leen como `${{ secrets.DOCKERHUB_TOKEN }}`. GitHub los enmascara (`***`) en los logs y **no** los entrega a workflows disparados desde forks.

### Ambientes → Settings → Environments

| Environment | Cuándo se usa | Configuración recomendada |
|---|---|---|
| `test` | Push a una rama `feature/...` | Sin aprobación: despliega solo |
| `simulacion-produccion` | *Run workflow* manual | **Required reviewers**: tú. *Deployment branches*: solo `main` |

GitHub crea el environment la primera vez que el workflow lo usa. Las reglas de aprobación hay que agregarlas a mano en **Settings** → **Environments** → *(nombre)*. Los secretos también se pueden definir **por environment**, por ejemplo un token distinto para test y para producción.

### Variables internas → bloque `env:` del workflow

`APP_DIR`, `OUT_DIR` y `SCRIPTS` se fijan en el bloque `env:` del workflow y no se tocan desde la interfaz.

---

## 3. Jenkins

### Variables del `docker-compose` → archivo `orchestrators/jenkins/.env`

```bash
cd 05-laboratorio-microservicios/devsecops-pipeline/orchestrators/jenkins
cp .env.example .env        # .env está en .gitignore: nunca se sube
```

| Variable en `.env` | Para qué |
|---|---|
| `JENKINS_ADMIN_PASSWORD` | Contraseña del usuario `admin` |
| `DOCKER_GID` | Grupo `docker` del host (`getent group docker \| cut -d: -f3`), para que Jenkins use el Docker del host |
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | Se convierten en la credencial `dockerhub` |
| `WS_DEVOPS_REPO` / `WS_DEVOPS_RAMA` | De qué repo y rama lee Jenkins el `Jenkinsfile` (por defecto `ws-devops`, rama `main`) |

Al arrancar, **Configuration as Code** ([`casc.yaml`](../orchestrators/jenkins/casc.yaml)) lee esas variables y crea el usuario, la credencial y el job. No hay que configurar nada en la interfaz.

### Parámetros → *Build with Parameters*

Salen del bloque `parameters { }` del [`Jenkinsfile`](../orchestrators/jenkins/Jenkinsfile): `REPO_URL`, `RAMA`, `COBERTURA_MINIMA`, `MODO_ESTRICTO` y `PUBLICAR`.

> Jenkins registra los parámetros en la **primera** ejecución del job, que corre con los valores por defecto. Desde la segunda aparece *Build with Parameters*.

### Secretos → Manage Jenkins → Credentials

Con JCasC la credencial `dockerhub` ya existe. Para crearla o cambiarla a mano:

1. **Manage Jenkins** → **Credentials** → **System** → **Global credentials (unrestricted)** → **Add Credentials**.
2. *Kind*: **Username with password**. *Username*: `edzamo13`. *Password*: el access token. **ID**: `dockerhub` (el `Jenkinsfile` lo busca por este ID).
3. Para un repo privado: otra credencial con ID `github` y agregar `credentialsId: 'github'` en la etapa `0. Checkout`.

En el `Jenkinsfile` la credencial solo existe dentro de `withCredentials { }` (etapa 9), y Jenkins la enmascara en el log.

### Variables internas → bloque `environment { }`

`APP_DIR`, `OUT_DIR`, `SCRIPTS`, `DOCKER_MOUNT` y `SONAR_HOST_URL` están en el bloque `environment { }` del `Jenkinsfile`. Si hiciera falta una variable para **todos** los jobs: **Manage Jenkins** → **System** → *Global properties* → **Environment variables**.

---

## 4. En la laptop

Las variables se exportan o se anteponen al comando:

```bash
cd 05-laboratorio-microservicios/devsecops-pipeline
./run-local.sh                                   # todo con los valores por defecto
RAMA=feature/nueva COBERTURA_MINIMA=50 ./run-local.sh
DOCKERHUB_USERNAME=edzamo13 DOCKERHUB_TOKEN=... PUBLICAR=true ./run-local.sh 9 9
```

No pongas tokens en archivos versionados. Si los guardas en un archivo local, que esté en `.gitignore`, como `orchestrators/jenkins/.env`.

---

## 5. Resumen: dónde va cada cosa

| Variable | GitHub Actions | Jenkins | Laptop |
|---|---|---|---|
| `RAMA`, `COBERTURA_MINIMA`, `MODO_ESTRICTO`, `PUBLICAR` | Formulario *Run workflow* | *Build with Parameters* | `export` o prefijo |
| `REPO_URL` | Campo `repositorio` | Parámetro `REPO_URL` | `export` |
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | Settings → Secrets → Actions | `.env` → credencial `dockerhub` | `export` (nunca en archivo versionado) |
| Aprobación antes del deploy | Settings → Environments → required reviewers | Etapa `Aprobación` (`input`) | — |
| `APP_DIR`, `OUT_DIR`, `DOCKER_MOUNT` | `env:` del workflow | `environment { }` del Jenkinsfile | Por defecto en `stages/lib/common.sh` |
