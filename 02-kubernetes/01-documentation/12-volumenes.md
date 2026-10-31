# 12 · Volúmenes (Volume, PersistentVolume, PersistentVolumeClaim, StorageClass)

> **En una frase:** El disco de un contenedor **se borra cuando el contenedor muere**; los volúmenes dan almacenamiento que sobrevive al contenedor (y, si es persistente, también al Pod).
>
> **Analogía (contar manzanas):** El contenedor es un cajero que anota en una **pizarra**: si se va, se borra. Un **volumen** es un **archivador**:
> - `emptyDir` = archivador de la ventanilla: dura mientras exista la ventanilla.
> - **PersistentVolume (PV)** = un archivador real en la bodega del banco.
> - **PersistentVolumeClaim (PVC)** = el **formulario de solicitud**: "necesito un archivador de 10 GB".
> - **StorageClass** = el **catálogo** de archivadores (rápido, económico, cifrado) y el proveedor que los fabrica bajo demanda.

---

## 1. Problema → solución

| Problema | Solución |
| --- | --- |
| Dos contenedores del mismo Pod comparten archivos | `emptyDir` |
| Montar configuración o secretos como archivos | Volumen `configMap` / `secret` (temas 13-14) |
| Los datos deben sobrevivir al Pod (base de datos, archivos subidos) | **PVC** + StorageClass |
| No quiero que alguien cree discos a mano | Aprovisionamiento **dinámico** (StorageClass) |
| Varios Pods escriben los mismos archivos | Almacenamiento `ReadWriteMany` (NFS, EFS, Azure Files, Filestore) |

---

## 2. Tipos de volumen

| Tipo | Vida | Uso |
| --- | --- | --- |
| `emptyDir` | Mientras vive el Pod | Caché, archivos temporales, compartir entre contenedores |
| `hostPath` | Atado a **un nodo** | Solo laboratorios o DaemonSets de sistema (riesgo de seguridad) |
| `configMap` / `secret` | Proyecta datos como archivos | Configuración |
| `persistentVolumeClaim` | Independiente del Pod | Datos de negocio |
| CSI (EBS, Azure Disk, PD, EFS…) | Disco real de la nube | Producción |

---

## 3. Cómo se conectan PV, PVC y StorageClass

```text
  Pod ──usa──► PVC "datos" (pido 1Gi, RWO, clase standard)
                 │  se "enlaza" (Bound)
                 ▼
               PV  pvc-3f2a...  (1Gi)  ◄── lo crea automáticamente el aprovisionador
                 │                         de la StorageClass "standard"
                 ▼
            Disco real (en Minikube: carpeta del nodo; en nube: EBS / Azure Disk / PD)
```

- **Estático:** un administrador crea PVs; los PVCs se enlazan a uno compatible.
- **Dinámico (lo normal):** el PVC nombra una StorageClass y el PV se crea solo.

### Modos de acceso

| Modo | Significado |
| --- | --- |
| `ReadWriteOnce` (RWO) | Lectura/escritura desde **un nodo** (discos de bloque: EBS, Azure Disk, PD) |
| `ReadOnlyMany` (ROX) | Solo lectura desde muchos nodos |
| `ReadWriteMany` (RWX) | Lectura/escritura desde muchos nodos (sistemas de archivos de red) |
| `ReadWriteOncePod` (RWOP) | Un solo Pod en todo el clúster |

### ¿Qué pasa con el disco al borrar el PVC? (`reclaimPolicy`)

| Política | Efecto |
| --- | --- |
| `Delete` | Se borra el disco (defecto en muchas clases) |
| `Retain` | El disco queda; hay que limpiarlo o reutilizarlo a mano (**recomendado para datos críticos**) |

---

## 4. Manifiestos

### emptyDir compartido

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: compartido
spec:
  containers:
    - name: escritor
      image: busybox:1.36
      command: ["sh", "-c", "while true; do date >> /datos/log.txt; sleep 5; done"]
      volumeMounts:
        - name: datos
          mountPath: /datos
    - name: lector
      image: busybox:1.36
      command: ["sh", "-c", "tail -f /datos/log.txt"]
      volumeMounts:
        - name: datos
          mountPath: /datos
  volumes:
    - name: datos
      emptyDir: {}
```

### PVC dinámico + Pod que lo usa

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: datos-app
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: standard        # la clase por defecto de Minikube
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: con-disco
spec:
  containers:
    - name: app
      image: nginx:1.27
      volumeMounts:
        - name: datos
          mountPath: /usr/share/nginx/html
  volumes:
    - name: datos
      persistentVolumeClaim:
        claimName: datos-app
```

### StorageClass (ejemplo conceptual para nube)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rapido-cifrado
provisioner: ebs.csi.aws.com          # AKS: disk.csi.azure.com · GKE: pd.csi.storage.gke.io
parameters:
  type: gp3
  encrypted: "true"
reclaimPolicy: Retain
allowVolumeExpansion: true            # permite agrandar el PVC después
volumeBindingMode: WaitForFirstConsumer   # crea el disco en la zona donde cae el Pod
```

---

## 5. Práctica en Minikube

```sh
kubectl get storageclass                        # "standard (default)"
kubectl apply -f pvc-pod.yaml
kubectl get pvc,pv                              # PVC Bound + PV creado solo

# Probar que los datos sobreviven al Pod
kubectl exec con-disco -- sh -c 'echo "persistente" > /usr/share/nginx/html/index.html'
kubectl delete pod con-disco
kubectl apply -f pvc-pod.yaml
kubectl exec con-disco -- cat /usr/share/nginx/html/index.html   # → persistente

kubectl delete pod con-disco && kubectl delete pvc datos-app     # con Delete, el PV también se va
```

---

## 6. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| PVC en `Pending` | No hay StorageClass o no existe la indicada | `kubectl get sc`; `describe pvc` |
| Pod `Pending`: *volume node affinity conflict* | El disco está en otra zona/nodo | `WaitForFirstConsumer`; repartir por zona |
| `Multi-Attach error` | Disco RWO usado por Pods en nodos distintos | RWX o un solo Pod (StatefulSet) |
| Perdí los datos al borrar el PVC | `reclaimPolicy: Delete` | `Retain` + respaldos |

---

## 7. Lo que debe saber el arquitecto

- **Kubernetes no es un backup.** Un PV replicado no protege de borrados ni de *ransomware*: necesitas **snapshots** (`VolumeSnapshot`) y respaldos externos (Velero o los servicios de backup de la nube) con RPO/RTO definidos.
- **Datos en el clúster vs. servicio gestionado:** en banca, la base de datos transaccional suele ir **fuera** del clúster (RDS/Aurora, Azure SQL/PostgreSQL Flexible, Cloud SQL). Kubernetes se queda con las apps *stateless*. Esto reduce riesgo operativo.
- **Cifrado en reposo** obligatorio (StorageClass con cifrado y llaves gestionadas: KMS / Key Vault / Cloud KMS).
- Los discos de bloque son **zonales**: el diseño multi-zona debe considerarlo.

---

## 8. Checklist junior → senior

- [ ] **Junior:** uso `emptyDir` y un PVC; compruebo que los datos sobreviven al Pod.
- [ ] **Semi-senior:** elijo modo de acceso, StorageClass y reclaimPolicy correctos.
- [ ] **Senior:** decido qué datos viven en el clúster y cuáles en servicios gestionados; defino respaldo, cifrado y RPO/RTO.

---

← [11 · Deployments](11-deployments.md) · [Índice](../README.md) · Siguiente → [13 · ConfigMaps](13-configmaps.md)
