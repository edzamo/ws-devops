# 🛡️ 05 · DevSecOps aplicado a microservicios

Laboratorio de cierre de la etapa Docker **y** material de estudio de DevSecOps. Toma un sistema real de 3 servicios, lo publica como imágenes en **Docker Hub** y construye un **pipeline DevSecOps** completo para él, en cuatro plataformas. Las imágenes publicadas son las que después se descargan en los pods de **Minikube** ([02-kubernetes](../02-kubernetes/)).

## 📚 Conceptos clave (por dónde empezar)

| Si quieres entender… | Lee |
|---|---|
| Qué es un pipeline, sus capas, cómo viajan los secretos, Bash vs. Python, cómo se organiza en un banco | [01 · Arquitectura del pipeline](devsecops-pipeline/docs/01-ARQUITECTURA.md) |
| Qué hace cada etapa, en qué orden y por qué (tests, cobertura, Sonar, imágenes, publicación) | [02 · Etapas](devsecops-pipeline/docs/02-ETAPAS.md) |
| Dónde se configuran variables y secretos en GitHub, Jenkins, Azure y AWS | [03 · Configuración](devsecops-pipeline/docs/03-CONFIGURACION.md) |
| Aprobaciones, ramas → ambientes, plantilla obligatoria, equivalencias en AWS y Azure | [04 · Gobernanza y nube](devsecops-pipeline/docs/04-GOBERNANZA-Y-NUBE.md) |
| **SAST, DAST (OWASP ZAP), SCA, SBOM, secretos, IAST**: qué es cada uno, herramientas open source y de pago, ruta de junior a arquitecto | [05 · DevSecOps: conceptos y aprendizaje](devsecops-pipeline/docs/05-DEVSECOPS-APRENDIZAJE.md) |
| Plantillas de pipeline (Azure `extends`, GitHub reusable workflows, Jenkins Shared Library, AWS), niveles de madurez | [06 · Plantillas de pipeline](devsecops-pipeline/docs/06-PLANTILLAS-DE-PIPELINE.md) |

| Parte | Qué | Estado |
|---|---|---|
| 1 | Contenerizar y publicar las 3 imágenes en Docker Hub | ✅ Hecho |
| 2 | Pipeline DevSecOps (GitHub Actions, Jenkins, Azure DevOps y AWS): tests, cobertura, Sonar, SAST/SCA, imágenes, publicación, deploy y DAST | ✅ Scripts validados en local · ⏳ primera ejecución en GitHub al subir la rama ([devsecops-pipeline/](devsecops-pipeline/)) |
| 3 | Kubernetes con Minikube y simulación local de AWS | ⏭️ Siguiente (sección *Próximos pasos*, al final) |

---

## Parte 1 — Lo que hicimos

### El sistema

Clonamos [`edzamo/poc-credit-evaluation`](https://github.com/edzamo/poc-credit-evaluation), un monorepo con 1 frontend y 2 backends que usan PostgreSQL:

| Servicio | Tecnología | Artefacto | Puerto |
|---|---|---|---|
| `mms-ux-credit-evaluation` | Angular servido por Nginx | Archivos estáticos (`dist/`) | 4200 |
| `ms-orchestrator-credit-evaluation` | Quarkus 3.8 / Java 21, arquitectura hexagonal | `quarkus-run.jar` | 8080 |
| `ms-risk-mock-credit-evaluation` | Quarkus 3.8 / Java 21 | `quarkus-run.jar` | 8081 |
| Base de datos | `postgres:16-alpine` (imagen oficial, no propia) | — | 5433 |

Flujo: Frontend → Orquestador → (Mock de riesgo + PostgreSQL).

> 💡 Lo que se publica en Docker Hub **no son jars**, son **imágenes**. Cada `Dockerfile` es *multi-stage*: una etapa compila el jar (o el `dist/` de Angular) y otra lo copia a una imagen mínima con solo el runtime. El jar viaja **dentro** de la imagen.

### Los pasos

1. **Clonar** el proyecto.
2. **Compilar** los backends con `mvn package` para ver el jar "crudo".
3. **Construir las imágenes** con `docker compose build`.
4. **Levantar el stack** con `docker compose up -d` y probarlo en `:4200` y en Swagger (`:8080/swagger-ui`, `:8081/swagger-ui`).
5. **Versionar desde el código**: la versión se cambió a `1.0.1` en `pom.xml`, `application.properties` y `package.json`, no solo en el tag.
6. **Publicar** con un script manual que leía la versión del código, rechazaba `-SNAPSHOT` y tags ya existentes, y agregaba labels OCI (versión, commit, fecha). Hoy lo reemplazan las etapas 7 y 9 del [pipeline](devsecops-pipeline/); el script original queda en el historial de Git.

### Resultado: imágenes publicadas

| Imagen | Tamaño | Digest |
|---|---|---|
| `edzamo13/austro-ms-risk-mock-credit-evaluation:1.0.1` | 91 MB | `sha256:d2fd5c780f98ab60dd56113fcdb1ffe7c50c8209094a1f99102e7c75808e1fb4` |
| `edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1` | 114 MB | `sha256:799ed5833887a2c8093474b02741613dd57b6dab7e869483e2abe136d617c3da` |
| `edzamo13/austro-mms-ux-credit-evaluation:1.0.1` | 22 MB | `sha256:7f2639224b17b7c1bcd5b612cdc824df4a0fb5e0ded01b82a080e896157659b8` |

Publicadas el 2026-09-24. Para verificarlo sin fiarse del script:

```bash
curl -s https://hub.docker.com/v2/repositories/edzamo13/austro-ms-orchestrator-credit-evaluation/tags/
docker pull edzamo13/austro-ms-orchestrator-credit-evaluation:1.0.1
```

Convención de nombres: Docker Hub gratuito solo permite `cuenta/repositorio`, así que el proyecto va como prefijo: `edzamo13/austro-<servicio>:<versión>`.

### Problemas que aparecieron (y lo que enseñan)

| Problema | Solución | Lección |
|---|---|---|
| El frontend fallaba en `npm ci`: el repo no trae `package-lock.json` (lo ignora su `.gitignore`) | Se generó con un contenedor descartable: `docker run --rm -v "$PWD":/app -w /app node:20-alpine npm install --legacy-peer-deps --package-lock-only` | Sin lockfile no hay builds reproducibles |
| La versión estaba en 4 lugares y no coincidía (`1.0.0-SNAPSHOT`, `1.0.0`) | Se alineó todo a `1.0.1` en el código antes de construir | La versión vive en el código; el tag se deriva de ahí |
| Las imágenes llevan el label `revision=<sha>-dirty` | — (queda como brecha conocida) | Los cambios a `1.0.1` no se commitearon en `poc-credit-evaluation`; en un proceso real solo se publica desde un commit limpio y etiquetado |

### Brechas frente a una empresa regulada

- ~~Sin escaneo de vulnerabilidades ni SBOM~~ → resuelto en la Parte 2 (etapas 6 y 8).
- ~~Publicación manual desde una laptop~~ → resuelto en la Parte 2 (etapa 9).
- Sin firma de imágenes → pendiente (Cosign; píldora R1 de [05-DEVSECOPS-APRENDIZAJE.md](devsecops-pipeline/docs/05-DEVSECOPS-APRENDIZAJE.md)).
- `DB_PASSWORD` en texto plano en `docker-compose.yml` → `Secret` en Kubernetes.
- Imágenes base flotantes (`node:20-alpine`, `nginx:1.27-alpine`) → fijarlas por digest.
- El frontend trae `apiBaseUrl: http://localhost:8080` fijo al compilar → en Kubernetes necesitará un proxy o un Ingress.

---

## Parte 2 — Pipeline simulado

Ver [devsecops-pipeline/README.md](devsecops-pipeline/README.md). Para entender cómo funciona por dentro, empezar por [docs/01-ARQUITECTURA.md](devsecops-pipeline/docs/01-ARQUITECTURA.md).

---

## Cómo reproducir la Parte 1

Ya no hace falta clonar el proyecto a mano: el pipeline descarga el código, compila, construye las imágenes y (con `PUBLICAR=true`) las publica.

```bash
cd 05-devsecops-microservicios/devsecops-pipeline
./run-local.sh 0 4                                                    # descargar, compilar, testear, verificar jars
./run-local.sh 7 7                                                    # construir las imágenes
DOCKERHUB_USERNAME=edzamo13 DOCKERHUB_TOKEN=<token> PUBLICAR=true ./run-local.sh 9 9   # publicar
```

Detalle en [devsecops-pipeline/README.md](devsecops-pipeline/README.md) y [docs/03-CONFIGURACION.md](devsecops-pipeline/docs/03-CONFIGURACION.md).

---

## ⏭️ Próximos pasos

### 1. Kubernetes con Minikube (siguiente laboratorio)

Para eso publicamos las imágenes en Docker Hub: Minikube las descarga por nombre y tag, o mejor, por **digest** (inmutable):

```bash
minikube start
kubectl create deployment ms-orchestrator \
  --image=edzamo13/austro-ms-orchestrator-credit-evaluation@sha256:799ed5833887a2c8093474b02741613dd57b6dab7e869483e2abe136d617c3da
```

Qué hay que resolver en ese laboratorio:

- [ ] Manifiestos por servicio: `Deployment`, `Service`, `ConfigMap` (`DB_URL`, `RISK_SERVICE_URL`) y `Secret` (`DB_PASSWORD`).
- [ ] PostgreSQL con `StatefulSet` + `PersistentVolumeClaim`.
- [ ] `readinessProbe` y `livenessProbe` sobre `/q/health` (reemplazan al `healthcheck` de Compose).
- [ ] Exponer el frontend con `Ingress` y resolver `apiBaseUrl: http://localhost:8080`, que viene fijo al compilar Angular.
- [ ] Agregar `devsecops-pipeline/environments/minikube/` y una variante de la etapa 10 que despliegue en el clúster en lugar de Compose.

### 2. Simular AWS en local (al final)

Para probar la versión AWS del pipeline (ECR, S3, Secrets Manager, CloudFormation) sin cuenta ni costo, usando un emulador de AWS en Docker:

| Herramienta | Licencia | Nota |
|---|---|---|
| **Floci** | MIT (open source) | Alternativa a LocalStack, mismo puerto (4566), compatible con AWS CLI, Terraform y CDK. Es reciente: verificar en su repositorio oficial qué servicios soporta |
| **LocalStack** | Comercial con plan gratuito | La referencia histórica. En marzo de 2026 cambió el empaquetado de su edición gratuita: revisar las condiciones vigentes |
| **Moto** | Apache 2.0 | Librería de Python para simular AWS en tests unitarios |

- [ ] Verificar qué servicios del pipeline cubre el emulador. CodeBuild y CodePipeline son los menos soportados: probablemente se simulen ECR, S3 y Secrets Manager, y la orquestación se ejecute con `run-local.sh`.
- [ ] Desplegar `orchestrators/aws-codepipeline/pipeline.yml` contra el emulador (`--endpoint-url http://localhost:4566`).
- [ ] Publicar las imágenes en el ECR emulado con `REGISTRY` y `REGISTRY_AUTH=plataforma`.

> Un emulador sirve para un ciclo de prueba rápido, no garantiza paridad total con AWS. La validación final siempre es contra una cuenta real, con presupuesto y limpieza de recursos.
