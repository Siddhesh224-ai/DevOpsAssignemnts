#!/bin/bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=$(hostname)

header() {
  printf '%s\n' "$1"
  printf 'Host: %s\n' "$HOST"
  printf 'Captured: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
}

cleanup_namespace() {
  kubectl delete namespace "$1" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

run_s09() {
  local out="$ROOT/session9-k8s/homework/evidence.txt"
  cleanup_namespace homework-s09
  {
    header "SESSION 9 - KUBERNETES FUNDAMENTALS"
    kubectl config current-context
    kubectl cluster-info
    kubectl get nodes -o wide
    kubectl apply -f "$ROOT/session9-k8s/homework/namespace.yaml"
    kubectl apply -f "$ROOT/session9-k8s/homework/deployment.yaml" -f "$ROOT/session9-k8s/homework/service.yaml"
    kubectl rollout status deployment/hello-kubernetes -n homework-s09 --timeout=180s
    kubectl get deployment,replicaset,pod,service -n homework-s09 -o wide
    kubectl scale deployment/hello-kubernetes --replicas=3 -n homework-s09
    kubectl rollout status deployment/hello-kubernetes -n homework-s09 --timeout=120s
    kubectl set image deployment/hello-kubernetes web=nginx:1.28-alpine -n homework-s09
    kubectl rollout status deployment/hello-kubernetes -n homework-s09 --timeout=180s
    kubectl get pods -n homework-s09 -L app
    kubectl run s09-client -n homework-s09 --image=curlimages/curl:8.12.1 --restart=Never --rm -i --command -- curl -sI http://hello-kubernetes | sed -n '1,5p'
    kubectl logs -n homework-s09 deployment/hello-kubernetes --tail=3
  } >"$out" 2>&1
  cleanup_namespace homework-s09
}

run_s10() {
  local out="$ROOT/session10-k8s-core-objects/homework/evidence.txt"
  cleanup_namespace homework-s10
  kubectl create namespace homework-s10 >/dev/null
  {
    header "SESSION 10 - DEPLOYMENT STRATEGIES AND POD LIFECYCLE"
    echo "[Rolling update v1 -> v2]"
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/01-rolling-update/deployment-v1.yaml" -f "$ROOT/session10-k8s-core-objects/01-rolling-update/service.yaml"
    kubectl rollout status deployment/app-rolling -n homework-s10 --timeout=180s
    kubectl get pods -n homework-s10 -l app=app-rolling -L version
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/01-rolling-update/deployment-v2.yaml"
    kubectl rollout status deployment/app-rolling -n homework-s10 --timeout=180s
    kubectl rollout history deployment/app-rolling -n homework-s10

    echo; echo "[Blue-green switch]"
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/02-blue-green/deployment-blue.yaml" -f "$ROOT/session10-k8s-core-objects/02-blue-green/deployment-green.yaml" -f "$ROOT/session10-k8s-core-objects/02-blue-green/service-blue.yaml"
    kubectl wait -n homework-s10 --for=condition=available deployment/app-blue deployment/app-green --timeout=180s
    kubectl get pods -n homework-s10 -l app=myapp -L slot,version
    kubectl get endpoints myapp-service -n homework-s10
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/02-blue-green/service-green.yaml"
    kubectl get service myapp-service -n homework-s10 -o custom-columns=NAME:.metadata.name,ACTIVE_SLOT:.spec.selector.slot

    echo; echo "[Canary 9:1 endpoint ratio]"
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/03-canary/deployment-stable.yaml" -f "$ROOT/session10-k8s-core-objects/03-canary/deployment-canary.yaml" -f "$ROOT/session10-k8s-core-objects/03-canary/service.yaml"
    kubectl wait -n homework-s10 --for=condition=available deployment/app-stable deployment/app-canary --timeout=240s
    kubectl get pods -n homework-s10 -l app=myapp-canary -L track,version
    kubectl get endpoints myapp-canary-service -n homework-s10

    echo; echo "[Recreate v1 -> v2]"
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/04-recreate/deployment-v1.yaml" -f "$ROOT/session10-k8s-core-objects/04-recreate/service.yaml"
    kubectl rollout status deployment/app-recreate -n homework-s10 --timeout=180s
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/04-recreate/deployment-v2.yaml"
    kubectl rollout status deployment/app-recreate -n homework-s10 --timeout=180s
    kubectl get replicasets,pods -n homework-s10 -l app=app-recreate -L version

    echo; echo "[Pod lifecycle states]"
    kubectl apply -n homework-s10 -f "$ROOT/session10-k8s-core-objects/pod-lifecycle/01-running.yaml" -f "$ROOT/session10-k8s-core-objects/pod-lifecycle/02-pending.yaml" -f "$ROOT/session10-k8s-core-objects/pod-lifecycle/03-succeeded.yaml" -f "$ROOT/session10-k8s-core-objects/pod-lifecycle/04-failed.yaml" -f "$ROOT/session10-k8s-core-objects/pod-lifecycle/05-crashloopbackoff.yaml" -f "$ROOT/session10-k8s-core-objects/pod-lifecycle/06-imagepullbackoff.yaml"
    sleep 12
    kubectl get pods -n homework-s10 | grep lifecycle || true
    kubectl logs lifecycle-succeeded -n homework-s10 || true
    kubectl get events -n homework-s10 --sort-by=.lastTimestamp | tail -8
  } >"$out" 2>&1
  cleanup_namespace homework-s10
}

run_s11() {
  local out="$ROOT/session-11-kubernetes-services/homework/evidence.txt"
  cleanup_namespace homework-s11
  kubectl create namespace homework-s11 >/dev/null
  {
    header "SESSION 11 - KUBERNETES SERVICES"
    for dir in 01-clusterip 02-nodeport 03-loadbalancer 04-externalname 05-headless; do
      kubectl apply -n homework-s11 -f "$ROOT/session-11-kubernetes-services/$dir" || true
    done
    kubectl wait -n homework-s11 --for=condition=available deployment --all --timeout=240s || true
    kubectl wait -n homework-s11 --for=condition=ready pod --all --timeout=240s || true
    kubectl get services -n homework-s11 -o wide
    kubectl get deployments,statefulsets,pods -n homework-s11 -o wide
    kubectl get endpoints,endpointslices -n homework-s11
    echo; echo "[ClusterIP connectivity]"
    kubectl run s11-client -n homework-s11 --image=curlimages/curl:8.12.1 --restart=Never --rm -i --command -- sh -c 'for s in clusterip-service nodeport-service loadbalancer-service; do echo "$s"; curl -sI --max-time 5 "http://$s" | head -n 1 || true; done' || true
    echo; echo "[Kubernetes DNS and FQDN]"
    kubectl run s11-dns -n homework-s11 --image=busybox:1.36 --restart=Never --rm -i --command -- nslookup kubernetes.default.svc.cluster.local || true
    kubectl get deployment coredns -n kube-system
    kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}' | sed -n '1,18p'
  } >"$out" 2>&1
  cleanup_namespace homework-s11
}

run_s12() {
  local out="$ROOT/session-12-ingress-configmaps-secrets/homework/evidence.txt"
  cleanup_namespace homework-s12
  kubectl create namespace homework-s12 >/dev/null
  minikube addons enable ingress >/dev/null 2>&1 || true
  {
    header "SESSION 12 - CONFIGMAP, SECRET, AND INGRESS"
    kubectl create configmap yatri-app-config -n homework-s12 --from-literal=ENVIRONMENT=production --from-literal=LOG_LEVEL=INFO
    kubectl create secret generic yatri-db-secret -n homework-s12 --from-literal=POSTGRES_USER=yatri_admin --from-literal=POSTGRES_PASSWORD=homework-only-value
    kubectl apply -n homework-s12 -f "$ROOT/session-12-ingress-configmaps-secrets/app/backend-with-config.yaml"
    kubectl rollout status deployment/yatri-backend -n homework-s12 --timeout=240s
    kubectl exec -n homework-s12 deployment/yatri-backend -- sh -c 'printf "ENVIRONMENT=%s\nPOSTGRES_USER=%s\n" "$ENVIRONMENT" "$POSTGRES_USER"'
    kubectl create deployment web -n homework-s12 --image=nginx:1.27-alpine
    kubectl expose deployment web -n homework-s12 --port=80 --target-port=80
    kubectl wait -n ingress-nginx --for=condition=available deployment/ingress-nginx-controller --timeout=240s
    kubectl create ingress yatri-ingress -n homework-s12 --class=nginx --rule='yatri.local/=web:80'
    kubectl rollout status deployment/web -n homework-s12 --timeout=180s
    kubectl get configmap,secret,deployment,service,ingress -n homework-s12
    kubectl exec -n homework-s12 deployment/yatri-backend -- wget -S -O- http://web 2>&1 | sed -n '1,8p'
    echo; echo "[Troubleshooting check: selected endpoints]"
    kubectl get endpoints web -n homework-s12
    kubectl describe ingress yatri-ingress -n homework-s12 | sed -n '1,35p'
  } >"$out" 2>&1
  cleanup_namespace homework-s12
}

run_s13() {
  local out="$ROOT/session-13-storage-hpa-probes/homework/evidence.txt"
  cleanup_namespace homework-s13
  kubectl create namespace homework-s13 >/dev/null
  minikube addons enable metrics-server >/dev/null 2>&1 || true
  {
    header "SESSION 13 - STORAGE, HPA, AND PROBES"
    kubectl apply -n homework-s13 -f "$ROOT/session-13-storage-hpa-probes/01-volumes/emptydir-pod.yaml"
    kubectl apply -n homework-s13 -f "$ROOT/session-13-storage-hpa-probes/02-persistent-storage/pv.yaml" -f "$ROOT/session-13-storage-hpa-probes/02-persistent-storage/pvc.yaml" -f "$ROOT/session-13-storage-hpa-probes/02-persistent-storage/pod.yaml" || true
    kubectl apply -n homework-s13 -f "$ROOT/session-13-storage-hpa-probes/04-hpa/deployment.yaml" -f "$ROOT/session-13-storage-hpa-probes/04-hpa/service.yaml" -f "$ROOT/session-13-storage-hpa-probes/04-hpa/hpa.yaml"
    kubectl rollout status deployment/hpa-demo -n homework-s13 --timeout=180s
    kubectl wait -n kube-system --for=condition=available deployment/metrics-server --timeout=240s
    sleep 25
    kubectl get pods,pvc,pv -n homework-s13 -o wide
    kubectl get storageclass
    kubectl get hpa -n homework-s13
    kubectl top pods -n homework-s13 || true
    kubectl describe hpa hpa-demo -n homework-s13 | sed -n '1,45p'
    echo; echo "[HPA load generation and scaling]"
    for i in 1 2 3; do
      kubectl run "hpa-load-$i" -n homework-s13 --image=busybox:1.36 --restart=Never --command -- sh -c 'while true; do wget -q -O- http://hpa-demo-service >/dev/null; done'
    done
    # HPA reconciliation and metrics sampling are intentionally slower than Pod startup.
    sleep 90
    kubectl get hpa,pods -n homework-s13
    kubectl top pods -n homework-s13 || true
    echo; echo "[Probe manifests]"
    kubectl apply -n homework-s13 -f "$ROOT/session-13-storage-hpa-probes/05-probes/liveness.yaml" -f "$ROOT/session-13-storage-hpa-probes/05-probes/readiness.yaml" -f "$ROOT/session-13-storage-hpa-probes/05-probes/startup.yaml" || true
    sleep 8
    kubectl get pods -n homework-s13
    echo; echo "[Mini-project validation]"
    kubectl apply -f "$ROOT/session-13-storage-hpa-probes/mini-project/namespace.yaml"
    kubectl apply -f "$ROOT/session-13-storage-hpa-probes/mini-project/pvc.yaml" -f "$ROOT/session-13-storage-hpa-probes/mini-project/deployment.yaml" -f "$ROOT/session-13-storage-hpa-probes/mini-project/service.yaml" -f "$ROOT/session-13-storage-hpa-probes/mini-project/hpa.yaml"
    kubectl rollout status deployment/web-app -n production-webapp --timeout=240s
    kubectl get deployment,pods,service,pvc,hpa -n production-webapp
  } >"$out" 2>&1
  cleanup_namespace homework-s13
  cleanup_namespace production-webapp
}

run_s14() {
  local out="$ROOT/session-14-kubernetes-troubleshooting/homework/evidence.txt"
  cleanup_namespace homework-s14
  kubectl create namespace homework-s14 >/dev/null
  {
    header "SESSION 14 - KUBERNETES TROUBLESHOOTING"
    echo "[CrashLoopBackOff before]"
    kubectl apply -n homework-s14 -f "$ROOT/session-14-kubernetes-troubleshooting/06-crashloopbackoff/broken-pod.yaml"
    sleep 8
    kubectl get pod crash-demo -n homework-s14
    kubectl logs crash-demo -n homework-s14 --tail=5 || true
    kubectl delete pod crash-demo -n homework-s14 --wait=true
    kubectl apply -n homework-s14 -f "$ROOT/session-14-kubernetes-troubleshooting/06-crashloopbackoff/fixed-pod.yaml"
    kubectl wait --for=condition=ready pod/crash-demo -n homework-s14 --timeout=120s
    echo "[CrashLoopBackOff fixed]"; kubectl get pod crash-demo -n homework-s14

    echo; echo "[ImagePullBackOff before/fixed]"
    kubectl apply -n homework-s14 -f "$ROOT/session-14-kubernetes-troubleshooting/07-imagepullbackoff/broken-pod.yaml"
    sleep 5
    kubectl get pod image-demo -n homework-s14
    kubectl describe pod image-demo -n homework-s14 | grep -E 'Failed|Back-off|Error' | tail -4 || true
    kubectl delete pod image-demo -n homework-s14 --wait=true
    kubectl apply -n homework-s14 -f "$ROOT/session-14-kubernetes-troubleshooting/07-imagepullbackoff/fixed-pod.yaml"
    kubectl wait --for=condition=ready pod/image-demo -n homework-s14 --timeout=180s
    kubectl get pod image-demo -n homework-s14

    echo; echo "[Pending before/fixed]"
    kubectl apply -n homework-s14 -f "$ROOT/session-14-kubernetes-troubleshooting/08-pending-pods/broken-pod.yaml"
    sleep 3
    kubectl get pod pending-demo -n homework-s14
    kubectl get events -n homework-s14 --field-selector involvedObject.name=pending-demo | tail -5
    kubectl delete pod pending-demo -n homework-s14 --wait=true
    kubectl apply -n homework-s14 -f "$ROOT/session-14-kubernetes-troubleshooting/08-pending-pods/fixed-pod.yaml"
    kubectl wait --for=condition=ready pod/pending-demo -n homework-s14 --timeout=180s
    kubectl get pod pending-demo -n homework-s14 -o wide

    echo; echo "[Command coverage]"
    kubectl explain pod.spec.containers.resources.requests | sed -n '1,12p'
    kubectl top pods -n homework-s14 || true
    kubectl exec -n homework-s14 crash-demo -- sh -c 'hostname; echo exec-ok'
  } >"$out" 2>&1
  cleanup_namespace homework-s14
}

run_s15() {
  local out="$ROOT/session-15-helm/homework/evidence.txt"
  local chart="$ROOT/session-15-helm/mini-project/notes-chart"
  cleanup_namespace homework-s15
  kubectl create namespace homework-s15 >/dev/null
  {
    header "SESSION 15 - HELM LIFECYCLE AND ROLLBACK"
    helm version --short
    helm lint "$chart"
    helm template notes "$chart" -n homework-s15 | sed -n '1,24p'
    helm upgrade --install notes "$chart" -n homework-s15 --wait --timeout 4m
    helm list -n homework-s15
    helm status notes -n homework-s15 | sed -n '1,18p'
    helm get values notes -n homework-s15
    helm upgrade notes "$chart" -n homework-s15 -f "$chart/values-prod.yaml" --wait --timeout 4m
    helm upgrade notes "$chart" -n homework-s15 --set replicaCount=2 --set image.tag=1.26 --wait --timeout 4m
    helm history notes -n homework-s15
    helm rollback notes 2 -n homework-s15 --wait --timeout 4m
    echo "[After rollback]"
    helm history notes -n homework-s15
    kubectl get deployment,pods,service,configmap -n homework-s15
    helm get manifest notes -n homework-s15 | sed -n '1,18p'
    helm repo list || true
    helm search hub nginx | head -6 || true
    helm uninstall notes -n homework-s15
    helm list -n homework-s15
  } >"$out" 2>&1
  cleanup_namespace homework-s15
}

case "${1:-all}" in
  s09) run_s09; sessions="session9-k8s" ;;
  s10) run_s10; sessions="session10-k8s-core-objects" ;;
  s11) run_s11; sessions="session-11-kubernetes-services" ;;
  s12) run_s12; sessions="session-12-ingress-configmaps-secrets" ;;
  s13) run_s13; sessions="session-13-storage-hpa-probes" ;;
  s14) run_s14; sessions="session-14-kubernetes-troubleshooting" ;;
  s15) run_s15; sessions="session-15-helm" ;;
  all)
    run_s09
    run_s10
    run_s11
    run_s12
    run_s13
    run_s14
    if command -v helm >/dev/null 2>&1; then
      run_s15
    else
      { header "SESSION 15 - HELM"; echo "Helm is not installed; live lifecycle was not executed."; } >"$ROOT/session-15-helm/homework/evidence.txt"
    fi
    sessions="session9-k8s session10-k8s-core-objects session-11-kubernetes-services session-12-ingress-configmaps-secrets session-13-storage-hpa-probes session-14-kubernetes-troubleshooting session-15-helm"
    ;;
  *) echo "usage: $0 [all|s09|s10|s11|s12|s13|s14|s15]" >&2; exit 2 ;;
esac

for session in $sessions; do
  "$ROOT/.homework-tools/render-evidence.sh" "$ROOT/$session/homework/evidence.txt" "$ROOT/$session/homework/evidence.png"
done

echo "Requested Kubernetes/Helm lab execution complete: $sessions"
