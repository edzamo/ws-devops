# 03 · Manifiesto vs. comandos y configuración declarativa

> **En una frase:** Puedes darle órdenes a Kubernetes **una por una** (imperativo) o entregarle un **documento con el estado final que quieres** (declarativo); en empresas serias se usa el segundo.
>
> **Analogía (contar manzanas):**
> - **Imperativo** = decirle al cajero en voz alta: "pon una manzana, pon otra, quita una". Nadie lo anotó; mañana nadie sabe por qué hay 1 manzana.
> - **Declarativo** = entregar un **contrato firmado**: "en esta canasta debe haber 3 manzanas rojas". Cualquiera puede leerlo, revisarlo y repetirlo, y el banco se encarga de cumplirlo.

---

## 1. Las tres formas de trabajar

| Forma | Ejemplo | ¿Queda registro? | Uso recomendado |
| --- | --- | --- | --- |
| Comandos imperativos | `kubectl run web --image=nginx` | No | Pruebas rápidas, diagnóstico |
| Imperativo con archivo | `kubectl create -f web.yaml` | Sí, pero falla si ya existe | Casi nunca |
| **Declarativo** | `kubectl apply -f web.yaml` | **Sí, en Git** | **Siempre en entornos reales** |

### Imperativo

```sh
kubectl run mi-pod --image=nginx:1.27
kubectl create deployment web --image=nginx:1.27 --replicas=2
kubectl expose deployment web --port=80
kubectl scale deployment web --replicas=3
kubectl delete deployment web
```

### Declarativo

```yaml
# web.yaml — "el contrato"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
```

```sh
kubectl apply -f web.yaml       # crea si no existe, actualiza si cambió, no hace nada si es igual
kubectl delete -f web.yaml      # borra lo que el archivo describe
```

---

## 2. Anatomía de un manifiesto (las 4 partes que siempre están)

```yaml
# fragmento
apiVersion: apps/v1     # 1. ¿Qué versión del "formulario" uso?  (v1, apps/v1, batch/v1, networking.k8s.io/v1)
kind: Deployment        # 2. ¿Qué tipo de objeto es?             (Pod, Service, Deployment...)
metadata:               # 3. ¿Cómo se llama y cómo lo identifico? (name, namespace, labels, annotations)
  name: web
spec:                   # 4. ¿Qué estado DESEO?                   (lo escribes tú)
  replicas: 3
# status:               #    ¿Qué estado HAY?  (lo escribe Kubernetes; nunca lo pongas tú)
```

`spec` = lo que pides. `status` = lo que hay. Kubernetes trabaja para que `status` se parezca a `spec`.

Para saber qué campos existen sin buscar en internet:

```sh
kubectl api-resources                      # todos los tipos de objeto y su apiVersion
kubectl explain deployment.spec            # documentación de cada campo
kubectl explain deployment.spec.strategy --recursive
```

---

## 3. Configuración declarativa en profundidad

### 3.1 Generar YAML sin escribirlo a mano

El truco más útil: usar un comando imperativo para **generar** el manifiesto, guardarlo y desde ahí trabajar declarativamente.

```sh
kubectl create deployment web --image=nginx:1.27 --replicas=3 \
  --dry-run=client -o yaml > web.yaml
```

### 3.2 Ver qué va a cambiar antes de aplicar

```sh
kubectl diff -f web.yaml                    # como un "git diff" contra el clúster
kubectl apply -f web.yaml --dry-run=server  # el servidor valida sin guardar nada
```

### 3.3 Aplicar carpetas completas

```sh
kubectl apply -f ./manifiestos/            # todos los YAML de la carpeta
kubectl apply -f ./manifiestos/ -R         # recursivo
kubectl apply -k ./overlays/dev            # Kustomize: base común + diferencias por entorno
```

Varios objetos pueden ir en un solo archivo separados por `---`.

### 3.4 ¿Cómo sabe `apply` qué borrar? (three-way merge)

`kubectl apply` compara **tres** versiones:

1. Lo que aplicaste la vez anterior (guardado en la anotación `kubectl.kubernetes.io/last-applied-configuration`).
2. Lo que dice tu archivo ahora.
3. Lo que hay vivo en el clúster.

Así distingue "este campo lo quitaste a propósito" de "este campo lo puso Kubernetes". La variante moderna es **Server-Side Apply** (`kubectl apply --server-side`), donde el servidor registra qué herramienta es "dueña" de cada campo (`managedFields`) y avisa si dos herramientas pelean por el mismo campo.

### 3.5 De `apply` manual a GitOps

```text
 Nivel 1: kubectl apply desde mi laptop          → aprendizaje
 Nivel 2: pipeline CI/CD ejecuta kubectl apply   → automatizado, auditable
 Nivel 3: GitOps (Argo CD / Flux)                → el clúster se sincroniza solo con Git;
                                                   Git es la única fuente de verdad
```

---

## 4. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `AlreadyExists` | Usaste `create` sobre algo existente | Usa `apply` |
| `error validating data` | Indentación YAML o campo mal escrito | `kubectl apply --dry-run=server -f` y `kubectl explain` |
| Cambio "se revierte solo" | Alguien editó a mano y el pipeline/GitOps volvió a aplicar Git | Cambia el archivo en Git, no el clúster |
| Mezclar `create`/`edit` con `apply` | La anotación *last-applied* queda desactualizada | Elige un modo: declarativo |

---

## 5. Lo que debe saber el arquitecto

- **Infraestructura como código aplicada a la plataforma:** el YAML es el contrato versionado, revisado por *pull request* y aprobado. Eso es lo que un auditor pide en banca: **quién cambió qué, cuándo y quién lo aprobó**.
- **Drift (desviación):** cualquier cambio manual hace que el clúster deje de coincidir con Git. GitOps detecta y corrige el *drift* automáticamente.
- **Imperativo solo para leer y diagnosticar** (`get`, `describe`, `logs`, `exec`). Para escribir, declarativo.
- **Estructura de repositorio:** base común + *overlays* por entorno (Kustomize) o plantillas (Helm). Evita copiar y pegar el mismo YAML para dev, qa y prod.

---

## 6. Checklist junior → senior

- [ ] **Junior:** escribo un manifiesto con sus 4 partes y lo aplico con `apply`.
- [ ] **Semi-senior:** genero YAML con `--dry-run=client -o yaml`, uso `diff` antes de aplicar y organizo carpetas.
- [ ] **Senior:** diseño el flujo Git → pipeline → clúster (GitOps), con aprobaciones y detección de *drift*.

---

← [02 · Configuración y perfiles](02-minikube-configuracion-y-perfiles.md) · [Índice](../README.md) · Siguiente → [04 · Pods](04-pods.md)
