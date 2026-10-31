#!/usr/bin/env bash
# Lab 01 · Verifica los criterios de éxito del Pod "web" en el namespace lab01.
NS=lab01
POD=web
ok=0; fallos=0

check() {   # check "descripción" "valor obtenido" "valor esperado" "pista si falla"
  if [ "$2" == "$3" ]; then
    echo "✅ $1"; ok=$((ok+1))
  else
    echo "❌ $1 → obtenido: '${2:-vacío}', esperado: '$3'. Pista: $4"; fallos=$((fallos+1))
  fi
}

get() { kubectl get pod "$POD" -n "$NS" -o jsonpath="$1" 2>/dev/null; }

check "Contexto de kubectl es minikube" "$(kubectl config current-context)" "minikube" "kubectl config use-context minikube"
check "Existe el namespace lab01" "$(kubectl get ns $NS -o jsonpath='{.metadata.name}' 2>/dev/null)" "$NS" "kubectl create namespace lab01"
check "Existe el Pod web" "$(get '{.metadata.name}')" "$POD" "kubectl apply -f pod.yaml"
check "Label app=web" "$(get '{.metadata.labels.app}')" "web" "revisa metadata.labels"
check "Label entorno=lab" "$(get '{.metadata.labels.entorno}')" "lab" "revisa metadata.labels"
check "Imagen nginx:1.27" "$(get '{.spec.containers[0].image}')" "nginx:1.27" "versión fija, no latest ni 1.99"
check "Nombre del contenedor nginx" "$(get '{.spec.containers[0].name}')" "nginx" "spec.containers[0].name"
check "Puerto 80 declarado" "$(get '{.spec.containers[0].ports[0].containerPort}')" "80" "ports.containerPort"
check "Request de CPU 50m" "$(get '{.spec.containers[0].resources.requests.cpu}')" "50m" "resources.requests.cpu"
check "Request de memoria 64Mi" "$(get '{.spec.containers[0].resources.requests.memory}')" "64Mi" "resources.requests.memory"
check "Limit de memoria 128Mi" "$(get '{.spec.containers[0].resources.limits.memory}')" "128Mi" "resources.limits.memory"
check "Pod en estado Running" "$(get '{.status.phase}')" "Running" "kubectl describe pod web -n lab01 → Events"
check "Contenedor Ready" "$(get '{.status.containerStatuses[0].ready}')" "true" "kubectl describe pod web -n lab01"
check "Existe respuestas.md" "$( [ -s "$(dirname "$0")/respuestas.md" ] && echo si)" "si" "crea respuestas.md con tus respuestas"

echo
echo "Resultado: $ok correctos, $fallos por revisar."
[ "$fallos" -eq 0 ] && echo "🎉 Lab 01 listo para revisión con el profesor."
exit "$fallos"
