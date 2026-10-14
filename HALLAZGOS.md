# Hallazgos

Aquí van **las tres líneas** del ejercicio, una por cada punto de abajo. Es lo único que hay que
traer hecho: un cambio de motor a medias con estas tres líneas escritas vale más que lo contrario,
porque lo que se discute en el directo es dónde te chocaste.

Escribe **una sola línea por punto**, con tus palabras y con lo que mediste, no con lo que suponías.

## 1. Cuántos casos nuevos fallaron y cuántos de los que ya había siguieron en verde

- De los 13 casos nuevos fallaron 5: la pantalla dio `Tests 44 passed, 3 failed (47)` en `make test-e2e` (7 nuevos, 3 en rojo) y `Tests 4 passed, 2 failed (6)` en `make test-unit` (6 nuevos, 2 en rojo), y los 40 que ya había siguieron todos en verde, ninguno se rompió.

## 2. Cuál de los casos nuevos PASÓ, y por qué creo que pasó

- Pasaron 8, y casi todos por el motivo equivocado: los que esperan «no vencida» (fecha de hoy, fecha futura, sin fecha, tarea hecha) pasan porque la regla leída de la base devuelve `false` **siempre**, así que un acierto ahí no prueba nada; el único que pasó por el motivo bueno es el caso 1 de la unitaria —fecha de ayer y sin hacer, vencida— y pasó precisamente porque ahí la fecha se la pongo yo en memoria como texto, que es el único camino por el que la comparación de la implementación funciona.

## 3. Mi duda: qué no pude comprobar, y qué tienen en común los casos que fallaron

- Dudé de si las cinco reglas del Prompt A se aguantarían hasta el final y sí se aguantaron (solo se escribió dentro de `backend/tests/`, la implementación ni se tocó, el `isOverdue` se mira en el cuerpo de la respuesta y el `today` va en cada petición), pero lo que no pude comprobar con tests es la tercera condición del requisito —que una tarea `done` no venza— porque por HTTP queda tapada: el defecto de la fecha hace que todo salga `false` y esos dos escenarios pasan en verde sin ejercer nada, y solo se ve en la unitaria; tampoco pude comprobar lo que no entra por la API (que el frontend no compare fechas por su cuenta ni qué hace la regla en un huso real, no simulado). Lo que tienen en común los 5 que fallaron es que son **los únicos que exigen que la regla diga «sí, está vencida»**: en cuanto la respuesta esperada es `true`, falla; una implementación que nunca dice «vencida» aprueba todo lo demás, y por eso el rojo se concentra ahí y no reparte.
