# 🧪 Laboratorio 05: Microservicios en Docker Hub y pipeline simulado

Laboratorio de cierre de la etapa Docker. Toma un sistema real de 3 servicios, lo deja publicado como imágenes en **Docker Hub** y muestra con un **pipeline simulado** cómo sería su despliegue. Las imágenes publicadas son las que después se descargan en los pods de **Minikube** ([02-kubernetes](../02-kubernetes/)).

| Parte | Qué | Estado |
|---|---|---|
| 1 | Contenerizar y publicar las 3 imágenes en Docker Hub | ✅ Hecho |
| 2 | Pipeline CI/CD simulado (GitHub Actions y Jenkins): tests, cobertura, Sonar, SAST/SCA, imágenes, publicación, deploy y DAST | ✅ Escrito y validado en local ([workspace/](workspace/)) |

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
6. **Publicar** con un script manual que leía la versión del código, rechazaba `-SNAPSHOT` y tags ya existentes, y agregaba labels OCI (versión, commit, fecha). Hoy lo reemplazan las etapas 7 y 9 del [pipeline](workspace/); el script original queda en el historial de Git.

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

Las cubre la Parte 2 (pipeline) o la etapa de Kubernetes:

- Sin escaneo de vulnerabilidades, SBOM ni firma de imágenes → Parte 2.
- Publicación manual desde una laptop, no desde un pipeline → Parte 2.
- `DB_PASSWORD` en texto plano en `docker-compose.yml` → `Secret` en Kubernetes.
- Imágenes base flotantes (`node:20-alpine`, `nginx:1.27-alpine`) → fijarlas por digest.
- El frontend trae `apiBaseUrl: http://localhost:8080` fijo al compilar → en Kubernetes necesitará un proxy o un Ingress.

---

## Parte 2 — Pipeline simulado

Ver [workspace/README.md](workspace/README.md) y [workspace/VARIABLES.md](workspace/VARIABLES.md): diseño, orden de las etapas, scripts, secretos, gobernanza, cómo ejecutarlo en GitHub Actions o Jenkins, y cómo llevarlo a AWS o Azure.

---

## Cómo reproducir la Parte 1

Ya no hace falta clonar el proyecto a mano: el pipeline descarga el código, compila, construye las imágenes y (con `PUBLICAR=true`) las publica.

```bash
cd 05-laboratorio-microservicios/workspace
./ejecutar-local.sh 0 4                                                    # descargar, compilar, testear, verificar jars
./ejecutar-local.sh 7 7                                                    # construir las imágenes
DOCKERHUB_USERNAME=edzamo13 DOCKERHUB_TOKEN=<token> PUBLICAR=true ./ejecutar-local.sh 9 9   # publicar
```

Detalle en [workspace/README.md](workspace/README.md) y [workspace/VARIABLES.md](workspace/VARIABLES.md).

---

## ⏭️ Siguiente: Kubernetes con Minikube

Con las imágenes en Docker Hub, Minikube las descarga por nombre y tag (o mejor, por digest):

```bash
kubectl create deployment ms-orchestrator \
  --image=edzamo13/austro-ms-orchestrator-credit-evaluation@sha256:799ed5833887a2c8093474b02741613dd57b6dab7e869483e2abe136d617c3da
```
