# 16 · StatefulSet

> **En una frase:** El StatefulSet ejecuta aplicaciones **con estado** (bases de datos, colas, clústeres) donde cada réplica necesita **nombre fijo, disco propio y orden de arranque**.
>
> **Analogía (contar manzanas):** En un Deployment los cajeros son intercambiables. En un StatefulSet son **los tesoreros de la bóveda**: tesorero-0, tesorero-1, tesorero-2. Cada uno tiene **su propia caja fuerte numerada** que nadie más usa. Si tesorero-1 se enferma, entra un reemplazo que **se llama igual y recibe la misma caja**.

---

## 1. Problema → solución

| Problema | Por qué un Deployment no sirve | Lo que da el StatefulSet |
| --- | --- | --- |
| Cada réplica necesita **su propio** disco | Todas las réplicas comparten el mismo PVC | `volumeClaimTemplates`: un PVC por réplica |
| El primario debe ser siempre "db-0" | Nombres aleatorios (`web-7c9d8-x2kqp`) | Nombres estables: `db-0`, `db-1`… |
| Las réplicas se buscan por nombre | IP y nombre cambian | DNS estable por Pod vía Service *headless* |
| El primario debe arrancar antes que las réplicas | Arranque en paralelo | Arranque y apagado **ordenados** |

---

## 2. Cómo funciona

```text
 Service headless "postgres" (clusterIP: None)
   ├── postgres-0.postgres.credito-dev.svc.cluster.local ─► Pod postgres-0 ─► PVC datos-postgres-0
   ├── postgres-1.postgres.credito-dev.svc.cluster.local ─► Pod postgres-1 ─► PVC datos-postgres-1
   └── postgres-2.postgres.credito-dev.svc.cluster.local ─► Pod postgres-2 ─► PVC datos-postgres-2

 Crea:  0 → 1 → 2   (espera a que el anterior esté Ready)
 Borra: 2 → 1 → 0
```

> Al borrar o escalar hacia abajo un StatefulSet, **sus PVCs no se borran** (protección de datos), salvo que configures `persistentVolumeClaimRetentionPolicy`.

---

## 3. Manifiesto comentado (Postgres de laboratorio)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  clusterIP: None                 # headless: DNS por Pod, sin balanceo
  selector:
    app: postgres
  ports:
    - port: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres           # el Service headless que da los nombres DNS
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_PASSWORD
              value: "solo-laboratorio"     # en real: Secret (tema 14)
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: datos
              mountPath: /var/lib/postgresql/data
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "postgres"]
  volumeClaimTemplates:           # un PVC NUEVO por cada réplica
    - metadata:
        name: datos
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 1Gi
```

---

## 4. Práctica en Minikube

```sh
kubectl apply -f statefulset.yaml
kubectl get sts,pods,pvc -l app=postgres       # postgres-0 y PVC datos-postgres-0

# Identidad estable: borrar el Pod y ver que vuelve con el mismo nombre y disco
kubectl exec postgres-0 -- psql -U postgres -c "CREATE TABLE prueba(id int);"
kubectl delete pod postgres-0
kubectl get pods -w
kubectl exec postgres-0 -- psql -U postgres -c "\dt"    # la tabla sigue ahí

# DNS por Pod
kubectl run tmp --rm -it --image=busybox:1.36 -- nslookup postgres-0.postgres

kubectl scale sts postgres --replicas=3        # crea postgres-1 y postgres-2, en orden
kubectl delete sts postgres                    # los PVC quedan; bórralos a mano si quieres
kubectl delete pvc -l app=postgres
```

> Escalar a 3 réplicas **no crea replicación de datos**: son 3 Postgres independientes. La replicación primario/réplica la configura la propia base de datos o un *operator*.

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `postgres-1` no arranca | `postgres-0` no está Ready (arranque ordenado) | Revisar el Pod 0; o `podManagementPolicy: Parallel` si no importa el orden |
| Datos "viejos" al recrear | Los PVC se conservan | Es lo esperado; borrar PVC para empezar de cero |
| Pod no se mueve de nodo | Su disco RWO está atado a una zona | Diseño multi-zona / almacenamiento replicado |
| Quise cambiar `volumeClaimTemplates` | Es inmutable | Recrear con `--cascade=orphan` o migración planificada |

---

## 6. Lo que debe saber el arquitecto

- **StatefulSet no es una base de datos administrada.** Respaldos, *failover*, replicación, actualizaciones de versión y *tuning* son tuyos. Por eso existen los **Operators** (CloudNativePG, Strimzi para Kafka, operadores de Redis/MongoDB), que codifican ese conocimiento.
- **Decisión clave en banca:** base de datos transaccional en **servicio gestionado** (RDS/Aurora, Azure Database for PostgreSQL, Cloud SQL) salvo razón fuerte. StatefulSet para componentes donde el *operator* es maduro o el dato es reconstruible (cachés, colas en entornos de prueba).
- Planifica **RPO/RTO**, *snapshots* y pruebas de restauración: un respaldo que nunca se restauró no es un respaldo.

---

## 7. Checklist junior → senior

- [ ] **Junior:** levanto Postgres en un StatefulSet y compruebo nombre y disco estables.
- [ ] **Semi-senior:** entiendo Service headless, `volumeClaimTemplates` y el orden de arranque.
- [ ] **Senior:** decido StatefulSet + Operator vs. servicio gestionado, con respaldo, alta disponibilidad y RPO/RTO.

---

← [15 · Requests y limits](15-requests-y-limits.md) · [Índice](../README.md) · Siguiente → [17 · Clúster multinodo y affinity](17-cluster-multinodo-y-affinity.md)
