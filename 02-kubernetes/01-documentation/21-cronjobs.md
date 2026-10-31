# 21 · CronJobs

> **En una frase:** Un CronJob crea **Jobs según un horario** (sintaxis *cron*), como el `crontab` de Linux pero dentro del clúster.
>
> **Analogía (contar manzanas):** Es la **alarma del cierre contable**: "todos los días a las 23:00 llama a un auditor (Job) para contar las manzanas del día". El CronJob no cuenta nada: solo **agenda** al auditor.

---

## 1. Problema → solución

| Problema | CronJob |
| --- | --- |
| Cierre diario, conciliación, reportes nocturnos | `schedule: "0 23 * * *"` |
| Limpiar datos o archivos temporales cada hora | `schedule: "0 * * * *"` |
| Respaldos programados | CronJob que ejecuta el respaldo |
| Que dos ejecuciones no se pisen | `concurrencyPolicy: Forbid` |

---

## 2. Sintaxis cron

```text
 ┌───────── minuto (0-59)
 │ ┌─────── hora (0-23)
 │ │ ┌───── día del mes (1-31)
 │ │ │ ┌─── mes (1-12)
 │ │ │ │ ┌─ día de la semana (0-6, 0 = domingo)
 │ │ │ │ │
 * * * * *
```

| Expresión | Significado |
| --- | --- |
| `*/5 * * * *` | Cada 5 minutos |
| `0 23 * * *` | Todos los días a las 23:00 |
| `0 6 * * 1-5` | Lunes a viernes a las 06:00 |
| `0 0 1 * *` | El día 1 de cada mes a medianoche |

Por defecto el horario es el del **controlador (normalmente UTC)**. Usa `timeZone` para fijarlo explícitamente.

---

## 3. Manifiesto comentado

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cierre-diario
spec:
  schedule: "*/2 * * * *"             # cada 2 min (para practicar); real: "0 23 * * *"
  timeZone: "America/Guayaquil"
  concurrencyPolicy: Forbid           # Allow | Forbid | Replace
  startingDeadlineSeconds: 120        # si se perdió el horario más de 2 min, no lo ejecuta tarde
  successfulJobsHistoryLimit: 3       # Jobs exitosos que se conservan
  failedJobsHistoryLimit: 5           # Jobs fallidos que se conservan (para investigar)
  suspend: false                      # true = pausar sin borrar
  jobTemplate:                        # el "molde" del Job (tema 20)
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: cierre
              image: busybox:1.36
              command: ["sh", "-c", "echo \"Cierre ejecutado: $(date)\""]
```

| `concurrencyPolicy` | Si la ejecución anterior sigue corriendo… |
| --- | --- |
| `Allow` (defecto) | Arranca otra en paralelo |
| `Forbid` | Se salta la nueva |
| `Replace` | Mata la anterior y arranca la nueva |

---

## 4. Práctica en Minikube

```sh
kubectl apply -f cronjob.yaml
kubectl get cronjobs                         # SCHEDULE, LAST SCHEDULE, ACTIVE
kubectl get jobs -w                          # aparece un Job cada 2 minutos
kubectl logs job/<nombre-del-job>          # nombre tomado de 'kubectl get jobs'

# Ejecutar ahora sin esperar el horario (muy útil para probar)
kubectl create job cierre-manual --from=cronjob/cierre-diario

# Pausar y reanudar
kubectl patch cronjob cierre-diario -p '{"spec":{"suspend":true}}'
kubectl patch cronjob cierre-diario -p '{"spec":{"suspend":false}}'

kubectl delete cronjob cierre-diario         # borra también sus Jobs
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| Se ejecuta 5 horas antes/después | Zona horaria UTC | `timeZone` |
| Ejecuciones duplicadas solapadas | `Allow` por defecto | `Forbid` |
| No queda rastro de fallos | Historial en 0 | `failedJobsHistoryLimit` |
| Se ejecutó una tanda "atrasada" tras una caída | Sin `startingDeadlineSeconds` | Definirlo según el negocio |

---

## 6. Lo que debe saber el arquitecto

- **Kubernetes no garantiza ejecución exacta:** en casos raros puede ejecutar dos veces o saltarse una. Igual que los Jobs: **idempotencia** y monitoreo de "¿se ejecutó el cierre de hoy?" (alerta si no).
- **Ventanas de negocio:** los procesos programados deben coordinarse con las ventanas operativas (cortes de core bancario, horarios de cámara de compensación).
- Para cadenas de procesos con dependencias ("A, luego B si A terminó bien") un CronJob no alcanza: orquestador de flujos.
- En nube, alternativa sin servidor: EventBridge Scheduler + Lambda/ECS (AWS), Logic Apps / Functions (Azure), Cloud Scheduler + Cloud Run Jobs (GCP).

---

## 7. Checklist junior → senior

- [ ] **Junior:** escribo expresiones cron y creo un CronJob.
- [ ] **Semi-senior:** controlo concurrencia, historial, zona horaria y ejecución manual.
- [ ] **Senior:** diseño procesos programados idempotentes, monitoreados y alineados con las ventanas de negocio.

---

← [20 · Jobs](20-jobs.md) · [Índice](../README.md) · Siguiente → [22 · Annotations](22-annotations.md)
