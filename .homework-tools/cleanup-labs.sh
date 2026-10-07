#!/bin/bash
set +e

ROOT=$(cd "$(dirname "$0")/.." && pwd)

# Stop any interrupted homework runners without touching unrelated processes.
pkill -f '.homework-tools/run-k8s-labs.sh' 2>/dev/null || true
pkill -f '.homework-tools/run-later-labs.sh' 2>/dev/null || true

# Stop/remove only containers and Compose projects started by the homework runs.
docker rm -f session17-homework >/dev/null 2>&1 || true
docker compose -f "$ROOT/session20-monitoring-observability-gitops/04-grafana/docker-compose.yml" down >/dev/null 2>&1 || true
docker compose -f "$ROOT/session21-python/docker-compose.yml" down >/dev/null 2>&1 || true

# Remove only namespaces/releases created by the automation.
helm uninstall notes -n homework-s15 >/dev/null 2>&1 || true
helm uninstall taskboard -n taskboard >/dev/null 2>&1 || true
for ns in \
  homework-s09 homework-s10 homework-s11 homework-s12 homework-s13 homework-s14 homework-s15 \
  production-webapp taskboard; do
  kubectl delete namespace "$ns" --ignore-not-found --wait=false >/dev/null 2>&1 || true
done

# Remove the older, explicitly named Session 10/14 demo workloads left in the
# default namespace. Do not use a broad --all deletion so the built-in
# kubernetes Service and unrelated resources remain untouched.
kubectl delete deployment app-rolling web -n default --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl delete pod \
  crash-demo describe-demo dns-test events-demo exec-demo image-demo logs-demo pending-demo \
  -n default --ignore-not-found --wait=false >/dev/null 2>&1 || true
kubectl delete service \
  app-rolling-service myapp-service myapp-canary-service app-recreate-service web \
  -n default --ignore-not-found >/dev/null 2>&1 || true

echo "Remaining non-system namespaces:"
kubectl get namespaces --no-headers | awk '$1 !~ /^(default|kube-node-lease|kube-public|kube-system|ingress-nginx)$/ {print}'
echo
echo "Remaining non-system Pods:"
kubectl get pods -A --no-headers | awk '$1 !~ /^(kube-system|ingress-nginx)$/ {print}'
echo
echo "Homework containers still running:"
docker ps --format '{{.Names}}' | grep -E '^(session17-homework|session20-|session21-python-)' || true
