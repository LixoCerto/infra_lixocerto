FROM node:22-bookworm-slim AS dependencias
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.4.1 --activate
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

FROM dependencias AS compilacao
WORKDIR /app
COPY package.json pnpm-lock.yaml tsconfig.json tsconfig.compilacao.json buf.yaml buf.gen.yaml configuracao_sequelize.cjs ./
COPY contratos ./contratos
COPY banco ./banco
COPY src ./src
RUN pnpm contratos:validar && pnpm compilar

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
RUN groupadd --system --gid 10001 lcr && useradd --system --uid 10001 --gid lcr --home-dir /nonexistent --shell /usr/sbin/nologin lcr
COPY --from=dependencias --chown=lcr:lcr /app/node_modules ./node_modules
COPY --from=compilacao --chown=lcr:lcr /app/dist ./dist
COPY --from=compilacao --chown=lcr:lcr /app/contratos ./contratos
COPY --from=compilacao --chown=lcr:lcr /app/banco ./banco
COPY --from=compilacao --chown=lcr:lcr /app/configuracao_sequelize.cjs ./configuracao_sequelize.cjs
COPY --from=compilacao --chown=lcr:lcr /app/package.json ./package.json
USER lcr
EXPOSE 50051
CMD ["node", "dist/src/principal.js"]
