# Orquestador GitHub Actions

GitHub solo ejecuta los workflows que están en `.github/workflows/` en la **raíz** del repositorio. Por eso el orquestador de GitHub Actions no está en esta carpeta, sino en:

**[`.github/workflows/poc-credit-evaluation-cicd.yml`](../../../../.github/workflows/poc-credit-evaluation-cicd.yml)**

Igual que el [`Jenkinsfile`](../jenkins/Jenkinsfile), ese archivo solo orquesta: llama a los scripts de [`stages/`](../../stages/) en orden.

| Evento | Qué corre | Ambiente |
|---|---|---|
| Push a `feature/**` | CI + CD (publicación en *dry run*) | `test` |
| Pull request | Solo CI | — |
| *Run workflow* manual | CI + CD con los parámetros elegidos | `simulacion-produccion` (con aprobación) |

Variables, secretos y environments: [03-CONFIGURACION.md](../../docs/03-CONFIGURACION.md#2-github-actions).
