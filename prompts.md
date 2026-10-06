# Prompts

Aquí van **todos los prompts que lanzaste** para hacer el ejercicio, en el orden en que los
lanzaste, con el modelo y la herramienta de cada uno.

Esto no es papeleo. Lo que se revisa es **cómo pediste las cosas**, no solo lo que salió: un
resultado flojo con un prompt bueno y un resultado flojo con un prompt vago necesitan feedback
distinto, y sin este archivo no se distinguen.

## Cómo rellenarlo

- Un apartado `## Prompt N` por cada prompt.
- **Pega el prompt tal cual lo lanzaste**, dentro del bloque de código, aunque ocupe diez líneas
  y aunque tenga faltas. No lo reescribas para que quede bien: el que arreglaste mentalmente
  después no es el que lanzaste.
- Incluye también los que **no funcionaron**. Suelen ser los más útiles de leer.
- `Modelo` y `Herramienta` en todos. Si cambiaste de una a otra a mitad, se nota aquí.

Borra el ejemplo de abajo cuando escribas el primero.

---

## Prompt 1

**Modelo:** Opus 1M xHigh
**Herramienta:** Claude Code

```
"Migra el proyecto de SQLite a PostgreSQL corriendo en una instancia de Docker, con 2 bases de datos: desarrollo y pruebas.
- El fichero de Compose se llama compose.yaml y los dos servicios se llaman db y db-test.
- La imagen es pgvector/pgvector:pg17. Es la imagen oficial de PostgreSQL con la extensión de vectores ya dentro.
- Los puertos son 54410 para desarrollo y 54411 para pruebas. No el 5432: quien tenga un PostgreSQL suyo levantado se lo encontraría ocupado, y el error que vería no menciona a Docker por ningún lado.
- La base de pruebas va en memoria, sin volumen. Es efímera a propósito: una batería de pruebas que depende de lo que dejó la anterior no es una batería de pruebas.
- Los dos servicios llevan comprobación de salud, y el arranque espera a que estén sanos. La propia imagen avisa de que, la primera vez, crea la base y no acepta conexiones mientras tanto, y de que eso rompe a quien levanta varios contenedores a la vez.
- Sin la clave `version:` en el fichero de Compose: está obsoleta y Docker imprime un aviso.
- La batería de pruebas apunta a la otra base por su propio fichero de entorno, que el framework carga solo cuando el entorno es de pruebas.
- Y deja atajos en el Makefile para levantar las bases, pararlas, migrar las dos bases de datos y correr las pruebas."
Si una migracion existente se va a tocar, para y avisame para anotarlo."
```

**Qué salió:** El objetivo era migrar FlowSync de SQLite a PostgreSQL en Docker: hecho y verificado, los tests estan en verde, ninguna migracion existente se toco. Todo esta staged pero sin committear ya que faltaba hacer "gh auth login" que se hizo manualmente junto con el commit (se deshabilito recaps en /config lo cual parece irrelevante).

## Prompt 2

**Modelo:** Opus 1M xHigh
**Herramienta:** Claude Code

```
! (cd backend && npm run typecheck)
```

**Qué salió:** Muestra tsc --noEmit. La comprobacion de tipos esta en Verde, como esperaba — y eso es exactamente el punto 1 de la parte B. Aunque esté en verde no significa que el cambio de motor no haya movido nada.

## Prompt 3

**Modelo:** Opus 1M xHigh
**Herramienta:** Claude Code

```
"En el diff del fichero de tipos generado @backend/database.schema.ts entre la rama de partida motor-sg y lo que tengo ahora en local. Que declaraciones han cambiado de tipo? de que tipos en la rama de partida a que nuevos tipos?"
```

**Qué salió:** La de status no es del motor: esa columna es un string en la base con los dos motores, y la regla la estrecha al tipo del dominio. La de due_date sí lo es, y es la que el fichero de reglas tapa con tsType: 'string'. El tipo declarado no cambia porque está escrito a mano; el valor que llega en tiempo de ejecución sí cambió, y eso es lo que rompe isOverdue.

## Prompt 4

**Modelo:** Opus 1M xHigh
**Herramienta:** Claude Code

```
Busca cómo decide el proyecto si una tarea está vencida y léelo con el diff delante. Hay un comentario en ese código que explica por qué la comparación funciona. Di si ese comentario sigue siendo verdad y por que?
```

**Qué salió:** En la parte B3, el comentario @app/models/task.ts:45-47 dice que se compara String contra String pero las fechas ya no son del mismo tipo de dato a comparar y esto es grave. Ya no solo por la integridad de los datos al hacer coercion de tipos (dice que una tarea vencida en 2020 no lo esta), si no por potenciales fugas/desbordamientos de memoria o type confusion o TypeError desde el punto de vista de la seguridad.

## Prompt 4

**Modelo:** Opus 1M xHigh
**Herramienta:** Claude Code

```
Responde a estas 3 preguntas de manera precisa:
1. Genera dos consultas SQL, una contra PostgreSQL corriendo en Docker contra la DB de desarrollo y otra contra la DB de pruebas para indicar cuantas filas cambian de valor en mi cambio de Schema. Midelo con una sola query SQL.
  Dime tambien en que rama del arbol de reversibilidad cae. Si la migracion no ha tocado datos, hazmelo saber tambien.
2. Una cosa que la batería de pruebas no podía ver. Si no encontraste ninguna, escribe qué buscaste y dónde.
3. Yo tenia dudas sobre como verificar la integridad de los datos tras la migracion de SQLite a PostgreSQL ya que una columna de INTEGERs en SQLite puede contener texto y eso falla al importar la columna a PostgreSQL porque se pierden datos. Los timestamps tambien son problematicos por ejemplo al cambiar de zona horaria. No tuve tiempo de hacer esas comprobaciones, Las hizo Claude Code? Lo dudo...

```

**Qué salió:** Ver HALLAZGOS.md

