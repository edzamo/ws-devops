# 25 · `kubectl edit` y `kubectl patch`

> **En una frase:** `edit` abre el objeto vivo en un editor para cambiarlo a mano; `patch` aplica un **cambio puntual** desde la línea de comandos. Ambos modifican el clúster **directamente**, sin pasar por Git.
>
> **Analogía (contar manzanas):** El manifiesto en Git es el **contrato original**. `edit` es **tachar y reescribir el contrato** en la ventanilla. `patch` es **pegar una enmienda**: "en la cláusula 3, donde dice 3 manzanas, ahora dice 5". Rápido… pero si nadie actualiza el contrato original, mañana el banco vuelve a lo que dice el original.

---

## 1. Problema → solución (y su riesgo)

| Situación | Herramienta | Riesgo |
| --- | --- | --- |
| Explorar o corregir algo en un laboratorio | `kubectl edit` | Bajo (es un lab) |
| Cambio puntual y repetible en un script o pipeline | `kubectl patch` | Medio: debe quedar documentado |
| Incidente en producción: subir réplicas **ya** | `kubectl scale` / `patch` | El cambio se pierde o genera *drift* si no se lleva a Git |
| Cambio normal | **Editar el YAML en Git y `apply`** | El camino correcto |

---

## 2. `kubectl edit`

```sh
kubectl edit deployment web                     # abre el editor (vi por defecto)
KUBE_EDITOR="code --wait" kubectl edit deploy web   # con VS Code
kubectl edit configmap credito-config -n credito-dev
```

- Al guardar y cerrar, se aplica. Si hay un error de validación, `kubectl` reabre el archivo con el error comentado.
- Algunos campos son **inmutables** (por ejemplo `spec.selector` de un Deployment, la mayor parte del `spec` de un Pod): el cambio se rechaza.

---

## 3. `kubectl patch`: los tres tipos

| Tipo | Bandera | Cómo trata las listas | Cuándo |
| --- | --- | --- | --- |
| **Strategic merge** (defecto) | `--type=strategic` | Inteligente: une listas por su clave (`name` del contenedor) | Objetos nativos de Kubernetes |
| **JSON merge** (RFC 7386) | `--type=merge` | **Reemplaza** listas completas | CRDs u objetos simples |
| **JSON patch** (RFC 6902) | `--type=json` | Operaciones exactas por ruta (`add`, `replace`, `remove`) | Cambios quirúrgicos en un índice concreto |

```sh
# Strategic merge: cambiar réplicas
kubectl patch deployment web -p '{"spec":{"replicas":5}}'

# Strategic merge: cambiar la imagen del contenedor "nginx" (une por nombre, no borra otros contenedores)
kubectl patch deployment web -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.28"}]}}}}'

# JSON merge: pausar un CronJob
kubectl patch cronjob cierre-diario --type=merge -p '{"spec":{"suspend":true}}'

# JSON patch: reemplazar la imagen del primer contenedor por su posición
kubectl patch deployment web --type=json \
  -p '[{"op":"replace","path":"/spec/template/spec/containers/0/image","value":"nginx:1.27"}]'

# Desde un archivo
kubectl patch deployment web --patch-file parche.yaml

# Ver el resultado sin aplicarlo
kubectl patch deployment web -p '{"spec":{"replicas":2}}' --dry-run=server -o yaml
```

### Atajos imperativos (son "patches" con nombre)

```sh
kubectl scale deployment web --replicas=3
kubectl set image deployment/web nginx=nginx:1.28
kubectl set resources deployment web -c nginx --requests=cpu=100m,memory=128Mi
kubectl set env deployment/web LOG_LEVEL=DEBUG
kubectl label / kubectl annotate ...
```

### Patches declarativos (la forma correcta a escala)

Kustomize usa *patches* dentro de Git para expresar "producción = base + estas diferencias":

```yaml
# fragmento: overlays/prod/kustomization.yaml
resources:
  - ../../base
patches:
  - target:
      kind: Deployment
      name: web
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 6
```

---

## 4. Práctica en Minikube

```sh
kubectl create deployment web --image=nginx:1.27 --replicas=2
kubectl patch deployment web -p '{"spec":{"replicas":4}}'
kubectl get deploy web

kubectl edit deployment web          # cambia replicas a 1, guarda y sal
kubectl get deploy web

# Ver el drift: el archivo original dice otra cosa
kubectl create deployment web --image=nginx:1.27 --replicas=2 --dry-run=client -o yaml > web.yaml
kubectl diff -f web.yaml             # muestra la diferencia entre Git (archivo) y el clúster
kubectl apply -f web.yaml            # vuelve al estado del archivo
kubectl delete deployment web
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `field is immutable` | Campo que no se puede cambiar | Recrear el objeto |
| El patch borró otros contenedores | Usaste `--type=merge` con una lista | Strategic merge (defecto) o JSON patch |
| El cambio "desapareció" | Se volvió a aplicar el YAML de Git / GitOps lo revirtió | Hacer el cambio en Git |
| Error de comillas en el JSON | Shell interpretando caracteres | Comillas simples por fuera; o `--patch-file` |

---

## 6. Lo que debe saber el arquitecto

- **`edit` y `patch` en producción = cambio fuera de proceso.** En banca, todo cambio productivo debe ser trazable a un ticket y a un commit aprobado. Política recomendada: en producción solo lectura para personas; escritura únicamente para el pipeline/GitOps; excepciones *break-glass* auditadas y llevadas a Git después.
- **GitOps convierte el drift en un evento visible:** Argo CD marca *OutOfSync* y puede revertir automáticamente un `edit` manual.
- `patch` sí tiene un lugar legítimo: **automatización** (pipelines, operadores, scripts de respuesta a incidentes) y **Kustomize** (parches versionados por entorno).

---

## 7. Checklist junior → senior

- [ ] **Junior:** uso `edit` y `patch` simples, y `scale`/`set image`.
- [ ] **Semi-senior:** distingo strategic/merge/json patch y uso `diff` para detectar drift.
- [ ] **Senior:** defino la política de cambios (Git como única fuente de verdad, *break-glass*) y uso parches declarativos por entorno.

---

← [24 · Ingress rules](24-ingress-rules.md) · [Índice](../README.md) · Siguiente → [26 · Kubernetes en la nube: EKS, AKS y GKE](26-kubernetes-en-la-nube-eks-aks-gke.md)
