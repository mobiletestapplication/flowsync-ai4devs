import Task from '#models/task'
import { test } from '@japa/runner'

/**
 * Los bordes de `Task.isOverdueOn`, la única definición de «vencida» del sistema
 * (`app/models/task.ts`). Sin servidor y sin base de datos: la tarea se arma en
 * memoria y la regla se llama directamente, porque lo que se está probando no es
 * una respuesta HTTP sino la frontera entre un día y el siguiente.
 *
 * Los cinco primeros casos son los bordes de la regla tal y como la escribe el
 * requisito «Cuándo una tarea está vencida» de `openspec/specs/tasks/spec.md`:
 * ayer, hoy, mañana, sin fecha, y hecha con la fecha pasada. Los tests
 * funcionales de `tests/functional/tasks/overdue.spec.ts` comprueban que eso
 * llega al cliente; estos comprueban la regla en sí, que es donde se decide.
 *
 * El sexto no sale de ningún requisito de producto: sale de cómo llega el dato de
 * verdad. Está explicado donde aparece.
 */
test.group('Task | isOverdueOn', () => {
  const HOY = '2026-08-20'
  const AYER = '2026-08-19'
  const MANANA = '2026-08-21'

  /**
   * Una tarea en memoria, sin pasar por la base. `Task` no necesita conexión
   * para existir: la regla es una función de sus campos y del día que se le pasa.
   */
  function tarea(dueDate: string | null, status: Task['status'] = 'pending') {
    const task = new Task()
    task.title = 'Revisar el informe'
    task.status = status
    task.dueDate = dueDate

    return task
  }

  test('1 | fecha anterior al día de referencia y la tarea sin hacer: vencida', ({ assert }) => {
    assert.isTrue(tarea(AYER).isOverdueOn(HOY))
    // Un día antes y meses antes son el mismo caso: no hay umbral de antigüedad.
    assert.isTrue(tarea('2025-01-01').isOverdueOn(HOY))
    // Y «sin hacer» son los dos estados que no son `done`.
    assert.isTrue(tarea(AYER, 'in_progress').isOverdueOn(HOY))
  })

  test('2 | fecha exactamente igual al día de referencia: todavía no vencida', ({ assert }) => {
    // El borde exacto de la regla: el `<` es estricto, vencer hoy no es estar
    // vencida. Es el único caso que distingue `<` de `<=`, y sin él ese cambio
    // de un carácter pasaría la revisión sin que nada fallara.
    assert.isFalse(tarea(HOY).isOverdueOn(HOY))
  })

  test('3 | fecha posterior al día de referencia: no vencida', ({ assert }) => {
    assert.isFalse(tarea(MANANA).isOverdueOn(HOY))
    assert.isFalse(tarea('2030-12-31').isOverdueOn(HOY))
  })

  test('4 | sin fecha: no vencida nunca, mire quien mire desde donde mire', ({ assert }) => {
    assert.isFalse(tarea(null).isOverdueOn(HOY))
    assert.isFalse(tarea(null).isOverdueOn('2099-12-31'))
  })

  test('5 | tarea ya hecha con la fecha pasada: no vencida', ({ assert }) => {
    // La tercera condición de la regla. Es la que hoy no está escrita en
    // `isOverdueOn`: el método no mira el estado.
    assert.isFalse(tarea(AYER, 'done').isOverdueOn(HOY))
    assert.isFalse(tarea('2025-01-01', 'done').isOverdueOn(HOY))
  })

  /**
   * Este caso no lo pide ningún requisito: lo pide la realidad del dato.
   *
   * `tasks.due_date` es una columna `date` de PostgreSQL. El modelo la declara
   * `string | null` y la regla la compara con `<` contra una cadena, pero lo que
   * el driver devuelve al leer una fila no tiene por qué ser una cadena, y un
   * `Date` comparado con `<` contra texto no da «menor»: da `false` siempre, en
   * los dos sentidos, sin lanzar nada. Esa es exactamente la forma de fallo que
   * no se ve: ningún error, solo tareas que nunca aparecen vencidas.
   *
   * De ahí el caso: la regla tiene que dar la misma respuesta reciba el día como
   * texto o como objeto de fecha, porque por los dos caminos llega.
   */
  test('6 | la misma respuesta reciba la fecha como texto o como objeto de fecha', ({ assert }) => {
    // Un día del calendario a mediodía UTC: así el objeto representa el mismo
    // día en cualquier huso, y lo que se compara no depende de dónde corra el test.
    const comoObjeto = (dia: string) => new Date(`${dia}T12:00:00Z`)

    /** La fecha de vencimiento tal y como puede llegar de la base: no siempre texto. */
    const conFechaObjeto = (dia: string, status: Task['status'] = 'pending') => {
      const task = tarea(null, status)
      // El cast es el punto del test: el tipo declarado dice `string`, la base
      // puede entregar otra cosa, y la regla no debe depender de cuál de las dos.
      task.dueDate = comoObjeto(dia) as unknown as string

      return task
    }

    // Caso por caso contra la versión en texto, que es la referencia.
    for (const [dia, status] of [
      [AYER, 'pending'],
      [HOY, 'pending'],
      [MANANA, 'pending'],
      [AYER, 'done'],
    ] as const) {
      assert.equal(
        conFechaObjeto(dia, status).isOverdueOn(HOY),
        tarea(dia, status).isOverdueOn(HOY),
        `la fecha ${dia} (${status}) como objeto da una respuesta distinta que como texto`
      )
    }

    // Y el día de referencia, por el mismo motivo: también puede llegar sin ser texto.
    assert.equal(
      tarea(AYER).isOverdueOn(comoObjeto(HOY) as unknown as string),
      tarea(AYER).isOverdueOn(HOY),
      'el día de referencia como objeto da una respuesta distinta que como texto'
    )
  })
})
