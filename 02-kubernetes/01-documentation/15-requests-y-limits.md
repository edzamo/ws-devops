# 15 · Requests y limits (recursos de CPU y memoria)

> **En una frase:** `requests` es lo que el Pod **tiene garantizado** (y lo que usa el *scheduler* para elegir nodo); `limits` es el **máximo** que puede consumir.
>
> **Analogía (contar manzanas):** Cada cajero recibe un escritorio. **Request** = "te reservo un escritorio de 1 metro, pase lo que pase". **Limit** = "puedes usar hasta 2 metros si hay espacio libre, nunca más". La sucursal solo acepta cajeros si la suma de escritorios **reservados** cabe en el local.

---

## 1. Problema → solución

| Problema | Solución |
| --- | --- |
| Un Pod se come toda la memoria del nodo y tumba a los vecinos (*noisy neighbor*) | `limits.memory` |
| Pods asignados a nodos que no tienen capacidad real | `requests` correctos |
| El autoescalado (HPA) no funciona | HPA calcula sobre `requests.cpu` |
| No sé cuánto cuesta cada equipo | Requests = capacidad reservada = costo asignable |
| Pods críticos expulsados primero bajo presión | Clase QoS `Guaranteed` |

---

## 2. Unidades

| Recurso | Unidad | Ejemplos |
| --- | --- | --- |
| CPU | núcleos o **milicores** | `1` = 1 núcleo · `500m` = medio núcleo · `100m` = 10 % |
| Memoria | bytes (potencias de 2) | `128Mi`, `1Gi` (usa `Mi`/`Gi`, no `M`/`G`) |

---

## 3. CPU y memoria se comportan distinto

| Al superar el limit | CPU | Memoria |
| --- | --- | --- |
| ¿Qué pasa? | **Throttling**: el proceso va más lento | **OOMKilled**: el contenedor muere y se reinicia |
| ¿Es "comprimible"? | Sí | No |

```text
 Nodo: 4 CPU / 8 GiB
 ┌────────────────────────────────────────────┐
 │ Pod A request 1 CPU / 2Gi                   │  suma de requests = 3 CPU / 6Gi
 │ Pod B request 1 CPU / 2Gi                   │  → cabe 1 Pod más de 1 CPU / 2Gi
 │ Pod C request 1 CPU / 2Gi                   │  → un Pod que pide 2 CPU queda Pending
 └────────────────────────────────────────────┘
```

El *scheduler* mira **requests**, no el consumo real.

---

## 4. Clases de calidad de servicio (QoS)

| Clase | Regla | ¿Quién es expulsado primero si falta memoria en el nodo? |
| --- | --- | --- |
| `Guaranteed` | requests = limits en CPU y memoria, en todos los contenedores | Último |
| `Burstable` | Tiene requests, pero menores que limits | Intermedio |
| `BestEffort` | Sin requests ni limits | **Primero** |

---

## 5. Manifiesto comentado

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: con-recursos
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:              # garantizado → decide el nodo
          cpu: 250m
          memory: 256Mi
        limits:                # techo
          cpu: "1"
          memory: 256Mi        # memoria: limit = request evita sorpresas de OOM por sobreventa
```

Práctica habitual: **memoria con request = limit**; **CPU con request** realista y limit holgado (o sin limit, según la política de la organización), porque el *throttling* de CPU causa latencias difíciles de diagnosticar.

### Prueba de OOMKilled

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-demo
spec:
  restartPolicy: Never
  containers:
    - name: estres
      image: busybox:1.36
      command: ["tail", "/dev/zero"]   # acumula memoria sin parar (el proceso principal)
      resources:
        requests:
          memory: 64Mi
        limits:
          memory: 100Mi        # al pasar de 100Mi → OOMKilled (exit code 137)
```

---

## 6. Práctica en Minikube

```sh
minikube addons enable metrics-server
kubectl apply -f oom-demo.yaml
kubectl get pod oom-demo -w                             # STATUS: OOMKilled
kubectl describe pod oom-demo | grep -A3 "Last State"   # Reason: OOMKilled, Exit Code 137

kubectl top pods                                        # consumo real
kubectl top nodes
kubectl describe node minikube | grep -A8 "Allocated resources"   # suma de requests/limits
kubectl get pod con-recursos -o jsonpath='{.status.qosClass}'
```

---

## 7. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `Pending` – *Insufficient cpu/memory* | Requests mayores a lo disponible | Bajar requests o agregar nodos |
| `OOMKilled` (exit 137) | Memoria real > limit | Medir y subir el limit, o corregir fuga |
| App Java lenta sin motivo | Throttling de CPU o heap mal dimensionado | Revisar limit de CPU; JVM consciente del contenedor (`-XX:MaxRAMPercentage`) |
| Nodo lleno pero CPU real al 10 % | Requests infladas | *Rightsizing* con métricas o VPA en modo recomendación |

---

## 8. Lo que debe saber el arquitecto

- **Requests = capacidad y costo.** El tamaño del clúster se paga por lo reservado, no por lo usado. Requests infladas = dinero desperdiciado; requests bajas = inestabilidad.
- **Vertical vs. horizontal:** subir requests/limits es escalar **vertical** (VPA lo automatiza); agregar réplicas es **horizontal** (HPA, tema 11). VPA y HPA no deben gestionar **la misma métrica** (CPU) a la vez.
- Gobierno por namespace: **LimitRange** (valores por defecto y máximos por contenedor) + **ResourceQuota** (total del equipo), ver tema 09.
- Para servicios críticos (core bancario, autorizador de pagos): QoS `Guaranteed` y `PriorityClass` alta, para que sean los últimos en ser expulsados.

---

## 9. Checklist junior → senior

- [ ] **Junior:** declaro requests y limits y sé qué es OOMKilled.
- [ ] **Semi-senior:** distingo throttling de OOM, leo QoS y dimensiono con `kubectl top`.
- [ ] **Senior:** defino la política de recursos de la organización (LimitRange, cuotas, prioridades) y el *rightsizing* continuo ligado a costos.

---

← [14 · Secrets](14-secrets.md) · [Índice](../README.md) · Siguiente → [16 · StatefulSet](16-statefulset.md)
