# Orquestador AWS (CodePipeline + CodeBuild)

En AWS, el pipeline se arma con tres piezas:

| Archivo | Servicio | Rol |
|---|---|---|
| [`pipeline.yml`](pipeline.yml) | **CloudFormation** | Infraestructura como código: crea el CodePipeline, los proyectos CodeBuild, los repositorios ECR, el bucket de artefactos y los roles IAM |
| [`buildspec-ci.yml`](buildspec-ci.yml) | **CodeBuild** | Ejecuta las etapas 1 a 8 (las mismas de [`stages/`](../../stages/)) |
| [`buildspec-cd.yml`](buildspec-cd.yml) | **CodeBuild** | Ejecuta las etapas 9 y 10 |

**CodePipeline** es el orquestador: encadena *Fuentes → CI → Aprobación → CD*. **CodeBuild** es la máquina que ejecuta los scripts. Es un ejemplo de referencia: la plantilla pasa `cfn-lint` sin observaciones, pero no se ha desplegado en una cuenta de AWS.

```text
CodePipeline  poc-credit-evaluation-cicd-<ambiente>
 ┌─────────────────────┐   ┌──────────────────┐   ┌────────────────────┐   ┌──────────────────┐
 │ Fuentes             │ → │ CI (CodeBuild)    │ → │ Aprobación manual  │ → │ CD (CodeBuild)    │
 │ • ws-devops         │   │ buildspec-ci.yml  │   │ solo en producción │   │ buildspec-cd.yml  │
 │ • poc-credit-eval.  │   │ etapas 1-8        │   │                    │   │ etapas 9-10 → ECR │
 └─────────────────────┘   └──────────────────┘   └────────────────────┘   └──────────────────┘
```

## Qué cambia respecto de GitHub Actions

| Concepto | GitHub Actions | AWS |
|---|---|---|
| Orquestador | Workflow YAML | **CodePipeline** (definido en CloudFormation) |
| Ejecutor | Runner `ubuntu-24.04` | **CodeBuild** con `PrivilegedMode` (para Docker) |
| Repo del código | `actions/checkout` | Acción de fuente con **CodeConnections** (`CODEBUILD_CLONE_REF` = clon git completo) |
| Registro | Docker Hub | **ECR**, con `ImageTagMutability: IMMUTABLE` (el registro mismo impide sobrescribir tags) |
| Login al registro | Token en un secret | **Rol IAM** del build: `aws ecr get-login-password`, credenciales temporales |
| Secretos | Settings → Secrets | **Secrets Manager** o **Parameter Store**, en el bloque `env:` del buildspec |
| Aprobación | Environment con reviewers | Acción **Manual approval** de CodePipeline |
| Ambientes | Un workflow, varios environments | **Un pipeline por ambiente** (un stack de CloudFormation por ambiente) |
| SonarQube efímero | `services:` | `docker run` dentro del build (CodeBuild no tiene service containers) |

## Despliegue

1. **Conexión con GitHub** (una vez): Developer Tools → Settings → **Connections** → *Create connection* → GitHub → autorizar. Copiar el ARN.
2. **Crear el pipeline de test:**

   ```bash
   aws cloudformation deploy \
     --stack-name poc-credit-evaluation-cicd-test \
     --template-file pipeline.yml \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameter-overrides ConnectionArn=<arn> Ambiente=test RamaPipeline=main RamaCodigo=main
   ```

3. **Crear el de producción simulada**, con aprobación y publicación en ECR. Los repositorios ECR los crea solo un stack: para el segundo ambiente, sepáralos en una plantilla propia o reutilízalos con `Prefijo` distinto.

   ```bash
   aws cloudformation deploy \
     --stack-name poc-credit-evaluation-cicd-prod \
     --template-file pipeline.yml \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameter-overrides ConnectionArn=<arn> Ambiente=simulacion-produccion Publicar=true Prefijo=austro-prod
   ```

> **Costo:** a diferencia de GitHub Actions en un repo público, en AWS los minutos de CodeBuild, las ejecuciones de CodePipeline y el almacenamiento en S3 y ECR **se cobran**. Para la simulación, eliminar los stacks al terminar: `aws cloudformation delete-stack --stack-name ...` (los repositorios ECR y el bucket deben vaciarse antes).
