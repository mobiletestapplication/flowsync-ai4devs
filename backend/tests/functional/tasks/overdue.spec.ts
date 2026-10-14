import { test } from '@japa/runner'
import testUtils from '@adonisjs/core/services/test_utils'

/**
 * Cuándo una tarea está vencida. Un test por cada Scenario del requisito
 * «Cuándo una tarea está vencida» de `openspec/specs/tasks/spec.md`:
 *
 *   1. Fecha del día anterior            5. Darla por hecha la deja de vencer
 *   2. Vencer hoy todavía no es estar…   6. Una tarea hecha con la fecha pasada
 *   3. Fecha futura                      7. Aplazar resuelve el vencimiento
 *   4. Sin fecha no se vence nunca
 *
 * Todo entra por HTTP, igual que entra el cliente de la API: la tarea se crea
 * con `POST /api/v1/tasks`, la fecha se pone con `PUT /api/v1/tasks/:id/due-date`
 * y el estado con `PATCH /api/v1/tasks/:id/status`. Lo que se comprueba es el
 * `isOverdue` que viaja en el cuerpo de la respuesta, nunca el resultado de un
 * método del modelo: la regla solo está cumplida si llega al cliente.
 *
 * El día de referencia se pasa en cada petición (`today`) y es fijo. Aquí no
 * aparece la fecha de hoy ni ningún reloj: si estos tests dependieran del día en
 * que se ejecutan, pasarían o fallarían solos.
 *
 * Ningún identificador se da por supuesto: el de cada tarea es el que devuelve
 * su creación.
 */
test.group('Tasks | vencimiento', (group) => {
  group.each.setup(() => testUtils.db().withGlobalTransaction())

  /** El día desde el que se mira en todos los tests. Fijo, no es «hoy». */
  const HOY = '2026-08-20'
  const AYER = '2026-08-19'
  const MANANA = '2026-08-21'

  const con = (token: string) => ({ Authorization: `Bearer ${token}` })

  /** Una cuenta con sesión abierta. */
  async function persona(client: any) {
    const email = 'ada@example.com'
    const password = 'secreto123'

    const signup = await client
      .post('/api/v1/auth/signup')
      .json({ fullName: 'Ada Lovelace', email, password, passwordConfirmation: password })
    signup.assertStatus(200)

    const login = await client.post('/api/v1/auth/login').json({ email, password })
    login.assertStatus(200)

    return login.body().data.token as string
  }

  /**
   * Crea una tarea y devuelve el identificador **que ha devuelto la creación**.
   * Si `dueDate` llega (incluido `null`), se fija por su propio endpoint: la
   * creación no acepta fecha.
   */
  async function tarea(client: any, token: string, dueDate?: string | null) {
    const creada = await client
      .post('/api/v1/tasks')
      .headers(con(token))
      .json({ title: 'Revisar el informe' })
    creada.assertStatus(201)

    const id = creada.body().data.id as number

    if (dueDate !== undefined) {
      const fijada = await client
        .put(`/api/v1/tasks/${id}/due-date`)
        .headers(con(token))
        .json({ dueDate, today: HOY })
      fijada.assertStatus(200)
    }

    return id
  }

  /** La tarea tal y como llega al cliente, mirada desde `today`. */
  async function leida(client: any, token: string, id: number, today: string = HOY) {
    const response = await client.get(`/api/v1/tasks/${id}`).qs({ today }).headers(con(token))
    response.assertStatus(200)

    return response.body().data
  }

  test('Scenario: fecha del día anterior | llega marcada como vencida', async ({
    client,
    assert,
  }) => {
    const token = await persona(client)
    const id = await tarea(client, token, AYER)

    const leidaAhora = await leida(client, token, id)

    // No está hecha, tiene fecha y la fecha es anterior al día de referencia:
    // las tres condiciones a la vez.
    assert.notEqual(leidaAhora.status, 'done')
    assert.isTrue(leidaAhora.isOverdue)
  })

  test('Scenario: vencer hoy todavía no es estar vencida | la fecha es el propio día de referencia', async ({
    client,
    assert,
  }) => {
    const token = await persona(client)
    const id = await tarea(client, token, HOY)

    const leidaAhora = await leida(client, token, id)

    // La regla exige que la fecha sea ANTERIOR. Un `<=` en la comparación
    // dejaría pasar este caso sin que nada más fallara.
    assert.notEqual(leidaAhora.status, 'done')
    assert.isFalse(leidaAhora.isOverdue)
  })

  test('Scenario: fecha futura | no llega marcada como vencida', async ({ client, assert }) => {
    const token = await persona(client)
    const id = await tarea(client, token, MANANA)

    const leidaAhora = await leida(client, token, id)

    assert.isFalse(leidaAhora.isOverdue)
  })

  test('Scenario: sin fecha no se vence nunca | por antigua que sea', async ({
    client,
    assert,
  }) => {
    const token = await persona(client)
    // Sin fecha de ninguna clase: la creación no la pone.
    const id = await tarea(client, token)

    // «Creada hace semanas»: la antigüedad no se simula tocando la base, se
    // mira desde un día muy posterior al de su creación, que es lo que la
    // regla permite. Si la antigüedad contara, aquí se vería.
    const leidaAhora = await leida(client, token, id, '2027-01-15')

    assert.isNull(leidaAhora.dueDate)
    assert.equal(leidaAhora.status, 'pending')
    assert.isFalse(leidaAhora.isOverdue)
  })

  test('Scenario: darla por hecha la deja de vencer | y conserva su fecha', async ({
    client,
    assert,
  }) => {
    const token = await persona(client)
    const id = await tarea(client, token, AYER)

    // Primero vencida: el cambio de estado es lo que se está probando, así que
    // el punto de partida tiene que estar comprobado.
    const antes = await leida(client, token, id)
    assert.isTrue(antes.isOverdue)

    const cambio = await client
      .patch(`/api/v1/tasks/${id}/status`)
      .headers(con(token))
      .json({ status: 'done' })
    cambio.assertStatus(200)

    const despues = await leida(client, token, id)

    assert.equal(despues.status, 'done')
    assert.isFalse(despues.isOverdue)
    // Y la fecha es la misma que antes del cambio: darla por hecha no la retira.
    assert.equal(despues.dueDate, antes.dueDate)
  })

  test('Scenario: una tarea hecha con la fecha pasada | no llega marcada como vencida', async ({
    client,
    assert,
  }) => {
    const token = await persona(client)
    const id = await tarea(client, token, AYER)

    const cambio = await client
      .patch(`/api/v1/tasks/${id}/status`)
      .headers(con(token))
      .json({ status: 'done' })
    cambio.assertStatus(200)

    // Se consulta una tarea que ya está en `done` y cuya fecha ya pasó: no
    // hace falta que el paso a `done` haya ocurrido ahora mismo para que la
    // lectura sea la misma.
    const leidaAhora = await leida(client, token, id, '2027-01-15')

    assert.equal(leidaAhora.status, 'done')
    assert.isFalse(leidaAhora.isOverdue)
  })

  test('Scenario: aplazar resuelve el vencimiento | en la misma respuesta del cambio', async ({
    client,
    assert,
  }) => {
    const token = await persona(client)
    const id = await tarea(client, token, AYER)

    const antes = await leida(client, token, id)
    assert.isTrue(antes.isOverdue)

    const aplazada = await client
      .put(`/api/v1/tasks/${id}/due-date`)
      .headers(con(token))
      .json({ dueDate: MANANA, today: HOY })

    aplazada.assertStatus(200)
    // En ESTA respuesta, no en una consulta posterior: quien aplaza no tiene
    // que volver a preguntar para saber que ya no está vencida.
    assert.isFalse(aplazada.body().data.isOverdue)
    assert.equal(aplazada.body().data.dueDate, MANANA)
  })
})
