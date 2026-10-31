# 22 · Annotations

> **En una frase:** Las annotations son pares clave-valor en `metadata` para **describir o configurar** un objeto; a diferencia de los labels, **no sirven para seleccionar**, pero las herramientas las leen para cambiar su comportamiento.
>
> **Analogía (contar manzanas):** El **label** es el gafete (sirve para llamar: "todos los de créditos"). La **annotation** es el **post-it pegado en la carpeta del empleado**: "responsable: Ana", "última auditoría: marzo", "atender en inglés". Nadie llama a la gente por su post-it, pero quien lo lee sabe qué hacer.

---

## 1. Labels vs. annotations

| | Labels | Annotations |
| --- | --- | --- |
| ¿Sirven para selectores? | **Sí** | No |
| Tamaño | Cortos (63 caracteres por valor) | Pueden ser grandes (hasta 256 KB en total) |
| Uso | Agrupar, conectar, filtrar | Describir, auditar, **configurar herramientas** |
| Ejemplo | `app: credito-api` | `nginx.ingress.kubernetes.io/rewrite-target: /` |

---

## 2. Problema → solución

| Necesidad | Annotation (ejemplos reales) |
| --- | --- |
| Documentar dueño, contacto y ticket del cambio | `ejemplo.com/owner`, `kubernetes.io/change-cause` |
| Configurar el Ingress Controller | `nginx.ingress.kubernetes.io/rewrite-target`, `.../ssl-redirect` |
| Que el balanceador de la nube sea **interno** | AWS: `service.beta.kubernetes.io/aws-load-balancer-scheme: internal` · Azure: `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` · GCP: `networking.gke.io/load-balancer-type: "Internal"` |
| Que Prometheus recolecte métricas | `prometheus.io/scrape: "true"` (convención común) |
| Pedir un certificado TLS automático | `cert-manager.io/cluster-issuer: letsencrypt` |
| Forzar un reinicio (lo hace `rollout restart`) | `kubectl.kubernetes.io/restartedAt` |
| Registro de `kubectl apply` | `kubectl.kubernetes.io/last-applied-configuration` (tema 03) |

> Una annotation **solo tiene efecto si alguna herramienta la lee**. Escribir `nginx.ingress.kubernetes.io/...` en un clúster sin NGINX Ingress no hace nada.

---

## 3. Manifiesto comentado

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: credito-web
  labels:
    app: credito-web                         # para seleccionar
  annotations:                               # para describir
    ejemplo.com/owner: "squad-creditos"
    ejemplo.com/contacto: "creditos-oncall@ejemplo.com"
    ejemplo.com/repositorio: "https://github.com/ejemplo/credito-web"
    kubernetes.io/change-cause: "v1.0.1 - corrige cálculo de cuota"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: credito-web
  template:
    metadata:
      labels:
        app: credito-web
      annotations:                           # annotations del Pod (las leen agentes del nodo)
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
    spec:
      containers:
        - name: web
          image: nginx:1.27
```

Formato de la clave: `prefijo-dns/nombre`. Usa un **prefijo propio** (`ejemplo.com/…`) para tus annotations y no choques con las de Kubernetes (`kubernetes.io/`, `k8s.io/`).

---

## 4. Práctica en Minikube

```sh
kubectl apply -f annotations.yaml
kubectl annotate deployment credito-web ejemplo.com/ticket="CHG-1234"            # agregar
kubectl annotate deployment credito-web ejemplo.com/ticket="CHG-1250" --overwrite
kubectl annotate deployment credito-web ejemplo.com/ticket-                      # quitar

kubectl get deployment credito-web -o jsonpath='{.metadata.annotations}'
kubectl describe deployment credito-web | grep -A6 Annotations
kubectl rollout history deployment/credito-web          # muestra change-cause
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| La annotation "no funciona" | Ninguna herramienta la lee, o se puso en el objeto equivocado (Deployment vs. Pod vs. Ingress) | Revisar la documentación de la herramienta |
| `metadata.annotations: Invalid value` | Valor no-texto (`true`, `80` sin comillas) | Valores siempre entre comillas |
| Quise filtrar con `-l` por annotation | Las annotations no son seleccionables | Usar un label |

---

## 6. Lo que debe saber el arquitecto

- **Las annotations son la "API extendida"** de muchas herramientas (Ingress, balanceadores de nube, service mesh, cert-manager). Gran parte de la configuración específica de cada nube vive aquí: es donde aparece el *lock-in* y donde hay que documentar las diferencias entre EKS, AKS y GKE.
- **Metadatos de gobierno:** dueño, criticidad, clasificación de datos, ticket de cambio. Se pueden exigir con políticas (Kyverno/OPA) como requisito de auditoría.
- **Nunca secretos en annotations**: cualquiera con permiso de lectura del objeto los ve.

---

## 7. Checklist junior → senior

- [ ] **Junior:** distingo label de annotation y agrego/quito annotations.
- [ ] **Semi-senior:** uso annotations para configurar Ingress y balanceadores.
- [ ] **Senior:** defino annotations obligatorias de gobierno y documento las específicas de cada nube.

---

← [21 · CronJobs](21-cronjobs.md) · [Índice](../README.md) · Siguiente → [23 · NGINX Ingress Controller](23-ingress-controller-nginx.md)
