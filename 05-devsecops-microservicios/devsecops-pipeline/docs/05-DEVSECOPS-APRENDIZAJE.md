# 🎓 DevSecOps: conceptos, herramientas y ruta de aprendizaje

Guía de estudio. Explica cada control de seguridad del pipeline: qué es, qué encuentra y qué no, qué herramientas libres y de pago existen. Al final hay una ruta de **píldoras**, de junior a arquitecto, con ejercicios sobre este mismo pipeline.

| Sección | Contenido |
|---|---|
| [1](#1-el-mapa-dónde-va-cada-control) | El mapa: dónde va cada control |
| [2](#2-los-controles-uno-por-uno) | Los controles uno por uno (incluye **DAST y ZAP** en detalle) |
| [3](#3-sast-vs-sca-vs-dast-vs-iast) | SAST vs. SCA vs. DAST vs. IAST |
| [4](#4-ruta-de-aprendizaje-píldoras-de-junior-a-arquitecto) | Ruta de aprendizaje: píldoras de junior a arquitecto |
| [5](#5-marcos-de-referencia-para-seguir-creciendo) | Marcos de referencia para seguir creciendo |

> Sobre los precios: las ediciones y los planes de las herramientas comerciales cambian seguido. Las tablas indican el **modelo**, que es lo estable: open source, plan gratuito limitado o comercial. Antes de una decisión de compra, revisa la página oficial de cada producto.

---

## 1. El mapa: dónde va cada control

**DevSecOps** es integrar la seguridad **dentro** del pipeline, como controles automáticos en cada etapa, en lugar de una auditoría manual al final. La idea central es ***shift left***: encontrar el problema lo más a la izquierda posible (cerca del desarrollador), donde corregirlo cuesta minutos y no semanas.

```text
 IZQUIERDA (barato de corregir) ───────────────────────────────────────────► DERECHA (caro)

 Código         Build            Artefacto / imagen      Ambiente corriendo       Producción
 ──────         ─────            ──────────────────      ──────────────────       ──────────
 Secretos       Tests            Escaneo de imagen       DAST (ZAP)               Monitoreo en ejecución
 SAST           Cobertura        SBOM                    Smoke tests              (runtime / RASP)
 IaC scan       Calidad (Sonar)  Firma de imagen
 SCA
 ↑ etapas 1, 6  ↑ etapas 2-5     ↑ etapas 7-9            ↑ etapa 10               (fuera del pipeline)
```

---

## 2. Los controles uno por uno

### 2.1 Secret scanning (detección de secretos) — etapa 1

| | |
|---|---|
| **Qué es** | Busca contraseñas, tokens y llaves privadas escritos en el código **y en todo el historial** de Git |
| **Analogía** | Revisar que nadie dejó la llave de la bóveda pegada en la puerta |
| **Encuentra** | `password=...`, tokens de AWS o GitHub, llaves `.pem` |
| **No encuentra** | Secretos ofuscados o partidos en varias líneas |
| **Lección clave** | Borrar el secreto en un commit nuevo **no basta**: sigue en el historial. Hay que **rotarlo** (invalidarlo y crear otro) |

| Libre / open source | Plan gratuito limitado | Comercial |
|---|---|---|
| **Gitleaks** (el que usamos), TruffleHog OSS, detect-secrets | GitHub Secret Scanning (gratis en repos públicos), GitGuardian | GitHub Advanced Security, GitGuardian Business, TruffleHog Enterprise |

### 2.2 SAST — Static Application Security Testing — etapa 6

| | |
|---|---|
| **Qué es** | Analiza el **código fuente sin ejecutarlo**, buscando patrones inseguros |
| **Analogía** | Un inspector que lee la **receta** buscando pasos peligrosos, sin cocinar |
| **Encuentra** | Inyección SQL, criptografía débil, deserialización insegura, Dockerfiles que corren como root (lo encontró en este proyecto) |
| **No encuentra** | Problemas de configuración del servidor, o lo que solo pasa en ejecución |
| **Debilidad típica** | Falsos positivos: hay que **triar** cada hallazgo |

| Libre / open source | Plan gratuito limitado | Comercial |
|---|---|---|
| **Semgrep CE** (el que usamos), SpotBugs + FindSecBugs (Java), Bandit (Python) | CodeQL (gratis en repos públicos), SonarQube Community (incluye reglas de seguridad básicas) | Checkmarx, Veracode, Fortify (OpenText), Snyk Code, Semgrep (versión de pago), GitHub Advanced Security |

### 2.3 SCA — Software Composition Analysis — etapa 6

| | |
|---|---|
| **Qué es** | Revisa las **librerías de terceros** contra bases de vulnerabilidades conocidas (CVE) y sus licencias |
| **Analogía** | Revisar que las manzanas del **proveedor** no vengan contaminadas |
| **Encuentra** | Quarkus 3.8.4 con ~33 CVE HIGH/CRITICAL (hallazgo real de este proyecto) |
| **Por qué importa** | El 80-90 % del código de una aplicación moderna son librerías de terceros |
| **Lección del laboratorio** | Analizar solo el `pom.xml` dio **0 vulnerabilidades** (falso negativo): las versiones reales vienen del BOM de Quarkus. Hubo que analizar los jars ya resueltos |

| Libre / open source | Plan gratuito limitado | Comercial |
|---|---|---|
| **Trivy** (el que usamos), OWASP Dependency-Check, Grype, `npm audit` | Dependabot (gratis en GitHub), Snyk Open Source (plan free) | Snyk, Mend (ex WhiteSource), Black Duck, Sonatype Nexus Lifecycle, JFrog Xray |

### 2.4 Calidad de código y cobertura — etapas 3 y 5

No son seguridad pura, pero son la base: un código sin tests y difícil de mantener esconde bugs de seguridad.

| | |
|---|---|
| **Cobertura** | Porcentaje de código que ejecutan los tests. Mide **cuánto** se prueba, no **qué tan bien** |
| **Quality gate** | Umbrales que el código debe cumplir: cobertura, bugs, duplicación, deuda técnica |

| Libre / open source | Plan gratuito limitado | Comercial |
|---|---|---|
| **JaCoCo** (el que usamos), **SonarQube Community** (el que usamos), PMD, Checkstyle | SonarQube Cloud (gratis en repos públicos) | SonarQube Developer/Enterprise, Codacy, CodeScene |

### 2.5 Escaneo de imágenes de contenedor — etapa 8

| | |
|---|---|
| **Qué es** | Escanea la **imagen completa**: el sistema operativo base y todas las librerías que contiene |
| **Analogía** | Revisar que la **botella** no tenga grietas, no solo el jugo |
| **Diferencia con SCA** | SCA ve tus dependencias; el escaneo de imagen ve además el sistema base. En este proyecto, la imagen del frontend tenía **60 CVE** por usar `nginx:1.27-alpine` viejo, aunque el código Angular tenía 0 |

| Libre / open source | Plan gratuito limitado | Comercial |
|---|---|---|
| **Trivy** (el que usamos), Grype, Clair | Docker Scout, escaneo básico de ECR (AWS) | Prisma Cloud, Aqua, Sysdig Secure, Microsoft Defender for Containers, Amazon Inspector |

### 2.6 SBOM — Software Bill of Materials — etapa 8

| | |
|---|---|
| **Qué es** | El **inventario** de todo lo que contiene una imagen: cada librería con su versión |
| **Analogía** | La etiqueta de ingredientes de la botella |
| **Para qué sirve** | Cuando sale un CVE nuevo (como Log4Shell en 2021), respondes en minutos "¿cuáles de nuestras 200 imágenes lo tienen?" sin volver a escanear todo |
| **Formatos** | CycloneDX (el que generamos) y SPDX |

Herramientas libres: **Trivy** (el que usamos), Syft, CycloneDX Maven Plugin. Comerciales: las plataformas de SCA de la sección 2.3 lo incluyen.

### 2.7 Firma de imágenes y procedencia (no implementado aún)

| | |
|---|---|
| **Qué es** | Firmar criptográficamente la imagen y registrar **cómo** se construyó (procedencia) |
| **Para qué sirve** | Que el clúster solo acepte imágenes firmadas por tu pipeline: nadie puede colar una imagen construida en su laptop |
| **Marco** | SLSA (*Supply-chain Levels for Software Artifacts*) |

Herramientas libres: **Cosign** (Sigstore), Notation. Del lado del clúster, para exigir la firma: Kyverno u OPA Gatekeeper.

### 2.8 DAST — Dynamic Application Security Testing — etapa 10

| | |
|---|---|
| **Qué es** | Ataca la aplicación **mientras corre**, desde afuera, como lo haría un atacante. No ve el código: solo ve lo que responde por HTTP |
| **Analogía** | Contratar a alguien para que intente entrar a la casa ya construida, probando puertas y ventanas |
| **Encuentra** | Cabeceras de seguridad faltantes, cookies inseguras, XSS, inyección, errores que revelan información interna, configuración del servidor |
| **No encuentra** | Código que no se ejecuta durante la prueba, ni lógica de negocio (por ejemplo, "un usuario ve créditos de otro") |
| **Requisito** | La aplicación tiene que estar **desplegada y corriendo**. Por eso va al final y por eso existe el ambiente simulado |

#### OWASP ZAP (Zed Attack Proxy) — el que usamos

ZAP es la herramienta de DAST open source más usada (licencia Apache 2.0). Nació en OWASP, la fundación que publica el OWASP Top 10, y hoy la desarrolla el mismo equipo con el patrocinio de Checkmarx. Funciona como un **proxy**: se pone entre el navegador (o el escáner) y la aplicación, y analiza o modifica cada petición.

| Modo de ZAP | Qué hace | Riesgo | Dónde usarlo |
|---|---|---|---|
| **Baseline** (`zap-baseline.py`) — **el que usamos** | Recorre la app (*spider*) y analiza las respuestas de forma **pasiva**, sin atacar | Ninguno: no modifica datos | En cada ejecución del pipeline |
| **Full scan** (`zap-full-scan.py`) | Además lanza **ataques activos**: inyecciones, XSS, *path traversal* | Puede crear o borrar datos, o tumbar el servicio | Solo en ambientes efímeros o de prueba, **nunca en producción** |
| **API scan** (`zap-api-scan.py`) | Ataca una API a partir de su especificación OpenAPI | Igual que el full scan | Microservicios REST, como el orquestador (`/q/openapi`) |

Cómo leer su resultado (en este proyecto: `0 FAIL, 12 WARN`):

| Nivel | Significado | Ejemplo real de este proyecto |
|---|---|---|
| `PASS` | La regla se revisó y no hubo hallazgo | 65 reglas pasaron |
| `WARN` | Hallazgo a revisar; con `-I` no detiene el pipeline | `X-Content-Type-Options Header Missing`, `Permissions Policy Header Not Set` |
| `FAIL` | Hallazgo que debe detener el pipeline | Ninguno |

Las reglas se ajustan con un archivo de configuración: qué regla es `FAIL`, cuál `WARN` y cuál se ignora, **siempre con una justificación escrita**. Eso es lo que revisa un auditor.

| Libre / open source | Plan gratuito limitado | Comercial |
|---|---|---|
| **OWASP ZAP** (el que usamos), Nuclei, Nikto | Burp Suite Community (manual, sin escáner automático) | Burp Suite Professional / DAST, Invicti, Acunetix, StackHawk (basado en ZAP), Veracode DAST, Checkmarx DAST, Rapid7 InsightAppSec |

### 2.9 Otros controles que vas a escuchar

| Control | Qué es | Libre | Comercial |
|---|---|---|---|
| **IAST** (*Interactive*) | Un agente **dentro** de la aplicación observa el código mientras corren los tests o el DAST. Combina SAST y DAST, con menos falsos positivos | Pocas opciones maduras | Contrast Security, Seeker (Black Duck) |
| **RASP** (*Runtime Application Self-Protection*) | El agente **bloquea** ataques en producción, desde dentro de la app | — | Contrast Protect, Imperva RASP |
| **IaC scanning** | Revisa Terraform, manifiestos de Kubernetes y Dockerfiles buscando malas configuraciones | Checkov, Trivy (`trivy config`), KICS, Hadolint | Prisma Cloud, Wiz |
| **Policy as code** | Reglas que el clúster o el pipeline hacen cumplir: "ninguna imagen sin firma", "ningún pod como root" | OPA / Gatekeeper, Kyverno | Styra |
| **Seguridad en ejecución** | Detecta comportamiento anómalo de los contenedores ya en producción | Falco | Sysdig, Aqua, Prisma Cloud |
| **Pentest** | Una persona experta ataca la aplicación manualmente | Burp Community, ZAP en modo manual | Burp Pro + consultoras |

---

## 3. SAST vs. SCA vs. DAST vs. IAST

| | SAST | SCA | DAST | IAST |
|---|---|---|---|---|
| **Mira** | Tu código | Las librerías de terceros | La app corriendo, desde afuera | La app corriendo, desde adentro |
| **Necesita la app corriendo** | No | No | **Sí** | **Sí** |
| **Momento en el pipeline** | Temprano | Temprano | Tarde (después del deploy) | Durante tests o DAST |
| **Velocidad** | Rápida | Muy rápida | Lenta | Media |
| **Falsos positivos** | Muchos | Pocos | Pocos | Muy pocos |
| **Te dice la línea exacta** | Sí | Sí (la librería) | No (solo la URL) | Sí |
| **En este pipeline** | Semgrep | Trivy | ZAP | — |

**Ninguno reemplaza a otro.** Un banco usa al menos SAST + SCA + DAST, porque cada uno ve lo que los otros no ven.

---

## 4. Ruta de aprendizaje: píldoras de junior a arquitecto

Cada píldora es un ejercicio corto (30 a 90 minutos) que puedes hacer sobre **este** pipeline. Las marcadas con 🧪 se pueden ejecutar hoy con [`run-local.sh`](../run-local.sh).

### 🟢 Junior: entender y operar

**Objetivo:** saber qué hace cada etapa, leer sus reportes y explicar un hallazgo.

| # | Píldora | Qué aprendes |
|---|---|---|
| J1 🧪 | Ejecuta `./run-local.sh 0 4` y abre el reporte de cobertura (`/tmp/poc-credit-evaluation-pipeline/salida/reportes/cobertura-*/index.html`) | Qué es cobertura y por qué `ms-risk-mock` tiene 32 % |
| J2 🧪 | Rompe un test a propósito y ejecuta la etapa 2 | Que el pipeline se detiene solo |
| J3 🧪 | Lee `trivy-dependencias-*.txt`: elige un CVE CRITICAL y búscalo en nvd.nist.gov | Qué es un CVE, su puntaje CVSS y qué es una versión "fixed" |
| J4 🧪 | Abre `zap-mms-ux.html` y explica en una frase cada WARN | Qué son las cabeceras de seguridad HTTP |
| J5 | Lee el OWASP Top 10 y relaciona cada riesgo con la herramienta del pipeline que lo detecta | El "por qué" de cada control |
| J6 | Explica con tus palabras la diferencia entre SAST, SCA y DAST (sección 3) | La pregunta más común en entrevistas |

### 🟡 Semi-senior: ajustar y corregir

**Objetivo:** dejar de solo leer reportes y empezar a corregir y ajustar los controles.

| # | Píldora | Qué aprendes |
|---|---|---|
| S1 🧪 | Agrega `Permissions-Policy` y `Content-Security-Policy` al `nginx.conf` y vuelve a correr la etapa 10 hasta que el WARN desaparezca | Corregir un hallazgo de DAST |
| S2 🧪 | Cambia la base del frontend a una versión actual de Nginx y compara los CVE de la etapa 8 (60 → ?) | El impacto de la imagen base |
| S3 | Cambia el frontend a `nginx-unprivileged` (puerto 8080) para corregir el hallazgo de Semgrep | Contenedores sin root |
| S4 | Actualiza Quarkus a una versión LTS vigente y mide cuántos CVE desaparecen | Gestión de dependencias y regresiones |
| S5 🧪 | Cambia ZAP a `zap-api-scan.py` contra `/q/openapi` del orquestador | DAST de APIs, modo activo |
| S6 | Triage: marca un hallazgo como falso positivo con una justificación escrita (`.trivyignore`, regla de ZAP) | Que suprimir sin justificar es un hallazgo de auditoría |
| S7 🧪 | Pon `MODO_ESTRICTO=true` y cuenta qué etapas fallan | La diferencia entre modo auditoría y modo bloqueo |

### 🟠 Senior: diseñar y endurecer

**Objetivo:** decidir qué controles van, con qué umbrales, y proteger el propio pipeline.

| # | Píldora | Qué aprendes |
|---|---|---|
| R1 | Firma las imágenes con Cosign en la etapa 9 y verifica la firma antes del deploy | Cadena de suministro y SLSA |
| R2 | Agrega un escaneo de IaC (Checkov o `trivy config`) sobre los Dockerfiles y los manifiestos de Kubernetes | Shift left de la infraestructura |
| R3 | Diseña una política de umbrales por severidad: CRITICAL bloquea siempre, HIGH bloquea solo si tiene parche, y lo demás se reporta | Riesgo vs. velocidad de entrega |
| R4 | Fija las actions de GitHub por SHA, no por tag, y explica por qué | Seguridad del propio pipeline |
| R5 | Plan de adopción: cómo pasar de modo auditoría a estricto en 3 meses sin frenar al equipo | Gestión del cambio |
| R6 | Mide MTTR de vulnerabilidades (cuánto tarda en corregirse un CRITICAL) y las 4 métricas DORA | Métricas de DevSecOps |

### 🔴 Arquitecto: gobernar a escala

**Objetivo:** que 50 equipos cumplan el mismo estándar sin que DevOps sea un cuello de botella.

| # | Píldora | Qué aprendes |
|---|---|---|
| A1 | Convierte este pipeline en un *reusable workflow* o en una Jenkins Shared Library versionada (sección 7 de [01-ARQUITECTURA.md](01-ARQUITECTURA.md)) | Plataforma de pipelines |
| A2 | Haz un modelo de amenazas (STRIDE) de `poc-credit-evaluation`: frontend → orquestador → mock → Postgres | Seguridad desde el diseño, antes del código |
| A3 | Mapea cada control del pipeline a un requisito de cumplimiento (PCI DSS, ISO 27001) | Hablar el idioma de auditoría |
| A4 | Evalúa la madurez del equipo con OWASP DSOMM o SAMM y propone los próximos 3 pasos | Hoja de ruta basada en un marco |
| A5 | Compara costo y beneficio de una herramienta comercial (Checkmarx, Snyk) frente a la combinación open source actual | Decisiones de compra fundamentadas |
| A6 | Exige en el clúster, con Kyverno, que solo corran imágenes firmadas, sin root y desde el registro aprobado | Cerrar el ciclo: pipeline + plataforma |

### Cómo saber en qué nivel estás

| Nivel | Puedes… |
|---|---|
| Junior | Ejecutar el pipeline, leer cada reporte y explicar qué hace cada etapa |
| Semi-senior | Corregir hallazgos, ajustar reglas y justificar falsos positivos |
| Senior | Diseñar qué controles van, con qué umbrales, y proteger el propio pipeline |
| Arquitecto | Definir el estándar para toda la organización, alinearlo con cumplimiento y medir su madurez |

---

## 5. Marcos de referencia para seguir creciendo

| Marco | Qué es | Para qué nivel |
|---|---|---|
| **OWASP Top 10** | Los 10 riesgos más comunes en aplicaciones web | Junior |
| **OWASP API Security Top 10** | Lo mismo, para APIs | Junior / semi-senior |
| **OWASP ASVS** | Lista verificable de requisitos de seguridad de una aplicación | Semi-senior |
| **CWE / CVE / CVSS** | Catálogo de tipos de debilidad, de vulnerabilidades concretas, y su puntaje de severidad | Semi-senior |
| **CIS Benchmarks** | Configuración segura de Docker, Kubernetes y sistemas operativos | Senior |
| **SLSA** | Niveles de seguridad de la cadena de suministro de software | Senior |
| **NIST SSDF** (SP 800-218) | Prácticas de desarrollo seguro | Senior / arquitecto |
| **OWASP DSOMM** | Modelo de madurez DevSecOps: qué controles adoptar y en qué orden | Arquitecto |
| **OWASP SAMM** | Modelo de madurez del programa de seguridad del software | Arquitecto |
| **PCI DSS, ISO 27001** | Normas de cumplimiento que aplican a la banca | Arquitecto |
