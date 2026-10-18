# Next.js storefront, built from the project cloned in ./src (pnpm monorepo of the DTC starter)

FROM node:22-alpine AS build

# pnpm, at the version pinned by the "packageManager" field of the project
RUN corepack enable

WORKDIR /app
COPY src/ ./

# Dependencies of the storefront only, at the versions of the lockfile
RUN pnpm install --frozen-lockfile --filter ./apps/storefront

# The NEXT_PUBLIC_ variables are written into the code by the build (see docker-compose.yml)
ARG NEXT_PUBLIC_MEDUSA_BACKEND_URL
ARG NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY
ARG NEXT_PUBLIC_BASE_URL
ARG NEXT_PUBLIC_DEFAULT_REGION
ENV NEXT_PUBLIC_MEDUSA_BACKEND_URL=$NEXT_PUBLIC_MEDUSA_BACKEND_URL \
    NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY \
    NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL \
    NEXT_PUBLIC_DEFAULT_REGION=$NEXT_PUBLIC_DEFAULT_REGION \
    NEXT_TELEMETRY_DISABLED=1

WORKDIR /app/apps/storefront
RUN pnpm build


FROM node:22-alpine

ENV NODE_ENV=production

# The whole workspace : "next start" reads next.config.js, which needs some development dependencies of the starter.
# Owned by the runtime user, Next.js writes its cache into .next
COPY --from=build --chown=node:node /app /app

WORKDIR /app/apps/storefront
USER node
EXPOSE 8000

CMD [ "node_modules/.bin/next", "start", "-p", "8000" ]
