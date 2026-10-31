# 10 · Services

> **En una frase:** Un Service le da a un grupo de Pods **una dirección fija (IP y nombre DNS)** y reparte el tráfico entre ellos, aunque los Pods mueran y nazcan con IPs nuevas.
>
> **Analogía (contar manzanas):** Los cajeros (Pods) cambian todo el tiempo. El cliente no busca a "Juan de la ventanilla 4": llama al **número único de atención** del área de créditos, y la centralita lo pasa a **cualquier cajero libre** con gafete de créditos. Ese número fijo es el Service.

---

## 1. Problema → solución

| Problema | Solución |
| --- | --- |
| Las IPs de los Pods cambian al recrearse | IP virtual estable (ClusterIP) + nombre DNS |
| Tengo 3 réplicas: ¿a cuál llamo? | El Service **balancea** entre las réplicas sanas |
| Quiero exponer la app fuera del clúster | `NodePort` o `LoadBalancer` (o Ingress, tema 23) |
| Necesito llamar a cada réplica por su nombre (bases de datos) | Service *headless* (tema 16) |

---

## 2. Cómo funciona

```text
  Pod cliente ──► http://credito-api  (DNS)
                       │
              Service credito-api  ClusterIP 10.96.12.7:80
              selector: app=credito-api
                       │  (kube-proxy reparte)
          ┌────────────┼────────────┐
     Pod 10.244.0.5  Pod 10.244.0.6  Pod 10.244.0.7   :8080 (targetPort)
```

El Service mantiene la lista de Pods que coinciden con su selector **y están Ready** en un objeto llamado **EndpointSlice**. Si la *readiness probe* de un Pod falla (tema 19), sale de la lista y deja de recibir tráfico.

### Los tres puertos (fuente clásica de confusión)

| Campo | Dónde | Ejemplo |
| --- | --- | --- |
| `port` | Puerto del **Service** | 80 |
| `targetPort` | Puerto del **contenedor** | 8080 |
| `nodePort` | Puerto abierto en **cada nodo** (solo NodePort/LoadBalancer) | 30080 (rango 30000-32767) |

---

## 3. Tipos de Service

| Tipo | Accesible desde | Uso típico |
| --- | --- | --- |
| **ClusterIP** (defecto) | Solo dentro del clúster | Comunicación entre microservicios |
| **NodePort** | `IP-del-nodo:30000-32767` | Laboratorios, integraciones simples |
| **LoadBalancer** | IP pública/privada de un balanceador de la nube | Exponer un servicio TCP/HTTP al exterior |
| **ExternalName** | Alias DNS a algo externo | Apuntar a `db.ejemplo.com` con nombre interno |
| **Headless** (`clusterIP: None`) | DNS devuelve las IPs de cada Pod | StatefulSets, bases de datos |

```text
 LoadBalancer ⊃ NodePort ⊃ ClusterIP   (cada tipo incluye al anterior)
```

---

## 4. Manifiesto comentado

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: credito-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: credito-api
  template:
    metadata:
      labels:
        app: credito-api
    spec:
      containers:
        - name: api
          image: hashicorp/http-echo:1.0
          args: ["-text=hola desde credito-api", "-listen=:8080"]
          ports:
            - name: http
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: credito-api
spec:
  type: ClusterIP
  selector:
    app: credito-api          # a qué Pods envía tráfico
  ports:
    - name: http
      port: 80                # puerto del Service
      targetPort: http        # nombre del puerto del contenedor (8080)
---
apiVersion: v1
kind: Service
metadata:
  name: credito-api-nodeport
spec:
  type: NodePort
  selector:
    app: credito-api
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080
```

---

## 5. Práctica en Minikube

```sh
kubectl apply -f service.yaml
kubectl get svc
kubectl get endpointslices -l kubernetes.io/service-name=credito-api
kubectl describe svc credito-api                  # ver Endpoints

# Probar desde dentro del clúster (DNS + balanceo: repetir varias veces)
kubectl run tmp --rm -it --image=busybox:1.36 -- wget -qO- http://credito-api

# Probar desde tu máquina
kubectl port-forward svc/credito-api 8080:80      # http://localhost:8080
minikube service credito-api-nodeport --url       # URL del NodePort

# LoadBalancer en Minikube: en otra terminal
minikube tunnel
```

Imperativo equivalente: `kubectl expose deployment credito-api --port=80 --target-port=8080`.

---

## 6. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `Endpoints: <none>` | Selector no coincide o Pods no están Ready | `--show-labels`, revisar readiness |
| `connection refused` | `targetPort` distinto al puerto real de la app | Verificar en qué puerto escucha el contenedor |
| `EXTERNAL-IP <pending>` en Minikube | No hay balanceador | `minikube tunnel` |
| Un LoadBalancer por cada microservicio | Costo alto y muchas IPs | Un Ingress / Gateway para todo el HTTP |

---

## 7. Lo que debe saber el arquitecto

- **Service = descubrimiento + balanceo interno (capa 4).** Para enrutar HTTP por dominio o ruta, TLS, etc., se usa Ingress/Gateway (capa 7, temas 23-24).
- **ClusterIP por defecto.** Solo el punto de entrada (Ingress Controller o Gateway) se expone; los microservicios **no** se publican directamente.
- En la nube, `type: LoadBalancer` **crea un balanceador real que se cobra** (NLB/ALB en AWS, Azure Load Balancer, Cloud Load Balancing en GCP). Se controla con anotaciones (interno vs. público, tema 22).
- El balanceo del Service es simple (conexión por conexión). Necesidades avanzadas (reintentos, mTLS, *circuit breaker*) se resuelven con un *service mesh* (Istio, Linkerd).

---

## 8. Checklist junior → senior

- [ ] **Junior:** expongo un Deployment con ClusterIP y NodePort y lo pruebo.
- [ ] **Semi-senior:** diagnostico Services sin endpoints y entiendo `port`/`targetPort`/`nodePort`.
- [ ] **Senior:** diseño la topología de exposición (qué es interno, qué es público, cuántos balanceadores y su costo).

---

← [09 · Namespaces](09-namespaces.md) · [Índice](../README.md) · Siguiente → [11 · Deployments](11-deployments.md)
