#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/with_bosc_proxy.sh --print-env
  scripts/with_bosc_proxy.sh --check [URL]
  scripts/with_bosc_proxy.sh -- COMMAND [ARG...]

Proxy defaults:
  BOSC_PROXY_URL      Full proxy URL. Default: http://bosc-ipv6:7890
  BOSC_PROXY_SCHEME   Proxy scheme when BOSC_PROXY_URL is unset. Default: http
  BOSC_PROXY_HOST     Proxy host when BOSC_PROXY_URL is unset. Default: bosc-ipv6
  BOSC_PROXY_PORT     Proxy port when BOSC_PROXY_URL is unset. Default: 7890
USAGE
}

default_no_proxy="localhost,127.0.0.1,::1,.local"

build_proxy_url() {
  if [[ -n "${BOSC_PROXY_URL:-}" ]]; then
    printf '%s\n' "$BOSC_PROXY_URL"
    return
  fi

  local scheme="${BOSC_PROXY_SCHEME:-http}"
  local host="${BOSC_PROXY_HOST:-bosc-ipv6}"
  local port="${BOSC_PROXY_PORT:-7890}"
  printf '%s://%s:%s\n' "$scheme" "$host" "$port"
}

proxy_url="$(build_proxy_url)"
export BOSC_PROXY_URL="$proxy_url"
export http_proxy="$proxy_url"
export https_proxy="$proxy_url"
export HTTP_PROXY="$proxy_url"
export HTTPS_PROXY="$proxy_url"
export all_proxy="$proxy_url"
export ALL_PROXY="$proxy_url"
export no_proxy="${NO_PROXY:-${no_proxy:-$default_no_proxy}}"
export NO_PROXY="$no_proxy"
export GIT_CURL_VERBOSE="${GIT_CURL_VERBOSE:-0}"

if command -v python3 >/dev/null 2>&1; then
  proxy_parts="$(
    python3 - "$proxy_url" <<'PY'
from urllib.parse import urlparse
import sys

u = urlparse(sys.argv[1])
scheme = u.scheme or "http"
host = u.hostname or ""
port = u.port
if port is None:
    port = 443 if scheme == "https" else 80
print(f"{scheme} {host} {port}")
PY
  )"
  read -r proxy_scheme proxy_host proxy_port <<<"$proxy_parts"
  if [[ -n "${proxy_host:-}" && -n "${proxy_port:-}" ]]; then
    java_proxy_opts="-Dhttp.proxyHost=${proxy_host} -Dhttp.proxyPort=${proxy_port} -Dhttps.proxyHost=${proxy_host} -Dhttps.proxyPort=${proxy_port}"
    export JAVA_TOOL_OPTIONS="${java_proxy_opts} ${JAVA_TOOL_OPTIONS:-}"
    export SBT_OPTS="${java_proxy_opts} ${SBT_OPTS:-}"
    export MAVEN_OPTS="${java_proxy_opts} ${MAVEN_OPTS:-}"
    export GRADLE_OPTS="${java_proxy_opts} ${GRADLE_OPTS:-}"
  fi
fi

print_env() {
  printf 'export BOSC_PROXY_URL=%q\n' "$BOSC_PROXY_URL"
  printf 'export http_proxy=%q\n' "$http_proxy"
  printf 'export https_proxy=%q\n' "$https_proxy"
  printf 'export HTTP_PROXY=%q\n' "$HTTP_PROXY"
  printf 'export HTTPS_PROXY=%q\n' "$HTTPS_PROXY"
  printf 'export all_proxy=%q\n' "$all_proxy"
  printf 'export ALL_PROXY=%q\n' "$ALL_PROXY"
  printf 'export no_proxy=%q\n' "$no_proxy"
  printf 'export NO_PROXY=%q\n' "$NO_PROXY"
}

check_proxy() {
  local url="${1:-https://github.com}"
  echo "Checking $url via proxy $BOSC_PROXY_URL" >&2

  if command -v curl >/dev/null 2>&1; then
    curl -I -L --connect-timeout 10 --max-time 30 "$url" >/dev/null
    return
  fi

  if command -v wget >/dev/null 2>&1; then
    wget --spider --timeout=30 "$url" >/dev/null 2>&1
    return
  fi

  echo "Neither curl nor wget is available for proxy checking." >&2
  return 127
}

case "${1:-}" in
  --print-env)
    print_env
    ;;
  --check)
    shift
    check_proxy "${1:-https://github.com}"
    ;;
  --help|-h|"")
    usage
    ;;
  --)
    shift
    if [[ "$#" -eq 0 ]]; then
      usage >&2
      exit 2
    fi
    exec "$@"
    ;;
  *)
    echo "Expected --print-env, --check, or -- before a command." >&2
    usage >&2
    exit 2
    ;;
esac

