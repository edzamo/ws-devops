# AWS DevOps Workspace

Notas, laboratorios y ejemplos del camino de aprendizaje DevOps.

| Carpeta | Tema | Estado |
|---|---|---|
| [01-docker](01-docker/) | Docker, Dockerfiles, volúmenes, redes, Docker Compose | En curso |
| [02-kubernetes](02-kubernetes/) | Minikube, Pods, manifiestos, labels/selectors, ReplicationController, Helm | En curso |
| 03-terraform | Infraestructura como código | Pendiente |
| [05-devsecops-microservicios](05-devsecops-microservicios/) | **DevSecOps**: pipeline CI/CD con seguridad integrada (GitHub Actions, Jenkins, Azure DevOps, AWS) sobre `poc-credit-evaluation` (Angular + 2 Quarkus), imágenes en Docker Hub | ✅ Cerrado · siguiente: Minikube y simulación local de AWS |

## 📚 Conceptos clave de DevSecOps

Material de estudio dentro de [05-devsecops-microservicios](05-devsecops-microservicios/):

| Concepto | En una frase | Documento |
|---|---|---|
| **Pipeline CI/CD** | Línea de producción del software: del repositorio a producción sin pasos manuales | [Arquitectura](05-devsecops-microservicios/devsecops-pipeline/docs/01-ARQUITECTURA.md) |
| **DevSecOps** | Los controles de seguridad van dentro del pipeline, no al final (*shift left*) | [DevSecOps](05-devsecops-microservicios/devsecops-pipeline/docs/05-DEVSECOPS-APRENDIZAJE.md) |
| **SAST** | Analiza el código fuente sin ejecutarlo (Semgrep, SonarQube, Checkmarx) | [DevSecOps § 2.2](05-devsecops-microservicios/devsecops-pipeline/docs/05-DEVSECOPS-APRENDIZAJE.md#22-sast--static-application-security-testing--etapa-6) |
| **SCA** | Busca vulnerabilidades conocidas (CVE) en librerías de terceros (Trivy, Dependency-Check, Snyk) | [DevSecOps § 2.3](05-devsecops-microservicios/devsecops-pipeline/docs/05-DEVSECOPS-APRENDIZAJE.md#23-sca--software-composition-analysis--etapa-6) |
| **DAST** | Ataca la aplicación mientras corre, desde afuera (OWASP ZAP, Burp Suite) | [DevSecOps § 2.8](05-devsecops-microservicios/devsecops-pipeline/docs/05-DEVSECOPS-APRENDIZAJE.md#28-dast--dynamic-application-security-testing--etapa-10) |
| **SBOM** | Inventario de todo lo que contiene una imagen | [DevSecOps § 2.6](05-devsecops-microservicios/devsecops-pipeline/docs/05-DEVSECOPS-APRENDIZAJE.md#26-sbom--software-bill-of-materials--etapa-8) |
| **Quality gate** | Umbrales de calidad que el código debe cumplir para avanzar | [Etapas](05-devsecops-microservicios/devsecops-pipeline/docs/02-ETAPAS.md) |
| **Plantilla de pipeline** | Un pipeline central y versionado que todos los proyectos reutilizan | [Plantillas](05-devsecops-microservicios/devsecops-pipeline/docs/06-PLANTILLAS-DE-PIPELINE.md) |
| **Gobernanza** | Aprobaciones, ramas → ambientes, plantilla obligatoria | [Gobernanza](05-devsecops-microservicios/devsecops-pipeline/docs/04-GOBERNANZA-Y-NUBE.md) |

Glosario completo en [Arquitectura § 9](05-devsecops-microservicios/devsecops-pipeline/docs/01-ARQUITECTURA.md#9-glosario).

Cada carpeta tiene su propio `README.md` y subcarpetas `01-documentation` (apuntes) y los ejemplos correspondientes.
