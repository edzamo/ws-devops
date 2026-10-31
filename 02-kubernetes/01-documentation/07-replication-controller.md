# 07 · ReplicationController

> **En una frase:** El ReplicationController garantiza que **siempre haya N copias** de un Pod corriendo; es el controlador original de Kubernetes y hoy está **reemplazado** por ReplicaSet y Deployment.
>
> **Analogía (contar manzanas):** Es el **primer gerente de personal** del banco. Su única regla: "en esta sucursal siempre debe haber **3 cajeros**". Si uno se va, contrata otro; si hay 4, despide uno. Cuenta a los cajeros por su gafete exacto (`app=web`).

---

## 1. Problema → solución

| Problema | Solución que aporta |
| --- | --- |
| Si un Pod muere, nadie lo vuelve a crear | Recrea el Pod automáticamente (autorreparación) |
| Un solo Pod no aguanta la carga | Mantiene N réplicas idénticas (escalado horizontal manual) |
| Un nodo se cae con sus Pods | Recrea las réplicas en otros nodos |

---

## 2. Cómo funciona

```text
 deseado: replicas = 3
 ┌──────────────────────────┐
 │ ReplicationController    │  cuenta Pods con label app=web
 │ selector: app=web        │
 └────────────┬─────────────┘
              │  real = 2  →  falta 1  →  crea 1 desde el template
     ┌────────┼────────┐
   [Pod]    [Pod]    [Pod nuevo]
```

---

## 3. Manifiesto comentado

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: web-rc
spec:
  replicas: 3                 # ¿cuántas manzanas quiero?
  selector:                   # SOLO igualdad (app = web). No soporta In / NotIn
    app: web-rc
  template:                   # el "molde" de cada Pod nuevo
    metadata:
      labels:
        app: web-rc           # debe coincidir con el selector
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

---

## 4. Práctica en Minikube

```sh
kubectl apply -f rc.yaml
kubectl get rc
kubectl get pods -l app=web-rc

kubectl delete pod <uno-de-los-pods>       # autorreparación: aparece otro
kubectl get pods -l app=web-rc -w          # -w = observar en vivo

kubectl scale rc web-rc --replicas=5       # escalar
kubectl describe rc web-rc                 # eventos: SuccessfulCreate / SuccessfulDelete
kubectl delete rc web-rc                   # borra el RC y sus Pods
```

---

## 5. Limitaciones (por qué dejó de usarse)

| Limitación | Consecuencia |
| --- | --- |
| Selector solo por igualdad | No puede agrupar "dev **o** qa" |
| No sabe actualizar versiones | Cambiar la imagen del template **no** cambia los Pods existentes |
| El *rolling update* se hacía desde el cliente (`kubectl rolling-update`, ya eliminado) | Si se cortaba tu laptop, la actualización quedaba a medias |

---

## 6. Lo que debe saber el arquitecto

- **Concepto vigente, objeto obsoleto.** La idea (réplicas + autorreparación + reconciliación) es la base de todo; el objeto `ReplicationController` no se usa en diseños nuevos.
- Si lo encuentras en un sistema existente, es **deuda técnica**: plan de migración a Deployment.
- Evolución que debes poder explicar: **ReplicationController → ReplicaSet → Deployment** (tema 08 y 11).

---

## 7. Checklist junior → senior

- [ ] **Junior:** explico qué hace un RC y veo la autorreparación borrando un Pod.
- [ ] **Semi-senior:** explico sus limitaciones frente a ReplicaSet.
- [ ] **Senior:** detecto RCs heredados y planifico su migración a Deployments.

---

← [06 · Reinicio de Pod y exec](06-pods-reinicio-y-exec.md) · [Índice](../README.md) · Siguiente → [08 · ReplicaSet](08-replicaset.md)
