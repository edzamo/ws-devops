# Minikube: Comandos Básicos

## Verificar la versión de Minikube

```bash
minikube version
```

## Iniciar Minikube

```bash
minikube start
```

## Detener Minikube

```bash
minikube stop
```

## Obtener la IP de Minikube

```bash
minikube ip
```
## Eliminar Minikube

```bash
minikube delete
```

## ¿Qué son los Addons en Minikube?

Los addons en Minikube son extensiones que añaden funcionalidades adicionales al clúster, facilitando tareas comunes como el monitoreo, el dashboard o el manejo de volúmenes.

### Addons más usados

- **dashboard**: Interfaz gráfica para gestionar el clúster.
- **metrics-server**: Recolecta métricas de recursos de los pods y nodos.
- **ingress**: Permite gestionar reglas de entrada HTTP y HTTPS.
- **storage-provisioner**: Provisión automática de almacenamiento persistente.
- **default-storageclass**: Define la clase de almacenamiento por defecto.
- **registry**: Registro privado de imágenes Docker local.

Puedes listar todos los addons disponibles con:

```bash
minikube addons list
## Listar Perfiles de Minikube

```bash
minikube profile list
```
`minikube profile list` muestra todos los perfiles de Minikube disponibles en tu máquina. Un perfil representa una configuración aislada de clúster, permitiendo tener múltiples entornos de Minikube con diferentes configuraciones.

### Tipos de drivers soportados por Minikube

Algunos de los drivers más comunes para crear clústeres son:

- **docker**: Usa Docker como backend para los nodos del clúster.
- **virtualbox**: Utiliza máquinas virtuales VirtualBox.
- **hyperkit**: Driver para macOS basado en HyperKit.
- **kvm2**: Usa KVM para virtualización en Linux.
- **none**: Ejecuta Minikube directamente en el host (requiere privilegios de root).

Puedes especificar el driver al crear un perfil con el parámetro `--driver`. Por ejemplo:

##

## ¿Cómo se usa kubectl?

`kubectl` es la herramienta de línea de comandos para interactuar con clústeres de Kubernetes. Permite desplegar aplicaciones, inspeccionar y gestionar recursos, y ver logs.

Ejemplo básico para listar pods en el espacio de nombres por defecto:

```bash
kubectl get pods
```

Algunos comandos útiles:

- Listar todos los servicios:
    ```bash
    kubectl get services
    ```
- Ver detalles de un pod:
    ```bash
    kubectl describe pod <nombre-del-pod>
    ```
- Aplicar un manifiesto:
    ```bash
    kubectl apply -f archivo.yaml
    ```
- Ver los logs de un pod:
    ```bash
    kubectl logs <nombre-del-pod>
    ```

Recuerda que si tienes varios perfiles de Minikube, puedes usar el comando `minikube -p <perfil> kubectl ...` para ejecutar `kubectl` en un perfil específico.



```bash
minikube start --profile mi-perfil --driver=docker
## Consultar los nodos del clúster con kubectl

Puedes usar el siguiente comando para ver los nodos disponibles en tu clúster de Minikube:

```bash
minikube -p cluster1 kubectl get nodes
```

Este comando ejecuta `kubectl get nodes` en el perfil de Minikube llamado `cluster1`, mostrando información sobre los nodos del clúster.

## Crear un nuevo clúster con una versión específica de Kubernetes

Puedes crear un nuevo clúster de Minikube con un perfil diferente y especificar la versión de Kubernetes que deseas usar:

```bash
minikube start -p cluster2 --kubernetes-version=v1.22.0
```

Este comando crea un clúster llamado `cluster2` utilizando la versión `v1.22.0` de Kubernetes. Así puedes probar diferentes versiones o mantener entornos separados en tu máquina.
## Alias útil para trabajar con perfiles de Minikube

Puedes crear un alias para facilitar el uso de `kubectl` en un perfil específico de Minikube. Por ejemplo, para el perfil `cluster2`:

```bash
alias k='minikube -p cluster2 kubectl'
```

Con este alias, puedes ejecutar comandos de `kubectl` directamente sobre el perfil `cluster2` usando `k`, por ejemplo:

```bash
k get pods
```

kubectl get all
