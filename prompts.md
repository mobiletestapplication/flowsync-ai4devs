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

**Modelo:** Opus 5.5 Medium
**Herramienta:** Claude Code

```
Vas a empezar por el contrato primero, miralo en rojo, y segundo bajaras la regla a un test que llame directamente;
aplicaras estrictamente las 5 restricciones que indico al final del prompt.

Primero, lee el Requirement 'Cuándo una tarea está vencida' entero y sus 8 Scenarios en @openspec/specs/tasks/spec.md:390-427.

Segundo, escribe un fichero de test funcionales que los ejerza entrando por HTTP (HyperText Transfer Protocol, 
 el protocolo por el que entra un cliente de la interfaz de programación de aplicaciones), igual que entra la aplicación que consume este backend.
 Uno por Scenario.

Tercero, ejecutalo con 'make test-e2e' y guarda la salida entera en @tarea-vencida.log, no solo con si pasó o no.

Cinco restricciones, y ninguna es decorativa:
1. No toques ni una línea fuera del directorio backend/tests/. Ni el modelo, ni el transformer, ni el controlador. 
 Si tu agente cambia implementación mientras escribe el test, el test nacerá verde y no comprobará nada.
2. Los tests comprueban lo que sale en la respuesta, no lo que devuelve un método interno. El campo se llama 'isOverdue' y viaja en el cuerpo.
3. El día de referencia se le pasa a la petición. Nada de la fecha de hoy ni de ningún reloj.
4. Sigue la forma de aislamiento que ya usan los tests de backend/tests/functional/, sin inventar otra.
5. No des por hecho ningún identificador: usa el que te devuelva la creación.

Adelante.
```

**Qué salió:** Claude encuentra @app/models/task.ts:74 que ignora el status; crea el fichero de test en @backend/tests/functional/tasks/overdue.spec.ts y salva la salida en @tarea-vencida.log por si la necesito mas tarde.

## Prompt 2

**Modelo:** Opus 5.5 Medium
**Herramienta:** Claude Code

```
La parte B consiste en que quiero bajar la regla que vive en isOverdueOn, en @backend/app/models/task.ts. 
Para ello, crea el directorio @backend/tests/unit/, que hoy no existe, y escribe ahí sus bordes, sin servidor y sin base de datos:
1. Fecha anterior al día de referencia, y la tarea sin hacer.
2. Fecha exactamente igual al día de referencia.
3. Fecha posterior.
4. Sin fecha.
5. Tarea ya hecha, con la fecha pasada.

Y añade un caso más que no sale de la spec: que la regla se comporte igual reciba la fecha como texto o como objeto de fecha.
Ese no lo pide ningún requisito de producto. Sale de preguntarse cómo llega el dato de verdad, que es justo donde mi criterio no lo pone nadie por mi.

No toques la implementación porque el propio proyecto te prohibe commitear. Muestrame con '!git branch' y '!git log --oneline' donde has salvado todo.
```

**Qué salió:** Parte B lista con un nuevo directorio @backend/tests/unit/, con @tests/unit/tasks/overdue.spec.ts: seis tests, sin servidor y sin base de datos (la tarea se arma con new Task() en memoria y se llama isOverdueOn directamente); la implementación fuera de @backend/test no se ha tocado; y ademas, guarde la salida entera en tarea-vencida-unit.log con 2 casos fallidos.

## Prompt 3

**Modelo:** Opus 5.5 Medium
**Herramienta:** Claude Code

```
Quiero que escribas la respuesta a las siguientes 3 preguntas en el fichero @HALLAZGOS.md en la raiz del repositorio:
1. Cuántos de los casos nuevos fallaron y cuántos de los que ya había siguieron en verde, con la cifra que me dio la pantalla.
2. Cuál de los casos nuevos PASÓ, si alguno pasó, y por qué crees que pasó. 
3. Dude si las reglas del Prompt A se respetarian a rajatabla o no. Que no pudiste comprobar con los tests? y mas importante, que tienen en comun los casos que fallaron?

```

**Qué salió:** Escrito en HALLAZGOS.md; Claude reemplazo los tres encabezados por mis preguntas del prompt de la parte C; comprobe las cifras manualmente y procedere al commit manualmente antes del directo.
