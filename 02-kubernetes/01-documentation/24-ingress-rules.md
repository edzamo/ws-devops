# 24 · Ingress rules (reglas de enrutamiento)

> **En una frase:** Un objeto Ingress define **reglas HTTP**: "si la petición llega a tal **dominio** y tal **ruta**, envíala a tal **Service**", además de la configuración **TLS**.
>
> **Analogía (contar manzanas):** Es el **directorio del edificio** que usa el recepcionista (tema 23): "**creditos.banco.local** → piso de Créditos"; "**banco.local/pagos** → piso de Pagos"; "lo que no esté en la lista → mesa de información (backend por defecto)".

---

## 1. Problema → solución

| Necesidad | Tipo de regla |
| --- | --- |
| Un dominio por aplicación | **Por host** (*name-based virtual hosting*) |
| Un dominio con varias APIs | **Por ruta** (*fanout*): `/creditos`, `/pagos` |
| HTTPS | Sección `tls` + Secret tipo `kubernetes.io/tls` |
| Respuesta para lo que no coincide | `defaultBackend` |
| Quitar el prefijo antes de llegar a la app | Annotation `rewrite-target` del controlador |

---

## 2. Partes de una regla

```text
 https://creditos.banco.local/api/v1/solicitudes
        └──────── host ───────┘└──── path ────┘
                    │                 │
             rules[].host    rules[].http.paths[].path (+ pathType)
                                      │
                               backend.service.name : port
```

### `pathType`

| pathType | Coincide con `/api` … |
| --- | --- |
| `Prefix` | `/api`, `/api/`, `/api/v1` (por segmentos; **no** `/apiv2`) |
| `Exact` | Solo `/api` |
| `ImplementationSpecific` | Lo decide el controlador (evitar) |

Si varias rutas coinciden, gana **la más larga/específica**.

---

## 3. Manifiestos

### Dos aplicaciones de prueba

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: creditos
spec:
  replicas: 1
  selector:
    matchLabels: { app: creditos }
  template:
    metadata:
      labels: { app: creditos }
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          args: ["-text=Servicio de CREDITOS", "-listen=:8080"]
---
apiVersion: v1
kind: Service
metadata:
  name: creditos
spec:
  selector: { app: creditos }
  ports: [{ port: 80, targetPort: 8080 }]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pagos
spec:
  replicas: 1
  selector:
    matchLabels: { app: pagos }
  template:
    metadata:
      labels: { app: pagos }
    spec:
      containers:
        - name: app
          image: hashicorp/http-echo:1.0
          args: ["-text=Servicio de PAGOS", "-listen=:8080"]
---
apiVersion: v1
kind: Service
metadata:
  name: pagos
spec:
  selector: { app: pagos }
  ports: [{ port: 80, targetPort: 8080 }]
```

### Regla por host y por ruta, con TLS

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: banco
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2     # quita el prefijo /creditos o /pagos
spec:
  ingressClassName: nginx               # qué controlador atiende esta regla
  tls:
    - hosts: ["banco.local"]
      secretName: banco-tls             # Secret tipo kubernetes.io/tls (tema 14)
  rules:
    - host: banco.local                 # 1) fanout por ruta
      http:
        paths:
          - path: /creditos(/|$)(.*)
            pathType: ImplementationSpecific   # requerido al usar expresiones regulares en NGINX
            backend:
              service:
                name: creditos
                port:
                  number: 80
          - path: /pagos(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: pagos
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: por-host
spec:
  ingressClassName: nginx
  rules:
    - host: creditos.banco.local        # 2) un dominio por aplicación
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: creditos
                port:
                  number: 80
    - host: pagos.banco.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: pagos
                port:
                  number: 80
```

---

## 4. Práctica en Minikube

```sh
minikube addons enable ingress
kubectl apply -f apps.yaml

# Certificado autofirmado para el laboratorio
openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=banco.local"
kubectl create secret tls banco-tls --cert=tls.crt --key=tls.key

kubectl apply -f ingress.yaml
kubectl get ingress                     # esperar ADDRESS
kubectl describe ingress banco

# Probar sin tocar /etc/hosts (enviando el Host a mano)
IP=$(minikube ip)
curl -k https://$IP/creditos -H "Host: banco.local"        # Servicio de CREDITOS
curl -k https://$IP/pagos    -H "Host: banco.local"        # Servicio de PAGOS
curl http://$IP/ -H "Host: creditos.banco.local"           # Servicio de CREDITOS
curl http://$IP/ -H "Host: otro.local"                     # 404 del controlador

# O agregar al /etc/hosts:  <minikube ip>  banco.local creditos.banco.local pagos.banco.local
```

> Con el driver `docker` en macOS/Windows la IP del nodo no es alcanzable: usa `minikube tunnel` y `127.0.0.1`.

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| 404 en todas las rutas | El `Host` no coincide con `rules[].host` | Enviar el Host correcto / `/etc/hosts` |
| La app recibe `/creditos/...` y responde 404 | No se reescribe el prefijo | `rewrite-target` o que la app use ese prefijo como *base path* |
| Certificado incorrecto | `secretName` inexistente → certificado por defecto del controlador | Crear el Secret TLS en el **mismo namespace** del Ingress |
| Ingress de otro namespace no ve mi Service | Un Ingress solo apunta a Services de **su** namespace | Un Ingress por namespace |

---

## 6. Lo que debe saber el arquitecto

- **Diseño de dominios y rutas = contrato público.** Decide con el negocio: `api.banco.com/creditos/v1` vs. `creditos.api.banco.com`. Cambiarlo después rompe clientes.
- **TLS automatizado:** cert-manager con una CA corporativa o Let's Encrypt; rotación automática. Certificados vencidos son una causa clásica de incidentes.
- **Ingress no es un API Gateway completo:** autenticación OAuth2/JWT, cuotas por cliente, monetización y catálogo de APIs se resuelven con un API Gateway (Kong, Apigee, Azure API Management, Amazon API Gateway) delante o integrado.
- Las reglas avanzadas (canary por peso, cabeceras) dependen de annotations del controlador; **Gateway API** las estandariza con `HTTPRoute` (tema 23).

---

## 7. Checklist junior → senior

- [ ] **Junior:** creo reglas por host y por ruta y las pruebo con `curl`.
- [ ] **Semi-senior:** configuro TLS, reescritura y backend por defecto; diagnostico 404/503.
- [ ] **Senior:** diseño la estrategia de dominios, TLS automatizado y la relación Ingress/Gateway/API Gateway/WAF.

---

← [23 · NGINX Ingress Controller](23-ingress-controller-nginx.md) · [Índice](../README.md) · Siguiente → [25 · Edit y patch](25-edit-y-patch.md)
