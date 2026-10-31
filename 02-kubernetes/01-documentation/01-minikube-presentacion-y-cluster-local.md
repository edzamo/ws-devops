El comando `kubectl get nodes` se utiliza para listar todos los nodos que forman parte del clúster de Kubernetes. Muestra información relevante como el nombre del nodo, su estado, roles asignados, edad y versión de Kubernetes que ejecuta. Es útil para verificar el estado y la disponibilidad de los nodos en el clúster.

Ejemplo de uso:

```sh
kubectl get nodes
```

Salida esperada:

```
NAME           STATUS   ROLES           AGE   VERSION
minikube       Ready    control-plane   10m   v1.29.0
```

Antes de ejecutar `kubectl get nodes`, verifica el estado de Minikube con el siguiente comando:

```sh
minikube status
```

Si Minikube no está en ejecución, inícialo con:

```sh
minikube start
```

Asegúrate de que `kubectl` esté utilizando el contexto de Minikube:

```sh
kubectl config use-context minikube
```

Luego, vuelve a intentar listar los nodos:

```sh
kubectl get nodes
```

## Formas de crear recursos en Kubernetes

Existen dos formas principales de crear recursos en Kubernetes: **declarativa** e **imperativa**.

### 1. Forma Declarativa

Consiste en definir el estado deseado del recurso en un archivo YAML y luego aplicar ese archivo usando `kubectl apply`. Es la forma recomendada para gestionar recursos de manera reproducible y controlada.

**Ejemplo:**

Archivo `pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
    name: mi-pod
spec:
    containers:
        - name: nginx
            image: nginx:latest
```

Comando para crear el recurso:

```sh
kubectl apply -f pod.yaml
```

### 2. Forma Imperativa

Consiste en crear recursos directamente desde la línea de comandos, especificando los parámetros necesarios.

**Ejemplo:**

```sh
kubectl run mi-pod --image=nginx:latest
kubectl create deployment pruebas --image=nginx:latest --replicas=2

```

Ambos métodos crean el mismo recurso, pero la forma declarativa facilita el versionado y la gestión de cambios.
## Descripción rápida de comandos útiles

- `kubectl apply -f ejemplo.yml`: Aplica la configuración definida en el archivo `ejemplo.yml` al clúster de Kubernetes, creando o actualizando los recursos especificados.
- `kubectl get all`: Muestra todos los recursos principales (pods, servicios, deployments, etc.) en el espacio de nombres actual del clúster.
- `kubectl delete -f ejemplo.yml`: Elimina los recursos definidos en el archivo `ejemplo.yml` del clúster de Kubernetes.
**Ejemplo:**

Si creaste un deployment llamado `pruebas` de forma imperativa, puedes eliminarlo con el siguiente comando:

```sh
kubectl delete deployment pruebas
```

- `kubectl delete <tipo> <nombre>`: Elimina un recurso específico indicando su tipo y nombre, por ejemplo, `kubectl delete pod mi-pod`.
- `kubectl delete all --all`: Elimina todos los recursos principales (pods, servicios, deployments, etc.) en el espacio de nombres actual. Es útil para limpiar rápidamente todos los recursos creados durante pruebas o desarrollos.

    **Ejemplo de salida:**
    ```
    pod "pod-hello-v2" deleted
    service "mi-servicio" deleted
    deployment.apps "mi-deployment" deleted
    ```

    **Opciones adicionales:**
    - `-n <namespace>`: Especifica el espacio de nombres donde se eliminarán los recursos, por ejemplo, `kubectl delete all --all -n desarrollo`.
    - `--grace-period=0 --force`: Elimina los recursos de forma inmediata, sin esperar el período de gracia.


