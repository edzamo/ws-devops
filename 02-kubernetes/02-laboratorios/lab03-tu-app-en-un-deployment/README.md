# Lab 03 · Tu app en un Deployment

| Nivel | Duración | Temas de apoyo |
| --- | --- | --- |
| Junior | 60-90 min | [Docker](../../../01-docker/README.md) · [07 · ReplicationController](../../01-documentation/07-replication-controller.md) · [08 · ReplicaSet](../../01-documentation/08-replicaset.md) · [10 · Services](../../01-documentation/10-services.md) · [11 · Deployments](../../01-documentation/11-deployments.md) |

## La historia

En los labs 01 y 02 las ventanillas eran Pods sueltos: si uno moría, **nadie lo reponía**. El banco no puede operar así. Hoy contratas a un **gerente de sucursal** (el **Deployment**) con una sola orden: *"quiero siempre 3 ventanillas iguales atendiendo con esta versión"*. Él las abre, las repone si una cae, abre más si se lo pides y, cuando llega una versión nueva, **las cambia una por una sin cerrar la sucursal**.

Y la app no será un nginx genérico: será **tu propia imagen**, la que construiste en el curso de Docker.

## Objetivos

- Llevar una imagen construida con Docker a Minikube **sin pasar por Docker Hub**.
- Escribir un **Deployment** y entender la cadena **Deployment → ReplicaSet → Pods**.
- Ver la **autorreparación**: matar Pods y verlos volver solos.
- Poner un **Service** delante y comprobar el **balanceo** y el **DNS** interno.
- **Escalar** y entender la diferencia entre escalar por comando y por YAML.
- Hacer un **rolling update** v1 → v2 sin corte, romper una versión y hacer **rollback**.

```text
                 Service "hola"   (nombre fijo + balanceo)
                        │  selector: app=hola
          ┌─────────────┼─────────────┐
        Pod           Pod           Pod        ← réplicas idénticas (efímeras)
          └─────────────┼─────────────┘
                    ReplicaSet                 ← "mantén 3 copias de ESTA versión"
                        │
                    Deployment "hola"          ← "esta es la versión que quiero; cámbiala sin corte"
```

---

## Paso 0 · Preparar el terreno

```sh
kubectl config current-context        # minikube
kubectl create namespace lab03
```

---

## Paso 1 · De Docker a Minikube: tu imagen

Usarás los Dockerfiles que escribiste en el curso de Docker, en [01-docker/02-dockerfiles](../../../01-docker/02-dockerfiles/):

| Archivo | Responde | Será la versión |
| --- | --- | --- |
| `Dockerfile.v01` | `hello world` | `hola-banco:1.0` |
| `Dockerfile` | `hello world 2.0` | `hola-banco:2.0` |

```sh
cd ../../../01-docker/02-dockerfiles
docker build -t hola-banco:1.0 -f Dockerfile.v01 .
docker build -t hola-banco:2.0 -f Dockerfile .
cd -
```

Ahora viene el punto clave: **Minikube no ve las imágenes de tu Docker.** Minikube tiene su propio motor de contenedores, como si fuera otra máquina. Hay que "pasarle" la imagen:

```sh
minikube image load hola-banco:1.0
minikube image load hola-banco:2.0
minikube image ls | grep hola-banco    # ahora sí están dentro del clúster
```

> **En la nube** este paso no existe: haces `docker push` a un registro (ECR, ACR, Artifact Registry) y el clúster descarga de ahí. `image load` es un atajo solo para laboratorio.

---

## Paso 2 · El Deployment

Completa [deployment.yaml](deployment.yaml):

| Requisito | Valor |
| --- | --- |
| Namespace | `lab03` |
| Réplicas | `3` |
| Selector y labels del molde | `app: hola` (los dos **iguales**) |
| Imagen | `hola-banco:1.0` |

```sh
kubectl apply -f deployment.yaml --dry-run=server
kubectl apply -f deployment.yaml
kubectl rollout status deploy/hola -n lab03
kubectl get deploy,rs,pods -n lab03 -o wide
```

**Observa los nombres:** `hola` (Deployment) → `hola-84c46cf8dd` (ReplicaSet) → `hola-84c46cf8dd-mwx7m` (Pod). Cada nivel agrega un sufijo. Ese `84c46cf8dd` es la "huella" de la versión del molde.

**Pruébalo:** cambia en el YAML el label del molde a `app: otra` (dejando el selector en `app: hola`) y aplica con `--dry-run=server`. ¿Qué responde Kubernetes? Vuelve a dejarlo como estaba.

---

## Paso 3 · Autorreparación: mata una ventanilla

Abre **dos terminales**.

```sh
# Terminal 1: observa en vivo
kubectl get pods -n lab03 -w
```

```sh
# Terminal 2: mata un Pod (copia un nombre real)
kubectl delete pod <un-pod-hola> -n lab03
```

¿Qué pasa en la terminal 1? Compáralo con el **paso 6 del lab 01**, cuando borraste un Pod suelto.

Ahora mata **todos** a la vez y cuenta cuánto tardan en volver:

```sh
kubectl delete pods -n lab03 -l app=hola
```

---

## Paso 4 · El Service y el balanceo

Completa [service.yaml](service.yaml) y aplícalo:

```sh
kubectl apply -f service.yaml
kubectl get endpointslices -n lab03 -l kubernetes.io/service-name=hola \
  -o custom-columns=POD:.endpoints[*].targetRef.name,IP:.endpoints[*].addresses[*]
```

Ahora hazte pasar por **otra aplicación del banco**: un Pod temporal que llama 6 veces al Service **por su nombre**, no por IP:

```sh
kubectl run cliente --rm -it --restart=Never --image=busybox:1.36 -n lab03 -- \
  sh -c 'for i in 1 2 3 4 5 6; do wget -qO- http://hola; done'
```

### ¿A quién le llegó cada llamada?

Lo natural sería mirar los logs de las 3 réplicas juntas:

```sh
kubectl logs -n lab03 -l app=hola --prefix
```

**Sale vacío.** No es un error de Kubernetes: tu imagen (Ubuntu + nginx) escribe sus logs en un **archivo** dentro del contenedor (`/var/log/nginx/access.log`), y `kubectl logs` solo ve lo que la app escribe en la **salida estándar** (stdout). Míralo réplica por réplica:

```sh
for p in $(kubectl get pods -n lab03 -l app=hola -o name); do
  echo -n "$p → peticiones: "
  kubectl exec -n lab03 $p -- sh -c 'wc -l < /var/log/nginx/access.log'
done
```

Las 6 llamadas quedaron **repartidas** entre las réplicas. Ese es el balanceo del Service.

### El nombre completo (DNS)

```sh
kubectl run cliente --rm -it --restart=Never --image=busybox:1.36 -n lab03 -- \
  nslookup hola.lab03.svc.cluster.local
```

`hola` (Service) **.** `lab03` (namespace) **.** `svc.cluster.local` (dominio del clúster). Desde el mismo namespace basta con `hola`; desde otro namespace necesitas `hola.lab03`.

> **Desde tu navegador:** `kubectl port-forward svc/hola 8080:80 -n lab03` y abre http://localhost:8080.

---

## Paso 5 · Escalar

### Por comando (rápido, pero no queda escrito)

```sh
kubectl scale deploy/hola --replicas=5 -n lab03
kubectl get pods -n lab03
```

Vuelve a mirar los endpoints del Service del paso 4: ¿cuántos Pods tiene ahora? ¿Tocaste el Service?

Ahora aplica de nuevo el YAML **sin cambiarlo**:

```sh
kubectl apply -f deployment.yaml
kubectl get pods -n lab03
```

¿Cuántas réplicas quedaron? ¿Por qué?

### Por YAML (lo profesional)

Cambia `replicas: 4` en `deployment.yaml` y aplica. Ahora el cambio **queda escrito** y se puede revisar en Git.

---

## Paso 6 · Rolling update: v1 → v2 sin cerrar la sucursal

Abre **dos terminales**.

```sh
# Terminal 1: un "cliente" que llama al Service sin parar
kubectl run cliente --rm -it --restart=Never --image=busybox:1.36 -n lab03 -- \
  sh -c 'while true; do wget -qO- -T 1 http://hola || echo "FALLO"; sleep 0.5; done'
```

```sh
# Terminal 2: cambia la imagen a hola-banco:2.0 en deployment.yaml y aplica
kubectl apply -f deployment.yaml
kubectl annotate deploy/hola -n lab03 kubernetes.io/change-cause="v2.0: nuevo saludo"
kubectl rollout status deploy/hola -n lab03
```

En la terminal 1 verás el cambio gradual de `hello world` a `hello world 2.0`. ¿Apareció algún `FALLO`?

```sh
kubectl get rs -n lab03              # ¿cuántos ReplicaSets hay? ¿cuántas réplicas tiene cada uno?
kubectl rollout history deploy/hola -n lab03
```

> ¿Recuerdas las **annotations** del lab 02? `change-cause` es una: no sirve para filtrar, pero deja escrito **por qué** se hizo cada versión. En un banco, ahí iría el número del ticket de cambio.

---

## Paso 7 · Rómpelo y vuelve atrás

Simula un despliegue con una versión que no existe:

1. En `deployment.yaml` cambia la imagen a `hola-banco:3.0` y aplica.
2. Observa (deja corriendo el cliente de la terminal 1):

```sh
kubectl get pods -n lab03
kubectl rollout status deploy/hola -n lab03 --timeout=20s
```

¿El cliente dejó de recibir respuestas? ¿Cuántos Pods nuevos intentó crear Kubernetes antes de detenerse?

3. Vuelve atrás:

```sh
kubectl rollout undo deploy/hola -n lab03
kubectl rollout status deploy/hola -n lab03
kubectl rollout history deploy/hola -n lab03
```

4. **Importante:** `undo` cambió el clúster, pero tu `deployment.yaml` sigue diciendo `3.0`. Corrígelo a `2.0` para que el archivo vuelva a decir la verdad.

---

## Preguntas para conversar en clase

1. ¿Por qué `minikube image load` es necesario aquí y qué lo reemplaza en EKS, AKS o GKE?
2. Explica la cadena **Deployment → ReplicaSet → Pod** con la analogía del banco. ¿Por qué en el paso 6 quedaron **dos** ReplicaSets?
3. En el paso 3, ¿quién recreó los Pods? ¿Qué cambió en los nuevos (nombre, IP) y qué se mantuvo (labels)?
4. En el paso 5, ¿por qué el Service encontró las réplicas nuevas sin que lo tocaras? ¿Y por qué el `apply` deshizo tu `scale`?
5. En el paso 7, ¿por qué el servicio **no se cayó** aunque la versión 3.0 no existía?
6. `kubectl logs` salió vacío con tu imagen. ¿Qué cambiarías en el Dockerfile y por qué es importante en Kubernetes que las apps escriban en stdout?
7. **Pregunta de arquitecto:** el negocio pide "cero caídas al desplegar". ¿Qué te dio este lab y qué te falta todavía? (pista: temas 15, 17 y 19).

---

## Cierre

Avisa con "Lab 03 terminado" y conversamos las preguntas. Luego:

```sh
kubectl delete namespace lab03
minikube image rm hola-banco:1.0 hola-banco:2.0    # opcional
```

Siguiente: **Lab 04 · Una imagen, muchos entornos** (namespaces, ConfigMap y Secret).
