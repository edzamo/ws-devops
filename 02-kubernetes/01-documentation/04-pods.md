# 04 · Pods

> **En una frase:** Un Pod es la unidad mínima que Kubernetes ejecuta: uno o varios contenedores que comparten **la misma IP, la misma red y los mismos volúmenes**.
>
> **Analogía (contar manzanas):** El contenedor es el **cajero**. El Pod es la **ventanilla**: tiene un número (IP), un escritorio (volúmenes) y normalmente un solo cajero. A veces hay un ayudante en la misma ventanilla (*sidecar*). Si la ventanilla se cierra, se cierra con todos los que están dentro.

---

## 1. ¿Por qué Kubernetes no ejecuta contenedores directamente?

Porque a veces dos procesos **deben vivir juntos**: la aplicación y su agente de logs, o la aplicación y un *proxy* de seguridad. El Pod es la "cápsula" que garantiza que estén en el mismo nodo, se vean por `localhost` y compartan archivos.

```text
┌──────────────── Pod (IP 10.244.0.15) ────────────────┐
│  ┌──────────────┐    localhost    ┌───────────────┐   │
│  │ contenedor   │ ◄─────────────► │ sidecar       │   │
│  │ app :8080    │                 │ logs / proxy  │   │
│  └──────┬───────┘                 └──────┬────────┘   │
│         └──────── volumen compartido ────┘            │
└───────────────────────────────────────────────────────┘
```

**Regla de oro:** un Pod = una instancia de **un** componente. Backend y base de datos van en Pods distintos, porque escalan y fallan por separado.

---

## 2. Manifiesto comentado

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
    - name: nginx
      image: nginx:1.27          # versión fija; nunca "latest" en entornos reales
      ports:
        - containerPort: 80      # informativo: documenta el puerto que escucha
      env:
        - name: ENTORNO
          value: "dev"
  restartPolicy: Always          # Always (defecto) | OnFailure | Never
```

### Pod con varios contenedores (init + sidecar)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-con-ayudantes
spec:
  initContainers:                # se ejecutan ANTES, en orden, y deben terminar bien
    - name: preparar
      image: busybox:1.36
      command: ["sh", "-c", "echo '<h1>Hola</h1>' > /html/index.html"]
      volumeMounts:
        - name: html
          mountPath: /html
  containers:
    - name: nginx
      image: nginx:1.27
      volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
    - name: lector-logs          # sidecar: corre junto a la app
      image: busybox:1.36
      command: ["sh", "-c", "while true; do date; sleep 30; done"]
  volumes:
    - name: html
      emptyDir: {}
```

- **initContainer:** "antes de abrir la ventanilla, ordena el escritorio" (migraciones, esperar a una dependencia, descargar configuración).
- **sidecar:** "ayudante permanente" (logs, proxy de *service mesh*, renovación de certificados).

---

## 3. Ciclo de vida de un Pod

| Fase (`STATUS`) | Qué significa |
| --- | --- |
| `Pending` | Aceptado, pero aún sin nodo o descargando imagen |
| `ContainerCreating` | Preparando volúmenes y red |
| `Running` | Al menos un contenedor está corriendo |
| `Succeeded` / `Completed` | Terminó bien (típico de Jobs) |
| `Failed` | Terminó con error |
| `CrashLoopBackOff` | Se cae y Kubernetes reintenta con espera creciente |
| `ImagePullBackOff` / `ErrImagePull` | No puede descargar la imagen |
| `OOMKilled` | Superó su límite de memoria (tema 15) |

---

## 4. Práctica en Minikube

```sh
kubectl apply -f pod.yaml
kubectl get pods                       # lista
kubectl get pods -o wide               # + IP y nodo
kubectl get pod web -o yaml            # el objeto completo, incluido status
kubectl describe pod web               # detalle + EVENTOS (lo primero que se mira ante un fallo)
kubectl logs web                       # logs del contenedor
kubectl logs web -c lector-logs -f     # logs de un contenedor específico, en vivo
kubectl logs web --previous            # logs del contenedor ANTERIOR (antes del crash)
kubectl port-forward pod/web 8080:80   # abrir http://localhost:8080
kubectl delete pod web
```

---

## 5. Errores comunes

| Síntoma | Causa probable | Dónde mirar |
| --- | --- | --- |
| `Pending` eterno | No hay CPU/memoria suficiente o no hay nodo compatible | `kubectl describe pod` → Events |
| `ImagePullBackOff` | Nombre/tag de imagen mal escrito o registro privado sin credenciales | Events; `imagePullSecrets` |
| `CrashLoopBackOff` | La aplicación arranca y muere | `kubectl logs --previous` |
| Borré el Pod y no volvió | Era un Pod "suelto", sin controlador | Usa un Deployment (tema 11) |

---

## 6. Lo que debe saber el arquitecto

- **Los Pods son desechables (ganado, no mascotas).** Su IP cambia cada vez que se recrean. Nadie debe apuntar a la IP de un Pod: para eso existe el Service (tema 10).
- **Nunca se crean Pods sueltos en producción.** Siempre a través de un controlador: Deployment, StatefulSet, DaemonSet o Job.
- **Imagen inmutable:** usa versiones fijas o, mejor, *digest* (`imagen@sha256:...`) para garantizar que se ejecuta exactamente lo que el pipeline escaneó.
- **Seguridad del Pod** (en banca no es opcional): ejecutar como no-root, sistema de archivos de solo lectura, sin privilegios.

```yaml
# fragmento: securityContext recomendado para un contenedor
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
```

---

## 7. Checklist junior → senior

- [ ] **Junior:** creo un Pod, veo sus logs y lo describo.
- [ ] **Semi-senior:** diagnostico `Pending`, `CrashLoopBackOff` e `ImagePullBackOff` por los eventos; uso init y sidecar.
- [ ] **Senior:** defino el estándar de Pod de la organización (securityContext, recursos, probes, imágenes por digest).

---

← [03 · Manifiesto vs. comandos](03-manifiesto-vs-comandos-y-declarativo.md) · [Índice](../README.md) · Siguiente → [05 · Metadata, labels y selectores](05-metadata-labels-selectores.md)
