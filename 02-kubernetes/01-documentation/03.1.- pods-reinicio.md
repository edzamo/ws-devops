
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