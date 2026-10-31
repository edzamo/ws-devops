# 20 · Jobs

> **En una frase:** Un Job ejecuta una tarea **hasta que termina con éxito** (y reintenta si falla); a diferencia de un Deployment, no busca estar siempre corriendo.
>
> **Analogía (contar manzanas):** El Deployment es el cajero que atiende todo el día. El Job es el **auditor contratado para contar las manzanas de la bodega una vez**: cuando termina, entrega el informe y se va. Si se equivoca, vuelve a contar (hasta un número máximo de intentos).

---

## 1. Problema → solución

| Problema | Job |
| --- | --- |
| Migrar el esquema de la base de datos antes de desplegar | Job de migración (o hook de Helm) |
| Procesar un lote de archivos / cierre contable puntual | Job con `parallelism` |
| Procesar 100 elementos repartidos en varios Pods | Job `Indexed` con `completions: 100` |
| Tarea repetitiva con horario | CronJob (tema 21), que crea Jobs |

---

## 2. Cómo funciona

```text
 Job (completions: 3, parallelism: 2)
   ├── Pod 1 ✔
   ├── Pod 2 ✘ → reintento (backoffLimit) → Pod 2' ✔
   └── Pod 3 ✔
 → Job Complete (3/3)
```

| Campo | Significado |
| --- | --- |
| `completions` | Cuántas ejecuciones exitosas se necesitan (defecto 1) |
| `parallelism` | Cuántos Pods a la vez |
| `backoffLimit` | Reintentos antes de marcar el Job como fallido (defecto 6) |
| `activeDeadlineSeconds` | Tiempo máximo total del Job |
| `ttlSecondsAfterFinished` | Borrar el Job (y sus Pods) N segundos después de terminar |
| `completionMode: Indexed` | Cada Pod recibe un índice (`JOB_COMPLETION_INDEX`) para repartir el trabajo |
| `restartPolicy` | En Jobs **solo** `OnFailure` o `Never` |

---

## 3. Manifiesto comentado

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: calcular-pi
spec:
  completions: 3
  parallelism: 2
  backoffLimit: 4
  activeDeadlineSeconds: 300
  ttlSecondsAfterFinished: 600      # limpieza automática a los 10 min
  template:
    spec:
      restartPolicy: Never          # Never: un Pod nuevo por intento (deja ver el fallo)
      containers:
        - name: pi
          image: perl:5.40
          command: ["perl", "-Mbignum=bpi", "-wle", "print bpi(500)"]
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
```

### Job que falla a propósito (para ver reintentos)

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-que-falla
spec:
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: falla
          image: busybox:1.36
          command: ["sh", "-c", "echo intentando...; exit 1"]
```

---

## 4. Práctica en Minikube

```sh
kubectl apply -f job.yaml
kubectl get jobs -w                          # COMPLETIONS 0/3 → 3/3
kubectl get pods -l job-name=calcular-pi     # Pods en Completed
kubectl logs -l job-name=calcular-pi --tail=1
kubectl wait --for=condition=complete job/calcular-pi --timeout=120s   # útil en pipelines

kubectl apply -f job-que-falla.yaml
kubectl get pods -l job-name=job-que-falla   # 3 Pods en Error (1 + 2 reintentos)
kubectl describe job job-que-falla           # BackoffLimitExceeded

# Imperativo
kubectl create job prueba --image=busybox:1.36 -- echo hola
kubectl delete job calcular-pi job-que-falla prueba
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| Error al crear: `restartPolicy` inválida | Usaste `Always` | `Never` u `OnFailure` |
| Cientos de Pods `Completed` acumulados | Sin limpieza | `ttlSecondsAfterFinished` |
| La tarea se ejecutó dos veces | Reintento tras un fallo parcial | Diseñar la tarea **idempotente** |
| Job "colgado" para siempre | Sin tiempo máximo | `activeDeadlineSeconds` |

---

## 6. Lo que debe saber el arquitecto

- **Idempotencia obligatoria:** Kubernetes garantiza "al menos una vez", no "exactamente una vez". Un Job que debita cuentas debe poder ejecutarse dos veces sin duplicar el débito (llaves de idempotencia, marcas de procesado).
- **Batch en Kubernetes vs. servicios dedicados:** para procesos batch críticos con dependencias complejas, evalúa orquestadores (Argo Workflows, Airflow) o servicios gestionados (AWS Batch, Azure Batch, Cloud Batch).
- Los Jobs **compiten por recursos** con los servicios en línea: usa node pools o `PriorityClass` más baja para que el batch no afecte la atención a clientes.
- Logs y resultados deben salir del Pod (sistema central de logs, almacenamiento de objetos): el Pod se borra.

---

## 7. Checklist junior → senior

- [ ] **Junior:** ejecuto un Job y leo sus logs y estado.
- [ ] **Semi-senior:** uso `completions`, `parallelism`, `backoffLimit` y limpieza automática.
- [ ] **Senior:** diseño procesos batch idempotentes, con prioridades y observabilidad.

---

← [19 · Probes](19-probes.md) · [Índice](../README.md) · Siguiente → [21 · CronJobs](21-cronjobs.md)
