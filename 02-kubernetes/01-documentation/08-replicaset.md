# 08 · ReplicaSet

> **En una frase:** El ReplicaSet es la versión moderna del ReplicationController: mantiene N réplicas de un Pod, pero con **selectores más potentes**. En la práctica **no lo creas tú**: lo crea y administra el Deployment.
>
> **Analogía (contar manzanas):** Es el **gerente de personal nuevo**. Hace lo mismo que el anterior ("siempre 3 cajeros"), pero puede contar con reglas más flexibles: "cajeros de créditos **del turno mañana o tarde**". Y trabaja a las órdenes de un jefe superior: el Deployment.

---

## 1. Problema → solución

| Problema | Solución |
| --- | --- |
| Necesito N réplicas con autorreparación | ReplicaSet mantiene la cantidad exacta |
| Necesito seleccionar Pods con reglas de conjunto | `matchLabels` + `matchExpressions` |
| Necesito actualizar versiones sin corte | **No lo resuelve** él solo → usa Deployment (tema 11) |

---

## 2. Relación Deployment → ReplicaSet → Pods

```text
 Deployment web                 (decide la estrategia de versiones)
   ├── ReplicaSet web-5d4f8   (versión 1, replicas: 0)   ← se conserva para hacer rollback
   └── ReplicaSet web-7c9d8   (versión 2, replicas: 3)
          ├── Pod web-7c9d8-a1
          ├── Pod web-7c9d8-b2
          └── Pod web-7c9d8-c3
```

Cada versión del template de un Deployment genera **un ReplicaSet nuevo**. El nombre del Pod lleva el *hash* de su ReplicaSet: `web-7c9d8-a1`.

---

## 3. Manifiesto comentado

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: web-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-rs
    matchExpressions:               # lo que el ReplicationController no podía hacer
      - key: entorno
        operator: In
        values: ["dev", "qa"]
  template:
    metadata:
      labels:
        app: web-rs
        entorno: dev
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
```

---

## 4. Práctica en Minikube

```sh
kubectl apply -f rs.yaml
kubectl get rs
kubectl get pods -l app=web-rs

kubectl scale rs web-rs --replicas=5
kubectl delete pod <uno>                         # se recrea

# Experimento: cambiar la imagen del ReplicaSet
kubectl set image rs/web-rs nginx=nginx:1.28
kubectl get pods -o jsonpath='{.items[*].spec.containers[0].image}'
# → los Pods existentes SIGUEN en 1.27. Solo los nuevos usarían 1.28.
#   Esto demuestra por qué se necesita el Deployment.

# Ver los ReplicaSets creados por un Deployment
kubectl get rs -l app=web
kubectl delete rs web-rs
```

**Adopción de Pods:** si creas un Pod suelto con labels que coinciden con el selector de un ReplicaSet, el ReplicaSet lo **adopta** y lo cuenta como propio (y puede borrar uno si sobra). Otra razón para tener labels únicos.

---

## 5. ReplicationController vs. ReplicaSet vs. Deployment

| Capacidad | ReplicationController | ReplicaSet | Deployment |
| --- | --- | --- | --- |
| Mantener N réplicas | ✅ | ✅ | ✅ (vía ReplicaSet) |
| Selector por conjuntos | ❌ | ✅ | ✅ |
| Rolling update en el servidor | ❌ | ❌ | ✅ |
| Rollback a versión anterior | ❌ | ❌ | ✅ |
| ¿Se usa hoy directamente? | No (heredado) | Casi nunca | **Sí, el estándar** |

---

## 6. Lo que debe saber el arquitecto

- **Escribe Deployments, no ReplicaSets.** El ReplicaSet es una pieza interna; conocerlo sirve para **diagnosticar** (por ejemplo, ver cuántas versiones viejas se conservan para rollback).
- El número de ReplicaSets antiguos se controla con `revisionHistoryLimit` en el Deployment (por defecto 10).
- La réplica es la **unidad de escalado horizontal**: más réplicas = más capacidad y más tolerancia a fallos (si están repartidas en nodos distintos, tema 17).

---

## 7. Checklist junior → senior

- [ ] **Junior:** creo un ReplicaSet y entiendo que no actualiza la imagen de Pods existentes.
- [ ] **Semi-senior:** identifico el ReplicaSet de cada versión de un Deployment.
- [ ] **Senior:** explico la cadena de controladores y la uso para diagnosticar despliegues.

---

← [07 · ReplicationController](07-replication-controller.md) · [Índice](../README.md) · Siguiente → [09 · Namespaces](09-namespaces.md)
