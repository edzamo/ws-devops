# Lab 02 · Labels y selectores

| Nivel | Duración | Temas de apoyo |
| --- | --- | --- |
| Junior | 45-60 min | [05 · Metadata, labels y selectores](../../01-documentation/05-metadata-labels-selectores.md) · [10 · Services](../../01-documentation/10-services.md) · [22 · Annotations](../../01-documentation/22-annotations.md) |

## La historia

El banco ya tiene varias ventanillas (Pods) de distintas áreas y entornos. El gerente no las llama por nombre: las llama por **gafete** (`app=credito`, `entorno=dev`). Hoy vas a ponerles gafetes, buscarlas con filtros y descubrir algo que inquieta a cualquier auditor: **quien tenga el gafete correcto recibe los clientes**, sea quien sea.

## Objetivos

- Poner, cambiar y quitar labels.
- Filtrar Pods con selectores de igualdad y de conjunto.
- Ver cómo un **Service elige sus Pods por labels** (endpoints).
- Provocar y corregir un **selector demasiado amplio** que mezcla entornos.
- Ver cómo un Pod "intruso" se cuela en un Service.
- Distinguir label de annotation.

---

## Paso 0 · Preparar el terreno

```sh
kubectl config current-context        # minikube
kubectl create namespace lab02
```

---

## Paso 1 · Cuatro ventanillas con gafete

Completa [pods.yaml](pods.yaml). El primer Pod ya está hecho como ejemplo; los otros tres llevan `TODO`.

| Pod | `app` | `entorno` | `tier` |
| --- | --- | --- | --- |
| `credito-dev` | credito | dev | backend |
| `credito-qa` | credito | qa | backend |
| `pagos-dev` | pagos | dev | backend |
| `web-dev` | web | dev | frontend |

```sh
kubectl apply -f pods.yaml --dry-run=server
kubectl apply -f pods.yaml
kubectl get pods -n lab02 --show-labels
kubectl get pods -n lab02 -L app,entorno,tier       # labels como columnas
```

---

## Paso 2 · Buscar por gafete

Escribe **el comando** para cada búsqueda y anota **qué Pods** devuelve:

| # | Quiero encontrar… | Pista |
| --- | --- | --- |
| a | Todos los Pods de `dev` | igualdad: `-l clave=valor` |
| b | Todos los Pods que **no** son de `dev` | `!=` |
| c | Los de `credito` en `dev` | dos condiciones separadas por coma |
| d | Los que están en `dev` **o** en `qa` | conjunto: `'clave in (a,b)'` |
| e | Los `backend` que **no** son de `pagos` | combina `tier` y `notin` |
| f | Los que **tienen** el label `tier`, valga lo que valga | solo la clave: `-l tier` |

> Usa comillas simples cuando el selector tenga espacios o paréntesis.

---

## Paso 3 · Cambiar gafetes en caliente

```sh
# Agregar version=v1 a TODOS los Pods de dev con un solo comando
kubectl label pods -n lab02 -l entorno=dev version=v1

# Cambiar la versión de web-dev (sin --overwrite falla: ¿por qué?)
kubectl label pod web-dev -n lab02 version=v2
kubectl label pod web-dev -n lab02 version=v2 --overwrite

# Quitar el label version de pagos-dev (guion al final)
kubectl label pod pagos-dev -n lab02 version-

kubectl get pods -n lab02 -L version
```

---

## Paso 4 · El Service elige por labels (y se equivoca)

Completa [service.yaml](service.yaml): un Service llamado `credito` que seleccione los Pods con `app: credito`. **Solo** ese label, por ahora.

```sh
kubectl apply -f service.yaml
kubectl get endpointslices -n lab02 -l kubernetes.io/service-name=credito \
  -o custom-columns=POD:.endpoints[*].targetRef.name
```

¿Cuántos Pods recibe el Service? ¿De qué entornos son?

Ahora **corrige** el selector de `service.yaml` para que el Service de crédito **de desarrollo** solo envíe tráfico a Pods de `dev`. Aplica y vuelve a mirar los endpoints: debe quedar **solo** `credito-dev`.

---

## Paso 5 · El intruso

Alguien crea un Pod cualquiera con el gafete "correcto":

```sh
kubectl run intruso -n lab02 --image=nginx:1.27 --labels=app=credito,entorno=dev
kubectl get endpointslices -n lab02 -l kubernetes.io/service-name=credito \
  -o custom-columns=POD:.endpoints[*].targetRef.name
```

¿Qué pasó? Ahora **sácalo del Service sin borrarlo**, solo con un label (pista: quitar `app`). Confirma con los endpoints que vuelve a quedar solo `credito-dev`, y que `intruso` sigue corriendo.

---

## Paso 6 · Label vs. annotation

```sh
kubectl annotate pod credito-dev -n lab02 ejemplo.com/owner="squad-creditos"
kubectl get pods -n lab02 -l ejemplo.com/owner=squad-creditos      # ¿qué devuelve?
kubectl get pod credito-dev -n lab02 -o jsonpath='{.metadata.annotations}'; echo
```

---

## Paso 7 · Borrar por label (con cuidado)

Borrar por label es potente y peligroso: primero **simula**, luego ejecuta.

```sh
kubectl delete pods -n lab02 -l entorno=qa --dry-run=server     # ¿qué borraría?
kubectl delete pods -n lab02 -l entorno=qa
kubectl get pods -n lab02 --show-labels
```

---

## Preguntas para conversar en clase

1. Con tus palabras: ¿qué es un label y qué es un selector? Usa la analogía del gafete.
2. ¿Qué comandos usaste en las búsquedas a-f del paso 2 y qué devolvió cada uno?
3. En el paso 4, el Service mezclaba `dev` y `qa`. En un banco, ¿qué problema de negocio podría causar un selector así en producción?
4. En el paso 5, ¿por qué el intruso empezó a recibir tráfico? Menciona **dos** controles que lo evitarían en un clúster real (pista: temas 05, 09 y 14 de la documentación).
5. ¿Por qué el filtro por `ejemplo.com/owner` no devolvió nada? ¿Cuándo usarías label y cuándo annotation?
6. **Pregunta de arquitecto:** propone los **5 labels obligatorios** que exigirías a todo Pod del banco y explica para qué sirve cada uno (costos, seguridad, operación...).

---

## Cierre

Avisa con "Lab 02 terminado": revisamos `pods.yaml`, `service.yaml` y conversamos las preguntas. Luego:

```sh
kubectl delete namespace lab02
```

Siguiente: **Lab 03 · De Docker a Kubernetes** (tu propio Dockerfile corriendo como Pod).
