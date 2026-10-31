# 09 · Namespaces

> **En una frase:** Un namespace es una **división lógica** del clúster: agrupa objetos, evita choques de nombres y permite aplicar permisos, cuotas y reglas de red por grupo.
>
> **Analogía (contar manzanas):** El clúster es el **edificio del banco**; cada namespace es un **piso o departamento**: piso de Créditos, piso de Tesorería. En cada piso puede haber una oficina llamada "recepción" sin confundirse con la del otro piso. Cada piso tiene su presupuesto (cuota) y sus llaves (permisos).

---

## 1. Problema → solución

| Problema | Solución con namespaces |
| --- | --- |
| Dos equipos quieren un Service llamado `api` | Cada uno en su namespace: `creditos/api` y `tesoreria/api` |
| Un equipo consume todo el clúster | `ResourceQuota` por namespace |
| Todos pueden borrar todo | `RBAC` (Role + RoleBinding) por namespace |
| Cualquier Pod puede llamar a cualquier Pod | `NetworkPolicy` por namespace |
| Quiero borrar un entorno de pruebas completo | `kubectl delete namespace pruebas-123` |

---

## 2. Namespaces que ya existen

| Namespace | Contenido |
| --- | --- |
| `default` | Donde cae todo si no indicas namespace (evítalo en serio) |
| `kube-system` | Componentes del clúster (DNS, kube-proxy...). No tocar |
| `kube-public` | Información pública del clúster |
| `kube-node-lease` | Latidos de los nodos |

**No todo vive en un namespace.** Nodos, PersistentVolumes, StorageClasses, IngressClasses y los propios Namespaces son objetos **de clúster**:

```sh
kubectl api-resources --namespaced=true     # objetos que viven en un namespace
kubectl api-resources --namespaced=false    # objetos de todo el clúster
```

---

## 3. Manifiestos

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: credito-dev
  labels:
    entorno: dev
    pod-security.kubernetes.io/enforce: restricted   # estándar de seguridad de Pods
---
apiVersion: v1
kind: ResourceQuota              # el "presupuesto" del piso
metadata:
  name: cuota
  namespace: credito-dev
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "30"
---
apiVersion: v1
kind: LimitRange                 # valores por defecto para cada contenedor
metadata:
  name: limites-por-defecto
  namespace: credito-dev
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      default:
        cpu: 500m
        memory: 512Mi
```

---

## 4. DNS entre namespaces

Cada Service recibe un nombre DNS:

```text
 <servicio>.<namespace>.svc.cluster.local

 Desde credito-dev:   http://api                         → api en MI namespace
 Desde otro lado:     http://api.credito-dev              → api en credito-dev
 Nombre completo:     http://api.credito-dev.svc.cluster.local
```

> El namespace **no aísla la red por sí solo**: un Pod de `tesoreria` puede llamar a `api.credito-dev` salvo que exista una **NetworkPolicy** que lo impida (y un plugin de red que las aplique, como Calico o Cilium).

---

## 5. Práctica en Minikube

```sh
kubectl create namespace credito-dev           # imperativo
kubectl apply -f namespace.yaml                # declarativo
kubectl get namespaces

kubectl get pods -n credito-dev                # en un namespace
kubectl get pods -A                            # en todos

# Cambiar el namespace por defecto del contexto actual
kubectl config set-context --current --namespace=credito-dev
kubectl config view --minify | grep namespace

kubectl describe quota -n credito-dev          # consumo vs. presupuesto
kubectl delete namespace credito-dev           # ⚠ borra TODO lo que contiene
```

---

## 6. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| "No encuentro mi Pod" | Está en otro namespace | `kubectl get pods -A` |
| `forbidden: exceeded quota` | Superaste la `ResourceQuota` | Ajustar requests o la cuota |
| `must specify requests` con cuota activa | Hay cuota y el Pod no declara recursos | Agregar `LimitRange` o recursos al Pod |
| Namespace queda en `Terminating` | Algún objeto tiene *finalizers* pendientes | Revisar los objetos que quedan dentro |

---

## 7. Lo que debe saber el arquitecto

- **Namespace = límite blando (soft multitenancy).** Sirve para equipos de la misma organización. Para aislamiento fuerte (clientes distintos, PCI vs. no PCI, producción vs. no producción) se usan **clústeres separados**.
- Patrones de diseño comunes:
  - **Por sistema/equipo** dentro de un clúster por entorno: `creditos`, `pagos`, `canales` (recomendado en banca).
  - Por entorno dentro de un mismo clúster (`dev`, `qa`): aceptable solo en no-producción.
- Todo namespace productivo nace con su **kit**: ResourceQuota, LimitRange, RBAC, NetworkPolicy por defecto "denegar todo" y nivel de Pod Security. Automatízalo (plantilla o *operator*).

---

## 8. Checklist junior → senior

- [ ] **Junior:** creo namespaces, trabajo con `-n` y cambio el namespace del contexto.
- [ ] **Semi-senior:** aplico ResourceQuota y LimitRange; resuelvo DNS entre namespaces.
- [ ] **Senior:** diseño la estrategia de multitenencia (namespaces vs. clústeres) con RBAC y NetworkPolicy.

---

← [08 · ReplicaSet](08-replicaset.md) · [Índice](../README.md) · Siguiente → [10 · Services](10-services.md)
