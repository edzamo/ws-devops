# Lab 01 · Tu primer Pod

| Nivel | Duración | Temas de apoyo |
| --- | --- | --- |
| Junior | 45-60 min | [01](../../01-documentation/01-minikube-presentacion-y-cluster-local.md) · [03](../../01-documentation/03-manifiesto-vs-comandos-y-declarativo.md) · [04](../../01-documentation/04-pods.md) · [06](../../01-documentation/06-pods-reinicio-y-exec.md) |

## La historia

El banco abre su primera ventanilla digital: una página web servida con **nginx**. Antes de pensar en réplicas o balanceadores, el equipo de plataforma necesita que sepas **crear una ventanilla (Pod), mirar qué pasa dentro, entrar a ella y diagnosticar cuando falla**.

## Objetivos

Al terminar podrás:

- Crear un Pod de forma **imperativa** y de forma **declarativa**, y explicar la diferencia.
- Leer un Pod con `get`, `describe` y `logs`, y entender sus **eventos**.
- Entrar al contenedor con `exec` y probarlo con `port-forward`.
- Demostrar que un Pod es **efímero**.
- Diagnosticar y corregir un `ImagePullBackOff`.

---

## Paso 0 · Preparar el terreno

```sh
minikube status
kubectl config current-context        # debe decir: minikube
kubectl get nodes
kubectl create namespace lab01        # el "piso" de este laboratorio (tema 09)
```

Todos los comandos de este lab usan `-n lab01`.

---

## Paso 1 · Forma imperativa (órdenes de voz)

```sh
kubectl run rapido --image=nginx:1.27 -n lab01
kubectl get pods -n lab01 -w          # observa los estados hasta Running (Ctrl+C para salir)
kubectl get pod rapido -n lab01 -o yaml | head -40
kubectl delete pod rapido -n lab01
```

**Observa:** en ningún lado quedó escrito qué creaste. Si mañana alguien pregunta "¿con qué imagen estaba ese Pod?", no hay registro.

---

## Paso 2 · Forma declarativa (el contrato escrito)

Abre [pod.yaml](pod.yaml) y completa los `TODO`:

| Requisito | Valor |
| --- | --- |
| Nombre | `web` |
| Namespace | `lab01` |
| Labels | `app: web` y `entorno: lab` |
| Contenedor | nombre `nginx`, imagen `nginx:1.27` |
| Puerto | `80` |
| Recursos | requests `50m` CPU y `64Mi` memoria; limit `128Mi` memoria |

> Pista: si no recuerdas un campo, usa `kubectl explain pod.spec.containers.resources`.

Valida **antes** de aplicar, y luego aplica:

```sh
kubectl apply -f pod.yaml --dry-run=server     # ¿el servidor lo acepta?
kubectl apply -f pod.yaml
kubectl get pods -n lab01 -o wide --show-labels
```

---

## Paso 3 · Inspeccionar

```sh
kubectl describe pod web -n lab01      # baja hasta "Events"
kubectl logs web -n lab01
```

Anota en `respuestas.md`: ¿en qué **nodo** está?, ¿qué **IP** tiene?, ¿qué **eventos** aparecen y en qué orden?

---

## Paso 4 · Probarlo desde tu máquina

En una terminal:

```sh
kubectl port-forward pod/web 8080:80 -n lab01
```

En otra:

```sh
curl http://localhost:8080             # página de bienvenida de nginx
kubectl logs web -n lab01              # ahora aparece tu petición en el log
```

---

## Paso 5 · Entrar a la ventanilla (`exec`)

```sh
kubectl exec -it web -n lab01 -- sh
# dentro del contenedor:
echo '<h1>Hola desde mi primer Pod</h1>' > /usr/share/nginx/html/index.html
hostname                               # ¿qué nombre ves? compáralo con el del Pod
exit
```

```sh
curl http://localhost:8080             # (con el port-forward activo) → tu mensaje
```

---

## Paso 6 · El Pod es efímero

```sh
kubectl delete pod web -n lab01
kubectl get pods -n lab01              # ¿volvió solo?
kubectl apply -f pod.yaml              # lo recreas tú
# vuelve a hacer port-forward y curl
```

¿Sigue tu mensaje "Hola desde mi primer Pod"? Explica por qué en `respuestas.md`.

---

## Paso 7 · Rómpelo y diagnostícalo

1. En `pod.yaml` cambia la imagen a `nginx:1.99` (una versión que **no existe**).
2. Aplica con `kubectl apply -f pod.yaml`. La imagen es uno de los pocos campos de un Pod que se pueden cambiar en caliente: el kubelet detiene el contenedor actual e intenta descargar la nueva versión. (Si cambiaras otros campos, como `resources`, el servidor respondería `Forbidden: pod updates may not change fields...` y tendrías que borrar y recrear el Pod.)
3. Diagnostica **solo con comandos**:

```sh
kubectl get pods -n lab01
kubectl describe pod web -n lab01      # ¿qué dicen los Events?
```

4. Corrige la imagen a `nginx:1.27`, vuelve a aplicar y confirma que queda `Running`.

---

## Paso 8 · Verificar

```sh
chmod +x verificar.sh
./verificar.sh
```

Todo debe salir ✅. Si algo sale ❌, el mensaje te dice qué revisar.

---

## Preguntas de comprensión (en `respuestas.md`)

1. Con tus palabras: ¿qué diferencia hay entre `kubectl run` y `kubectl apply -f`? ¿Cuál usarías en un banco y por qué?
2. ¿Qué parte del YAML escribiste tú (`spec`) y qué parte llenó Kubernetes (`status`)? Da un ejemplo de cada una sacado de `kubectl get pod web -o yaml`.
3. En el paso 6 el mensaje desapareció. ¿Por qué? ¿Qué dos conceptos de la documentación resuelven ese problema? (pista: temas 11 y 12).
4. Al borrar el Pod, nadie lo recreó. ¿Qué objeto lo habría recreado solo?
5. ¿Qué estado mostró el Pod con `nginx:1.99` y qué línea de los eventos te dio la causa?
6. **Pregunta de arquitecto:** ¿por qué la documentación dice que nunca se crean Pods sueltos en producción?

---

## Cuando termines

Avisa al profesor con: "Lab 01 terminado". Se revisan `pod.yaml`, `respuestas.md` y la salida de `verificar.sh`. Después, limpieza:

```sh
kubectl delete namespace lab01
```

Siguiente: **Lab 02 · Labels y selectores** (se abre tras la revisión).
