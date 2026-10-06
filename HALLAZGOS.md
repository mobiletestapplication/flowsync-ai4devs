# Hallazgos

Aquí van **las tres líneas** del ejercicio, una por cada punto de abajo. Es lo único que hay que
traer hecho: un cambio de motor a medias con estas tres líneas escritas vale más que lo contrario,
porque lo que se discute en el directo es dónde te chocaste.

Escribe **una sola línea por punto**, con tus palabras y con lo que mediste, no con lo que suponías.

## 1. Las filas que cambian y la rama

Cuántas filas cambian de valor en tu cambio de esquema, medido con una consulta, y en qué rama del
árbol de reversibilidad cae. Si tu migración no toca datos, dilo tal cual: también es una respuesta.

- 0 filas cambian entre la DB de pruebas y la DB de desarrollo medido con "docker exec -i flowsync-db      psql -U flowsync -d flowsync      -x -f - < filas.sql" y "docker exec -i flowsync-db-test psql -U flowsync -d flowsync_test -x -f - < filas.sql" pero creo que la pregunta se refieria entre SQLite y PostgeSQL. Respecto a la rama del arbol de reversibilidad es la rama 1. 

## 2. Lo que la batería de pruebas no podía ver

Una cosa que la batería de pruebas no podía ver. Si no encontraste ninguna, escribe qué buscaste y dónde.

- Task.isOverdueOn() devuelve falso para toda taraea porque el controlador pg es quien parsea la columna data a un Data de JavaScript y lo compara contra un String. Fallo tipico que produce falso siempre. Ademas @app/models/task.ts:45-47 sigue afirmando que se compara String contra String lo cual no es cierto.

## 3. Tu duda

De qué dudaste, o qué no pudiste comprobar.

- La dudas sobre como verificar la integridad de los datos tras la migracion de SQLite a PostgreSQL no importo porque no toco datos. Los timestamps son problematicos pero no habia ni una sola comprobacion en tipos de datos de fechas y Claude Code confirmo que no pudo hacer esas comprobaciones.


