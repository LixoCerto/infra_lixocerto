# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS dependencias
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.4.1 --activate
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM dependencias AS compilacao
WORKDIR /app
COPY . .
RUN pnpm build

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
ENV PORT=3000
WORKDIR /app
RUN groupadd --system --gid 10001 lcr && useradd --system --uid 10001 --gid lcr --home-dir /nonexistent --shell /usr/sbin/nologin lcr
COPY --from=dependencias --chown=lcr:lcr /app/node_modules ./node_modules
COPY --from=compilacao --chown=lcr:lcr /app/dist ./dist
COPY --from=compilacao --chown=lcr:lcr /app/package.json ./package.json
USER lcr
EXPOSE 3000
CMD ["node", "dist/index.js"]
