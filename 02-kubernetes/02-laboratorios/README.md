# 02 · Laboratorios de Kubernetes — de junior a senior

La teoría está en [01-documentation](../01-documentation/). Aquí se **practica**: cada laboratorio es un ejercicio corto que construye sobre el anterior, desde un Pod suelto hasta desplegar `poc-credit-evaluation` completo en Minikube.

---

## Cómo trabajamos (alumno y profesor)

1. **Lee el `README.md` del laboratorio**: la historia, el objetivo, los pasos y los temas de la documentación que necesitas.
2. **Escribe tú los manifiestos.** Cada laboratorio trae plantillas `.yaml` con `TODO` para completar. No hay solución publicada: se aprende escribiendo.
3. **Ejecuta los pasos** en Minikube.
4. **Revisión con el profesor:** avisa cuando termines; se revisan tus manifiestos, se conversan las preguntas del README y recién entonces se abre el siguiente laboratorio.

> Regla de oro: si algo falla, **primero diagnostica** (`kubectl get`, `describe`, `logs`, eventos) antes de preguntar. Diagnosticar es la mitad del aprendizaje.

---

## Plan de laboratorios

Son **8 laboratorios**: pocos, pero densos. Cada uno junta varios temas en un escenario realista, y la última columna dice qué cambia cuando lo mismo corre en la nube.

| Lab | Nivel | Ejercicio | Qué practicas | Temas | En la nube (EKS · AKS · GKE) | Estado |
| --- | --- | --- | --- | --- | --- | --- |
| [01](lab01-primer-pod/) | Junior | **Tu primer Pod** | Imperativo vs. declarativo, `describe`, `logs`, `exec`, `port-forward`, Pod efímero, diagnosticar `ImagePullBackOff` | 01-04, 06 | Igual; solo cambia el contexto de `kubectl` | ✅ |
| [02](lab02-labels-y-selectores/) | Junior | **Labels y selectores** | Varios objetos en un YAML, filtrar, Service que elige por labels, el Pod intruso, label vs. annotation | 05, 10, 22 | Igual; los labels alimentan costos y políticas | ✅ |
| [03](lab03-tu-app-en-un-deployment/) | Junior | **Tu app en un Deployment** | Tu imagen `hello world` cargada en Minikube → Deployment de 3 réplicas: matar Pods (autorreparación), escalar, Service + DNS, rolling update v1 → v2 y rollback | 01-docker, 07-08, 10-11 | La imagen viene de ECR / ACR / Artifact Registry | 🟡 En curso |
| 04 | Semi-senior | **Una imagen, muchos entornos** | Namespaces `dev`/`qa`, ConfigMap y Secret por entorno, ResourceQuota, DNS entre namespaces | 09, 13-14 | Secretos desde Secrets Manager / Key Vault / Secret Manager | ⬜ |
| 05 | Semi-senior | **Datos que sobreviven** | Tu compose de Postgres → StatefulSet + PVC + Secret; borrar el Pod y ver que los datos siguen; respaldo con CronJob | 12, 16, 20-21 | Disco EBS / Azure Disk / Persistent Disk; en banca, BD gestionada | ⬜ |
| 06 | Semi-senior | **Listo para producción** | Requests/limits, provocar `OOMKilled`, probes (romper y arreglar), HPA escalando bajo carga | 11, 15, 19 | Autoescalado de nodos (Karpenter, Cluster Autoscaler, Autopilot) | ⬜ |
| 07 | Senior | **La puerta de entrada** | Ingress: dominios y rutas hacia dos servicios, TLS | 23-24 | ALB / Application Gateway / GKE Gateway + WAF | ⬜ |
| 08 | Proyecto | **poc-credit-evaluation en Minikube + simulacro** | Angular + 2 Quarkus desde Docker Hub (por digest), ConfigMap, Secret, probes en `/q/health`, Ingress. Al final el profesor rompe algo y tú diagnosticas la causa raíz | Todos | Qué cambiaría para llevarlo a EKS, AKS o GKE | ⬜ |

**Para profundizar después (opcionales):** clúster multinodo con affinity/taints (17), DaemonSet (18), `edit`/`patch`, drift y Kustomize (25).

Leyenda: ⬜ pendiente · 🟡 en curso · ✅ aprobado en revisión

---

## Estructura de cada laboratorio

```text
labNN-nombre/
├── README.md   ← enunciado: historia, objetivo, pasos y preguntas para conversar
└── *.yaml      ← plantillas con TODO que completas tú
```

Cada laboratorio usa su propio namespace (`lab01`, `lab02`...) para no mezclar ejercicios. Para empezar de cero: `kubectl delete namespace labNN`.

La carpeta [00-practicas-previas](00-practicas-previas/) guarda los manifiestos que escribiste antes de empezar los laboratorios.
