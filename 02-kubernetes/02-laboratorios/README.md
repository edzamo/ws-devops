# 02 · Laboratorios de Kubernetes — de junior a senior

La teoría está en [01-documentation](../01-documentation/). Aquí se **practica**: cada laboratorio es un ejercicio corto que construye sobre el anterior, desde un Pod suelto hasta desplegar `poc-credit-evaluation` completo en Minikube.

---

## Cómo trabajamos (alumno y profesor)

1. **Lee el `README.md` del laboratorio**: la historia, el objetivo y los temas de la documentación que necesitas.
2. **Escribe tú los manifiestos.** Cada laboratorio trae plantillas con `TODO` para completar. No hay solución publicada: se aprende escribiendo.
3. **Ejecuta los pasos** en Minikube y responde las **preguntas de comprensión** en el archivo `respuestas.md` del laboratorio.
4. **Comprueba tu trabajo** con `./verificar.sh` (✅ / ❌ por cada criterio).
5. **Revisión con el profesor:** avisa cuando termines; se revisan tus manifiestos y respuestas, se corrigen conceptos y recién entonces se abre el siguiente laboratorio.

> Regla de oro: si algo falla, **primero diagnostica** (`kubectl get`, `describe`, `logs`, eventos) antes de preguntar. Diagnosticar es la mitad del aprendizaje.

---

## Plan de laboratorios

| Lab | Nivel | Ejercicio | Qué practicas | Temas | Estado |
| --- | --- | --- | --- | --- | --- |
| [01](lab01-primer-pod/) | Junior | **Tu primer Pod** | Imperativo vs. declarativo, `describe`, `logs`, `exec`, `port-forward`, Pod efímero, diagnosticar `ImagePullBackOff` | 01-04, 06 | 🟡 En curso |
| 02 | Junior | Labels y selectores | Etiquetar, filtrar, "robar" un Pod con labels | 05 | ⬜ |
| 03 | Junior | De Docker a Kubernetes | Construir **tu** Dockerfile `hello world`, cargarlo en Minikube y correrlo como Pod | 01-docker, 04 | ⬜ |
| 04 | Junior | ReplicaSet y autorreparación | Matar Pods y ver cómo vuelven; escalar | 07-08 | ⬜ |
| 05 | Junior | Deployment: versiones sin corte | Rolling update de tu imagen v1 → v2 (`hello world 2.0`) y rollback | 11 | ⬜ |
| 06 | Junior | Services y DNS | ClusterIP, NodePort, balanceo entre réplicas, Service sin endpoints | 10 | ⬜ |
| 07 | Junior | Namespaces y cuotas | Entornos `dev`/`qa`, ResourceQuota, LimitRange, DNS entre namespaces | 09 | ⬜ |
| 08 | Semi-senior | Traducir un docker-compose | Tu compose **nginx + redis** → Deployments + Services | 10-11 | ⬜ |
| 09 | Semi-senior | ConfigMap y Secret | Misma imagen en dev y prod con distinta configuración | 13-14 | ⬜ |
| 10 | Semi-senior | Volúmenes | `emptyDir` compartido y PVC que sobrevive al Pod | 12 | ⬜ |
| 11 | Semi-senior | Postgres con estado | Tu compose de **Postgres** → StatefulSet + Secret + PVC | 16 | ⬜ |
| 12 | Semi-senior | Recursos y autoescalado | Provocar `OOMKilled`, generar carga y ver al HPA escalar | 15, 11 | ⬜ |
| 13 | Semi-senior | Probes | Romper y arreglar liveness/readiness; ver el efecto en el Service | 19 | ⬜ |
| 14 | Semi-senior | Jobs y CronJobs | Respaldo programado de Postgres con `pg_dump` | 20-21 | ⬜ |
| 15 | Senior | Clúster multinodo | Anti-affinity, taints/tolerations, `drain` de un nodo sin corte | 17 | ⬜ |
| 16 | Senior | DaemonSet | Agente en cada nodo; agregar un nodo y verlo aparecer | 18 | ⬜ |
| 17 | Senior | Ingress | Dominios y rutas con TLS para dos servicios | 22-24 | ⬜ |
| 18 | Senior | Cambios y drift | `edit`/`patch`, detectar drift con `diff`, Kustomize `dev`/`prod` | 25, 03 | ⬜ |
| 19 | Proyecto | **poc-credit-evaluation en Minikube** | Angular + 2 Quarkus desde Docker Hub (por digest), ConfigMap, Secret, probes en `/q/health`, Ingress | Todos | ⬜ |
| 20 | Proyecto | Simulacro de incidente | El profesor rompe el sistema; tú diagnosticas y explicas la causa raíz | Todos | ⬜ |

Leyenda: ⬜ pendiente · 🟡 en curso · ✅ aprobado en revisión

---

## Estructura de cada laboratorio

```text
labNN-nombre/
├── README.md        ← enunciado: historia, objetivo, pasos, preguntas
├── *.yaml           ← plantillas con TODO que completas tú
├── respuestas.md    ← lo creas tú: respuestas a las preguntas
└── verificar.sh     ← comprobación automática de los criterios de éxito
```

Cada laboratorio usa su propio namespace (`lab01`, `lab02`...) para no mezclar ejercicios. Para empezar de cero: `kubectl delete namespace labNN`.

La carpeta [00-practicas-previas](00-practicas-previas/) guarda los manifiestos que escribiste antes de empezar los laboratorios.
