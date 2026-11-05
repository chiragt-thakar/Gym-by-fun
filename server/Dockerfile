# Build context: repository root (the server reads content/ and its schema).
FROM node:22-alpine AS build
WORKDIR /repo/server
COPY server/package.json server/package-lock.json ./
RUN npm ci
COPY server/ ./
RUN npm run build && npm prune --omit=dev

FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /repo/server
COPY --from=build /repo/server/node_modules ./node_modules
COPY --from=build /repo/server/dist ./dist
COPY server/package.json ./
COPY content/ /repo/content/
USER node
EXPOSE 8080
# Liveness probe without curl (alpine image has none): node's built-in fetch.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/livez').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"
# Migrations (run once per deploy, before starting api/worker):
#   docker run --rm --env-file .env <image> node dist/db/migrate.js
# Worker: docker run ... <image> node dist/worker.js
CMD ["node", "dist/server.js"]
