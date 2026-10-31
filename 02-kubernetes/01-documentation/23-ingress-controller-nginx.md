# 23 · NGINX Ingress Controller

> **En una frase:** El Ingress Controller es un **proxy inverso que corre dentro del clúster** y es la puerta de entrada HTTP/HTTPS: recibe todo el tráfico externo y lo reparte a los Services según las reglas Ingress (tema 24).
>
> **Analogía (contar manzanas):** En lugar de que cada departamento tenga **su propia puerta a la calle** (un LoadBalancer por servicio, caro), el edificio tiene **una sola recepción** (el Ingress Controller). El recepcionista lee el **directorio** (las reglas Ingress): "¿créditos? piso 3; ¿pagos? piso 5".

---

## 1. Problema → solución

| Problema | Solución |
| --- | --- |
| 10 microservicios = 10 balanceadores públicos = 10 costos y 10 IPs | **Un** balanceador → Ingress Controller → 10 Services |
| Enrutar por dominio (`api.banco.com`) o ruta (`/creditos`) | Reglas Ingress (capa 7) |
| HTTPS en un solo lugar | Terminación TLS en el Ingress Controller |
| Límites de tasa, CORS, redirecciones, tamaños de petición | Configuración del controlador (annotations) |

---

## 2. Objeto Ingress ≠ Ingress Controller

```text
  Internet
     │
  LoadBalancer / NodePort  (uno solo)
     │
 ┌───▼──────────────────────────┐
 │ Ingress Controller (Pods NGINX) │ ◄── lee los objetos Ingress del clúster
 └───┬──────────────┬───────────┘
     │ /creditos    │ /pagos
  Service A      Service B
     │              │
   Pods           Pods
```

| Pieza | Qué es |
| --- | --- |
| **Objeto `Ingress`** | Solo un **documento de reglas** (YAML). Por sí solo no hace nada |
| **Ingress Controller** | El **software** que lee esas reglas y enruta (NGINX, Traefik, HAProxy, controladores de nube) |
| **`IngressClass`** | Dice qué controlador atiende cada Ingress (`ingressClassName: nginx`) |

> **Sin controlador instalado, un Ingress no hace nada.** Kubernetes no trae uno por defecto.

---

## 3. Instalarlo en Minikube

```sh
minikube addons enable ingress
kubectl get pods -n ingress-nginx                 # ingress-nginx-controller Running
kubectl get ingressclass                          # nginx
kubectl get svc -n ingress-nginx                  # el Service de entrada del controlador
```

En un clúster real se instala con Helm:

```sh
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```

---

## 4. Estado del proyecto (importante en 2026)

- Existen **dos** controladores NGINX distintos: el comunitario **`ingress-nginx`** (Kubernetes, el del addon de Minikube; annotations `nginx.ingress.kubernetes.io/…`) y el de la empresa F5/NGINX (**NGINX Ingress Controller**, annotations `nginx.org/…`). No son intercambiables.
- El proyecto comunitario **`ingress-nginx` fue retirado por Kubernetes en marzo de 2026**: ya no recibe nuevas versiones ni parches de seguridad (las instalaciones existentes siguen funcionando y las imágenes siguen disponibles). Para aprender sigue siendo perfecto (es el estándar de facto y el que más verás en sistemas existentes), pero **para diseños nuevos** la recomendación es **Gateway API** (el sucesor del Ingress) o un controlador mantenido. Ninguna alternativa es un reemplazo directo: migrar requiere traducir reglas y annotations.
- Fuentes oficiales: [Ingress NGINX Retirement: What You Need to Know (nov. 2025)](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) · [Statement from the Steering and Security Response Committees (ene. 2026)](https://kubernetes.io/blog/2026/01/29/ingress-nginx-statement/).
- ¿Lo uso en un clúster? `kubectl get pods -A --selector app.kubernetes.io/name=ingress-nginx`

| Opción para producción | Comentario |
| --- | --- |
| **Gateway API** (Envoy Gateway, Istio, Cilium, NGINX Gateway Fabric, Traefik…) | Estándar nuevo: separa rol de plataforma (Gateway) y de aplicación (HTTPRoute); soporta pesos (canary) nativos |
| Controladores de la nube | AWS Load Balancer Controller (ALB), Application Gateway for Containers (Azure), GKE Gateway / Ingress |
| Traefik, HAProxy, Kong, NGINX (F5) | Alternativas mantenidas que soportan Ingress y/o Gateway API |

```text
 Ingress (antiguo)               Gateway API (nuevo)
 ─────────────────               ────────────────────
 IngressClass                    GatewayClass   → qué implementación (plataforma)
 Ingress (todo junto)            Gateway        → puertos, TLS, IP (plataforma)
                                 HTTPRoute      → rutas de cada app (equipos)
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| El Ingress no tiene `ADDRESS` | No hay controlador o `ingressClassName` incorrecto | `minikube addons enable ingress`; revisar `kubectl get ingressclass` |
| `404 Not Found` de NGINX | Ninguna regla coincide con el host/ruta | Revisar `host` y `path` (tema 24) |
| `503 Service Temporarily Unavailable` | El Service no tiene endpoints | Revisar Service y readiness |
| Annotation ignorada | Annotation de otro controlador (`nginx.org` vs `nginx.ingress.kubernetes.io`) | Usar la del controlador instalado |

---

## 6. Lo que debe saber el arquitecto

- **El Ingress Controller es un componente crítico compartido:** si cae, cae todo el tráfico HTTP. Réplicas ≥ 2, anti-affinity, PDB, recursos y monitoreo propios.
- **Es la frontera de seguridad:** TLS, cabeceras, límites de tasa. En banca, delante suele ir un **WAF** (AWS WAF, Azure WAF / Front Door, Cloud Armor) y el controlador queda en red privada.
- **Ciclo de vida de componentes de plataforma:** el retiro de `ingress-nginx` es el ejemplo perfecto de por qué un arquitecto vigila el estado de soporte de cada pieza y planifica migraciones (Ingress → Gateway API).
- Ingress Controller interno (para APIs entre sistemas) vs. externo (para canales digitales): suelen ser **instancias separadas**.

---

## 7. Checklist junior → senior

- [ ] **Junior:** habilito el addon y explico la diferencia entre objeto Ingress y controlador.
- [ ] **Semi-senior:** diagnostico 404/503 e identifico qué controlador y qué annotations aplican.
- [ ] **Senior:** elijo la tecnología de entrada (Ingress vs. Gateway API, controlador de nube), su alta disponibilidad y su plan de migración.

---

← [22 · Annotations](22-annotations.md) · [Índice](../README.md) · Siguiente → [24 · Ingress rules](24-ingress-rules.md)
