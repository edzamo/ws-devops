# 13 · ConfigMaps

> **En una frase:** Un ConfigMap guarda **configuración no sensible** (URLs, banderas, archivos de configuración) fuera de la imagen, para que **la misma imagen** sirva en dev, qa y producción.
>
> **Analogía (contar manzanas):** La imagen es el **cajero entrenado**; el ConfigMap es el **manual de procedimientos de la sucursal**. El mismo cajero trabaja en Quito o en Guayaquil: solo cambia el manual que le entregas (horario, moneda, teléfono del supervisor).

---

## 1. Problema → solución

| Problema | Solución |
| --- | --- |
| Hay una imagen por entorno porque la URL va "quemada" en el código | Una imagen + un ConfigMap por entorno (principio *12-factor*) |
| Cambiar un parámetro exige recompilar | Editar el ConfigMap y reiniciar |
| La app lee un archivo de configuración (`application.properties`, `nginx.conf`) | Montar el ConfigMap como archivo |

---

## 2. Tres formas de consumirlo

```text
 ConfigMap "credito-config"
   ├─► variable de entorno individual   (env.valueFrom.configMapKeyRef)
   ├─► todas las claves como variables  (envFrom.configMapRef)
   └─► archivos en un volumen           (volumes.configMap)  ← se actualiza solo (con retardo)
```

| Forma | ¿Ve cambios sin reiniciar? |
| --- | --- |
| Variables de entorno | **No**: se leen al arrancar el contenedor |
| Volumen | Sí, en ~1 minuto (salvo `subPath`); la app debe releer el archivo |

---

## 3. Manifiesto comentado

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: credito-config
data:
  APP_ENTORNO: "dev"
  API_BASE_URL: "http://credito-api"
  LOG_LEVEL: "INFO"
  application.properties: |          # un archivo completo como valor
    quarkus.http.port=8080
    quarkus.log.level=INFO
---
apiVersion: v1
kind: Pod
metadata:
  name: usa-config
spec:
  containers:
    - name: app
      image: busybox:1.36
      command: ["sh", "-c", "env | grep -E 'APP_|LOG_'; cat /config/application.properties; sleep 3600"]
      env:
        - name: LOG_LEVEL                    # 1) una clave
          valueFrom:
            configMapKeyRef:
              name: credito-config
              key: LOG_LEVEL
      envFrom:
        - configMapRef:                      # 2) todas las claves
            name: credito-config
      volumeMounts:
        - name: config                       # 3) como archivos
          mountPath: /config
          readOnly: true
  volumes:
    - name: config
      configMap:
        name: credito-config
        items:
          - key: application.properties
            path: application.properties
```

---

## 4. Práctica en Minikube

```sh
# Crear de forma imperativa (útil para generar YAML)
kubectl create configmap credito-config \
  --from-literal=APP_ENTORNO=dev \
  --from-file=application.properties \
  --dry-run=client -o yaml > configmap.yaml

kubectl apply -f configmap.yaml
kubectl get configmap credito-config -o yaml
kubectl logs usa-config

# Cambiar y aplicar el cambio a un Deployment
kubectl edit configmap credito-config
kubectl rollout restart deployment/<app>    # necesario si se consume como variables
```

---

## 5. Errores comunes

| Síntoma | Causa | Solución |
| --- | --- | --- |
| `CreateContainerConfigError` | El ConfigMap o la clave no existe | Crear el ConfigMap antes; `optional: true` si aplica |
| Cambié el ConfigMap y la app sigue igual | Se consume como variable | `rollout restart` |
| Archivo montado con `subPath` no se actualiza | Limitación de `subPath` | Montar el directorio completo |
| Contraseña dentro del ConfigMap | Es texto plano visible para todos | Usar Secret (tema 14) |

---

## 6. Lo que debe saber el arquitecto

- **Una imagen, muchas configuraciones.** La imagen que pasó por el pipeline de seguridad es la misma que llega a producción; solo cambia su configuración. Eso es trazabilidad.
- **Versionar la configuración con el despliegue:** Kustomize (`configMapGenerator`) y Helm agregan un *hash* al nombre del ConfigMap; al cambiar el contenido cambia el nombre, el Deployment detecta el cambio y hace rolling update automático (y el rollback también devuelve la configuración vieja).
- `immutable: true` para configuraciones que no deben cambiar: protege contra errores y reduce carga del API server.
- Límite de 1 MiB por ConfigMap: no es una base de datos.

---

## 7. Checklist junior → senior

- [ ] **Junior:** creo un ConfigMap y lo consumo como variables y como archivo.
- [ ] **Semi-senior:** sé cuándo hace falta reiniciar y uso generadores con hash.
- [ ] **Senior:** defino la estrategia de configuración por entorno (Kustomize/Helm + Git) y la separación config vs. secretos.

---

← [12 · Volúmenes](12-volumenes.md) · [Índice](../README.md) · Siguiente → [14 · Secrets](14-secrets.md)
