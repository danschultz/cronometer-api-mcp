# syntax=docker/dockerfile:1

# Upstream commit to build (https://github.com/rwestergren/cronometer-api-mcp).
# Bumped automatically by .github/workflows/update-upstream.yml.
ARG CRONOMETER_API_MCP_REF=c059c962d1b7c133f2a470662d83244fdb38b8b9

# Base image: supercorp/supergateway:uvx (Alpine + Node 20 + uv). Pinned by
# digest, copied from upstream's Dockerfile; Dependabot tracks it.
FROM supercorp/supergateway:uvx@sha256:f285119b1dc1c83b7cf6e0fdd29d4fe36892e575f32730396b09e55939cbe278

ARG CRONOMETER_API_MCP_REF

LABEL org.opencontainers.image.source="https://github.com/danschultz/cronometer-api-mcp" \
      org.opencontainers.image.description="rwestergren/cronometer-api-mcp served over streamable HTTP, with Docker secret (_FILE) support" \
      io.github.rwestergren.cronometer-api-mcp.ref="${CRONOMETER_API_MCP_REF}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_INSTALL_DIR=/opt/uv-python \
    UV_PROJECT_ENVIRONMENT=/app/.venv \
    PATH=/app/.venv/bin:$PATH \
    HOME=/home/app \
    PORT=8080

# cronometer-api-mcp requires Python >=3.14. `--frozen` installs exactly what
# upstream's uv.lock pins and fails on a stale lock.
ADD https://github.com/rwestergren/cronometer-api-mcp.git#${CRONOMETER_API_MCP_REF} /app
WORKDIR /app
RUN uv python install 3.14 \
 && uv sync --frozen --no-dev --compile-bytecode --python 3.14

# supergateway validates Mcp-Protocol-Version against its bundled
# @modelcontextprotocol/sdk, whose pinned 1.19.1 tops out at 2025-06-18. Newer
# clients then connect but get "no tools available". Upgrade the SDK in
# supergateway's own node_modules (same workaround as upstream's Dockerfile;
# see https://github.com/supercorp-ai/supergateway/issues/117).
RUN cd /usr/local/lib/node_modules/supergateway \
 && npm install @modelcontextprotocol/sdk@^1.29.0 --no-save --no-audit --no-fund

RUN addgroup -g 10001 app \
 && adduser -D -u 10001 -G app -h /home/app app

COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh

USER app
WORKDIR /home/app

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# supergateway owns the HTTP listener and spawns the stdio server as a child.
# --stateful enables Mcp-Session-Id semantics per the streamable-HTTP spec.
CMD ["sh", "-c", "exec supergateway --stdio cronometer-api-mcp --outputTransport streamableHttp --stateful --streamableHttpPath /mcp --healthEndpoint /healthz --port \"${PORT}\" --sessionTimeout 3600000 --logLevel info"]
