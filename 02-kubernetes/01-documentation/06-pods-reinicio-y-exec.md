# 06 · Reinicio de Pod y `kubectl exec`

> **En una frase:** En Kubernetes un Pod **no se reinicia: se reemplaza**; y `kubectl exec` te permite entrar a un contenedor vivo para ejecutar comandos.
>
> **Analogía (contar manzanas):** Si una manzana se pudre, no la "reparas": la **tiras y pones una nueva** de la misma caja. Quien repone es el gerente (el controlador). `exec` es **entrar a la ventanilla** a mirar los cajones del cajero sin cerrar la atención.

---

## 1. Dos tipos de "reinicio" (no confundir)

| Tipo | Qué pasa | Quién lo hace | ¿Cambia el Pod? |
| --- | --- | --- | --- |
| **Reinicio del contenedor** | El proceso muere y el *kubelet* lo vuelve a arrancar **dentro del mismo Pod** | kubelet, según `restartPolicy` | No: mismo nombre e IP; sube `RESTARTS` |
| **Reemplazo del Pod** | El Pod se borra y el controlador crea **otro** | Deployment / ReplicaSet / StatefulSet | Sí: nombre e IP nuevos |

```text
kubectl get pods
NAME                    READY   STATUS    RESTARTS      AGE
web-7c9d8f6b5d-x2kqp    1/1     Running   3 (2m ago)    1h    ← el contenedor se reinició 3 veces
```

`restartPolicy`: `Always` (por defecto, para servicios), `OnFailure` (Jobs), `Never`.

Entre reintentos el kubelet espera cada vez más (10 s, 20 s, 40 s… hasta 5 min): eso es el **BackOff** de `CrashLoopBackOff`.

---

## 2. Formas correctas de "reiniciar"

```sh
# 1) La forma profesional: reinicio ordenado de todos los Pods de un Deployment
kubectl rollout restart deployment/web
kubectl rollout status deployment/web

# 2) Reemplazar un solo Pod (el controlador crea otro)
kubectl delete pod web-7c9d8f6b5d-x2kqp

# 3) Bajar y subir réplicas (provoca CORTE de servicio; evitar)
kubectl scale deployment/web --replicas=0
kubectl scale deployment/web --replicas=3
```

`rollout restart` agrega una anotación con la fecha al template del Pod; como el template cambió, el Deployment hace un **rolling update** (tema 11): crea nuevos antes de matar viejos, **sin corte**.

> Un Pod suelto (sin controlador) que borras **no vuelve**. Por eso en producción todo va dentro de un Deployment u otro controlador.

---

## 3. `kubectl exec`: entrar al contenedor

```sh
kubectl exec web -- ls /usr/share/nginx/html        # un comando suelto
kubectl exec -it web -- sh                          # terminal interactiva (sh si no hay bash)
kubectl exec -it web -c nginx -- bash               # elegir contenedor en un Pod con varios
kubectl exec -it deploy/web -- sh                   # cualquier Pod del Deployment
kubectl exec web -- env                             # ver variables de entorno
kubectl exec web -- cat /etc/resolv.conf            # ver DNS del Pod
```

- `-i` = interactivo (mantener la entrada abierta), `-t` = terminal.
- `--` separa las opciones de `kubectl` del comando que corre adentro.

### Herramientas hermanas

```sh
kubectl cp web:/etc/nginx/nginx.conf ./nginx.conf   # copiar archivos
kubectl port-forward pod/web 8080:80                # probar el puerto desde tu máquina
kubectl debug -it web --image=busybox:1.36 --target=nginx   # contenedor efímero de diagnóstico
kubectl run tmp --rm -it --image=busybox:1.36 -- sh # Pod temporal para probar red/DNS
```

`kubectl debug` es clave cuando la imagen es mínima (*distroless*) y no trae `sh`: agrega un contenedor temporal con herramientas, compartiendo los procesos del Pod.

---

## 4. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `executable file not found: bash` | La imagen no trae bash | Usa `sh` o `kubectl debug` |
| Cambié un archivo con `exec` y se perdió | El sistema de archivos del contenedor es efímero | Cambia la imagen o usa ConfigMap/volumen |
| `RESTARTS` sube sin parar | La app muere o la *liveness probe* la mata | `kubectl logs --previous` y revisar probes (tema 19) |
| Escalar a 0 para reiniciar | Provoca indisponibilidad | `kubectl rollout restart` |

---

## 5. Lo que debe saber el arquitecto

- **`exec` en producción es una puerta de alto riesgo.** Quien hace `exec` puede leer secretos, variables y datos de clientes. En banca: restringido por RBAC (`pods/exec`), con acceso *break-glass* temporal, auditado y justificado por ticket.
- **Nunca "arreglar" en caliente con `exec`.** Lo que se corrige dentro del contenedor desaparece con el siguiente reemplazo y genera diferencias no auditadas. La corrección va en la imagen o en el manifiesto.
- **Imágenes mínimas (distroless)** reducen superficie de ataque; el diagnóstico se hace con `kubectl debug`, no metiendo herramientas en la imagen.
- **`RESTARTS` es una métrica de salud**: un contenedor que se reinicia seguido debe generar alerta.

---

## 6. Checklist junior → senior

- [ ] **Junior:** entro a un contenedor con `exec -it` y reinicio con `rollout restart`.
- [ ] **Semi-senior:** distingo reinicio de contenedor vs. reemplazo de Pod; uso `logs --previous` y `debug`.
- [ ] **Senior:** defino la política de acceso `exec` en producción (RBAC, auditoría, *break-glass*).

---

← [05 · Metadata, labels y selectores](05-metadata-labels-selectores.md) · [Índice](../README.md) · Siguiente → [07 · ReplicationController](07-replication-controller.md)
