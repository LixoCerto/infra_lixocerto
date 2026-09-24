# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS dependencias
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.4.1 --activate
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM dependencias AS compilacao
WORKDIR /app
ARG VITE_API_BASE_URL=/api/rpc
ARG VITE_OIDC_ISSUER
ARG VITE_OIDC_CLIENT_ID
ARG VITE_OIDC_AUDIENCE
ARG VITE_OIDC_SCOPE=openid profile email
ARG VITE_OIDC_REDIRECT_URI=http://localhost:3000/callback
ARG VITE_OIDC_POST_LOGOUT_REDIRECT_URI=http://localhost:3000/login
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV VITE_OIDC_ISSUER=$VITE_OIDC_ISSUER
ENV VITE_OIDC_CLIENT_ID=$VITE_OIDC_CLIENT_ID
ENV VITE_OIDC_AUDIENCE=$VITE_OIDC_AUDIENCE
ENV VITE_OIDC_SCOPE=$VITE_OIDC_SCOPE
ENV VITE_OIDC_REDIRECT_URI=$VITE_OIDC_REDIRECT_URI
ENV VITE_OIDC_POST_LOGOUT_REDIRECT_URI=$VITE_OIDC_POST_LOGOUT_REDIRECT_URI
COPY package.json pnpm-lock.yaml vite.config.ts tsconfig.json buf.yaml buf.gen.yaml ./
COPY client ./client
COPY shared ./shared
COPY proto ./proto
RUN pnpm build

FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime
COPY --from=compilacao /app/dist /usr/share/nginx/html
RUN rm -f /etc/nginx/conf.d/default.conf && printf '%s\n' \
  'server {' \
  '  listen 8080;' \
  '  server_name _;' \
  '  root /usr/share/nginx/html;' \
  '  index index.html;' \
  '  location /api/rpc/ {' \
  '    proxy_pass http://gateway:8080/;' \
  '    proxy_http_version 1.1;' \
  '    proxy_set_header Host $host;' \
  '    proxy_set_header X-Real-IP $remote_addr;' \
  '    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
  '    proxy_buffering off;' \
  '    proxy_request_buffering off;' \
  '  }' \
  '  location / {' \
  '    try_files $uri $uri/ /index.html;' \
  '  }' \
  '}' > /etc/nginx/conf.d/default.conf
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --retries=5 CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
