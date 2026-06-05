#!/bin/sh
# Validate the object_detector_web install and publish access capabilities.
# Executed by the Fabric plugin via `sh` -- keep POSIX sh compatible.
set -eu
trap 'echo "ERROR: env_postcheck failed at line $LINENO (exit $?)" >&2' EXIT

WEB_PORT="${WEB_PORT:-443}"
TLS_MODE="${TLS_MODE:-internal}"
VM_IP="${VM_IP:-}"

SCHEME="https"
if [ "$TLS_MODE" = "none" ]; then
    SCHEME="http"
fi

if [ -z "$VM_IP" ]; then
    VM_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
WEB_URL="${SCHEME}://${VM_IP}:${WEB_PORT}/"

# All three systemd units must be active for the app to be healthy.
RUNNING="true"
for svc in od-cameras od-web od-caddy; do
    if sudo systemctl is-active --quiet "$svc"; then
        ctx logger info "Service ${svc}: active"
    else
        ctx logger error "Service ${svc}: NOT active"
        RUNNING="false"
    fi
done

# Probe the web endpoint (self-signed TLS -> -k). Non-fatal on failure.
HTTP_CODE="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 15 "$WEB_URL" 2>/dev/null || echo '000')"
ctx logger info "Object detector web URL: ${WEB_URL} (HTTP ${HTTP_CODE})"
ctx logger info "Services running: ${RUNNING}"

ctx instance runtime-properties capabilities.services_running "$RUNNING"
ctx instance runtime-properties capabilities.web_url "$WEB_URL"
ctx instance runtime-properties capabilities.web_http_code "$HTTP_CODE"

trap - EXIT
