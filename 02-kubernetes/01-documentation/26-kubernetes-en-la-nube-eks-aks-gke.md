# 26 · Kubernetes en la nube: EKS (AWS), AKS (Azure) y GKE (Google Cloud)

> **En una frase:** Los tres proveedores te dan el **mismo Kubernetes** (los mismos manifiestos de los temas 01-25), pero cada uno **administra el control plane** por ti y conecta el clúster con **sus** servicios de red, discos, identidad, secretos y monitoreo.
>
> **Analogía (contar manzanas):** Minikube es la maqueta del banco en tu escritorio. EKS, AKS y GKE son **tres constructoras** que te entregan el edificio real. Las reglas del banco (los manifiestos) son las mismas; lo que cambia es **de qué marca son las puertas, las bóvedas y las cámaras de seguridad**.

---

## 1. ¿Qué te gestiona la nube y qué sigue siendo tuyo?

```text
                         Minikube        Kubernetes gestionado (EKS / AKS / GKE)
 Control plane + etcd    tú              PROVEEDOR (alta disponibilidad, parches, respaldo de etcd)
 Nodos (worker)          tú              tú (o el proveedor en modos automáticos: Auto Mode / Automatic / Autopilot)
 Versión y upgrades      tú              tú decides cuándo; el proveedor fuerza al terminar el soporte
 Manifiestos y apps      tú              TÚ
 Seguridad de las apps   tú              TÚ (RBAC, NetworkPolicy, imágenes, secretos)
```

**Responsabilidad compartida:** la nube cuida el clúster; **tú cuidas lo que corre dentro**.

---

## 2. Vista general

| Aspecto | AWS · **EKS** | Azure · **AKS** | Google Cloud · **GKE** |
| --- | --- | --- | --- |
| Modos de nodos | Managed node groups, self-managed, **Fargate** (serverless), **EKS Auto Mode** | Node pools (system / user), virtual nodes, **AKS Automatic** | **Standard** (tú gestionas nodos) y **Autopilot** (Google gestiona nodos) |
| Costo del control plane | Cargo por hora por clúster | Nivel *Free* (sin SLA) y *Standard/Premium* (con SLA) | Cargo por hora por clúster (con crédito gratuito limitado) |
| Red de Pods | Amazon VPC CNI: los Pods usan IPs de la VPC | Azure CNI (overlay o IPs de la VNet) | VPC-native; Dataplane V2 (eBPF, basado en Cilium) |
| Identidad de personas | IAM + *access entries* | Microsoft Entra ID + RBAC de Azure | Google Cloud IAM |
| Registro de imágenes | ECR | ACR | Artifact Registry |

> Los precios y nombres de niveles cambian: verifícalos en la página oficial de cada proveedor antes de un caso de negocio.

---

## 3. Mapeo tema por tema (el mismo orden del curso)

### 3.1 Clúster y configuración (temas 01-02)

| Concepto | Minikube | EKS | AKS | GKE |
| --- | --- | --- | --- | --- |
| Crear clúster | `minikube start` | `eksctl create cluster`, Terraform, consola | `az aks create`, Terraform, Bicep | `gcloud container clusters create(-auto)`, Terraform |
| Obtener credenciales `kubectl` | automático | `aws eks update-kubeconfig` | `az aks get-credentials` | `gcloud container clusters get-credentials` |
| Varios clústeres | perfiles | un clúster por cuenta/entorno | uno por suscripción/entorno | uno por proyecto/entorno |
| Multinodo / grupos de nodos (tema 17) | `--nodes` | node groups | node pools | node pools |
| Zonas de disponibilidad | simuladas con labels | subredes en varias AZ | `--zones 1 2 3` | clúster **regional** |

### 3.2 Manifiestos y objetos básicos (temas 03-11)

Pods, labels, ReplicaSets, Namespaces, Deployments y probes **funcionan igual** en las tres nubes. Lo que cambia es el ecosistema alrededor:

| Concepto | EKS | AKS | GKE |
| --- | --- | --- | --- |
| GitOps (tema 03) | Argo CD / Flux (instalación propia o como add-on) | Extensión **Flux (GitOps)** de AKS | **Config Sync** / Argo CD / Flux |
| Multitenencia (tema 09) | Namespaces + IAM + políticas | Namespaces + Entra ID + Azure Policy | Namespaces + IAM + Policy Controller |
| HPA (tema 11) | metrics-server (se instala como add-on) | incluido | incluido |
| Escalado de nodos (tema 11) | Cluster Autoscaler, **Karpenter**, Auto Mode | Cluster Autoscaler, Node Auto Provisioning | Cluster Autoscaler, node auto-provisioning, Autopilot |
| Escalar por eventos | KEDA | **KEDA como add-on** | KEDA |

### 3.3 Services y exposición (tema 10)

| `type` del Service | EKS | AKS | GKE |
| --- | --- | --- | --- |
| `LoadBalancer` | **NLB** (con AWS Load Balancer Controller) | **Azure Load Balancer** | **Cloud Load Balancing** (L4) |
| Balanceador interno (annotation, tema 22) | `service.beta.kubernetes.io/aws-load-balancer-scheme: internal` | `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` | `networking.gke.io/load-balancer-type: "Internal"` |

### 3.4 Almacenamiento (temas 12 y 16)

| Necesidad | EKS | AKS | GKE |
| --- | --- | --- | --- |
| Disco de bloque RWO (StatefulSet) | **EBS** (CSI `ebs.csi.aws.com`) | **Azure Disk** (`disk.csi.azure.com`) | **Persistent Disk / Hyperdisk** (`pd.csi.storage.gke.io`) |
| Archivos compartidos RWX | **EFS** | **Azure Files** | **Filestore** |
| Snapshots / backup | EBS snapshots, AWS Backup, Velero | Azure Backup para AKS, Velero | Backup for GKE, Velero |
| Base de datos gestionada (alternativa al StatefulSet) | RDS / Aurora | Azure Database for PostgreSQL | Cloud SQL / AlloyDB |

### 3.5 Configuración, secretos e identidad (temas 13-14)

| Necesidad | EKS | AKS | GKE |
| --- | --- | --- | --- |
| Gestor de secretos | **Secrets Manager** / Parameter Store | **Key Vault** | **Secret Manager** |
| Llevar secretos al Pod | Secrets Store CSI Driver (proveedor AWS) o External Secrets Operator | Secrets Store CSI Driver (proveedor Azure Key Vault, add-on) | Add-on de Secret Manager o External Secrets Operator |
| Cifrar Secrets en etcd | KMS (cifrado de sobre) | KMS con Key Vault | Cifrado de secretos a nivel de aplicación con Cloud KMS |
| Permisos de nube para el Pod (sin llaves) | **EKS Pod Identity** / IRSA | **Microsoft Entra Workload ID** | **Workload Identity Federation for GKE** |

### 3.6 Recursos y costos (tema 15)

| Concepto | EKS | AKS | GKE |
| --- | --- | --- | --- |
| Qué pagas | Control plane + instancias EC2 (o Fargate por Pod) | Control plane (según nivel) + VMs | Control plane + VMs (Standard) o **por requests de Pod** (Autopilot) |
| Nodos baratos interrumpibles (batch, tema 20) | Spot Instances | Spot node pools | Spot VMs |
| Visibilidad de costos | Split cost allocation (CUR) + Kubecost | Análisis de costos de AKS | Asignación de costos de GKE |

> En **GKE Autopilot** y **EKS Fargate** pagas por lo que pides en `requests`: el tema 15 se vuelve directamente una línea de la factura.

### 3.7 Ubicación y DaemonSets (temas 17-18)

| Concepto | EKS | AKS | GKE |
| --- | --- | --- | --- |
| Label de zona | `topology.kubernetes.io/zone` (estándar en las tres) | igual | igual |
| Nodos dedicados (taints) | node groups con taints | node pools con taints | node pools con taints |
| DaemonSets en modo serverless | **No** en Fargate | No en virtual nodes | Permitidos en Autopilot con restricciones |

### 3.8 Jobs y CronJobs (temas 20-21)

Funcionan igual. Alternativas gestionadas fuera del clúster: **AWS Batch / EventBridge Scheduler**, **Azure Batch / Container Apps Jobs**, **Cloud Batch / Cloud Run Jobs + Cloud Scheduler**.

### 3.9 Entrada HTTP: Ingress y Gateway (temas 22-24)

| Necesidad | EKS | AKS | GKE |
| --- | --- | --- | --- |
| Ingress nativo de la nube | **AWS Load Balancer Controller → ALB** (`ingressClassName: alb`) | **Application Gateway for Containers** / AGIC | **GKE Ingress → Cloud Load Balancing** (`gce`, `gce-internal`) |
| Gateway API | AWS Load Balancer Controller (soporte de Gateway API en versiones recientes), VPC Lattice | Application Gateway for Containers | **GKE Gateway controller** |
| NGINX gestionado | — (instalación propia) | Add-on *application routing* (NGINX gestionado; revisar su hoja de ruta tras el retiro de ingress-nginx) | — (instalación propia) |
| WAF delante | AWS WAF | Azure WAF / Front Door | Cloud Armor |
| Certificados | AWS Certificate Manager | Key Vault / cert-manager | Certificate Manager / certificados gestionados por Google |

### 3.10 Observabilidad (transversal)

| Señal | EKS | AKS | GKE |
| --- | --- | --- | --- |
| Logs y métricas | CloudWatch Container Insights | Azure Monitor Container Insights | Cloud Logging / Cloud Monitoring |
| Prometheus gestionado | Amazon Managed Service for Prometheus | Azure Monitor managed Prometheus | Google Cloud Managed Service for Prometheus |
| Grafana gestionado | Amazon Managed Grafana | Azure Managed Grafana | (Grafana propio / Cloud Monitoring) |

---

## 4. ¿Qué cambia cuando pasas de Minikube a la nube?

| En Minikube haces… | En la nube haces… |
| --- | --- |
| `minikube image load` | Publicar en ECR / ACR / Artifact Registry y referenciar por digest |
| `minikube addons enable ingress` | Instalar el controlador de la nube o Gateway API |
| `minikube tunnel` para LoadBalancer | El balanceador real se crea solo (y se cobra) |
| StorageClass `standard` (carpeta del nodo) | StorageClass con discos cifrados de la nube |
| Secret con `stringData` | Gestor de secretos + identidad de carga de trabajo |
| Un nodo | Node pools en 3 zonas con autoescalado |
| `kubectl apply` desde la laptop | Pipeline / GitOps con aprobaciones |

---

## 5. ¿Cómo elegir? (criterios de arquitecto)

1. **Dónde ya está la organización:** identidad corporativa, red, contratos y equipo. Si la empresa vive en Microsoft 365/Entra ID, AKS integra mejor; si la data y los servicios están en AWS, EKS; si hay apuesta por analítica/IA en Google, GKE.
2. **Cuánta operación quieres asumir:** GKE Autopilot, AKS Automatic y EKS Auto Mode reducen el trabajo de nodos a cambio de menos control.
3. **Regulación y residencia de datos:** región disponible en el país o cercana, certificaciones (PCI DSS, ISO 27001, SOC 2) y conectividad privada con el *datacenter* (Direct Connect / ExpressRoute / Cloud Interconnect).
4. **Portabilidad:** mantén los manifiestos estándar (temas 03-25) y aísla lo específico de la nube (annotations, StorageClass, IngressClass, identidad) en *overlays* por proveedor. Así migrar o tener multinube es un cambio de configuración, no de aplicación.

---

## 6. Checklist junior → senior

- [ ] **Junior:** explico qué gestiona la nube y qué sigue siendo mío en EKS/AKS/GKE.
- [ ] **Semi-senior:** traduzco Service LoadBalancer, StorageClass, Ingress y secretos a los servicios de cada nube.
- [ ] **Senior:** elijo proveedor y modo de operación con criterios de negocio, regulación, costo y portabilidad.

---

← [25 · Edit y patch](25-edit-y-patch.md) · [Índice](../README.md)
