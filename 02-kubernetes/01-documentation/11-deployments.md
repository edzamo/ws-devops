# 11 · Deploys y Deployments (incluye escalabilidad horizontal y vertical)

> **En una frase:** El Deployment es el objeto estándar para ejecutar aplicaciones *stateless*: mantiene N réplicas, **cambia de versión sin corte** (rolling update) y permite **volver atrás** (rollback).
>
> **Analogía (contar manzanas):** El Deployment es el **gerente de sucursal**. Le dices "quiero 3 cajeros con el manual versión 2". Él no despide a todos de golpe: **entra un cajero nuevo, sale uno viejo**, uno por uno, para que la fila nunca quede sin atención. Si el manual nuevo sale mal, vuelve a la versión anterior.

---

## 1. "Deploy" vs. "Deployment"

| Término | Significado |
| --- | --- |
| **Deploy (desplegar)** | La **acción** de poner una versión en un entorno (lo hace el pipeline) |
| **Deployment** | El **objeto** de Kubernetes que ejecuta esa versión y gestiona su ciclo de vida |

---

## 2. Problema → solución

| Problema | Solución en el Deployment |
| --- | --- |
| Actualizar sin cortar el servicio | `strategy: RollingUpdate` |
| La versión nueva falla | `kubectl rollout undo` (rollback) |
| La carga aumenta | Más réplicas (manual o automático con HPA) |
| Dos versiones no pueden convivir (cambio de esquema) | `strategy: Recreate` |
| Saber si el despliegue terminó bien en el pipeline | `kubectl rollout status` (+ `progressDeadlineSeconds`) |

---

## 3. Cómo funciona un rolling update

```text
 replicas: 3   maxSurge: 1   maxUnavailable: 0

 v1 v1 v1                  inicio
 v1 v1 v1 v2               +1 nuevo (surge); espera a que v2 esté READY
 v1 v1 v2                  -1 viejo
 v1 v1 v2 v2               +1 nuevo
 v1 v2 v2                  -1 viejo
 v1 v2 v2 v2  → v2 v2 v2   fin: el ReplicaSet v1 queda con 0 réplicas (para rollback)
```

- `maxSurge`: cuántos Pods **extra** se permiten durante el cambio.
- `maxUnavailable`: cuántos Pods pueden faltar durante el cambio.
- Kubernetes solo avanza cuando el Pod nuevo está **Ready**: sin *readiness probe* (tema 19), "Ready" solo significa "el proceso arrancó".

---

## 4. Manifiesto comentado

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  revisionHistoryLimit: 5           # versiones viejas guardadas para rollback
  progressDeadlineSeconds: 300      # si en 5 min no avanza → falla (el pipeline lo detecta)
  strategy:
    type: RollingUpdate             # RollingUpdate (defecto) | Recreate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0             # nunca menos de 3 atendiendo
  selector:
    matchLabels:
      app: web                      # inmutable una vez creado
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:                # obligatorio para escalar bien (tema 15)
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 256Mi
          readinessProbe:           # obligatorio para un rolling update sin errores
            httpGet:
              path: /
              port: 80
```

---

## 5. Práctica en Minikube

```sh
kubectl apply -f deployment.yaml
kubectl get deploy,rs,pods -l app=web

# Desplegar una versión nueva
kubectl set image deployment/web nginx=nginx:1.28
kubectl rollout status deployment/web          # espera hasta terminar (úsalo en pipelines)
kubectl get rs -l app=web                      # 2 ReplicaSets: viejo en 0, nuevo en 3

# Historial y rollback
kubectl annotate deployment/web kubernetes.io/change-cause="nginx 1.28" --overwrite
kubectl rollout history deployment/web
kubectl rollout undo deployment/web                    # a la versión anterior
kubectl rollout undo deployment/web --to-revision=1    # a una versión concreta

# Pausar para hacer varios cambios de una sola vez
kubectl rollout pause deployment/web
kubectl rollout resume deployment/web

# Simular un despliegue roto
kubectl set image deployment/web nginx=nginx:no-existe
kubectl rollout status deployment/web --timeout=60s    # falla; los Pods v1 siguen atendiendo
kubectl rollout undo deployment/web
```

> Lo correcto en un equipo es cambiar la imagen **en el YAML de Git** y aplicar; `set image` es para practicar.

---

## 6. Escalabilidad: horizontal vs. vertical

```text
 VERTICAL (scale up)                   HORIZONTAL (scale out)
 un cajero más fuerte                  más cajeros iguales

 ┌──────────┐                          ┌───┐ ┌───┐ ┌───┐ ┌───┐
 │  Pod     │  más CPU/RAM             │Pod│ │Pod│ │Pod│ │Pod│
 │  grande  │                          └───┘ └───┘ └───┘ └───┘
 └──────────┘
 Tiene techo (tamaño del nodo)          Casi sin techo, tolera fallos
 Suele requerir reiniciar el Pod        Requiere app stateless
```

| Nivel | Horizontal | Vertical |
| --- | --- | --- |
| **Pods** | `replicas` manual o **HPA** (Horizontal Pod Autoscaler) | `resources` manual o **VPA** (Vertical Pod Autoscaler) |
| **Nodos** | **Cluster Autoscaler / Karpenter**: agrega nodos cuando hay Pods `Pending` | Cambiar a máquinas más grandes (nuevo *node pool*) |

### Escalado manual

```sh
kubectl scale deployment/web --replicas=5
```

### Escalado automático horizontal (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 3                # mínimo para alta disponibilidad
  maxReplicas: 10               # techo para controlar costo
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70   # % del REQUEST de CPU (sin requests no funciona)
```

```sh
minikube addons enable metrics-server
kubectl apply -f hpa.yaml
kubectl get hpa -w
kubectl top pods
```

**Cómo decidirlo como arquitecto:**

| Síntoma | Primera respuesta |
| --- | --- |
| Latencia sube con más usuarios y la CPU de los Pods está alta | **Horizontal**: más réplicas / HPA |
| Un Pod se cae por `OOMKilled` con carga normal | **Vertical**: más memoria (corregir requests/limits) |
| HPA quiere más réplicas pero quedan `Pending` | Faltan nodos → **Cluster Autoscaler** |
| La base de datos es el cuello de botella | Escalar la app **no ayuda**: réplicas de lectura, caché, base gestionada |
| Picos por eventos de negocio (cola de mensajes) | **KEDA**: escalar por largo de cola o eventos, no por CPU |

---

## 7. Estrategias de despliegue (más allá del objeto)

| Estrategia | Idea | Cómo en Kubernetes |
| --- | --- | --- |
| Rolling update | Reemplazo gradual | Nativo del Deployment |
| Recreate | Apagar todo y prender lo nuevo | `strategy: Recreate` (hay corte) |
| Blue/Green | Dos entornos completos; se cambia el tráfico de golpe | Dos Deployments + cambiar el selector del Service |
| Canary | Un % pequeño del tráfico a la versión nueva | Ingress/Gateway con pesos, Argo Rollouts, Flagger |

---

## 8. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| Rollout "terminó" pero hay errores 5xx | No hay readiness probe | Agregar probes (tema 19) |
| `rollout status` nunca termina | Imagen inexistente o Pods sin recursos | `kubectl describe pod` → eventos |
| Rollback no vuelve a la versión esperada | Historial recortado | Revisar `revisionHistoryLimit` |
| Cambié un ConfigMap y no se aplicó | El template del Pod no cambió | `kubectl rollout restart` (tema 13) |
| HPA en `<unknown>` | Sin metrics-server o sin requests de CPU | Habilitar métricas y definir requests |

---

## 9. Lo que debe saber el arquitecto

- **Deployment = cargas sin estado.** Si cada réplica necesita su propio disco o identidad, es StatefulSet (tema 16).
- **Alta disponibilidad mínima:** `replicas ≥ 2` (en producción, normalmente 3), repartidas en nodos y zonas distintas (anti-affinity / topology spread, tema 17) y un **PodDisruptionBudget** para que el mantenimiento de nodos no tumbe todas las réplicas a la vez.
- **El pipeline despliega por digest y espera** (`rollout status`); si falla, hace rollback automático. Eso es un despliegue auditable.
- **Escalabilidad es de extremo a extremo:** más réplicas multiplican conexiones a la base de datos; dimensiona *pools* de conexión.

---

## 10. Checklist junior → senior

- [ ] **Junior:** creo un Deployment, cambio la imagen y hago rollback.
- [ ] **Semi-senior:** ajusto `maxSurge`/`maxUnavailable`, uso HPA y entiendo horizontal vs. vertical.
- [ ] **Senior:** diseño estrategia de despliegue (canary/blue-green), alta disponibilidad multi-zona y escalado de punta a punta (Pods, nodos y dependencias).

---

← [10 · Services](10-services.md) · [Índice](../README.md) · Siguiente → [12 · Volúmenes](12-volumenes.md)
