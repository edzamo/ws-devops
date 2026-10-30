# Orquestador Azure DevOps (Azure Pipelines)

[`azure-pipelines.yml`](azure-pipelines.yml) orquesta las mismas etapas de [`stages/`](../../stages/), en el mismo orden que GitHub Actions y Jenkins. Es un ejemplo de referencia: está validado en sintaxis, pero no se ha ejecutado en una organización de Azure DevOps.

## Qué cambia respecto de GitHub Actions

| Concepto | GitHub Actions | Azure DevOps |
|---|---|---|
| Archivo | `.github/workflows/*.yml` | `azure-pipelines.yml` (cualquier ruta; se elige al crear el pipeline) |
| Estructura | `jobs` → `steps` | `stages` → `jobs` → `steps` |
| Repo del código | `actions/checkout` con `repository:` | `resources.repositories` + `checkout: app` |
| Registro | Docker Hub | **Azure Container Registry (ACR)** |
| Login al registro | Token en un secret | Tarea `Docker@2` con una **service connection**: la identidad de Azure, sin contraseña |
| Secretos | Settings → Secrets | **Variable group** enlazado a **Azure Key Vault** |
| Aprobación | Environment con *required reviewers* | Environment con **Approvals and checks** |
| Evidencia | `upload-artifact` | `publish` (pipeline artifacts) y `PublishTestResults@2` (pestaña Tests) |

## Configuración (una sola vez)

| # | Dónde | Qué crear |
|---|---|---|
| 1 | Project settings → **Service connections** → GitHub | `github-edzamo`: acceso de lectura a `ws-devops` y `poc-credit-evaluation` |
| 2 | Project settings → **Service connections** → Docker Registry → Azure Container Registry | `acr-poc-credit`: el ACR donde se publican las imágenes |
| 3 | Pipelines → **Library** → Variable group | `poc-credit-evaluation` con `ACR_LOGIN_SERVER` (p. ej. `pocregistry.azurecr.io`). Para secretos: activar *Link secrets from an Azure key vault* |
| 4 | Pipelines → **Environments** | `test` (sin checks) y `simulacion-produccion` → *Approvals and checks* → **Approvals** |
| 5 | Pipelines → **New pipeline** → GitHub → `ws-devops` → *Existing YAML file* | Ruta `/05-laboratorio-microservicios/devsecops-pipeline/orchestrators/azure-devops/azure-pipelines.yml` |

> **Secretos en Azure:** una variable secreta **no** llega sola a los scripts. Hay que pasarla explícitamente en el bloque `env:` del paso (`DOCKERHUB_TOKEN: $(DOCKERHUB_TOKEN)`). Es una protección de Azure: el secreto existe solo donde lo declaras. Con ACR no hace falta, porque el login lo hace la service connection.

## Cuándo corre

| Evento | Ambiente |
|---|---|
| Push a `feature/*` | `test` |
| Push a `main` | `simulacion-produccion` (espera la aprobación) |
| Pull request a `main` | Solo CI |
| *Run pipeline* manual | Según la rama, con los parámetros del formulario |
