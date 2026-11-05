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
CMD ["node", "dist/server.js"]
