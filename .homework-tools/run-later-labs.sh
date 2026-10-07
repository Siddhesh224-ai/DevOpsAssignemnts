#!/bin/bash
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HOST=$(hostname)

header() {
  printf '%s\n' "$1"
  printf 'Host: %s\n' "$HOST"
  printf 'Captured: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
}

render() {
  "$ROOT/.homework-tools/render-evidence.sh" "$ROOT/$1/homework/evidence.txt" "$ROOT/$1/homework/evidence.png"
}

run_s16() {
  local project="$ROOT/session-16-github-actions/session-16-github-actions/10-final-cicd-pipeline"
  local out="$ROOT/session-16-github-actions/homework/evidence.txt"
  {
    header "SESSION 16 - LOCAL CI/CD QUALITY GATE"
    echo "[Workflow triggers/jobs/artifact]"
    grep -E '^(name:|on:|  (test|build|security-check):|      - name: Upload build artifact)' "$project/.github/workflows/ci.yml"
    echo; echo "[Tests]"
    docker run --rm -v "$project:/work" -w /work python:3.12-slim sh -c 'pip install -q -r requirements.txt && pytest -v'
    echo; echo "[Build and artifact]"
    chmod +x "$project/build.sh"
    (cd "$project" && ./build.sh && cat build/build-info.txt)
    echo; echo "[Credential hygiene]"
    if find "$project" -type f \( -name '.env' -o -name '*.pem' -o -name '*.key' \) | grep -q .; then
      echo "FAIL: sensitive-looking file found"
    else
      echo "PASS: no .env, PEM, or key files"
    fi
  } >"$out" 2>&1
  render session-16-github-actions
}

run_s17() {
  local project="$ROOT/session-17-devsecops/demo"
  local out="$ROOT/session-17-devsecops/homework/evidence.txt"
  {
    header "SESSION 17 - LOCAL DEVSECOPS QUALITY GATE"
    echo "[Unit tests and coverage]"
    docker run --rm -v "$project:/work" -w /work python:3.12-slim sh -c 'pip install -q -r requirements-dev.txt && pytest --cov=app --cov-report=term-missing'
    echo; echo "[Pipeline security stages]"
    grep -E '^  (test|sast|sca|secret-scan|docker-build|image-scan|push|deploy):|exit-code 1|gitleaks|pip-audit|CodeQL' "$project/.github/workflows/devsecops.yml"
    echo; echo "[Docker build and non-root check]"
    docker build -t session17-devsecops:homework "$project"
    docker image inspect session17-devsecops:homework --format 'Image={{.RepoTags}} User={{.Config.User}}'
    docker rm -f session17-homework >/dev/null 2>&1 || true
    docker run -d --name session17-homework -p 15001:5001 session17-devsecops:homework
    for _ in $(seq 1 30); do curl -fsS http://127.0.0.1:15001/health && break; sleep 1; done
    echo
    curl -fsS http://127.0.0.1:15001/api/status | head -c 300; echo
    docker rm -f session17-homework >/dev/null
    echo; echo "[Kubernetes manifest client validation]"
    kubectl apply --dry-run=client --validate=false -f "$project/k8s/deployment.yaml" -f "$project/k8s/service.yaml"
  } >"$out" 2>&1
  render session-17-devsecops
}

terraform_verify() {
  local dir=$1
  terraform -chdir="$dir" fmt -recursive
  terraform -chdir="$dir" init -backend=false -input=false
  terraform -chdir="$dir" validate
  terraform -chdir="$dir" providers
}

run_s18() {
  local project="$ROOT/session18-terraform-iac/terraform-s3-demo"
  local out="$ROOT/session18-terraform-iac/homework/evidence.txt"
  {
    header "SESSION 18 - TERRAFORM S3 STATIC/PROVIDER VALIDATION"
    terraform version | head -2
    terraform_verify "$project"
    echo; echo "[Resources and outputs]"
    terraform -chdir="$project" providers schema -json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("AWS provider schema loaded:", "registry.terraform.io/hashicorp/aws" in d["provider_schemas"])'
    grep -R -E 'resource "aws_s3_bucket"|output "bucket_' "$project"/*.tf
    echo; echo "AWS execution status: NOT RUN - no AWS credentials/profile configured."
  } >"$out" 2>&1
  render session18-terraform-iac
}

run_s19() {
  local project="$ROOT/session19-cloud-terraform/08-mini-project"
  local out="$ROOT/session19-cloud-terraform/homework/evidence.txt"
  {
    header "SESSION 19 - CLOUD TERRAFORM VALIDATION"
    terraform_verify "$project"
    echo; echo "[Planned resource types represented in configuration]"
    grep -h '^resource ' "$project"/*.tf
    echo; echo "[Dependency references]"
    grep -E 'vpc_id|subnet_id|route_table_id|gateway_id' "$project/main.tf" | sed -n '1,18p'
    echo; echo "AWS plan/apply/destroy status: NOT RUN - no AWS credentials/profile configured."
  } >"$out" 2>&1
  render session19-cloud-terraform
}

run_s20() {
  local project="$ROOT/session20-monitoring-observability-gitops"
  local out="$project/homework/evidence.txt"
  {
    header "SESSION 20 - MONITORING, OBSERVABILITY, AND GITOPS"
    echo "[Prometheus and Grafana containers]"
    docker compose -f "$project/04-grafana/docker-compose.yml" down >/dev/null 2>&1 || true
    docker compose -f "$project/04-grafana/docker-compose.yml" up -d --quiet-pull
    for _ in $(seq 1 45); do curl -fsS http://127.0.0.1:9090/-/ready >/dev/null && break; sleep 1; done
    for _ in $(seq 1 45); do curl -fsS http://127.0.0.1:3000/api/health >/dev/null && break; sleep 1; done
    docker compose -f "$project/04-grafana/docker-compose.yml" ps
    printf 'Prometheus readiness: '; curl -fsS http://127.0.0.1:9090/-/ready; echo
    sleep 6
    printf 'Prometheus target health: '
    curl -fsS 'http://127.0.0.1:9090/api/v1/targets' | python3 -c 'import json,sys; d=json.load(sys.stdin); print([(x["labels"].get("job"), x["health"]) for x in d["data"]["activeTargets"]])'
    printf 'Grafana health: '; curl -fsS http://127.0.0.1:3000/api/health; echo
    docker compose -f "$project/04-grafana/docker-compose.yml" down
    echo; echo "[GitOps manifests]"
    find "$project/08-mini-project" -type f \( -name '*.yaml' -o -name '*.yml' \) -maxdepth 3 -print
    kubectl apply --dry-run=client --validate=false -f "$project/08-mini-project/app" 2>/dev/null || true
    grep -R -E 'kind: (Application|Deployment|Service|Namespace)|replicas:' "$project/08-mini-project" --include='*.yaml' --include='*.yml' || true
  } >"$out" 2>&1
  render session20-monitoring-observability-gitops
}

run_s21() {
  local project="$ROOT/session21-python"
  local out="$project/homework/evidence.txt"
  {
    header "SESSION 21 - TASKBOARD APPLICATION ASSIGNMENT"
    echo "Scope: TaskBoard assignment only; no separate capstone/final project added."
    echo; echo "[Backend tests - SQLite test database]"
    docker run --rm -v "$project/backend:/work" -w /work python:3.12-slim sh -c 'pip install -q -r requirements.txt && pytest -v'
    echo; echo "[Frontend production build]"
    docker run --rm -v "$project/frontend:/work" -w /work node:22-alpine sh -c 'npm install --silent && npm run build'
    echo; echo "[Docker Compose build and application health]"
    docker compose -f "$project/docker-compose.yml" down >/dev/null 2>&1 || true
    docker compose -f "$project/docker-compose.yml" up -d --build
    for _ in $(seq 1 60); do curl -fsS http://127.0.0.1:8000/health >/dev/null && break; sleep 2; done
    for _ in $(seq 1 30); do curl -fsS http://127.0.0.1:3000/ >/dev/null && break; sleep 1; done
    docker compose -f "$project/docker-compose.yml" ps
    printf 'Health: '; curl -fsS http://127.0.0.1:8000/health; echo
    printf 'Readiness: '; curl -fsS http://127.0.0.1:8000/ready; echo
    printf 'Tasks API: '; curl -fsS http://127.0.0.1:8000/api/tasks | head -c 220; echo
    printf 'Metrics sample: '; curl -fsS http://127.0.0.1:8000/metrics | grep -m1 '^http_' || true; echo
    printf 'Frontend title: '; curl -fsS http://127.0.0.1:3000/ | grep -o '<title>[^<]*' | head -1; echo
    docker image inspect session21-python-backend session21-python-frontend --format 'Image={{index .RepoTags 0}} User={{.Config.User}}'

    echo; echo "[Helm lint and render]"
    helm lint "$project/helm/taskboard"
    helm template taskboard "$project/helm/taskboard" --set monitoring.serviceMonitor.enabled=false --set ingress.enabled=true >/tmp/taskboard-rendered.yaml
    grep -E '^kind: (Deployment|Service|Ingress|HorizontalPodAutoscaler|PersistentVolumeClaim|Secret)' /tmp/taskboard-rendered.yaml | sort | uniq -c

    echo; echo "[Terraform VPC/EKS validation]"
    terraform_verify "$project/terraform"
    echo "AWS plan/apply status: NOT RUN - no AWS credentials/profile configured."

    echo; echo "[Local Minikube Helm deployment]"
    minikube image load session21-python-backend:latest
    minikube image load session21-python-frontend:latest
    kubectl delete namespace taskboard --ignore-not-found --wait=true >/dev/null 2>&1 || true
    kubectl apply -f "$project/k8s/namespace.yaml"
    helm upgrade --install taskboard "$project/helm/taskboard" -n taskboard \
      --set backend.image=session21-python-backend --set backend.tag=latest \
      --set frontend.image=session21-python-frontend --set frontend.tag=latest \
      --set monitoring.serviceMonitor.enabled=false --set ingress.enabled=true \
      --wait --timeout 8m
    kubectl get deployment,pods,service,ingress,hpa,pvc -n taskboard
    helm list -n taskboard
    kubectl rollout status deployment/taskboard-taskboard-backend -n taskboard --timeout=180s
    kubectl exec -n taskboard deployment/taskboard-taskboard-backend -- python -c 'import urllib.request; print(urllib.request.urlopen("http://localhost:8000/health").read().decode())'
    helm uninstall taskboard -n taskboard
    kubectl delete namespace taskboard --wait=false
    docker compose -f "$project/docker-compose.yml" down
  } >"$out" 2>&1
  render session21-python
}

case "${1:-all}" in
  s16) run_s16 ;;
  s17) run_s17 ;;
  s18) run_s18 ;;
  s19) run_s19 ;;
  s20) run_s20 ;;
  s21) run_s21 ;;
  status)
    kubectl get pods,events -n taskboard -o wide
    echo "--- frontend logs ---"
    kubectl logs -n taskboard deployment/taskboard-frontend --tail=60 || true
    echo "--- backend logs ---"
    kubectl logs -n taskboard deployment/taskboard-taskboard-backend --tail=60 || true
    ;;
  all) run_s16; run_s17; run_s18; run_s19; run_s20; run_s21 ;;
  *) echo "usage: $0 [all|s16|s17|s18|s19|s20|s21|status]" >&2; exit 2 ;;
esac

echo "Requested later-session lab execution complete."
