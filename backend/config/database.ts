import env from '#start/env'
import { defineConfig } from '@adonisjs/lucid'

/**
 * Una sola conexión, a PostgreSQL. Cuál de las dos bases es depende solo del
 * entorno: `.env` apunta a la de desarrollo (54410) y `.env.test` —que el
 * framework carga únicamente cuando `NODE_ENV=test`— a la de pruebas (54411).
 * Así ni la configuración ni los tests tienen que saber que hay dos bases.
 *
 * Las dos viven en `compose.yaml`, en la raíz del repositorio.
 */
const dbConfig = defineConfig({
  /**
   * Default connection used for all queries.
   */
  connection: 'postgres',

  connections: {
    /**
     * PostgreSQL connection (default).
     */
    postgres: {
      client: 'pg',

      connection: {
        host: env.get('DB_HOST'),
        port: env.get('DB_PORT'),
        user: env.get('DB_USER'),
        password: env.get('DB_PASSWORD'),
        database: env.get('DB_DATABASE'),
      },

      migrations: {
        /**
         * Sort migration files naturally by filename.
         */
        naturalSort: true,

        /**
         * Paths containing migration files.
         */
        paths: ['database/migrations'],
      },

      schemaGeneration: {
        /**
         * Enable schema generation from Lucid models.
         */
        enabled: true,

        /**
         * Custom schema rules file paths.
         */
        rulesPaths: ['./database/schema_rules.js'],
      },
    },
  },
})

export default dbConfig
