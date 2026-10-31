# 02 · Configuración de Minikube, configurar el clúster y multiclúster con perfiles

> **En una frase:** Puedes decidir cuánta CPU, memoria, nodos y qué versión de Kubernetes tiene tu clúster, y tener **varios clústeres a la vez** usando *perfiles*.
>
> **Analogía (contar manzanas):** Si Minikube es la maqueta del banco, la **configuración** es decidir de qué tamaño es la maqueta (cuántas sucursales, cuánto espacio). Un **perfil** es tener **varias maquetas** en el escritorio, cada una con su nombre: "desarrollo", "pruebas", "versión-nueva".

---

## 1. ¿Qué problema resuelve?

- Probar tu aplicación con la **misma versión** de Kubernetes que producción.
- Simular entornos separados (dev / qa) o **probar una actualización** de Kubernetes sin romper tu clúster principal.
- Dar al clúster los recursos que realmente necesita tu sistema (por ejemplo, 2 microservicios Java + Postgres + Angular piden más de 2 GB).

---

## 2. Configurar el clúster al crearlo

Los parámetros se fijan **al crear** el clúster (`minikube start`). Cambiar CPU o memoria de un clúster existente exige borrarlo y recrearlo.

```sh
minikube start \
  --driver=docker \
  --cpus=4 \
  --memory=8192 \
  --disk-size=30g \
  --kubernetes-version=v1.32.0 \
  --container-runtime=containerd \
  --nodes=1
```

| Bandera | Qué decide |
| --- | --- |
| `--driver` | Cómo se crean los nodos (docker, kvm2, virtualbox...) |
| `--cpus` / `--memory` / `--disk-size` | Recursos por nodo (memoria en MB) |
| `--kubernetes-version` | Versión de Kubernetes: igual a producción |
| `--container-runtime` | Runtime de contenedores (containerd, docker, cri-o) |
| `--nodes` | Cantidad de nodos (ver tema 17: multinodo) |

### Drivers más usados

| Driver | Qué es | Cuándo |
| --- | --- | --- |
| `docker` | Cada nodo es un contenedor Docker | Opción por defecto, la más simple |
| `kvm2` | Máquina virtual KVM (Linux) | Aislamiento más real |
| `virtualbox` | Máquina virtual VirtualBox | Multiplataforma, más pesado |
| `hyperkit` / `vfkit` | Virtualización nativa de macOS | Mac |
| `none` | Directo sobre el host (root) | Solo casos especiales, no recomendado |

### Configuración por defecto persistente

En lugar de repetir banderas, guárdalas como preferencia:

```sh
minikube config set cpus 4
minikube config set memory 8192
minikube config set driver docker
minikube config view                # ver la configuración guardada
```

### Addons: funcionalidades que se encienden con un interruptor

```sh
minikube addons list
minikube addons enable metrics-server   # métricas de CPU/memoria (kubectl top)
minikube addons enable ingress          # NGINX Ingress Controller (tema 23)
minikube addons enable dashboard        # interfaz gráfica
```

| Addon | Para qué |
| --- | --- |
| `storage-provisioner` + `default-storageclass` | Crea discos automáticamente cuando un Pod pide un volumen (tema 12) |
| `metrics-server` | Habilita `kubectl top` y el autoescalado (HPA) |
| `ingress` | Entrada HTTP/HTTPS por nombre de dominio |
| `registry` | Registro de imágenes local |
| `dashboard` | Panel web del clúster |

### Comandos útiles del día a día

```sh
minikube ip                       # IP del nodo
minikube ssh                      # entrar al nodo (como entrar a la sucursal)
minikube image load app:1.0       # subir una imagen local al clúster
minikube service <servicio>       # abrir un Service en el navegador
minikube tunnel                   # habilita Services tipo LoadBalancer
minikube logs                     # logs de Minikube para diagnosticar
```

---

## 3. Multiclúster con perfiles

Un **perfil** es un clúster independiente con su propio nombre, recursos, versión y contexto de `kubectl`. El perfil por defecto se llama `minikube`.

```text
  Tu laptop
  ├── perfil "minikube"   → v1.32.0, 1 nodo   (contexto kubectl: minikube)
  ├── perfil "dev"        → v1.32.0, 1 nodo   (contexto kubectl: dev)
  └── perfil "upgrade"    → v1.33.0, 3 nodos  (contexto kubectl: upgrade)
```

### Práctica

```sh
# Crear dos clústeres adicionales
minikube start -p dev --cpus=2 --memory=4096
minikube start -p upgrade --kubernetes-version=v1.33.0 --nodes=3

# Ver todos los perfiles (el activo aparece con *)
minikube profile list

# Cambiar el perfil activo de minikube
minikube profile dev

# Cambiar el clúster al que apunta kubectl (lo más importante)
kubectl config get-contexts
kubectl config use-context upgrade
kubectl get nodes

# Ejecutar contra un perfil concreto sin cambiar el contexto
kubectl --context=dev get pods
minikube -p dev kubectl -- get pods

# Detener o borrar solo un perfil
minikube stop -p dev
minikube delete -p upgrade

# Borrar todos los perfiles
minikube delete --all
```

Alias práctico:

```sh
alias kdev='kubectl --context=dev'
kdev get pods
```

> **Perfil ≠ contexto.** El *perfil* es de Minikube (qué clúster existe). El *contexto* es de `kubectl` (a qué clúster le hablas). Minikube crea un contexto con el mismo nombre de cada perfil. El archivo que guarda los contextos es `~/.kube/config`.

---

## 4. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| Aplicaste en el clúster equivocado | `kubectl` seguía en otro contexto | Revisa siempre `kubectl config current-context` |
| `--memory` no cambia nada | El clúster ya existía | `minikube delete -p <perfil>` y crear de nuevo |
| La laptop se queda sin RAM | Varios perfiles encendidos | `minikube stop -p <perfil>` los que no uses |
| `kubectl top` no funciona | Falta `metrics-server` | `minikube addons enable metrics-server` |

---

## 5. Lo que debe saber el arquitecto

- **El contexto de `kubectl` es un riesgo operativo.** En empresas reales, un `kubectl delete` en el contexto equivocado borra producción. Prácticas: mostrar el contexto en el *prompt* de la terminal, usar herramientas como `kubectx`, y que **producción solo se toque desde el pipeline**, nunca desde laptops.
- **Clústeres por entorno vs. namespaces por entorno:** en banca lo habitual es **un clúster por entorno** (dev, qa, prod) y namespaces por equipo o sistema dentro de cada uno. Los perfiles de Minikube te permiten ensayar ese modelo.
- **Ensayo de upgrades:** Kubernetes publica una versión menor aproximadamente cada 4 meses y cada una tiene soporte cerca de 14 meses. Un perfil con la versión nueva te permite detectar APIs eliminadas antes de actualizar producción.
- **Dimensionamiento:** la suma de los `requests` de tus Pods (tema 15) debe caber en los nodos. Si no caben, quedan en `Pending`.

---

## 6. Checklist junior → senior

- [ ] **Junior:** creo un perfil, cambio de contexto y lo borro.
- [ ] **Semi-senior:** dimensiono CPU/memoria y fijo la versión de Kubernetes igual a producción.
- [ ] **Senior:** diseño la estrategia de clústeres por entorno y controlo el acceso a contextos productivos.

---

← [01 · Presentación y clúster local](01-minikube-presentacion-y-cluster-local.md) · [Índice](../README.md) · Siguiente → [03 · Manifiesto vs. comandos](03-manifiesto-vs-comandos-y-declarativo.md)
