# Medusa backend (API + admin dashboard), built from the project cloned in ./src (pnpm monorepo of the DTC starter)

FROM node:22-alpine AS build

# pnpm, at the version pinned by the "packageManager" field of the project
RUN corepack enable

WORKDIR /app
COPY src/ ./

# Dependencies of the backend only, at the versions of the lockfile
RUN pnpm install --frozen-lockfile --filter ./apps/backend

# Compiles the backend and the admin dashboard into apps/backend/.medusa/server
WORKDIR /app/apps/backend
RUN pnpm build


FROM node:22-alpine

# The application files belong to the runtime user : the migrations write into node_modules
# (they create an empty "migrations" folder in every module that has none)
WORKDIR /server
RUN chown node:node /server
USER node

COPY --from=build --chown=node:node /app/apps/backend/.medusa/server ./

# Production dependencies of the compiled application
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

# Directory of the uploaded files (volume)
RUN mkdir static

EXPOSE 9000

# The pending migrations are applied at every start (the first ones also seed the store), then the server starts
CMD [ "sh", "-c", "npx medusa db:migrate && exec npx medusa start" ]
