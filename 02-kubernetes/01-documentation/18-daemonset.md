# 18 · DaemonSet

> **En una frase:** Un DaemonSet ejecuta **exactamente un Pod en cada nodo** (o en cada nodo que cumpla una condición); si se agrega un nodo, el Pod aparece solo.
>
> **Analogía (contar manzanas):** Es el **guardia de seguridad**: cada sucursal tiene **uno**, ni más ni menos. Si el banco abre una sucursal nueva, se le asigna su guardia automáticamente. No se cuenta por "réplicas" sino por "sucursales".

---

## 1. Problema → solución

| Problema | Ejemplo de DaemonSet |
| --- | --- |
| Recolectar logs de todos los nodos | Fluent Bit, Fluentd |
| Métricas del sistema operativo de cada nodo | Prometheus node-exporter, agente de Datadog |
| Red del clúster | kube-proxy, Calico, Cilium |
| Seguridad en tiempo de ejecución | Falco, agentes EDR |
| Almacenamiento en cada nodo | Drivers CSI |

---

## 2. Cómo funciona

```text
  nodo-1          nodo-2          nodo-3          nodo-4 (nuevo)
 [agente-logs]   [agente-logs]   [agente-logs]   [agente-logs]  ← aparece solo
 [app][app]      [app]           [app][app]
```

No tiene campo `replicas`: el número de Pods = número de nodos elegibles.

---

## 3. Manifiesto comentado

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: agente-logs
  labels:
    app: agente-logs
spec:
  selector:
    matchLabels:
      app: agente-logs
  updateStrategy:
    type: RollingUpdate            # nodo por nodo
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: agente-logs
    spec:
      tolerations:                 # también en el control plane (que tiene taint)
        - key: node-role.kubernetes.io/control-plane
          operator: Exists
          effect: NoSchedule
      # nodeSelector:              # opcional: solo en algunos nodos
      #   disco: ssd
      containers:
        - name: agente
          image: busybox:1.36
          command: ["sh", "-c", "while true; do echo \"nodo $NODO: $(ls /var/log | wc -l) archivos\"; sleep 60; done"]
          env:
            - name: NODO
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName   # el nombre del nodo donde corre
          resources:
            requests:
              cpu: 20m
              memory: 32Mi
            limits:
              memory: 64Mi
          volumeMounts:
            - name: logs-nodo
              mountPath: /var/log
              readOnly: true
      volumes:
        - name: logs-nodo
          hostPath:                # lee el disco del nodo: caso legítimo de hostPath
            path: /var/log
```

---

## 4. Práctica en Minikube

```sh
kubectl get daemonsets -A                       # kube-proxy ya es un DaemonSet
kubectl apply -f daemonset.yaml
kubectl get ds agente-logs                      # DESIRED = CURRENT = número de nodos
kubectl get pods -l app=agente-logs -o wide     # uno por nodo
kubectl logs -l app=agente-logs

# En el perfil multinodo (tema 17): agregar un nodo y ver aparecer el Pod
minikube node add -p multinodo
kubectl get pods -l app=agente-logs -o wide -w

kubectl rollout status ds/agente-logs
kubectl delete ds agente-logs
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| Falta el Pod en algún nodo | El nodo tiene un taint no tolerado | Agregar toleration |
| DaemonSet consume mucho en total | Recursos × número de nodos | Requests pequeños y medidos |
| `drain` falla por Pods de DaemonSet | Se gestionan aparte | `--ignore-daemonsets` |

---

## 6. Lo que debe saber el arquitecto

- **Es la pieza de las capacidades transversales** (observabilidad, seguridad, red): las que la plataforma da a todos los equipos sin que ellos hagan nada.
- **Costo multiplicado:** 100 m de CPU × 50 nodos = 5 CPU fijos. Sumar todos los DaemonSets al dimensionar nodos.
- **Privilegios:** muchos agentes necesitan `hostPath`, `hostNetwork` o privilegios elevados. Solo imágenes aprobadas y en namespaces de plataforma.
- En nubes con nodos *serverless* (EKS Fargate, GKE Autopilot con restricciones, nodos virtuales de AKS) los DaemonSets **no corren o están limitados**: los agentes se ejecutan como *sidecar* o el proveedor ofrece la integración.

---

## 7. Checklist junior → senior

- [ ] **Junior:** explico qué es un DaemonSet y reconozco kube-proxy como uno.
- [ ] **Semi-senior:** creo uno con tolerations y nodeSelector.
- [ ] **Senior:** defino los agentes de plataforma (logs, métricas, seguridad) y su costo por nodo.

---

← [17 · Clúster multinodo y affinity](17-cluster-multinodo-y-affinity.md) · [Índice](../README.md) · Siguiente → [19 · Probes](19-probes.md)
