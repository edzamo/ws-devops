# 02 · Kubernetes con Minikube — lo que un arquitecto de soluciones debe saber

Resumen del curso: las **píldoras** de cada tema, la tabla de "problema → solución" y la ruta de junior a senior. El detalle (analogías, YAML comentados, práctica en Minikube, errores comunes) está en [01-documentation](01-documentation/).

> **Analogía de todo el curso:** Kubernetes es un **banco con sucursales**. El clúster es el banco; los **nodos** son las sucursales; los **Pods** son las ventanillas; los **contenedores** son los cajeros; el **control plane** es la gerencia que vigila que todo esté como se ordenó.

---

## 1. La idea madre (si solo recuerdas una cosa)

Kubernetes **no ejecuta órdenes: persigue un estado**.

```text
  Tú declaras (YAML en Git)      "quiero 3 manzanas"        ← spec   (estado deseado)
  Kubernetes observa             "hay 2"                     ← status (estado real)
  Kubernetes corrige             "creo 1"                    ← controlador
  ...y repite para siempre (bucle de reconciliación)
```

Todo lo demás (Deployments, StatefulSets, autoescalado, GitOps) es este mismo bucle aplicado a cosas distintas.

---

## 2. Mapa de cómo se conectan las piezas

```text
                  Internet
                     │
             [Ingress Controller] ◄── reglas: Ingress (host / ruta / TLS)
                     │
                 [Service]  ── IP y DNS fijos; elige Pods por LABELS (selector)
                     │
   [Deployment] ─► [ReplicaSet] ─► [Pod] [Pod] [Pod]   ← réplicas (escala horizontal)
                                    │
                    ┌───────────────┼──────────────────┐
               [ConfigMap]      [Secret]        [PVC] ─► [PV] ─► disco real
                configuración   credenciales     datos persistentes

  Otros controladores:  StatefulSet (con estado) · DaemonSet (uno por nodo)
                        Job (una vez) · CronJob (con horario)
  Todo vive dentro de un Namespace, con requests/limits, probes y reglas de ubicación.
```

---

## 3. Índice del temario

| # | Tema | En una frase | Documento |
| --- | --- | --- | --- |
| 01 | Presentación de Minikube y clúster local | Un clúster real en miniatura en tu laptop; control plane + nodos | [01](01-documentation/01-minikube-presentacion-y-cluster-local.md) |
| 02 | Configuración y multiclúster con perfiles | CPU, memoria, versión y addons; varios clústeres con `-p` | [02](01-documentation/02-minikube-configuracion-y-perfiles.md) |
| 03 | Manifiesto vs. comandos · configuración declarativa | Imperativo para mirar; declarativo (`apply` + Git) para cambiar | [03](01-documentation/03-manifiesto-vs-comandos-y-declarativo.md) |
| 04 | Pods | La unidad mínima: contenedores que comparten IP y volúmenes | [04](01-documentation/04-pods.md) |
| 05 | Metadata, labels y selectores | Gafetes y filtros: así se conectan los objetos | [05](01-documentation/05-metadata-labels-selectores.md) |
| 06 | Reinicio de Pod y exec | Un Pod no se repara, se reemplaza; `exec` para entrar | [06](01-documentation/06-pods-reinicio-y-exec.md) |
| 07 | ReplicationController | El primer "mantén N copias" (obsoleto) | [07](01-documentation/07-replication-controller.md) |
| 08 | ReplicaSet | N copias con selectores potentes; lo gestiona el Deployment | [08](01-documentation/08-replicaset.md) |
| 09 | Namespaces | Pisos del edificio: nombres, cuotas, permisos y red por grupo | [09](01-documentation/09-namespaces.md) |
| 10 | Services | Dirección fija + balanceo hacia Pods que cambian | [10](01-documentation/10-services.md) |
| 11 | Deploys y Deployments | Versiones sin corte, rollback y escalado (HPA) | [11](01-documentation/11-deployments.md) |
| 12 | Volúmenes | Datos que sobreviven al contenedor: PVC, PV, StorageClass | [12](01-documentation/12-volumenes.md) |
| 13 | ConfigMaps | Configuración fuera de la imagen: una imagen, muchos entornos | [13](01-documentation/13-configmaps.md) |
| 14 | Secrets | Datos sensibles; base64 **no** es cifrado | [14](01-documentation/14-secrets.md) |
| 15 | Requests y limits | Garantizado vs. máximo; OOMKilled y throttling | [15](01-documentation/15-requests-y-limits.md) |
| 16 | StatefulSet | Réplicas con nombre, disco y orden propios (bases de datos) | [16](01-documentation/16-statefulset.md) |
| 17 | Clúster multinodo, Pod affinity y anti-affinity | Dónde va cada Pod: juntos, separados, en nodos dedicados | [17](01-documentation/17-cluster-multinodo-y-affinity.md) |
| 18 | DaemonSet | Un Pod por nodo (logs, métricas, seguridad) | [18](01-documentation/18-daemonset.md) |
| 19 | Probes | ¿Arrancó? ¿Está vivo? ¿Está listo para atender? | [19](01-documentation/19-probes.md) |
| 20 | Jobs | Tareas que terminan, con reintentos | [20](01-documentation/20-jobs.md) |
| 21 | CronJobs | Jobs con horario | [21](01-documentation/21-cronjobs.md) |
| 22 | Annotations | Post-its que describen y configuran herramientas | [22](01-documentation/22-annotations.md) |
| 23 | NGINX Ingress Controller | La recepción única del tráfico HTTP (y su retiro en 2026) | [23](01-documentation/23-ingress-controller-nginx.md) |
| 24 | Ingress rules | El directorio: dominio + ruta → Service, con TLS | [24](01-documentation/24-ingress-rules.md) |
| 25 | Edit y patch | Cambios directos al clúster: útiles, pero generan *drift* | [25](01-documentation/25-edit-y-patch.md) |
| 26 | Kubernetes en la nube: EKS, AKS, GKE | Lo mismo en AWS, Azure y Google, tema por tema | [26](01-documentation/26-kubernetes-en-la-nube-eks-aks-gke.md) |

---

## 4. Píldoras por bloque

### Bloque A · Plataforma y forma de trabajo (01-03)

- **Control plane = gerencia; nodos = sucursales.** En la nube el control plane lo gestiona el proveedor; los nodos y las apps siguen siendo tu responsabilidad.
- **Minikube valida manifiestos y comportamiento**, no rendimiento ni alta disponibilidad. Usa la **misma versión de Kubernetes** que producción.
- **Perfil (Minikube) ≠ contexto (kubectl).** Revisa siempre `kubectl config current-context`: el contexto equivocado es la forma más rápida de romper producción.
- **Declarativo siempre:** YAML en Git → revisión → pipeline/GitOps → clúster. Imperativo solo para leer y diagnosticar.
- Todo manifiesto tiene 4 partes: `apiVersion`, `kind`, `metadata`, `spec`. Kubernetes escribe el `status`.

### Bloque B · Cargas de trabajo (04, 06-08, 11, 16, 18, 20-21)

- **El Pod es desechable**: su IP cambia; nunca se crean Pods sueltos en producción.
- **Un Pod no se reinicia, se reemplaza.** Reinicio ordenado: `kubectl rollout restart`.
- **ReplicationController → ReplicaSet → Deployment**: misma idea (N réplicas), cada vez más capacidades. Hoy escribes **Deployments**.
- **¿Qué controlador uso?**

```text
 ¿La tarea termina?
 ├── Sí ──► ¿Tiene horario? ── Sí ──► CronJob
 │                         └─ No ──► Job
 └── No (corre siempre)
     ├── ¿Una copia en CADA nodo? ──────────────► DaemonSet
     ├── ¿Cada réplica necesita nombre/disco propio? ► StatefulSet
     └── Réplicas intercambiables (stateless) ──► Deployment  (el 80 % de los casos)
```

- **Jobs y CronJobs deben ser idempotentes**: Kubernetes garantiza "al menos una vez".

### Bloque C · Organización (05, 09, 22)

- **Labels para seleccionar, annotations para describir.** Los selectores son el pegamento: Service → Pods, Deployment → Pods.
- **La taxonomía de labels es una decisión de arquitectura** (sistema, componente, entorno, dueño, criticidad): alimenta costos, seguridad y observabilidad.
- **Namespace = límite blando** (equipos de la misma organización). Aislamiento fuerte (PCI, clientes, producción) = **clústeres separados**.
- Kit de todo namespace productivo: ResourceQuota, LimitRange, RBAC, NetworkPolicy "denegar todo" y Pod Security.

### Bloque D · Red y exposición (10, 23, 24)

- **Service = dirección fija + balanceo interno (capa 4).** ClusterIP por defecto; no publiques cada microservicio.
- **Ingress = enrutamiento HTTP (capa 7)** por dominio y ruta, con TLS, detrás de **un solo** balanceador.
- **Objeto Ingress ≠ Ingress Controller**: sin controlador, las reglas no hacen nada.
- **`ingress-nginx` comunitario fue retirado en marzo de 2026**: sirve para aprender; para diseños nuevos, **Gateway API** o un controlador mantenido.
- Delante de la entrada, en banca: **WAF** y, para APIs de terceros, **API Gateway**.

### Bloque E · Configuración y datos (12-14)

- **Una imagen, muchas configuraciones** (ConfigMap por entorno). La imagen que se escaneó es la que llega a producción.
- Cambios de ConfigMap consumidos como variables **requieren reinicio**.
- **base64 no es cifrado.** La fuente de verdad del secreto vive en un gestor (Secrets Manager, Key Vault, Secret Manager, Vault) y llega al Pod con External Secrets / CSI; el Pod se autentica con **identidad de carga de trabajo**, sin llaves.
- **PVC = solicitud; PV = disco; StorageClass = catálogo.** Discos de bloque son RWO y zonales.
- **Kubernetes no es backup.** Y la base de datos transaccional, en banca, suele ir a un **servicio gestionado** fuera del clúster.

### Bloque F · Recursos, resiliencia y ubicación (15, 17, 19)

- **Requests = garantizado y facturado; limits = techo.** CPU de más → lentitud (throttling); memoria de más → **OOMKilled**.
- Sin requests no hay HPA ni dimensionamiento confiable.
- **Probes:** startup (¿arrancó?), liveness (¿vivo? → reinicia), readiness (¿listo? → recibe tráfico). **Nunca chequees la base de datos en liveness.**
- **Alta disponibilidad real** = ≥ 2-3 réplicas + repartidas en nodos/zonas (anti-affinity / topologySpread) + PodDisruptionBudget + readiness.
- **Affinity atrae, taints repelen.** Nodos dedicados = taint + node affinity.

### Bloque G · Operación y cambios (06, 25)

- `exec`, `edit` y `patch` en producción son **cambios fuera de proceso**: restringidos por RBAC, auditados, y llevados a Git después.
- **Drift** = el clúster ya no coincide con Git. GitOps lo detecta y lo corrige.

---

## 5. Problema → solución (la tabla del arquitecto)

| Síntoma / necesidad de negocio | Qué usar | Tema |
| --- | --- | --- |
| Más usuarios, la CPU de los Pods sube, la latencia empeora | **Escala horizontal**: más réplicas / **HPA** | 11 |
| Un Pod muere por memoria con carga normal | **Escala vertical**: ajustar requests/limits / VPA | 15 |
| HPA quiere más réplicas pero quedan `Pending` | Más nodos: **Cluster Autoscaler / Karpenter** | 11, 26 |
| Picos por mensajes en cola | **KEDA** (escalar por eventos) | 11 |
| El cuello de botella es la base de datos | Escalar la app no sirve: réplicas de lectura, caché, BD gestionada | 12, 16 |
| Si un servidor cae, se cae el servicio | Réplicas + anti-affinity/topologySpread por zona + PDB | 11, 17 |
| Errores 5xx en cada despliegue | Readiness probe + rolling update + apagado ordenado | 11, 19 |
| Una versión nueva salió mal | `rollout undo` / canary | 11 |
| Un equipo consume todo el clúster | ResourceQuota + LimitRange por namespace | 09, 15 |
| Las IPs cambian y los servicios no se encuentran | Service + DNS interno | 10 |
| Exponer 10 APIs sin pagar 10 balanceadores | Un Ingress Controller / Gateway + reglas | 23, 24 |
| Misma app en dev, qa y prod | ConfigMaps por entorno + Kustomize/Helm | 13, 03 |
| Contraseñas en el código o en Git | Gestor de secretos + External Secrets + Workload Identity | 14 |
| La base de datos pierde datos al reiniciar | PVC + StorageClass (o servicio gestionado) | 12, 16 |
| Logs/métricas en todos los nodos | DaemonSet | 18 |
| La app se cuelga y nadie la reinicia | Liveness probe | 19 |
| Proceso nocturno / cierre diario | CronJob → Job idempotente | 20, 21 |
| Cargas sensibles separadas (PCI, GPU) | Node pool dedicado: taints + node affinity | 17 |
| "Alguien cambió algo en producción a mano" | Declarativo + GitOps + RBAC restrictivo | 03, 25 |

### Horizontal vs. vertical en una imagen

```text
 VERTICAL: un cajero más fuerte          HORIZONTAL: más cajeros iguales
 (más CPU/RAM al Pod)                     (más réplicas)
 + simple                                 + casi sin techo, tolera fallos
 − tiene techo, suele reiniciar           − exige app sin estado (stateless)
 Herramienta: requests/limits, VPA        Herramienta: replicas, HPA, KEDA
```

---

## 6. Ruta de aprendizaje junior → senior

| Nivel | Debe poder… |
| --- | --- |
| **Junior** | Levantar Minikube; escribir y aplicar Pods, Deployments, Services, ConfigMaps y Secrets; leer `get`, `describe`, `logs`; hacer rollback |
| **Semi-senior** | Diagnosticar `Pending`, `CrashLoopBackOff`, `ImagePullBackOff`, `OOMKilled` y Services sin endpoints; configurar probes, requests/limits, HPA, PVC, StatefulSet, Ingress con TLS, affinity y taints |
| **Senior / arquitecto** | Diseñar la plataforma: clústeres por entorno, namespaces y multitenencia, alta disponibilidad multi-zona, estrategia de despliegue (GitOps, canary), secretos con identidad de carga de trabajo, entrada (Gateway API, WAF, API Gateway), datos (gestionado vs. StatefulSet), costos y elección de nube |

---

## 7. Chuleta de comandos

```sh
# Contexto y clúster
kubectl config current-context        kubectl get nodes -o wide
minikube start -p <perfil>            minikube profile list

# Ver y diagnosticar (en este orden ante un problema)
kubectl get pods -o wide              kubectl describe pod <pod>      # Events
kubectl logs <pod> [--previous]       kubectl get events --sort-by=.lastTimestamp
kubectl exec -it <pod> -- sh          kubectl top pods

# Aplicar y cambiar (declarativo)
kubectl apply -f <archivo|carpeta>    kubectl diff -f <archivo>
kubectl apply -f x.yaml --dry-run=server

# Despliegues
kubectl rollout status deploy/<d>     kubectl rollout undo deploy/<d>
kubectl rollout restart deploy/<d>    kubectl scale deploy/<d> --replicas=N

# Generar YAML sin escribirlo
kubectl create deployment web --image=nginx:1.27 --dry-run=client -o yaml
kubectl explain deployment.spec.strategy
```

---

## 8. Relación con las nubes (resumen; detalle en el [tema 26](01-documentation/26-kubernetes-en-la-nube-eks-aks-gke.md))

| Concepto del curso | AWS · EKS | Azure · AKS | Google Cloud · GKE |
| --- | --- | --- | --- |
| Clúster gestionado | EKS (Auto Mode, Fargate) | AKS (Automatic) | GKE (Standard, Autopilot) |
| Service `LoadBalancer` | NLB | Azure Load Balancer | Cloud Load Balancing |
| Ingress / Gateway | AWS Load Balancer Controller → ALB | Application Gateway for Containers | GKE Ingress / GKE Gateway |
| Disco RWO / archivos RWX | EBS / EFS | Azure Disk / Azure Files | Persistent Disk / Filestore |
| Secretos | Secrets Manager | Key Vault | Secret Manager |
| Identidad del Pod | EKS Pod Identity / IRSA | Entra Workload ID | Workload Identity Federation |
| Registro de imágenes | ECR | ACR | Artifact Registry |
| Escalado de nodos | Cluster Autoscaler / Karpenter | Cluster Autoscaler / Node Auto Provisioning | Cluster Autoscaler / Autopilot |
| WAF | AWS WAF | Azure WAF | Cloud Armor |

**Regla de portabilidad:** los manifiestos estándar (temas 03-25) son iguales en las tres nubes; lo específico (annotations, StorageClass, IngressClass, identidad) se aísla en *overlays* por proveedor.

---

## 9. Anti-patrones que un arquitecto debe frenar

| Anti-patrón | Por qué es malo | Alternativa |
| --- | --- | --- |
| `image: app:latest` | No sabes qué versión corre; rollback imposible | Tag fijo o digest `@sha256:` |
| Pods sin requests/limits | Vecinos ruidosos, sin autoescalado, costos opacos | Recursos obligatorios + LimitRange |
| Sin readiness probe | Errores en cada despliegue | Probes obligatorias |
| 1 réplica en producción | Cualquier mantenimiento es una caída | ≥ 2-3 réplicas + PDB |
| Secretos en Git o ConfigMaps | Fuga de credenciales | Gestor de secretos + External Secrets |
| `kubectl edit` en producción | Drift y cambios sin auditoría | Git + GitOps |
| Un LoadBalancer por microservicio | Costo y superficie de ataque | Ingress / Gateway único |
| Todo en `default` | Sin cuotas, permisos ni orden | Namespaces con su kit |

---

## 10. Estructura de la carpeta

```text
02-kubernetes/
├── README.md               ← este resumen
├── 01-documentation/       ← un documento por tema (01-26)
└── 02-laboratorios/        ← ejercicios prácticos, de junior a senior (ver su README)
```

**Siguiente paso:** laboratorio de Minikube con `poc-credit-evaluation` (Angular + 2 Quarkus + Postgres): Deployments, Services, ConfigMap, Secret, StatefulSet con PVC, probes en `/q/health` e Ingress.
