#!/usr/bin/env bash
# Apache License 2.0
#
# Copyright 2026 Shane
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Render checks for charts/manager: each case runs `helm template` with a set
# of values and asserts on the rendered manifests.
set -euo pipefail

chart="$(cd "$(dirname "${BASH_SOURCE[0]}")/../charts/manager" && pwd)"
failures=0

render() {
  helm template fm "$chart" --set fm.tlsSecretName=fm-tls "$@"
}

pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1"; failures=$((failures + 1)); }

expect_line() {
  local name="$1" manifest="$2" line="$3"
  if grep -qxF -- "$line" <<<"$manifest"; then pass "$name"; else fail "$name: missing line [$line]"; fi
}

expect_no_match() {
  local name="$1" manifest="$2" pattern="$3"
  if grep -qF -- "$pattern" <<<"$manifest"; then fail "$name: unexpected [$pattern]"; else pass "$name"; fi
}

expect_render_error() {
  local name="$1" message="$2"
  shift 2
  local out
  if out="$(render "$@" 2>&1)"; then
    fail "$name: render succeeded, expected an error"
  elif grep -qF -- "$message" <<<"$out"; then
    pass "$name"
  else
    fail "$name: error did not mention [$message]: $out"
  fi
}

mcp_on=(
  --set mcp.enabled=true
  --set mcp.publicURL=https://fleetos.example.org
  --set operatorCANode=operator-ca
  --set operatorCA.configMap=fm-operator-ca
)

# MCP off (defaults).
cm="$(render --show-only templates/configmap.yaml)"
deploy="$(render --show-only templates/deployment.yaml)"
expect_line "default: config.yaml key rendered" "$cm" "  config.yaml: |"
expect_line "default: mcp disabled" "$cm" "      enabled: false"
expect_no_match "default: no operator_ca_node" "$cm" "operator_ca_node"
expect_no_match "default: no public_url" "$cm" "public_url"
expect_no_match "default: no operatorCAPath" "$cm" "operatorCAPath"
expect_line "default: tlsCert path" "$cm" "    tlsCert: \"/etc/cryptos/fm/tls/tls.crt\""
expect_line "default: listen on targetPort" "$cm" "    listen: \":8443\""
expect_line "default: config mounted where the image reads it" "$deploy" "              mountPath: /etc/cryptos/fleet/config.yaml"
expect_no_match "default: no operator CA volume" "$deploy" "operator-ca"

# operatorCANode on its own still drives revocation enforcement.
cm="$(render --show-only templates/configmap.yaml --set operatorCANode=operator-ca)"
expect_line "operatorCANode without MCP: rendered" "$cm" "    operator_ca_node: \"operator-ca\""
expect_line "operatorCANode without MCP: mcp stays off" "$cm" "      enabled: false"

# MCP on.
cm="$(render --show-only templates/configmap.yaml "${mcp_on[@]}")"
deploy="$(render --show-only templates/deployment.yaml "${mcp_on[@]}")"
expect_line "mcp on: enabled" "$cm" "      enabled: true"
expect_line "mcp on: public_url" "$cm" "      public_url: \"https://fleetos.example.org\""
expect_line "mcp on: operator_ca_node" "$cm" "    operator_ca_node: \"operator-ca\""
expect_line "mcp on: operatorCAPath" "$cm" "    operatorCAPath: /etc/cryptos/fleet/operator-ca/operator-ca.pem"
expect_line "mcp on: operator CA configMap mounted" "$deploy" "            name: fm-operator-ca"

# MCP on without what the manager needs to start.
expect_render_error "mcp on: operatorCANode required" "mcp.enabled requires operatorCANode" \
  --set mcp.enabled=true --set mcp.publicURL=https://fleetos.example.org --set operatorCA.configMap=fm-operator-ca
expect_render_error "mcp on: publicURL required" "mcp.enabled requires mcp.publicURL" \
  --set mcp.enabled=true --set operatorCANode=operator-ca --set operatorCA.configMap=fm-operator-ca
expect_render_error "mcp on: operatorCA.configMap required" "mcp.enabled requires operatorCA.configMap" \
  --set mcp.enabled=true --set mcp.publicURL=https://fleetos.example.org --set operatorCANode=operator-ca

if ((failures > 0)); then
  printf '%d check(s) failed\n' "$failures"
  exit 1
fi
printf 'all checks passed\n'
