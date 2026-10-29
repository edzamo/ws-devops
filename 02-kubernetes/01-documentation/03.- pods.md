# ¿Qué es un Pod en Kubernetes?

Un **Pod** es la unidad más pequeña y básica que se puede desplegar y gestionar en Kubernetes. Un Pod representa una instancia en ejecución de uno o varios contenedores que comparten almacenamiento, red y especificaciones sobre cómo ejecutar los contenedores.

## Características principales de un Pod

- **Uno o varios contenedores:** Normalmente, un Pod contiene un solo contenedor, pero puede tener varios que necesiten compartir recursos.
- **Red compartida:** Todos los contenedores de un Pod comparten la misma dirección IP, puerto y espacio de red.
- **Almacenamiento compartido:** Los contenedores pueden acceder a volúmenes compartidos definidos en el Pod.
- **Ciclo de vida conjunto:** Los contenedores de un Pod se crean, inician, detienen y eliminan juntos.

## ¿Para qué se usan los Pods?

- Ejecutar aplicaciones o servicios en contenedores.
- Agrupar contenedores que necesitan compartir recursos.
- Gestionar el ciclo de vida de aplicaciones en Kubernetes.

## Ejemplo básico de un Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mi-primer-pod
spec:
  containers:
    - name: nginx
      image: nginx:latest

```

## Comandos comunes para trabajar con Pods

A continuación, algunos comandos útiles de `kubectl` para gestionar y consultar Pods y otros recursos en Kubernetes:

- **Ver todos los recursos del namespace actual:**
  
  ```sh
  kubectl get all
  ```

- **Ver todos los Pods:**
  
  ```sh
  kubectl get pods
  ```

- **Ver todos los recursos con información extendida (IP, nodo, etc):**
  
  ```sh
  kubectl get all -o wide
  ```

- **Describir un Pod específico (muestra detalles, eventos y estado):**
  
  ```sh
  kubectl describe pod <nombre-del-pod>
  ```

Reemplaza `<nombre-del-pod>` por el nombre real del Pod que deseas inspeccionar. Estos comandos te permiten monitorear, depurar y administrar los Pods y otros recursos en tu clúster de Kubernetes.

## Reinicio de un Pod y uso de Exec en un contenedor

- **Reiniciar un Pod:**  
  Kubernetes no tiene un comando directo para reiniciar un Pod, pero puedes eliminarlo y el controlador (Deployment, ReplicaSet, etc.) lo recreará automáticamente.

  **Ejemplo:**
  ```sh
  kubectl delete pod <nombre-del-pod>
  ```
  Esto elimina el Pod y, si está gestionado por un Deployment, se creará uno nuevo con la misma configuración.

- **Exec en un contenedor:**  
  El comando `kubectl exec` te permite ejecutar comandos dentro de un contenedor que está corriendo en un Pod, útil para depuración o administración.

  **Ejemplo:**
  ```sh
  kubectl exec -it <nombre-del-pod> -- bash
  ```
  Esto abre una terminal interactiva dentro del contenedor principal del Pod.

Reemplaza `<nombre-del-pod>` por el nombre real del Pod que deseas inspeccionar.