# Orquestador Azure DevOps (Azure Pipelines) — modelo de plantilla central

Este ejemplo sigue el modelo que usa la banca con Azure DevOps: **el repo de cada aplicación tiene un pipeline corto que *extiende* una plantilla central** mantenida por el equipo de plataforma DevOps. Es un ejemplo de referencia: está validado en sintaxis, pero no se ha ejecutado en una organización de Azure DevOps.

```text
Repo de la APLICACIÓN (poc-credit-evaluation)        Repo CENTRAL de plantillas (aquí: ws-devops)
azure-pipelines.yml   ← caller/azure-pipelines.yml    templates/java/quarkus/maven/devsecops.yml
 • ramas que disparan                                  • etapas CI y CD completas
 • variable group por ambiente           extends ──►   • reglas rama → ambiente
 • parámetros permitidos                 @v1.0.0       • llama a stages/*.sh (mismos scripts de siempre)
```

| Archivo | Dónde vive en la realidad | Quién lo mantiene |
|---|---|---|
| [`caller/azure-pipelines.yml`](caller/azure-pipelines.yml) | Raíz del repo de la aplicación | El equipo de la aplicación |
| [`templates/java/quarkus/maven/devsecops.yml`](templates/java/quarkus/maven/devsecops.yml) | Repo central de plantillas | El equipo de plataforma DevOps |

## Prácticas incorporadas

| Práctica | Cómo se aplica | Por qué |
|---|---|---|
| **Plantilla central con `extends`** | El pipeline de la app no define etapas: `extends: template: …@devsecops-templates` | Un único estándar para todos los equipos; un control nuevo se agrega una vez |
| **Check "Required template"** | En los environments `test` y `simulacion-produccion` | Azure solo deja desplegar a pipelines que extienden la plantilla aprobada: nadie se salta un control borrando una etapa. Es la razón para usar `extends` y no un simple `template:` |
| **Catálogo por stack** | `templates/<lenguaje>/<framework>/<build>/` → `java/quarkus/maven/` | Una plantilla por tipo de proyecto: Spring Boot + Gradle, Node + npm… |
| **Plantilla fijada a un tag** | `ref: refs/tags/devsecops-templates-v1.0.0` | Un cambio en la plantilla no rompe a todos los equipos a la vez; cada uno sube de versión cuando está listo. Fijarla a una **rama** (`master`) es un antipatrón común |
| **GitFlow → ambiente** | Ver tabla de abajo | La rama decide a dónde se despliega, sin intervención manual |
| **Variable group por ambiente** | `<plataforma>-<ambiente>-<dominio>` → `docker-dev-credit-evaluation` | La configuración de cada ambiente vive fuera del código, y sus secretos en Key Vault |
| **Nombre de ejecución con la rama** | `$(SourceBranchName)-$(Date:yyyyMMdd)$(Rev:.r)` | En el historial se ve de un vistazo qué rama produjo cada ejecución |
| **Parámetros de compilación como parámetros** | La service connection del ACR va como parámetro de la plantilla | Azure resuelve las service connections al **compilar** el pipeline: no pueden venir de un variable group |

### Estrategia de ramas (GitFlow)

| Rama | Variable group | Ambiente | Aprobación |
|---|---|---|---|
| `feature/*`, `bugfix/*` | `docker-dev-credit-evaluation` | `dev` | No |
| `develop`, `release/*`, `hotfix/*` | `docker-test-credit-evaluation` | `test` | Opcional |
| `main` | `docker-prod-credit-evaluation` | `simulacion-produccion` | **Sí** |
| Pull request a `develop` o `main` | — | Solo CI | — |

El prefijo `docker-` indica la plataforma de despliegue actual (el ambiente simulado con Docker Compose). Cuando el despliegue pase a Kubernetes, habrá una plantilla hermana (p. ej. `templates/java/quarkus/maven/devsecops-aks.yml`) y grupos `aks-dev-…`, `aks-test-…`.

## Qué cambia respecto de GitHub Actions

| Concepto | GitHub Actions | Azure DevOps |
|---|---|---|
| Reutilización | *Reusable workflows* (`uses: org/repo/.github/workflows/x.yml@v1`) | **`extends`** de una plantilla en otro repo |
| Estructura | `jobs` → `steps` | `stages` → `jobs` → `steps` |
| Registro | Docker Hub | **Azure Container Registry (ACR)** |
| Login al registro | Token en un secret | Tarea `Docker@2` con una **service connection** (identidad de Azure) |
| Secretos | Settings → Secrets | **Variable group** enlazado a **Azure Key Vault** |
| Aprobación | Environment con *required reviewers* | Environment → **Approvals and checks** (Approvals + Required template) |

## Configuración (una sola vez)

| # | Dónde | Qué crear |
|---|---|---|
| 1 | Repo central | El tag `devsecops-templates-v1.0.0` sobre el commit aprobado de la plantilla |
| 2 | Project settings → **Service connections** → GitHub | `github-edzamo`: lectura de `ws-devops` y `poc-credit-evaluation` |
| 3 | Project settings → **Service connections** → Docker Registry → Azure Container Registry | `acr-poc-credit` |
| 4 | Pipelines → **Library** → Variable groups | `docker-dev-credit-evaluation`, `docker-test-…`, `docker-prod-…`, cada uno con `REGISTRY` (`<nombre>.azurecr.io`) y `PUBLICAR` (`false` en dev, `true` en prod). Secretos: *Link secrets from an Azure key vault* |
| 5 | Pipelines → **Environments** | `dev`; `test` y `simulacion-produccion` con *Approvals and checks* → **Approvals** y **Required template** (apuntando a la plantilla) |
| 6 | Repo de la aplicación | Copiar `caller/azure-pipelines.yml` a su raíz → Pipelines → *New pipeline* → *Existing YAML file* |

> **Secretos en Azure:** una variable secreta de un variable group **no** llega sola a los scripts. Hay que pasarla explícitamente en el `env:` del paso (`DOCKERHUB_TOKEN: $(DOCKERHUB_TOKEN)`). Con ACR no hace falta, porque el login lo hace la service connection.
