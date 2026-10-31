# 01 · Presentación de Minikube y clúster local

> **En una frase:** Minikube levanta un clúster de Kubernetes completo dentro de tu laptop para aprender y probar sin pagar nube.
>
> **Analogía (contar manzanas):** Kubernetes es un **banco con muchas sucursales**. Minikube es la **maqueta de ese banco** sobre tu escritorio: tiene la gerencia, una sucursal y las reglas reales, pero en miniatura.

---

## 1. ¿Qué problema resuelve?

Un clúster real (EKS, AKS, GKE u on-premise) cuesta dinero, tarda en crearse y suele estar controlado por otro equipo. Para aprender, para probar manifiestos antes de un pipeline o para reproducir un bug, necesitas un clúster **tuyo, barato y desechable**. Eso es Minikube.

| Opción local | Para qué sirve | Nota |
| --- | --- | --- |
| **Minikube** | Aprender y desarrollar; trae *addons* (ingress, dashboard, metrics) | El que usa este curso |
| kind | Clústeres en contenedores, muy usado en pipelines de CI | Más liviano, menos *addons* |
| k3d / k3s | Kubernetes liviano (edge, IoT) | k3s también se usa en producción |
| Docker Desktop / Rancher Desktop | Kubernetes integrado al escritorio | Cómodo, menos control |

---

## 2. Cómo funciona: las piezas de un clúster

Todo clúster de Kubernetes —el de tu laptop y el de un banco— tiene dos mitades:

```text
                ┌──────────── CONTROL PLANE (la gerencia) ────────────┐
 kubectl ─────► │ kube-apiserver   → la única puerta de entrada         │
 (tú)           │ etcd             → el libro mayor: estado deseado      │
                │ kube-scheduler   → decide en qué nodo va cada Pod      │
                │ controller-manager → vigila que real == deseado        │
                └───────────────────────────┬─────────────────────────┘
                                            │
                ┌──────────── WORKER NODE (la sucursal) ──────────────┐
                │ kubelet     → el jefe de sucursal: arranca los Pods   │
                │ kube-proxy  → reglas de red para los Services         │
                │ container runtime (containerd/docker) → corre imágenes│
                │ [Pod] [Pod] [Pod]                                      │
                └───────────────────────────────────────────────────────┘
```

En Minikube **ambas mitades viven en un solo nodo** llamado `minikube` (por eso su rol es `control-plane` y además ejecuta tus Pods).

**La idea más importante de todo Kubernetes — el bucle de reconciliación:**

1. Tú declaras: "quiero **3** manzanas en la canasta" (estado deseado, se guarda en etcd).
2. Un controlador cuenta: "hay **2**" (estado real).
3. Actúa: "falta **1**, la creo".
4. Repite para siempre.

Kubernetes no ejecuta órdenes una vez; **persigue un estado** sin parar. Si entiendes esto, entiendes el 80 % de la plataforma.

---

## 3. Instalación

### Linux

```sh
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### macOS

```sh
brew install minikube
```

`kubectl` (el control remoto del clúster) se instala aparte, o se usa el que trae Minikube con `minikube kubectl -- <comando>`.

---

## 4. Práctica: tu primer clúster local

```sh
minikube start                         # crea y arranca el clúster (driver docker por defecto)
minikube status                        # host, kubelet y apiserver deben estar Running
kubectl config current-context         # debe responder: minikube
kubectl get nodes -o wide              # ver el nodo, su IP y la versión de Kubernetes
kubectl get pods -A                    # ver los Pods del sistema (namespace kube-system)
kubectl cluster-info                   # URL del apiserver
minikube dashboard                     # interfaz web (opcional)
```

Salida típica de `kubectl get nodes`:

```text
NAME       STATUS   ROLES           AGE   VERSION
minikube   Ready    control-plane   10m   v1.32.0
```

Ciclo de vida del clúster:

| Comando | Qué hace | ¿Pierdo lo desplegado? |
| --- | --- | --- |
| `minikube stop` | Apaga la maqueta | No |
| `minikube start` | La vuelve a encender | No |
| `minikube pause` / `unpause` | Congela el control plane para ahorrar CPU | No |
| `minikube delete` | Destruye el clúster | **Sí, todo** |

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `kubectl` responde con otro clúster | Contexto equivocado | `kubectl config use-context minikube` |
| `minikube start` falla por memoria | Docker con pocos recursos | `minikube start --memory=4096 --cpus=2` |
| `ImagePullBackOff` en una imagen local | Minikube tiene su **propio** Docker | `minikube image load mi-imagen:tag` |
| El clúster "se cayó" tras reiniciar la PC | Minikube no arranca solo | `minikube start` |

---

## 6. Lo que debe saber el arquitecto

- **Minikube no es producción.** Un solo nodo, sin alta disponibilidad, sin balanceador real. Sirve para validar *manifiestos y comportamiento*, no rendimiento ni resiliencia.
- **El control plane es el activo crítico.** En producción se usa uno gestionado (EKS/AKS/GKE) con etcd replicado y respaldado. Si cae etcd, el banco pierde el libro mayor.
- **Paridad de entornos:** fija en Minikube la **misma versión de Kubernetes** que producción (`--kubernetes-version`) para que lo que funciona en local funcione en el clúster real.
- **Kubernetes es declarativo y eventual:** "aplicado" no significa "listo". Los pipelines deben esperar (`kubectl rollout status`) en lugar de asumir.

---

## 7. Checklist junior → senior

- [ ] **Junior:** arranco, detengo y borro Minikube; leo `kubectl get nodes`.
- [ ] **Semi-senior:** explico qué hace cada componente del control plane y del nodo.
- [ ] **Senior:** explico el bucle de reconciliación y por qué un clúster gestionado reduce riesgo operativo.

---

[Índice](../README.md) · Siguiente → [02 · Configuración y perfiles](02-minikube-configuracion-y-perfiles.md)
