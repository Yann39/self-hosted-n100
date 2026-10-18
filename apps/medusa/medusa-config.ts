import { loadEnv, defineConfig } from '@medusajs/framework/utils'

loadEnv(process.env.NODE_ENV || 'development', process.cwd())

// Production configuration of the backend : copy this file over apps/backend/medusa-config.ts in the project.
// Everything comes from the environment variables (see docker-compose.yml and .env)
module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    // Sessions of the admin dashboard, kept in Redis instead of memory
    redisUrl: process.env.REDIS_URL,
    // shared : one process for the API and the background jobs ; server / worker to run them in two containers
    workerMode: process.env.MEDUSA_WORKER_MODE as 'shared' | 'worker' | 'server',
    http: {
      storeCors: process.env.STORE_CORS!,
      adminCors: process.env.ADMIN_CORS!,
      authCors: process.env.AUTH_CORS!,
      jwtSecret: process.env.JWT_SECRET,
      cookieSecret: process.env.COOKIE_SECRET,
    },
  },
  modules: [
    // Redis versions of the infrastructure modules : the default ones keep the events, the workflows in progress
    // and the locks in memory, lost at every restart (development only)
    {
      resolve: '@medusajs/medusa/event-bus-redis',
      options: {
        redisUrl: process.env.REDIS_URL,
      },
    },
    {
      resolve: '@medusajs/medusa/workflow-engine-redis',
      options: {
        redis: {
          redisUrl: process.env.REDIS_URL,
        },
      },
    },
    {
      resolve: '@medusajs/medusa/locking',
      options: {
        providers: [
          {
            resolve: '@medusajs/medusa/locking-redis',
            id: 'locking-redis',
            is_default: true,
            options: {
              redisUrl: process.env.REDIS_URL,
            },
          },
        ],
      },
    },
    // Uploaded files stored on disk (a volume) and served by the backend under /static.
    // backend_url must be the PUBLIC address : it is saved as is in the database and loaded by the visitors' browsers
    // (the default one, http://localhost:9000/static, only works on a development machine)
    {
      resolve: '@medusajs/medusa/file',
      options: {
        providers: [
          {
            resolve: '@medusajs/medusa/file-local',
            id: 'local',
            options: {
              upload_dir: 'static',
              backend_url: `${process.env.MEDUSA_BACKEND_URL}/static`,
            },
          },
        ],
      },
    },
  ],
})
