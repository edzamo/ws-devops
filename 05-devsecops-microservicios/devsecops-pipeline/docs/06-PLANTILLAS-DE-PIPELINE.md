# 🧩 Plantillas de pipeline: de lo básico a lo avanzado

Cómo pasar de "un pipeline por aplicación" a "una plataforma de pipelines para todo el banco". Primero se explica en Azure DevOps (donde hicimos el ejemplo) y después cómo se aplica lo mismo en GitHub Actions, Jenkins y AWS.

| Sección | Contenido |
|---|---|
| [1](#1-estaba-mal-el-pipeline-inicial-de-azure) | ¿Estaba mal el pipeline inicial de Azure? |
| [2](#2-cómo-funciona-una-plantilla-en-azure-devops) | Cómo funciona una plantilla en Azure DevOps |
| [3](#3-niveles-de-madurez-de-lo-básico-a-lo-avanzado) | Niveles de madurez, de lo básico a lo avanzado |
| [4](#4-lo-mismo-en-cada-plataforma) | Lo mismo en GitHub Actions, Jenkins y AWS |
| [5](#5-jenkins-dentro-de-aws-o-azure) | Jenkins dentro de AWS o Azure |
| [6](#6-ventajas-costos-y-cómo-mitigarlos) | Ventajas, costos y cómo mitigarlos |
| [7](#7-próximos-pasos-para-este-proyecto) | Próximos pasos para este proyecto |

---

## 1. ¿Estaba mal el pipeline inicial de Azure?

**No.** La primera versión (un solo `azure-pipelines.yml` con todas las etapas) era correcta y funcional. Es el **nivel 2** de la tabla de la sección 3: lógica en scripts y un orquestador que los llama. Para **una** aplicación es suficiente.

El problema aparece **a escala**. Con 50 microservicios, cada uno con su copia del pipeline:

| Situación | Con un pipeline por aplicación | Con plantilla central |
|---|---|---|
| Seguridad pide agregar un escaneo nuevo | Editar 50 repos, 50 PR | Un cambio en la plantilla y una versión nueva |
| Un equipo borra la etapa de SAST "porque tarda" | Nadie se entera | Imposible: el ambiente exige la plantilla |
| Auditoría pregunta "¿todos pasan los mismos controles?" | Revisar 50 archivos distintos | Sí, por diseño |
| Un equipo nuevo arranca | Copia el YAML de otro equipo, con sus errores | 20 líneas y listo |

Por eso evolucionamos al modelo de plantilla central, el mismo que usan los pipelines reales de banca.

---

## 2. Cómo funciona una plantilla en Azure DevOps

### 2.1 La idea: expansión al compilar

Una plantilla **no se ejecuta**: se **inserta**. Cuando lanzas el pipeline, Azure primero arma un único YAML gigante juntando el tuyo con las plantillas, y recién después lo ejecuta.

```text
 1. Lanzas el pipeline
 2. Azure descarga tu azure-pipelines.yml + las plantillas (de su repo y su versión)
 3. COMPILA: reemplaza parámetros, evalúa ${{ if }}, expande ${{ each }}   ← aquí actúan las plantillas
 4. Obtiene el pipeline final (lo ves en "Download full YAML")
 5. EJECUTA ese pipeline final: stages → jobs → steps → scripts
```

Hay tres sintaxis, y cada una se evalúa en un momento distinto:

| Sintaxis | Cuándo se evalúa | Para qué | Ejemplo |
|---|---|---|---|
| `${{ ... }}` | Al **compilar** (paso 3) | Parámetros, condicionales de estructura, decidir qué etapas existen | `${{ if eq(parameters.publicar, true) }}` |
| `$(...)` | Justo antes de cada tarea | Variables normales y de variable groups | `$(REGISTRY)` |
| `$[ ... ]` | Durante la ejecución | Valores que dependen de etapas anteriores | `$[ stageDependencies.CI.ci.outputs['x.y'] ]` |

> Por eso la service connection de ACR va como **parámetro** (`${{ }}`) y no como variable del variable group (`$( )`): Azure necesita saber cuál es al compilar, antes de que existan las variables.

### 2.2 Los tipos de plantilla

| Tipo | Qué inserta | Se usa con | Ejemplo de uso |
|---|---|---|---|
| **Step template** | Una lista de pasos | `- template: steps/sonar.yml` dentro de `steps:` | Reutilizar "análisis Sonar" en varios jobs |
| **Job template** | Uno o varios jobs | `- template: jobs/build-java.yml` dentro de `jobs:` | Mismo build para varios servicios |
| **Stage template** | Una o varias etapas | `- template: stages/cd.yml` dentro de `stages:` | Un CD reutilizable por ambiente |
| **Variable template** | Variables | `- template: vars/dev.yml` dentro de `variables:` | Configuración por ambiente versionada en Git |
| **Extends template** | **El pipeline completo** | `extends: template: ...` | El modelo de banco: la plantilla es dueña de todo |

### 2.3 Incluir (`template:`) vs. extender (`extends:`)

Es la diferencia más importante, y es de **gobernanza**:

| | `- template:` (incluir) | `extends:` (extender) |
|---|---|---|
| Quién controla la estructura | El pipeline de la aplicación: usa las piezas que quiere | **La plantilla**: el pipeline solo pasa parámetros |
| ¿Puede un equipo quitar el SAST? | Sí, no incluyendo esa pieza | No |
| ¿Se puede exigir desde el ambiente? | No | **Sí**: check *Required template* |
| Analogía | Una caja de piezas de Lego | Un formulario con campos permitidos |

```yaml
# INCLUIR: el equipo arma su pipeline con piezas
steps:
  - template: steps/build-java.yml@templates
  - template: steps/sast.yml@templates        # ...y podría borrar esta línea

# EXTENDER: el equipo solo llena el formulario
extends:
  template: java/quarkus/maven/devsecops.yml@templates
  parameters:
    coberturaMinima: "30"
```

### 2.4 Parámetros con tipo: el "contrato" de la plantilla

La plantilla declara qué se le puede pasar. Azure valida el tipo **antes** de ejecutar:

```yaml
parameters:
  - name: coberturaMinima      # texto
    type: string
    default: "30"
  - name: modoEstricto         # sí/no
    type: boolean
    default: false
  - name: servicios            # lista de objetos
    type: object
    default: [ms-risk-mock, ms-orchestrator]
  - name: pasosPrevios         # puerta controlada para pasos propios del equipo
    type: stepList
    default: []
```

Tipos disponibles: `string`, `number`, `boolean`, `object`, `step`/`stepList`, `job`/`jobList`, `deployment`/`deploymentList`, `stage`/`stageList`.

### 2.5 Puertas de extensión (*hooks*): flexibilidad sin perder el control

Un estándar rígido hace que los equipos lo eviten. La solución es dejar **puntos de extensión** controlados: el equipo puede agregar pasos propios **en lugares definidos**, y la plantilla puede validarlos.

```yaml
# En la plantilla
parameters:
  - name: pasosPrevios
    type: stepList
    default: []

steps:
  - ${{ each paso in parameters.pasosPrevios }}:
      # La plantilla puede rechazar pasos no permitidos (p. ej. scripts arbitrarios)
      - ${{ if not(startsWith(paso.task, 'PowerShell')) }}:
          - ${{ paso }}
  - script: "$(SCRIPTS)/02-build-test.sh"     # las etapas obligatorias siguen igual
```

### 2.6 Versionado: plantilla fijada a un tag

```yaml
resources:
  repositories:
    - repository: templates
      type: git
      name: Plataforma/devsecops-templates
      ref: refs/tags/v1.2.0          # ✅ versión fija y auditada
      # ref: refs/heads/master       # ❌ cualquier cambio afecta a todos al instante
```

Se usa versionado semántico: `v1.2.0` → `v1.2.1` es una corrección que nadie nota, `v1.3.0` agrega algo compatible, y `v2.0.0` rompe compatibilidad y cada equipo migra cuando está listo.

---

## 3. Niveles de madurez, de lo básico a lo avanzado

| Nivel | Nombre | Cómo se ve | Problema que resuelve | Problema que deja |
|---|---|---|---|---|
| **0** | Manual | Alguien compila y sube desde su laptop (el Lab 05, Parte 1) | — | No reproducible, sin controles |
| **1** | Pipeline *inline* | Todo el código de las etapas dentro del YAML | Automatiza | Atado a una plataforma; difícil de probar |
| **2** | Lógica en scripts | YAML delgado que llama a `stages/*.sh` (**nuestro GitHub Actions, Jenkins, AWS y el primer Azure**) | Portable entre plataformas; se prueba en la laptop | Cada aplicación copia el YAML |
| **3** | Plantillas locales | Pasos y jobs reutilizables dentro del mismo repo (`- template:`) | Elimina duplicación dentro de un proyecto | Cada proyecto sigue teniendo las suyas |
| **4** | Plantilla central versionada | Repo de plataforma + `extends` + tag (**nuestro Azure actual**) | Un estándar para todos; cambios controlados | Un equipo todavía podría no usarla |
| **5** | Plantilla obligatoria | El ambiente exige la plantilla (*Required template*, rulesets) | Nadie despliega sin pasar los controles | Rigidez si no hay puertas de extensión |
| **6** | Plataforma de autoservicio | Catálogo por stack, hooks, creación de repos con el pipeline ya listo (p. ej. Backstage), actualización automática de versiones (Renovate) | El equipo nuevo tiene CI/CD en minutos | Requiere un equipo de plataforma dedicado |

Un banco grande suele estar entre los niveles **4 y 5**. Los pipelines reales que revisamos estaban en el nivel 4 (plantilla central con `extends`), con una debilidad propia del nivel 3: la plantilla fijada a `master` y no a una versión.

---

## 4. Lo mismo en cada plataforma

El concepto es el mismo en todas: **una plantilla central, versionada, que los proyectos consumen pasando parámetros**. Cambia el mecanismo.

| Concepto | Azure DevOps | GitHub Actions | Jenkins | AWS |
|---|---|---|---|---|
| Reutilizar pasos | Step template | **Composite action** | Paso global en una **Shared Library** (`vars/sonar.groovy`) | Script compartido en una fuente secundaria de CodeBuild |
| Reutilizar el pipeline completo | **`extends`** | **Reusable workflow** (`on: workflow_call`) | Pipeline declarativo dentro de la Shared Library | **Fábrica de pipelines**: plantilla de CloudFormation o *construct* de CDK que crea el pipeline de cada aplicación |
| Fijar la versión | `ref: refs/tags/v1.2.0` | `uses: org/repo/.github/workflows/x.yml@v1.2.0` | `@Library('devsecops@v1.2.0') _` | Versión de la plantilla en S3 o en el paquete de CDK |
| Obligar su uso | *Required template* en el environment | *Rulesets* que exigen un workflow | Organization Folders + Jenkinsfile por defecto; o restringir quién edita Jenkinsfiles | **Service Catalog**: los equipos solo pueden crear pipelines desde productos aprobados |
| Contrato de parámetros | `parameters:` con tipo | `inputs:` y `secrets:` de `workflow_call` | Argumentos del paso (`Map config`) | `Parameters:` de la plantilla |

### 4.1 GitHub Actions: reusable workflow

```yaml
# Repo de la aplicación: .github/workflows/cicd.yml
jobs:
  devsecops:
    uses: edzamo/devsecops-templates/.github/workflows/java-quarkus-maven.yml@v1.0.0
    with:
      cobertura_minima: "30"
    secrets: inherit
```

### 4.2 Jenkins: Shared Library

```text
devsecops-shared-library/                  (repo central)
├── vars/
│   ├── devsecopsPipeline.groovy           el pipeline completo, como "paso" reutilizable
│   └── secretScan.groovy                  pasos sueltos reutilizables
├── src/org/banco/devsecops/…              clases Groovy (lógica compleja)
└── resources/stages/*.sh                  los scripts, empaquetados con la librería
```

```groovy
// Repo de la aplicación: Jenkinsfile — 3 líneas
@Library('devsecops-shared-library@v1.0.0') _
devsecopsPipeline(stack: 'java-quarkus-maven', coberturaMinima: 30)
```

```groovy
// vars/devsecopsPipeline.groovy — en la librería central
def call(Map config) {
    pipeline {
        agent any
        environment {
            SCRIPTS          = "${WORKSPACE}/.devsecops/stages"
            COBERTURA_MINIMA = "${config.coberturaMinima ?: 30}"
        }
        stages {
            // Copia al workspace los scripts empaquetados en resources/ de la librería (misma versión del tag)
            stage('Preparar')         { steps { script { prepararScripts() } } }
            stage('2. Build + tests') { steps { sh '$SCRIPTS/02-build-test.sh' } }
            stage('3. Cobertura')     { steps { sh '$SCRIPTS/03-coverage-gate.sh' } }
            // … las mismas etapas de siempre
        }
    }
}
```

### 4.3 AWS: fábrica de pipelines

En AWS no se "incluye" un pipeline: se **crea uno por aplicación** desde una plantilla de infraestructura versionada. Nuestra [`pipeline.yml`](../orchestrators/aws-codepipeline/pipeline.yml) ya es casi eso: con parámetros por aplicación (repo, nombre, servicios), cada equipo crea su pipeline con un comando:

```bash
aws cloudformation deploy --stack-name cicd-<aplicacion>-test \
  --template-url https://<bucket-de-plataforma>.s3.amazonaws.com/devsecops/v1.0.0/pipeline.yml \
  --parameter-overrides Aplicacion=<aplicacion> RepositorioCodigo=org/<aplicacion> Ambiente=test
```

Para obligar el estándar se publica como producto de **AWS Service Catalog**: los equipos no tienen permiso para crear un CodePipeline a mano, solo desde el producto aprobado.

---

## 5. Jenkins dentro de AWS o Azure

Es muy común, y conviene separar dos cosas: **dónde corre** el CI y **qué herramienta** es.

```text
 Herramienta de CI   →  Jenkins             GitHub Actions          Azure Pipelines      CodePipeline
 Dónde corre         →  EC2, EKS, AKS, VM   Nube de GitHub o        Nube de Microsoft    AWS (nativo)
                        on-premise          runners propios         o agentes propios
```

**Jenkins en AWS o Azure sigue siendo Jenkins:** el mismo `Jenkinsfile` y la misma Shared Library. La nube solo le presta:

| Necesidad | Jenkins en AWS | Jenkins en Azure |
|---|---|---|
| Máquinas para los builds | Agentes efímeros en EKS (plugin Kubernetes) o EC2 (plugin EC2) | Agentes efímeros en AKS (plugin Kubernetes) o VM Scale Sets |
| Secretos | Plugin *AWS Secrets Manager Credentials Provider* | Plugin *Azure Key Vault* |
| Registro de imágenes | ECR, con el rol IAM del agente | ACR, con *managed identity* |
| Identidad sin contraseñas | IAM Roles for Service Accounts (IRSA) | Workload Identity |

¿Por qué un banco elige Jenkins aunque esté en la nube? Por inversión previa (cientos de jobs y librerías), por portabilidad entre nubes, o porque tiene parte de la infraestructura on-premise. ¿Por qué elige la herramienta nativa? Porque se integra sola con la identidad, los secretos y la auditoría de esa nube, y no hay un servidor que mantener.

**Lo que aprendimos aplica igual:** la plantilla central en Azure es `extends`, en Jenkins es una Shared Library, en GitHub un reusable workflow y en AWS una fábrica de pipelines. Y los scripts de `stages/` sirven para todos.

---

## 6. Ventajas, costos y cómo mitigarlos

### Ventajas

| Ventaja | Qué significa en un banco |
|---|---|
| **Estandarización** | Todos los servicios pasan los mismos controles de seguridad y calidad |
| **Cumplimiento demostrable** | "¿Todos usan SAST?": sí, porque el ambiente exige la plantilla |
| **Cambio centralizado** | Un control nuevo se agrega una vez y llega a todos con la siguiente versión |
| **Arranque rápido** | Un microservicio nuevo tiene CI/CD con 20 líneas |
| **Menos errores** | Los equipos no reinventan ni copian pipelines con errores |
| **Separación de responsabilidades** | DevOps es dueño del *cómo*; cada equipo, de su código y sus parámetros |

### Costos (y cómo mitigarlos)

| Costo | Mitigación |
|---|---|
| **Radio de impacto:** un error en la plantilla afecta a todos | Versionado con tags, *changelog*, y equipos piloto que prueban la versión nueva primero |
| **Rigidez:** "mi proyecto es distinto" | Puertas de extensión (hooks con `stepList`), parámetros bien pensados, varias plantillas por stack |
| **Depurar es más difícil** | "Download full YAML" en Azure; logs claros por etapa; los scripts se pueden ejecutar en local |
| **La plantilla también es código** | Probarla: un repo de ejemplo que corre cada versión nueva antes de publicarla, y linters (`actionlint`, `cfn-lint`) |
| **Equipos atrasados en versiones viejas** | Renovate o Dependabot abren PR automáticos para subir de versión; política de soporte (p. ej. solo las 2 últimas versiones mayores) |

---

## 7. Próximos pasos para este proyecto

Dónde estamos y qué se podría agregar para subir de nivel en cada plataforma:

| Plataforma | Nivel actual | Para llegar a 4-5 |
|---|---|---|
| Azure DevOps | **4** (plantilla central con `extends`, fijada a tag) | Crear el tag `devsecops-templates-v1.0.0` y configurar *Required template* en los environments |
| GitHub Actions | 2 | Convertir el workflow en *reusable workflow* (`workflow_call`) y que `poc-credit-evaluation` lo llame con un archivo de 10 líneas |
| Jenkins | 2 | Crear una Shared Library con `devsecopsPipeline(...)` y reducir el Jenkinsfile a 3 líneas |
| AWS | 2-3 | Parametrizar `pipeline.yml` por aplicación y publicarlo versionado (fábrica de pipelines) |
| Todas | — | Puertas de extensión (hooks) y un repo de prueba que valide cada versión de la plantilla |
