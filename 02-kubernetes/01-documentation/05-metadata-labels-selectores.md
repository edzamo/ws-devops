# 05 · Metadata, labels y selectores

> **En una frase:** Los **labels** son etiquetas clave-valor que pegas a los objetos, y los **selectores** son filtros que dicen "todos los objetos que tengan esta etiqueta". Así se conectan entre sí las piezas de Kubernetes.
>
> **Analogía (contar manzanas):** Cada empleado del banco lleva un **gafete** con datos: `area=creditos`, `turno=mañana`. El gerente no llama a la gente por nombre; dice: "**todos los que tengan gafete de créditos**, vengan". El gafete es el *label*; la frase del gerente es el *selector*. Si a una manzana le pegas la etiqueta "roja", el selector "roja" la cuenta.

---

## 1. `metadata`: la identidad del objeto

```yaml
# fragmento
metadata:
  name: credito-api            # único dentro del namespace y del tipo de objeto
  namespace: credito-dev       # en qué "piso" vive (tema 09)
  labels:                      # para SELECCIONAR y agrupar (tema de este documento)
    app.kubernetes.io/name: credito-api
    app.kubernetes.io/part-of: evaluacion-crediticia
    app.kubernetes.io/version: "1.0.1"
    entorno: dev
  annotations:                 # para DESCRIBIR, no para seleccionar (tema 22)
    equipo.ejemplo.com/responsable: "squad-creditos"
```

Campos que pone Kubernetes por ti: `uid`, `creationTimestamp`, `resourceVersion`, `ownerReferences` (quién es el "padre" del objeto).

---

## 2. Labels

- Formato: `prefijo/opcional: valor`, máximo 63 caracteres por parte.
- No son únicos: muchos objetos comparten el mismo label.
- **Labels recomendados** por Kubernetes (úsalos, las herramientas los entienden):

| Label | Ejemplo | Significado |
| --- | --- | --- |
| `app.kubernetes.io/name` | `credito-api` | Nombre de la aplicación |
| `app.kubernetes.io/instance` | `credito-api-dev` | Instancia concreta |
| `app.kubernetes.io/version` | `1.0.1` | Versión |
| `app.kubernetes.io/component` | `backend` | Rol dentro de la arquitectura |
| `app.kubernetes.io/part-of` | `evaluacion-crediticia` | Sistema al que pertenece |
| `app.kubernetes.io/managed-by` | `helm` / `kustomize` | Herramienta que lo gestiona |

---

## 3. Selectores: cómo se "enchufan" los objetos

```text
 Service (selector: app=web) ──┐
                               ├──► Pod (labels: app=web)  ✔
 Deployment (matchLabels:      │    Pod (labels: app=web)  ✔
             app=web) ─────────┘    Pod (labels: app=api)  ✘ no coincide
```

Los selectores son el **pegamento** de Kubernetes: un Service encuentra sus Pods, un Deployment cuenta sus réplicas, una NetworkPolicy decide a quién proteger… todo por labels.

### Dos tipos de selector

```yaml
# fragmento — 1) Igualdad (Service, ReplicationController)
selector:
  app: web
  entorno: dev

# fragmento — 2) Por conjuntos (ReplicaSet, Deployment, Job, DaemonSet, StatefulSet)
selector:
  matchLabels:
    app: web
  matchExpressions:
    - key: entorno
      operator: In          # In | NotIn | Exists | DoesNotExist
      values: ["dev", "qa"]
```

### Ejemplo completo: Deployment + Service unidos por labels

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend            # "cuento como míos los Pods con app=backend"
  template:
    metadata:
      labels:
        app: backend          # DEBE coincidir con el selector de arriba
        version: v1
    spec:
      containers:
        - name: app
          image: nginx:1.27
---
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  selector:
    app: backend              # "envío tráfico a los Pods con app=backend"
  ports:
    - port: 80
      targetPort: 80
```

---

## 4. Práctica en Minikube

```sh
kubectl get pods --show-labels
kubectl get pods -l app=backend                      # igualdad
kubectl get pods -l 'app=backend,version!=v2'        # varias condiciones
kubectl get pods -l 'entorno in (dev,qa)'            # por conjunto
kubectl get pods -L app,version                      # labels como columnas

kubectl label pod <pod> entorno=dev                  # agregar label
kubectl label pod <pod> entorno=qa --overwrite       # cambiar
kubectl label pod <pod> entorno-                     # quitar (guion al final)

kubectl delete pods -l app=prueba                    # borrar por label (¡cuidado!)
```

**Experimento revelador:** quítale el label `app=backend` a uno de los Pods del Deployment. El Deployment deja de contarlo como suyo, ve que tiene 1 de 2 y **crea uno nuevo**. El Pod "huérfano" sigue vivo, pero ya no recibe tráfico del Service.

```sh
kubectl label pod <pod-del-backend> app-
kubectl get pods --show-labels
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `selector does not match template labels` | Los labels del `template` no contienen los del `selector` | Igualarlos |
| Service sin tráfico (`endpoints <none>`) | El selector del Service no coincide con ningún Pod | `kubectl get endpoints` y `--show-labels` |
| No puedo cambiar el selector de un Deployment | El `selector` es **inmutable** | Borrar y recrear el Deployment |
| Dos Deployments "se pelean" por Pods | Selectores que se solapan | Labels únicos por aplicación |

---

## 6. Lo que debe saber el arquitecto

- **La taxonomía de labels es una decisión de arquitectura**, no un detalle. Define un estándar corporativo (sistema, componente, entorno, centro de costo, criticidad, clasificación de datos) y hazlo obligatorio con políticas (Kyverno / OPA Gatekeeper).
- Los labels alimentan **costos** (*chargeback* por equipo), **seguridad** (NetworkPolicies), **observabilidad** (filtros en dashboards) y **despliegues** (canary, blue/green).
- **Labels para seleccionar, annotations para describir.** No metas textos largos ni datos sensibles en labels.

---

## 7. Checklist junior → senior

- [ ] **Junior:** pongo labels, filtro con `-l` y entiendo que el Service encuentra Pods por labels.
- [ ] **Semi-senior:** uso `matchExpressions` y diagnostico un Service sin endpoints.
- [ ] **Senior:** defino la taxonomía de labels de la organización y la hago cumplir por política.

---

← [04 · Pods](04-pods.md) · [Índice](../README.md) · Siguiente → [06 · Reinicio de Pod y exec](06-pods-reinicio-y-exec.md)
