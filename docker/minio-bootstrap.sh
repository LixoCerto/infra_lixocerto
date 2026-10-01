#!/bin/sh
set -eu

fail() {
  echo "Falha no bootstrap MinIO: $1" >&2
  exit 1
}

: "${MINIO_ROOT_USER:?MINIO_ROOT_USER não configurado}"
: "${MINIO_ROOT_PASSWORD:?MINIO_ROOT_PASSWORD não configurado}"
: "${LCR_EVIDENCIAS_S3_BUCKET:?LCR_EVIDENCIAS_S3_BUCKET não configurado}"
: "${LCR_EVIDENCIAS_S3_ACCESS_KEY:?LCR_EVIDENCIAS_S3_ACCESS_KEY não configurado}"
: "${LCR_EVIDENCIAS_S3_SECRET_KEY:?LCR_EVIDENCIAS_S3_SECRET_KEY não configurado}"

attempt=0
ready=0
while [ "$attempt" -lt 10 ]; do
  if timeout 5s mc alias set lcr http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1 \
    && timeout 5s mc ready lcr >/dev/null 2>&1; then
    ready=1
    break
  fi
  attempt=$((attempt + 1))
  echo "Aguardando MinIO responder (tentativa $attempt/10)." >&2
  sleep 2
done
[ "$ready" -eq 1 ] || fail 'MinIO não respondeu ao alias/health check dentro do prazo.'

echo 'MinIO respondeu; preparando bucket privado.' >&2
if ! timeout 10s mc mb --ignore-existing "lcr/$LCR_EVIDENCIAS_S3_BUCKET" >/dev/null 2>&1; then
  fail 'não foi possível criar/verificar o bucket.'
fi

if ! timeout 10s mc admin user info lcr "$LCR_EVIDENCIAS_S3_ACCESS_KEY" >/dev/null 2>&1; then
  echo 'Criando identidade de serviço para a API.' >&2
  if ! timeout 10s mc admin user add lcr "$LCR_EVIDENCIAS_S3_ACCESS_KEY" "$LCR_EVIDENCIAS_S3_SECRET_KEY" >/dev/null 2>&1; then
    fail 'não foi possível provisionar a identidade de serviço.'
  fi
fi

if ! timeout 10s mc admin policy info lcr lcr-evidencias-app >/dev/null 2>&1; then
  echo 'Criando política restrita do bucket.' >&2
  if ! timeout 10s mc admin policy create lcr lcr-evidencias-app /policy.json >/dev/null 2>&1; then
    fail 'não foi possível criar a política de bucket.'
  fi
fi
if ! timeout 10s mc admin policy attach lcr lcr-evidencias-app --user "$LCR_EVIDENCIAS_S3_ACCESS_KEY" >/dev/null 2>&1; then
  fail 'não foi possível associar a política à identidade de serviço.'
fi
if ! timeout 10s mc anonymous set none "lcr/$LCR_EVIDENCIAS_S3_BUCKET" >/dev/null 2>&1; then
  fail 'não foi possível confirmar acesso privado ao bucket.'
fi

if ! timeout 10s mc alias set appcheck http://minio:9000 "$LCR_EVIDENCIAS_S3_ACCESS_KEY" "$LCR_EVIDENCIAS_S3_SECRET_KEY" >/dev/null 2>&1; then
  fail 'a identidade de serviço não autenticou.'
fi
if ! timeout 10s mc ls "appcheck/$LCR_EVIDENCIAS_S3_BUCKET" >/dev/null 2>&1; then
  fail 'a identidade de serviço não consegue listar o bucket.'
fi

# Smoke test com objeto temporário para validar PutObject, GetObject e DeleteObject.
probe_file=$(mktemp)
readback_file=$(mktemp)
probe_object="appcheck/$LCR_EVIDENCIAS_S3_BUCKET/.lcr-bootstrap-check-$(date +%s)-$$"
cleanup() {
  if [ -n "${probe_object:-}" ]; then
    timeout 10s mc rm "$probe_object" >/dev/null 2>&1 || true
  fi
  rm -f "${probe_file:-}" "${readback_file:-}"
}
trap cleanup 0 HUP INT TERM
printf '%s' 'lixocerto-minio-bootstrap-ok' > "$probe_file"
if ! timeout 10s mc cp "$probe_file" "$probe_object" >/dev/null 2>&1; then
  fail 'a política da aplicação não permite gravar objetos.'
fi
if ! timeout 10s mc cat "$probe_object" > "$readback_file" 2>/dev/null || ! cmp -s "$probe_file" "$readback_file"; then
  fail 'a política da aplicação não permite ler/verificar objetos.'
fi
if ! timeout 10s mc rm "$probe_object" >/dev/null 2>&1; then
  fail 'a política da aplicação não permite excluir o objeto temporário de teste.'
fi
probe_object=''

echo 'Bootstrap MinIO concluído; bucket privado e acesso S3 da API verificados.' >&2
