#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# User configurable macros
###############################################################################

# Keep site-specific proxy endpoints outside Git. Set BOSC_PROXY_URL in the
# shell, for example: BOSC_PROXY_URL=socks5h://HOST:PORT
BOSC_PROXY_URL="${BOSC_PROXY_URL:-${BOSC_IVP6_PROXY:-}}"
BOSC_PROXY_SCHEME="${BOSC_PROXY_SCHEME:-socks5h}"
BOSC_PROXY_HOST="${BOSC_PROXY_HOST:-}"
BOSC_PROXY_PORT="${BOSC_PROXY_PORT:-}"
BOSC_NO_PROXY="${BOSC_NO_PROXY:-localhost,127.0.0.1,::1,.local}"
CHECK_URL="${CHECK_URL:-https://github.com}"

###############################################################################
# Implementation
###############################################################################

usage() {
  cat <<'EOF'
Usage:
  scripts/with_bosc_proxy.sh --check [URL]
  scripts/with_bosc_proxy.sh --print-env
  scripts/with_bosc_proxy.sh -- COMMAND [ARG...]

Configure the proxy through environment variables:
  BOSC_PROXY_URL=socks5h://HOST:PORT scripts/with_bosc_proxy.sh -- git clone URL

Or:
  BOSC_PROXY_SCHEME=socks5h BOSC_PROXY_HOST=HOST BOSC_PROXY_PORT=PORT \
    scripts/with_bosc_proxy.sh -- curl -I https://github.com

This script intentionally does not hard-code site proxy endpoints.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

resolve_proxy_url() {
  if [[ -z "$BOSC_PROXY_URL" ]]; then
    if [[ -n "$BOSC_PROXY_HOST" && -n "$BOSC_PROXY_PORT" ]]; then
      BOSC_PROXY_URL="$BOSC_PROXY_SCHEME://$BOSC_PROXY_HOST:$BOSC_PROXY_PORT"
    else
      die "set BOSC_PROXY_URL, or set BOSC_PROXY_HOST and BOSC_PROXY_PORT"
    fi
  fi

  if [[ "$BOSC_PROXY_URL" =~ ^([a-zA-Z0-9+.-]+)://([^/:]+):([0-9]+)$ ]]; then
    PROXY_SCHEME="${BASH_REMATCH[1]}"
    PROXY_HOST="${BASH_REMATCH[2]}"
    PROXY_PORT="${BASH_REMATCH[3]}"
  else
    die "unsupported BOSC_PROXY_URL format: $BOSC_PROXY_URL"
  fi
}

export_proxy_env() {
  resolve_proxy_url

  export http_proxy="$BOSC_PROXY_URL"
  export https_proxy="$BOSC_PROXY_URL"
  export all_proxy="$BOSC_PROXY_URL"
  export HTTP_PROXY="$BOSC_PROXY_URL"
  export HTTPS_PROXY="$BOSC_PROXY_URL"
  export ALL_PROXY="$BOSC_PROXY_URL"
  export no_proxy="$BOSC_NO_PROXY"
  export NO_PROXY="$BOSC_NO_PROXY"

  local java_proxy_opts=""
  case "$PROXY_SCHEME" in
    socks5|socks5h)
      java_proxy_opts="-DsocksProxyHost=$PROXY_HOST -DsocksProxyPort=$PROXY_PORT -Djava.net.preferIPv4Stack=true"
      ;;
    http|https)
      java_proxy_opts="-Dhttp.proxyHost=$PROXY_HOST -Dhttp.proxyPort=$PROXY_PORT -Dhttps.proxyHost=$PROXY_HOST -Dhttps.proxyPort=$PROXY_PORT"
      ;;
  esac

  if [[ -n "$java_proxy_opts" ]]; then
    export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} $java_proxy_opts"
    export SBT_OPTS="${SBT_OPTS:-} $java_proxy_opts"
  fi
}

print_env() {
  export_proxy_env
  cat <<EOF
BOSC_PROXY_URL=$BOSC_PROXY_URL
http_proxy=$http_proxy
https_proxy=$https_proxy
all_proxy=$all_proxy
no_proxy=$no_proxy
JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS:-}
SBT_OPTS=${SBT_OPTS:-}
EOF
}

check_proxy() {
  export_proxy_env
  local url="${1:-$CHECK_URL}"
  curl -fsSIL --max-time 20 "$url" >/dev/null
  printf 'proxy check ok: %s\n' "$url"
}

main() {
  case "${1:-}" in
    -h|--help)
      usage
      ;;
    --check)
      shift
      check_proxy "${1:-$CHECK_URL}"
      ;;
    --print-env)
      print_env
      ;;
    --)
      shift
      (($# > 0)) || die "missing command after --"
      export_proxy_env
      exec "$@"
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

main "$@"
