# 🏛️ Gobernanza y despliegue en la nube

## 1. Gobernanza

| Control | GitHub Actions | Jenkins | Qué demuestra |
|---|---|---|---|
| Aprobación humana antes de publicar y desplegar | Environment `simulacion-produccion` con *required reviewers* (Settings → Environments) | Etapa `Aprobación` (`input`) | Segregación de funciones |
| Mínimo privilegio | `permissions: contents: read` | Credenciales solo dentro de `withCredentials` | El pipeline no puede modificar el repo, y los secretos solo existen en la etapa que los usa |
| Rama protegida | Settings → Branches: PR obligatorio y check del pipeline en verde | — | Nadie fusiona sin pasar el pipeline |
| Mismo commit en CI y CD | El job de CD descarga el SHA exacto que pasó el CI | El workspace es el mismo | Lo que se aprobó es lo que se despliega |
| Trazabilidad | Labels OCI + digest publicado + artefactos de cada ejecución | `archiveArtifacts` + resultados JUnit | Responder "¿de qué commit salió esta imagen?" |

---

### Estrategia de ramas → ambiente (GitFlow)

Práctica habitual en banca: la **rama** decide a qué ambiente se despliega, sin intervención manual.

| Rama | Ambiente | Aprobación |
|---|---|---|
| `feature/*`, `bugfix/*` | `dev` | No |
| `develop`, `release/*`, `hotfix/*` | `test` | Opcional |
| `main` | Producción | **Sí** |
| Pull request | Solo CI | — |

El ejemplo de [Azure DevOps](../orchestrators/azure-devops/) aplica esta tabla completa, con un variable group por ambiente. El workflow de GitHub Actions usa una versión simplificada: `feature/*` → `test` y ejecución manual → `simulacion-produccion`.

### Plantilla obligatoria

En una organización con muchos equipos, el control más fuerte es que **el ambiente exija una plantilla**. En Azure DevOps es el check *Required template* del environment: si el pipeline no extiende la plantilla aprobada, no despliega. En GitHub el equivalente son los *rulesets* que exigen un *required workflow*. Así, ningún equipo puede saltarse un control de seguridad editando su YAML.

---

## 2. Llevarlo a AWS o Azure

Hay ejemplos completos en [`orchestrators/azure-devops/`](../orchestrators/azure-devops/) y [`orchestrators/aws-codepipeline/`](../orchestrators/aws-codepipeline/), cada uno con su guía de configuración.

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
