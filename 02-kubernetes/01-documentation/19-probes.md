# 19 · Probes (liveness, readiness y startup)

> **En una frase:** Las probes son **chequeos de salud** que el kubelet hace a cada contenedor para decidir si **reiniciarlo** (liveness), si **mandarle tráfico** (readiness) o si **todavía está arrancando** (startup).
>
> **Analogía (contar manzanas):** El supervisor de la sucursal pasa por cada ventanilla y pregunta:
> - **Startup:** "¿ya terminaste de abrir tu caja?" (no te molesto hasta que digas que sí).
> - **Liveness:** "¿estás **vivo**?" — si no responde varias veces, lo **reemplaza**.
> - **Readiness:** "¿estás **listo para atender**?" — si dice que no (está contando el efectivo), **no le manda clientes**, pero no lo despide.

---

## 1. Problema → solución

| Problema | Probe |
| --- | --- |
| La app se colgó (deadlock) pero el proceso sigue vivo | **Liveness** → reinicio |
| Durante un despliegue llegan errores 5xx porque el Pod aún no está listo | **Readiness** → no recibe tráfico hasta estar listo |
| La base de datos se cayó y la app no puede atender temporalmente | **Readiness** falla → sale del Service, sin reinicios inútiles |
| App Java/Spring/Quarkus tarda 60 s en arrancar y la liveness la mata en bucle | **Startup** → protege el arranque |

---

## 2. Cómo se comportan

| Probe | Si falla… | Afecta al Service | Afecta a reinicios |
| --- | --- | --- | --- |
| `startupProbe` | Al agotar intentos → reinicio | Sí (no está Ready) | Sí |
| `livenessProbe` | Reinicia el contenedor | Indirectamente | **Sí** |
| `readinessProbe` | Lo quita de los endpoints | **Sí** | **No** |

```text
 arranque ──► startupProbe OK ──► empiezan liveness y readiness (en paralelo, para siempre)
                                    readiness OK  → entra al balanceo del Service
                                    readiness KO  → sale del balanceo
                                    liveness KO×N → reinicio del contenedor
```

### Mecanismos

| Tipo | Ejemplo |
| --- | --- |
| `httpGet` | `GET /q/health/live` responde 200-399 |
| `tcpSocket` | El puerto 5432 acepta conexión |
| `exec` | El comando `pg_isready` devuelve 0 |
| `grpc` | Servicio gRPC de salud |

### Parámetros

| Parámetro | Defecto | Significado |
| --- | --- | --- |
| `initialDelaySeconds` | 0 | Espera antes del primer chequeo |
| `periodSeconds` | 10 | Cada cuánto chequear |
| `timeoutSeconds` | 1 | Tiempo máximo de respuesta |
| `failureThreshold` | 3 | Fallos seguidos para declarar falla |
| `successThreshold` | 1 | Éxitos para volver a OK (readiness) |

Tiempo máximo de arranque permitido por la startup probe = `failureThreshold × periodSeconds`.

---

## 3. Manifiesto comentado

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-probes
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-probes
  template:
    metadata:
      labels:
        app: web-probes
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
          startupProbe:                 # hasta 30 × 2 s = 60 s para arrancar
            httpGet:
              path: /
              port: http
            periodSeconds: 2
            failureThreshold: 30
          livenessProbe:                # ¿el proceso está sano?
            httpGet:
              path: /
              port: http
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:               # ¿puede atender tráfico?
            httpGet:
              path: /
              port: http
            periodSeconds: 5
            failureThreshold: 2
```

Para Quarkus (como los microservicios del lab 05) con `quarkus-smallrye-health`:

```yaml
# fragmento
livenessProbe:
  httpGet: { path: /q/health/live, port: 8080 }
readinessProbe:
  httpGet: { path: /q/health/ready, port: 8080 }
startupProbe:
  httpGet: { path: /q/health/started, port: 8080 }
  failureThreshold: 30
  periodSeconds: 2
```

---

## 4. Práctica en Minikube

```sh
kubectl apply -f probes.yaml
kubectl get pods -l app=web-probes                 # READY 1/1

# Romper la readiness: borrar la página → deja de recibir tráfico (READY 0/1) pero NO se reinicia
POD=$(kubectl get pod -l app=web-probes -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- rm /usr/share/nginx/html/index.html
kubectl get pods -l app=web-probes -w              # READY 0/1 y luego RESTARTS sube (liveness usa la misma ruta)
kubectl describe pod $POD | grep -A10 Events       # "Readiness probe failed", "Liveness probe failed"
```

> En este ejemplo liveness y readiness usan la misma ruta, así que primero el Pod sale del Service y luego se reinicia. En una app real, **liveness y readiness deben chequear cosas distintas**.

---

## 5. Errores comunes (y graves)

| Error | Consecuencia | Correcto |
| --- | --- | --- |
| Liveness revisa la base de datos | Se cae la BD → **se reinician todos** los Pods en cascada | Liveness = solo el proceso; dependencias en **readiness** |
| Sin readiness | Errores 5xx en cada despliegue y escalado | Siempre readiness en servicios que reciben tráfico |
| Liveness con `timeoutSeconds: 1` en app lenta | Reinicios bajo carga (empeora el incidente) | Tiempos realistas |
| Sin startup en apps de arranque lento | `CrashLoopBackOff` eterno | `startupProbe` |

---

## 6. Lo que debe saber el arquitecto

- **Las probes son el contrato entre la aplicación y la plataforma.** Exígelas en el estándar de desarrollo (endpoints `/health/live` y `/health/ready`) y valídalas con políticas.
- Sin readiness, ni el rolling update (tema 11) ni el Service (tema 10) pueden proteger al usuario.
- **Apagado ordenado:** además de las probes, la app debe atender `SIGTERM` y terminar las peticiones en curso (`terminationGracePeriodSeconds`, *hook* `preStop`). Sin eso, cada despliegue corta transacciones.
- Las probes miden **salud del Pod**, no la experiencia del usuario: se complementan con monitoreo sintético y SLOs.

---

## 7. Checklist junior → senior

- [ ] **Junior:** configuro las 3 probes y sé qué hace cada una al fallar.
- [ ] **Semi-senior:** ajusto tiempos para apps lentas y separo liveness de dependencias.
- [ ] **Senior:** defino el contrato de salud y de apagado ordenado para todos los servicios.

---

← [18 · DaemonSet](18-daemonset.md) · [Índice](../README.md) · Siguiente → [20 · Jobs](20-jobs.md)
