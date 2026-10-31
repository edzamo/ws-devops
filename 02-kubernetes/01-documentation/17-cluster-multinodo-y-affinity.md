# 17 · Clúster multinodo, Pod affinity y anti-affinity

> **En una frase:** Con varios nodos puedes **decidir dónde se ubica cada Pod**: junto a ciertos Pods (*affinity*), lejos de otros (*anti-affinity*), en cierto tipo de nodo (*node affinity*) o fuera de nodos reservados (*taints*).
>
> **Analogía (contar manzanas):** El banco ahora tiene **3 sucursales** (nodos). Reglas de ubicación:
> - **nodeSelector / node affinity:** "este cajero solo trabaja en sucursales **con bóveda**".
> - **Pod affinity:** "el cajero de créditos se sienta **cerca** del analista de riesgos" (se comunican mucho).
> - **Pod anti-affinity:** "**no pongas** a los 3 cajeros de créditos en la misma sucursal; si esa sucursal cierra, nadie atiende".
> - **Taint / toleration:** "la sucursal VIP **no acepta** personal común, salvo quien tenga pase VIP".

---

## 1. Problema → solución

| Problema | Herramienta |
| --- | --- |
| Las 3 réplicas cayeron en el mismo nodo y ese nodo murió | **Pod anti-affinity** o **topologySpreadConstraints** |
| Repartir entre zonas de disponibilidad | `topologyKey: topology.kubernetes.io/zone` |
| La app necesita GPU / disco SSD / arquitectura arm64 | **nodeSelector** o **node affinity** |
| Dos servicios con alta comunicación tienen latencia | **Pod affinity** (mismo nodo o zona) |
| Nodos dedicados (PCI, sistema, GPU) que nadie más debe usar | **Taints** en el nodo + **tolerations** en los Pods autorizados |

---

## 2. Crear un clúster multinodo en Minikube

```sh
minikube start -p multinodo --nodes=3 --cpus=2 --memory=2048
kubectl config use-context multinodo
kubectl get nodes
# multinodo       Ready  control-plane
# multinodo-m02   Ready  <none>
# multinodo-m03   Ready  <none>

minikube node add -p multinodo              # agregar un nodo
minikube node list -p multinodo

# Simular zonas y tipos de nodo con labels
kubectl label node multinodo-m02 topology.kubernetes.io/zone=zona-a disco=ssd
kubectl label node multinodo-m03 topology.kubernetes.io/zone=zona-b
kubectl get nodes -L topology.kubernetes.io/zone,disco
```

> En Minikube multinodo, los volúmenes del aprovisionador por defecto viven en el disco de un nodo: un Pod con PVC queda "atado" a ese nodo.

---

## 3. Las herramientas, de la más simple a la más potente

### 3.1 nodeSelector — "solo en nodos con esta etiqueta"

```yaml
# fragmento (dentro de spec del Pod)
nodeSelector:
  disco: ssd
```

### 3.2 Node affinity — reglas obligatorias o preferidas

```yaml
# fragmento
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:     # OBLIGATORIO
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
    preferredDuringSchedulingIgnoredDuringExecution:    # PREFERIDO (puntos)
      - weight: 80
        preference:
          matchExpressions:
            - key: disco
              operator: In
              values: ["ssd"]
```

- `required…` = "si no se cumple, el Pod queda `Pending`".
- `preferred…` = "intenta, pero si no puedes, ubícalo igual".
- `…IgnoredDuringExecution` = si el nodo cambia de labels después, el Pod **no** se mueve.

### 3.3 Pod affinity y anti-affinity — "cerca de" / "lejos de" otros Pods

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
      affinity:
        podAntiAffinity:                            # LEJOS de mis propias réplicas
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: credito-api
              topologyKey: kubernetes.io/hostname   # "lejos" = en otro nodo
        podAffinity:                                # CERCA de la caché
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 50
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: cache
                topologyKey: kubernetes.io/hostname
      containers:
        - name: api
          image: nginx:1.27
```

**`topologyKey` define qué significa "el mismo lugar":**

| topologyKey | "Mismo lugar" = |
| --- | --- |
| `kubernetes.io/hostname` | Mismo nodo |
| `topology.kubernetes.io/zone` | Misma zona de disponibilidad |
| `topology.kubernetes.io/region` | Misma región |

> Con anti-affinity **required** por nodo y 3 nodos, la 4.ª réplica queda `Pending`. Si quieres repartir "lo mejor posible" usa **preferred** o, mejor, `topologySpreadConstraints`.

### 3.4 topologySpreadConstraints — repartir de forma equilibrada (recomendado)

```yaml
# fragmento
topologySpreadConstraints:
  - maxSkew: 1                                  # diferencia máxima de réplicas entre zonas
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: ScheduleAnyway           # o DoNotSchedule (estricto)
    labelSelector:
      matchLabels:
        app: credito-api
```

### 3.5 Taints y tolerations — "este nodo rechaza Pods"

Affinity **atrae** Pods hacia nodos; taints **repelen** Pods de nodos.

```sh
kubectl taint nodes multinodo-m03 dedicado=pci:NoSchedule      # poner
kubectl taint nodes multinodo-m03 dedicado=pci:NoSchedule-     # quitar
```

```yaml
# fragmento (en el Pod autorizado)
tolerations:
  - key: dedicado
    operator: Equal
    value: pci
    effect: NoSchedule
```

| Efecto | Qué hace |
| --- | --- |
| `NoSchedule` | No ubica Pods nuevos sin toleration |
| `PreferNoSchedule` | Lo evita si puede |
| `NoExecute` | Además **expulsa** los Pods que ya estaban |

> La toleration **permite** entrar al nodo, no **obliga**. Para nodos dedicados se combinan: taint (los demás no entran) + node affinity (los míos solo van ahí).

---

## 4. Práctica

```sh
kubectl apply -f anti-affinity.yaml
kubectl get pods -o wide -l app=credito-api       # columna NODE: una réplica por nodo
kubectl scale deploy credito-api --replicas=4
kubectl get pods -l app=credito-api               # la 4.ª en Pending
kubectl describe pod <pendiente> | grep -A5 Events   # "didn't match pod anti-affinity rules"

# Mantenimiento de un nodo
kubectl cordon multinodo-m02                      # no aceptar Pods nuevos
kubectl drain multinodo-m02 --ignore-daemonsets --delete-emptydir-data   # vaciar
kubectl uncordon multinodo-m02                    # volver a servicio
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `Pending`: *didn't match node affinity* | Ningún nodo tiene el label requerido | Revisar labels de nodos o usar `preferred` |
| `Pending`: *untolerated taint* | Nodo con taint y Pod sin toleration | Agregar toleration o usar otro nodo |
| Réplicas juntas pese a anti-affinity `preferred` | Era una preferencia, no una obligación | `required` o `topologySpreadConstraints` |
| `drain` se bloquea | Un PodDisruptionBudget no permite más bajas | Esperar o revisar el PDB |

---

## 6. Lo que debe saber el arquitecto

- **Alta disponibilidad real = réplicas repartidas en zonas.** Tres réplicas en el mismo nodo equivalen a una sola ante una falla. Estándar: `topologySpreadConstraints` por zona + por nodo, y **PodDisruptionBudget**.
- **Node pools por tipo de carga:** sistema, aplicaciones generales, cargas PCI o con datos sensibles, GPU. Se aíslan con taints + affinity. En nube cada pool es un grupo de máquinas con su propio tamaño y escalado.
- Las reglas `required` muy estrictas **reducen la capacidad efectiva** del clúster y pueden bloquear despliegues o el autoescalado. Úsalas con intención.
- `cordon` / `drain` son la base del mantenimiento y de las actualizaciones de nodos sin corte.

---

## 7. Checklist junior → senior

- [ ] **Junior:** creo un clúster de 3 nodos, etiqueto nodos y uso `nodeSelector`.
- [ ] **Semi-senior:** aplico anti-affinity y taints/tolerations; hago `drain` de un nodo.
- [ ] **Senior:** diseño node pools, reparto multi-zona y PDBs para la tolerancia a fallos del sistema.

---

← [16 · StatefulSet](16-statefulset.md) · [Índice](../README.md) · Siguiente → [18 · DaemonSet](18-daemonset.md)
