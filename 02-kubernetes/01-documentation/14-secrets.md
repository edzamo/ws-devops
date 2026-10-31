# 14 · Secrets

> **En una frase:** Un Secret guarda **datos sensibles** (contraseñas, tokens, certificados) separados de la configuración normal, para controlarlos con permisos más estrictos. **Ojo: por defecto solo están codificados en base64, no cifrados.**
>
> **Analogía (contar manzanas):** El ConfigMap es el manual que está sobre el escritorio. El Secret es la **combinación de la caja fuerte**: se guarda en un sobre cerrado y solo lo abren quienes tienen autorización. Pero el sobre de Kubernetes por defecto es de **papel transparente** (base64): si no lo metes en una caja fuerte de verdad (cifrado + gestor de secretos), cualquiera con acceso lo lee.

---

## 1. Problema → solución

| Problema | Solución |
| --- | --- |
| Contraseña de la base de datos en el código o en Git | Secret inyectado en el Pod |
| Descargar imágenes de un registro privado | Secret tipo `kubernetes.io/dockerconfigjson` + `imagePullSecrets` |
| Certificados TLS para HTTPS | Secret tipo `kubernetes.io/tls` (usado por Ingress) |
| Rotar credenciales sin redeploy manual | Gestor externo (Vault / AWS Secrets Manager / Key Vault) + External Secrets Operator |

---

## 2. Tipos de Secret

| Tipo | Uso |
| --- | --- |
| `Opaque` | Genérico: usuario, contraseña, API keys |
| `kubernetes.io/tls` | Certificado + llave privada (`tls.crt`, `tls.key`) |
| `kubernetes.io/dockerconfigjson` | Credenciales de registro de imágenes |
| `kubernetes.io/service-account-token` | Token de una ServiceAccount (heredado) |

---

## 3. base64 NO es cifrado

```sh
echo -n 'SuperClave123' | base64        # U3VwZXJDbGF2ZTEyMw==
echo 'U3VwZXJDbGF2ZTEyMw==' | base64 -d # SuperClave123  ← cualquiera lo revierte
```

Capas de protección reales:

```text
 1. RBAC              → quién puede hacer "get secrets" (muy pocos)
 2. Cifrado en etcd   → encryption at rest con KMS (AWS KMS / Azure Key Vault / Cloud KMS)
 3. Gestor externo    → la fuente de verdad del secreto vive FUERA del clúster
 4. Nunca en Git      → o, si va en Git, cifrado (Sealed Secrets, SOPS)
```

---

## 4. Manifiesto comentado

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credenciales
type: Opaque
stringData:                     # texto plano al escribir; Kubernetes lo guarda en base64
  DB_USER: credito_app
  DB_PASSWORD: "cambiar-en-cada-entorno"
---
apiVersion: v1
kind: Pod
metadata:
  name: usa-secret
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "echo usuario=$DB_USER; ls /secretos; sleep 3600"]
      env:
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credenciales
              key: DB_USER
      volumeMounts:
        - name: secretos              # preferible: como archivo (no aparece en "env")
          mountPath: /secretos
          readOnly: true
  volumes:
    - name: secretos
      secret:
        secretName: db-credenciales
        defaultMode: 0400             # solo lectura para el dueño
```

---

## 5. Práctica en Minikube

```sh
kubectl create secret generic db-credenciales \
  --from-literal=DB_USER=credito_app \
  --from-literal=DB_PASSWORD='cambiar' \
  --dry-run=client -o yaml           # ver cómo queda (en base64)

kubectl apply -f secret.yaml
kubectl get secrets
kubectl describe secret db-credenciales            # muestra tamaños, no valores
kubectl get secret db-credenciales -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Registro privado de imágenes
kubectl create secret docker-registry registro \
  --docker-server=docker.io --docker-username=<usuario> --docker-password=<token>

# Certificado TLS
kubectl create secret tls web-tls --cert=tls.crt --key=tls.key
```

---

## 6. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| Secret subido a GitHub | YAML con `data`/`stringData` versionado | Rotar **de inmediato**; usar Sealed Secrets/SOPS/External Secrets |
| Valor con salto de línea extra | `echo` sin `-n` al codificar | Usar `stringData` o `echo -n` |
| La contraseña aparece en logs | La app imprime sus variables de entorno | Montar como archivo; revisar logging |
| Todos los desarrolladores leen secretos | RBAC con `get secrets` amplio | Mínimo privilegio |

---

## 7. Lo que debe saber el arquitecto

- **El Secret de Kubernetes es el "último metro", no la bóveda.** La fuente de verdad va en un gestor (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, GCP Secret Manager) con rotación, auditoría y control de acceso. Se sincroniza con **External Secrets Operator** o el **Secrets Store CSI Driver**.
- **Identidad de carga de trabajo en lugar de llaves:** en la nube, el Pod obtiene permisos por su ServiceAccount (EKS Pod Identity / IRSA, Azure Workload Identity, GKE Workload Identity). Así no existe una llave de acceso que se pueda filtrar.
- Requisitos típicos de auditoría bancaria (PCI DSS, normativa local): cifrado en reposo con llaves gestionadas, rotación periódica, mínimo privilegio y registro de accesos.

---

## 8. Checklist junior → senior

- [ ] **Junior:** creo un Secret y lo consumo como variable y como archivo; sé que base64 no es cifrado.
- [ ] **Semi-senior:** uso secretos de registro y TLS; restrinjo con RBAC.
- [ ] **Senior:** diseño la cadena gestor externo → External Secrets → Pod, con identidad de carga de trabajo y rotación.

---

← [13 · ConfigMaps](13-configmaps.md) · [Índice](../README.md) · Siguiente → [15 · Requests y limits](15-requests-y-limits.md)
