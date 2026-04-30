#!/usr/bin/env bash
# =============================================================================
# Smart Redact command wrapper
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND=""
VARIANT="cpu"
BACKEND="compose"
ENV_FILE=""
LICENSE_KEY=""
FORCE=0
VOLUMES=0
IMAGES=0
TIMEOUT=300
LOG_SERVICES=()
LOG_SERVICE_COUNT=0

usage() {
  cat <<'USAGE'
Smart Redact samples helper

Usage:
  ./smart-redact.sh <command> [options] [service...]

Commands:
  setup       Create an env file with generated secrets
  up          Start services
  down        Stop and remove containers, keeping volumes
  restart     Restart services
  status      Show container status
  health      Show health/status
  logs        Stream logs (optional service names)
  pull        Pull Docker images
  clean       Stop and remove containers; add --volumes/--images/--all to delete data and images
  help        Show this help

Options:
  --variant cpu|gpu|minimal       Deployment variant (default: cpu full stack)
  --backend compose|docker-run    Runtime backend (default: compose)
  --env-file PATH                 Env file path
  --license-key KEY               Smart Redact license key for setup
  --force                         Overwrite existing env file during setup
  --volumes                       Delete persisted Docker volumes during clean
  --images                        Delete Smart Redact Docker images during clean
  --all                           Shorthand for --volumes --images
  --timeout SECONDS               Compose up --wait timeout (default: 300)
  -h, --help                      Show this help

Examples:
  ./smart-redact.sh setup --license-key "<RDCTSRV,...>"
  ./smart-redact.sh up
  ./smart-redact.sh logs manager worker
  ./smart-redact.sh health
  ./smart-redact.sh clean --volumes
  ./smart-redact.sh clean --all
USAGE
}

die() {
  echo "Error: $*" >&2
  exit 1
}

is_command() {
  case "$1" in
    setup|up|down|restart|status|health|logs|pull|clean|help) return 0 ;;
    *) return 1 ;;
  esac
}

need_value() {
  local option="$1"
  local value="${2:-}"
  [ -n "$value" ] || die "$option requires a value."
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --variant)
      need_value "$1" "${2:-}"
      VARIANT="$2"
      shift 2
      ;;
    --backend)
      need_value "$1" "${2:-}"
      BACKEND="$2"
      shift 2
      ;;
    --env-file)
      need_value "$1" "${2:-}"
      ENV_FILE="$2"
      shift 2
      ;;
    --license-key)
      need_value "$1" "${2:-}"
      LICENSE_KEY="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --volumes)
      VOLUMES=1
      shift
      ;;
    --images)
      IMAGES=1
      shift
      ;;
    --all)
      VOLUMES=1
      IMAGES=1
      shift
      ;;
    --timeout)
      need_value "$1" "${2:-}"
      TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      COMMAND="help"
      shift
      ;;
    *)
      if [ -z "$COMMAND" ] && is_command "$1"; then
        COMMAND="$1"
      elif [ "$COMMAND" = "logs" ]; then
        LOG_SERVICES+=("$1")
        LOG_SERVICE_COUNT=$((LOG_SERVICE_COUNT + 1))
      else
        die "Unknown argument: $1"
      fi
      shift
      ;;
  esac
done

COMMAND="${COMMAND:-help}"

case "$VARIANT" in
  cpu|gpu|minimal) ;;
  *) die "--variant must be one of: cpu, gpu, minimal." ;;
esac

case "$BACKEND" in
  compose|docker-run) ;;
  *) die "--backend must be one of: compose, docker-run." ;;
esac

case "$TIMEOUT" in
  ''|*[!0-9]*) die "--timeout must be a positive integer." ;;
  0) die "--timeout must be greater than zero." ;;
esac

compose_file() {
  echo "${SCRIPT_DIR}/docker-compose/${VARIANT}/docker-compose.yml"
}

default_env_file() {
  if [ "$BACKEND" = "compose" ]; then
    echo "${SCRIPT_DIR}/docker-compose/${VARIANT}/.env"
  else
    echo "${SCRIPT_DIR}/.env"
  fi
}

resolved_env_file() {
  if [ -n "$ENV_FILE" ]; then
    case "$ENV_FILE" in
      /*) echo "$ENV_FILE" ;;
      *) echo "${PWD}/${ENV_FILE}" ;;
    esac
  else
    default_env_file
  fi
}

ENV_FILE="$(resolved_env_file)"

require_docker() {
  command -v docker >/dev/null 2>&1 || die "Docker is required. Install Docker Desktop or Docker Engine and try again."
}

require_openssl() {
  command -v openssl >/dev/null 2>&1 || die "openssl is required to generate secrets. Install openssl or provide an env file manually."
}

require_compose_wait() {
  require_docker
  docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is required. Install/update Docker Compose and try again."
  docker compose up --help 2>/dev/null | grep -q -- '--wait' || \
    die "Your Docker Compose version does not support 'docker compose up --wait'. Please update Docker Compose."
}

run_compose() {
  require_docker
  local args=()
  if [ -f "$ENV_FILE" ]; then
    args+=(--env-file "$ENV_FILE")
  fi
  args+=(-f "$(compose_file)")
  docker compose "${args[@]}" "$@"
}

prompt_license_key() {
  if [ -n "$LICENSE_KEY" ]; then
    return 0
  fi

  if [ -t 0 ]; then
    printf 'Smart Redact license key: ' >&2
    IFS= read -r LICENSE_KEY
  else
    die "Pass --license-key when running setup non-interactively."
  fi

  [ -n "$LICENSE_KEY" ] || die "License key cannot be empty."
}

generate_secret_32() {
  openssl rand -base64 32
}

generate_jwt_secret() {
  openssl rand -base64 64 | tr -d '\n'
}

env_file_get() {
  local key="$1"
  local default="${2:-}"
  local value=""

  if [ -f "$ENV_FILE" ]; then
    value="$(
      awk -v key="$key" '
        /^[[:space:]]*(#|$)/ { next }
        {
          line = $0
          sub(/^[[:space:]]*export[[:space:]]+/, "", line)
          split(line, parts, "=")
          current_key = parts[1]
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", current_key)
          if (current_key != key) { next }
          sub(/^[^=]*=/, "", line)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
          if (line ~ /^".*"$/ || line ~ /^\047.*\047$/) {
            line = substr(line, 2, length(line) - 2)
          }
          print line
          exit
        }
      ' "$ENV_FILE"
    )"
  fi

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '%s\n' "$default"
  fi
}

swagger_url_from_base() {
  local url="${1%/}"
  case "$url" in
    */swagger) printf '%s\n' "$url" ;;
    *://*/*) printf '%s\n' "$url" ;;
    *) printf '%s/swagger\n' "$url" ;;
  esac
}

write_env_file() {
  local target="$1"
  mkdir -p "$(dirname "$target")"

  if [ -e "$target" ] && [ "$FORCE" -ne 1 ]; then
    die "Env file already exists: $target. Use --force to replace it."
  fi

  local encryption_key jwt_secret
  encryption_key="$(generate_secret_32)"

  {
    echo '# ============================================================================='
    echo '# Smart Redact - generated local environment'
    echo '# ============================================================================='
    echo '# This file contains secrets. Do not commit it.'
    echo ''
    echo "PDFTOOLS_LICENSE_KEY=${LICENSE_KEY}"
    echo "ENCRYPTION_KEY=${encryption_key}"
    if [ "$VARIANT" != "minimal" ]; then
      jwt_secret="$(generate_jwt_secret)"
      echo "ORCHESTRATOR_JWT_SECRET=${jwt_secret}"
    fi
    echo ''
    echo '# Optional settings'
    echo '# VERSION=latest'
    if [ "$VARIANT" != "minimal" ]; then
      echo '# HITL_WEB_PORT=3000'
      echo '# HITL_ORCHESTRATOR_URL=http://localhost:9983'
    fi
  } > "$target"

  chmod 600 "$target" 2>/dev/null || true
  echo "Created env file: $target"
  echo "Variant: ${VARIANT} ($(variant_description))"
}

variant_description() {
  case "$VARIANT" in
    cpu) echo "full stack with CPU inference: Manager, Worker, Orchestrator, HITL Web UI, and PostgreSQL" ;;
    gpu) echo "full stack with GPU/CUDA inference: Manager, Worker, Orchestrator, HITL Web UI, and PostgreSQL" ;;
    minimal) echo "API-only stack: Manager, Worker, and PostgreSQL; no Orchestrator or HITL Web UI" ;;
  esac
}

cmd_setup() {
  if [ "$BACKEND" = "docker-run" ] && [ "$VARIANT" = "minimal" ]; then
    die "docker-run backend supports cpu and gpu full-stack variants only. Use --backend compose for --variant minimal."
  fi
  require_openssl
  prompt_license_key
  write_env_file "$ENV_FILE"
}

ensure_env_exists() {
  [ -f "$ENV_FILE" ] || die "Env file not found: $ENV_FILE. Run setup first."
}

cmd_compose_up() {
  ensure_env_exists
  require_compose_wait
  run_compose up -d --wait --wait-timeout "$TIMEOUT"

  local hitl_web_port orchestrator_url

  echo ""
  echo "Services are ready."
  if [ "$VARIANT" != "minimal" ]; then
    hitl_web_port="$(env_file_get "HITL_WEB_PORT" "3000")"
    orchestrator_url="$(env_file_get "HITL_ORCHESTRATOR_URL" "http://localhost:9983")"
    echo "  HITL Web UI:      http://localhost:${hitl_web_port}"
    echo "  Orchestrator API: $(swagger_url_from_base "$orchestrator_url")"
  fi
  echo "  Manager API:      http://localhost:9982/swagger"
}

cmd_compose_down() {
  run_compose down
}

cmd_compose_restart() {
  cmd_compose_down
  cmd_compose_up
}

cmd_compose_status() {
  run_compose ps
}

cmd_compose_health() {
  run_compose ps
}

cmd_compose_logs() {
  local ids logs_pid
  local services=()
  local svc

  if [ "$LOG_SERVICE_COUNT" -gt 0 ]; then
    for svc in "${LOG_SERVICES[@]}"; do
      services+=("$(container_for_service "$svc")")
    done
    ids="$(run_compose ps -q "${services[@]}" 2>/dev/null || true)"
    [ -n "$ids" ] || die "No running Compose containers found for: ${services[*]}"
    run_compose logs -f --tail 200 "${services[@]}" &
  else
    ids="$(run_compose ps -q 2>/dev/null || true)"
    [ -n "$ids" ] || die "No running Compose containers found. Run up first."
    run_compose logs -f --tail 200 &
  fi

  logs_pid="$!"
  trap 'kill "$logs_pid" 2>/dev/null || true' INT TERM EXIT

  while kill -0 "$logs_pid" 2>/dev/null; do
    if [ "$LOG_SERVICE_COUNT" -gt 0 ]; then
      ids="$(run_compose ps -q "${services[@]}" 2>/dev/null || true)"
    else
      ids="$(run_compose ps -q 2>/dev/null || true)"
    fi

    if [ -z "$ids" ]; then
      kill "$logs_pid" 2>/dev/null || true
      wait "$logs_pid" 2>/dev/null || true
      trap - INT TERM EXIT
      echo "Compose services stopped; log stream closed."
      return 0
    fi
    sleep 2
  done

  wait "$logs_pid"
  trap - INT TERM EXIT
}

cmd_compose_pull() {
  run_compose pull
}

remove_smart_redact_images() {
  require_docker
  local repo image images count=0
  for repo in \
    pdftoolsag/smart-redact-manager \
    pdftoolsag/smart-redact-worker \
    pdftoolsag/smart-redact-orchestrator \
    pdftoolsag/smart-redact-hitl-web; do
    images="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${repo}:" || true)"
    [ -n "$images" ] || continue
    while IFS= read -r image; do
      [ -n "$image" ] || continue
      if docker rmi -f "$image" >/dev/null; then
        echo "  Removed: $image"
        count=$((count + 1))
      else
        echo "  Failed to remove: $image" >&2
      fi
    done <<< "$images"
  done
  if [ "$count" -eq 0 ]; then
    echo "  No Smart Redact images found."
  else
    echo "  Removed ${count} image(s)."
  fi
}

cmd_compose_clean() {
  local args=(down)
  [ "$VOLUMES" -eq 1 ] && args+=(-v)
  run_compose "${args[@]}"

  if [ "$IMAGES" -eq 1 ]; then
    echo ""
    echo "Removing Smart Redact images..."
    remove_smart_redact_images
  fi
}

load_env_file() {
  ensure_env_exists
  local line key value
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    key="$(printf '%s' "$key" | sed 's/[[:space:]]//g')"
    value="${value%$'\r'}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    case "$key" in
      PDFTOOLS_LICENSE_KEY|ENCRYPTION_KEY|ORCHESTRATOR_JWT_SECRET|VERSION|HITL_WEB_PORT|HITL_ORCHESTRATOR_URL)
        export "${key}=${value}"
        ;;
    esac
  done < "$ENV_FILE"
}

run_script() {
  local script="$1"
  shift
  "${SCRIPT_DIR}/docker-run/${script}" "$@"
}

wait_for_worker_container() {
  local start timeout status
  timeout="$TIMEOUT"
  if [ -n "${WORKER_HEALTH_TIMEOUT_SECONDS:-}" ]; then
    case "$WORKER_HEALTH_TIMEOUT_SECONDS" in
      ''|*[!0-9]*|0)
        die "WORKER_HEALTH_TIMEOUT_SECONDS must be a positive integer."
        ;;
      *)
        if [ "$WORKER_HEALTH_TIMEOUT_SECONDS" -lt "$timeout" ]; then
          timeout="$WORKER_HEALTH_TIMEOUT_SECONDS"
        fi
        ;;
    esac
  fi
  start="$(date +%s)"
  echo "Waiting for Worker to become healthy..."
  until docker inspect --format='{{.State.Health.Status}}' smart-redact-worker 2>/dev/null | grep -q healthy; do
    if (( $(date +%s) - start > timeout )); then
      echo "Error: Worker did not become healthy within ${timeout}s." >&2
      docker logs --tail 50 smart-redact-worker >&2 || true
      exit 1
    fi
    sleep 2
  done
  echo "Worker is ready."
}

cmd_docker_run_up() {
  [ "$VARIANT" != "minimal" ] || die "docker-run backend supports cpu and gpu full-stack variants only. Use --backend compose for --variant minimal."
  load_env_file
  require_docker
  run_script run-storage-init.sh
  run_script run-postgres.sh
  if [ "$VARIANT" = "gpu" ]; then
    run_script run-worker-gpu.sh
  else
    run_script run-worker.sh
  fi
  wait_for_worker_container
  run_script run-manager.sh
  run_script run-orchestrator.sh
  run_script run-hitl-web.sh
  "${SCRIPT_DIR}/docker-run/wait-for-services.sh" "$TIMEOUT"
}

cmd_docker_run_down() {
  require_docker
  run_script cleanup.sh
}

cmd_docker_run_restart() {
  cmd_docker_run_down
  cmd_docker_run_up
}

cmd_docker_run_status() {
  require_docker
  docker ps -a --filter 'name=smart-redact-' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

cmd_docker_run_health() {
  load_env_file
  "${SCRIPT_DIR}/docker-run/health-check.sh"
}

container_for_service() {
  case "$1" in
    manager) echo smart-redact-manager ;;
    worker) echo smart-redact-worker ;;
    orchestrator) echo smart-redact-orchestrator ;;
    hitl|hitl-web) echo smart-redact-hitl-web ;;
    manager-db) echo smart-redact-manager-db ;;
    orchestrator-db) echo smart-redact-orchestrator-db ;;
    *) echo "$1" ;;
  esac
}

cmd_docker_run_logs() {
  require_docker
  local containers=() service container pids=()
  local pids_count=0

  if [ "$LOG_SERVICE_COUNT" -gt 0 ]; then
    for service in "${LOG_SERVICES[@]}"; do
      containers+=("$(container_for_service "$service")")
    done
  else
    containers=(
      smart-redact-manager
      smart-redact-worker
      smart-redact-orchestrator
      smart-redact-hitl-web
      smart-redact-manager-db
      smart-redact-orchestrator-db
    )
  fi

  for container in "${containers[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
      docker logs -f --tail 200 "$container" &
      pids+=("$!")
      pids_count=$((pids_count + 1))
    else
      echo "Skipping missing container: $container" >&2
    fi
  done

  [ "$pids_count" -gt 0 ] || die "No matching docker-run containers found."
  trap 'kill "${pids[@]}" 2>/dev/null || true' INT TERM EXIT
  wait
}

cmd_docker_run_pull() {
  load_env_file
  require_docker
  local version="${VERSION:-latest}"
  docker pull postgres:15-alpine
  docker pull alpine:3
  docker pull "pdftoolsag/smart-redact-manager:${version}"
  docker pull "pdftoolsag/smart-redact-orchestrator:${version}"
  docker pull "pdftoolsag/smart-redact-hitl-web:${version}"
  if [ "$VARIANT" = "gpu" ]; then
    docker pull "pdftoolsag/smart-redact-worker:${version}-cuda"
  else
    docker pull "pdftoolsag/smart-redact-worker:${version}"
  fi
}

cmd_docker_run_clean() {
  require_docker
  if [ "$VOLUMES" -eq 1 ] && [ "$IMAGES" -eq 1 ]; then
    run_script cleanup.sh --volumes --images
  elif [ "$VOLUMES" -eq 1 ]; then
    run_script cleanup.sh --volumes
  elif [ "$IMAGES" -eq 1 ]; then
    run_script cleanup.sh --images
  else
    run_script cleanup.sh
  fi
}

case "$COMMAND" in
  help)
    usage
    ;;
  setup)
    cmd_setup
    ;;
  up|down|restart|status|health|logs|pull|clean)
    if [ "$BACKEND" = "compose" ]; then
      "cmd_compose_${COMMAND}"
    else
      "cmd_docker_run_${COMMAND}"
    fi
    ;;
  *)
    die "Unknown command: $COMMAND"
    ;;
esac
