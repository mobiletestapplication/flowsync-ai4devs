---
name: analisis-de-amenazas
description: Produce un análisis de amenazas fechado de este sistema, recorriendo las diez entradas del OWASP Top 10 for LLM Applications 2025 de LLM01 a LLM10. Usar cuando se pida revisar la postura de seguridad frente a modelos de lenguaje, o antes de cerrar una unidad de trabajo que toque el harness.
---
# Análisis de amenazas

Esto es un **procedimiento**, no un consejo. Cada ejecución recorre los mismos pasos en el mismo orden y produce un archivo con la misma forma. Dos ejecuciones sobre el mismo commit deben salir iguales salvo en lo que haya cambiado el repositorio; si salen distintas, algo se ha saltado.

## Dos prohibiciones

Van primero porque son lo que distingue este análisis de un texto de relleno.

1. **No afirmar que se comprobó lo que no se abrió.** «Qué se miró» lleva rutas de archivos que se han leído de verdad en esta ejecución. Si una entrada se resolvió sin abrir nada, se dice: «nada; no hay en este repositorio superficie que mirar para esta entrada». Nunca se escribe una ruta que no se abrió, ni se describe el contenido de un archivo por su nombre.
2. **No rellenar una entrada con generalidades del catálogo.** Está prohibido explicar qué es LLM0X en abstracto, o qué suele pasar «en aplicaciones de este tipo». Cada entrada habla de **este** sistema, con sus rutas. Si en este sistema no hay nada que mirar para una entrada, la decisión es `fuera de alcance` con su motivo — **y eso es una respuesta válida y completa**, no un hueco que haya que disimular.

## Paso 0 — los tres datos de cabecera

```bash
date -u +%F                  # la fecha del análisis y del nombre del archivo
git rev-parse --short HEAD   # el commit sobre el que se analiza
git status --short           # si no está limpio, dilo en el alcance
```

Un análisis fechado describe un estado del árbol. Si hay cambios sin commitear, la frase de alcance lo dice, porque entonces el commit de la cabecera no cuenta toda la verdad.

## Paso 1 — inventario de superficies

Dos superficies, y solo dos. Hay que abrir archivos en ambas antes de tocar el paso 2.

### 1a. El producto — ¿integra hoy algún modelo?

**Se mira, no se supone.** El mínimo a comprobar:

```bash
grep -rniE 'anthropic|openai|@ai-sdk|langchain|gemini|mistral|cohere|ollama|llama|embedding' \
  --include=package.json --include=package-lock.json backend/ frontend/ | head -40
grep -rniE 'anthropic|openai|claude|gpt-|prompt|completion|embedding' \
  backend/app backend/config backend/start frontend/src | head -40
```

Si no hay dependencia ni llamada, la conclusión es que **el producto no integra ningún modelo hoy**, y se escribe con las rutas que se abrieron para comprobarlo. Esa conclusión es la que hace que varias entradas del paso 2 caigan en `fuera de alcance`: se apoya en los dos grep de arriba, no en una suposición.

Si **sí** lo integra, el inventario nombra: dónde se construye el prompt, qué entra en él y de quién viene, qué se hace con la respuesta, y qué credencial lo autentica.

### 1b. El harness con el que se desarrolla

Aquí es donde un modelo lee y escribe hoy. Abrir, al menos:

- `CLAUDE.md` — las instrucciones que entran en contexto en cada sesión. Y comprobar qué es `AGENTS.md`: `ls -l AGENTS.md` (hoy es un symlink al mismo archivo; si deja de serlo, son dos fuentes que pueden divergir).
- `.claude/settings.json` y `.claude/settings.local.json` — hooks, permisos, servidores MCP habilitados.
- `.claude/hooks/` — todo script que el harness ejecuta por su cuenta.
- `.claude/agents/*.md` — subagentes, y **qué herramientas declara cada uno**.
- `.claude/skills/*/SKILL.md` y `.claude/commands/` — procedimientos que el modelo sigue como si fueran suyos.
- `.mcp.json` — servidores MCP, y si traen datos de fuera.
- `.github/workflows/*.yml` — dónde corre un modelo sin una persona delante, con qué permisos y con qué secretos.

Ojo con lo que vive **fuera** del repositorio y no se versiona: `~/.claude/settings.json`, `~/.claude/.credentials.json`, `backend/.env`, `backend/tmp/db.sqlite3`. Entran en el inventario como superficie, y se dice de cada uno si se abrió o no.

### Lo que el inventario deja escrito

Una lista literal de **los archivos que se abrieron**, con su ruta. Es la lista contra la que se valida la prohibición 1: una ruta en «Qué se miró» del paso 2 que no esté aquí es un error del análisis.

## Paso 2 — las diez entradas, de LLM01 a LLM10

**OWASP Top 10 for LLM Applications 2025** (https://genai.owasp.org/). Se recorren las diez por su código, en orden, sin saltarse ninguna y sin añadir ninguna:

| Código | Nombre |
|---|---|
| LLM01 | Prompt Injection |
| LLM02 | Sensitive Information Disclosure |
| LLM03 | Supply Chain |
| LLM04 | Data and Model Poisoning |
| LLM05 | Improper Output Handling |
| LLM06 | Excessive Agency |
| LLM07 | System Prompt Leakage |
| LLM08 | Vector and Embedding Weaknesses |
| LLM09 | Misinformation |
| LLM10 | Unbounded Consumption |

Cada entrada lleva **dos campos y solo dos**. Ni un tercero, ni un párrafo de introducción, ni una nota al pie.

- **Qué se miró** — rutas concretas, de archivos abiertos en esta ejecución. Si fue «nada», se dice.
- **Decisión** — exactamente uno de estos tres valores, y con lo que el valor exige:
  - `mitigado` — **y con qué**. Se nombra el mecanismo y su ruta. Que algo esté mitigado no se afirma de palabra: se señala el archivo donde está el freno.
  - `aceptado` — **por qué** se vive con ello, **y qué lo volvería inaceptable**. Ese segundo trozo es obligatorio: un riesgo aceptado sin condición de revisión es un riesgo olvidado.
  - `fuera de alcance` — **por qué** no aplica a este sistema, **y cuándo se reabre**. El disparador tiene que ser un hecho observable («cuando el producto añada una dependencia de un proveedor de modelos»), no una fecha vaga.

### Dónde mirar en este repositorio, por entrada

Esto es el guion que hace el análisis repetible. No es la respuesta: es dónde buscarla.

- **LLM01 Prompt Injection** — por dónde entra texto que el modelo no escribió: `.mcp.json` (un servidor MCP devuelve texto de terceros, p. ej. el contenido de un ticket), `.github/workflows/` (el título, el cuerpo y el diff de un PR de fuera llegan al modelo sin nadie delante), `CLAUDE.md`, `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`.
- **LLM02 Sensitive Information Disclosure** — qué dato puede salir y qué lo frena: `.claude/hooks/datos-que-no-salen.sh`, `docs/seguridad/registro-de-bloqueos.md`, `.gitignore` (raíz, `backend/`, `frontend/`), `backend/.env.example`, `backend/app/transformers/` (qué publica la API), `frontend/src/lib/api.ts`. Y el alcance real del freno: a quién intercepta y a quién no.
- **LLM03 Supply Chain** — `backend/package.json`, `frontend/package.json`, los `package-lock.json`, las versiones de las actions en `.github/workflows/*.yml` (¿fijadas a tag o a SHA?), el servidor remoto de `.mcp.json`, y qué se trae `.claude/` de fuera del repositorio.
- **LLM04 Data and Model Poisoning** — aquí no se entrena ningún modelo, así que lo que toca comprobar es si existe algo que haga de datos de entrenamiento: `grep -rn 'fine-tun\|training\|dataset' --include='*.json' --include='*.ts' backend frontend`. Lo análogo —envenenar las instrucciones que el modelo lee— es LLM01 y se resuelve allí, no aquí; si se decide `fuera de alcance`, el motivo lo dice.
- **LLM05 Improper Output Handling** — a dónde va la salida del modelo sin que nadie la lea: `.claude/settings.json` (un hook que ejecuta un comando con una ruta que el modelo eligió), `.claude/hooks/`, `eval-harness/hooks/`, `.github/workflows/` (un modelo que escribe en el repositorio en CI). En el producto, si lo hubiera: dónde se renderiza o se ejecuta la respuesta.
- **LLM06 Excessive Agency** — qué puede hacer el agente por su cuenta: `allow` en `.claude/settings.json` y `.claude/settings.local.json`, el `~/.claude/settings.json` que **no** se versiona, las herramientas declaradas en `.claude/agents/*.md`, el bloque `permissions` de `.github/workflows/*.yml`, y las reglas de proceso de `CLAUDE.md` (qué se le exige confirmar).
- **LLM07 System Prompt Leakage** — `CLAUDE.md` y `AGENTS.md` están versionados, y en un repositorio público eso es deliberado. Lo que hay que comprobar es si contienen algo que no debería leerse: `grep -niE 'key|token|secret|password|@' CLAUDE.md .claude/agents/*.md .claude/skills/*/SKILL.md`.
- **LLM08 Vector and Embedding Weaknesses** — comprobar si hay RAG o almacén vectorial: `grep -rniE 'embedding|pgvector|vector|chroma|pinecone|qdrant|faiss' --include=package.json backend frontend`. Si no hay, `fuera de alcance` con el disparador.
- **LLM09 Misinformation** — lo que el agente escribe y luego se trata como verdad: `openspec/specs/`, `docs/api/openapi.json`, `docs/capabilities/*/README.md`, `docs/adr/`. Y qué lo contrasta: `backend/tests/`, `npm run openapi:check` y su workflow, `.claude/agents/adversarial-reviewer.md`, `REVIEW.md`.
- **LLM10 Unbounded Consumption** — dónde se gasta sin techo: `.github/workflows/revisor.yml` (qué eventos lo disparan, y si un PR de un fork puede lanzarlo), los `timeout` de los hooks en `.claude/settings.json`, `eval-harness/`. En el producto, si lo hubiera: si hay un endpoint que llame a un modelo sin límite.

## Paso 3 — la forma del archivo

Fija. Esta plantilla, literal, sin secciones de más ni de menos:

```markdown
# Análisis de amenazas — <AAAA-MM-DD>

- **Fecha (UTC):** <date -u +%F>
- **Commit:** <git rev-parse --short HEAD>
- **Alcance:** <una frase: qué se analiza y qué no>

## Superficies donde un modelo lee o escribe

### El producto
<qué se comprobó y qué salió, con rutas>

### El harness
<qué se comprobó y qué salió, con rutas>

### Archivos abiertos en esta ejecución
- <ruta>
- <ruta>

## LLM01 Prompt Injection
- **Qué se miró:** <rutas>
- **Decisión:** `mitigado` | `aceptado` | `fuera de alcance` — <lo que el valor exige>

## LLM02 Sensitive Information Disclosure
- **Qué se miró:** <rutas>
- **Decisión:** ...

## LLM03 Supply Chain
## LLM04 Data and Model Poisoning
## LLM05 Improper Output Handling
## LLM06 Excessive Agency
## LLM07 System Prompt Leakage
## LLM08 Vector and Embedding Weaknesses
## LLM09 Misinformation
## LLM10 Unbounded Consumption

## Fuera de alcance y cuándo se reabre

| Entrada | Por qué quedó fuera | Qué lo reabre |
|---|---|---|
| LLM0X | <motivo> | <disparador observable> |
```

Las diez secciones van completas, cada una con sus dos campos. En la plantilla de arriba se abrevian de LLM03 a LLM10 solo para no repetir; en el archivo producido ninguna se abrevia.

La sección final **reúne** todo lo que quedó en `fuera de alcance` en el paso 2, con su motivo y su disparador. Es un resumen, no una decisión nueva: lo que esté en la tabla tiene que estar también en su entrada, con el mismo motivo. Si ninguna entrada quedó fuera, la sección se escribe igual, con una línea que lo diga.

## Paso 4 — dónde se escribe

```bash
docs/seguridad/analisis-de-amenazas-$(date -u +%F).md
```

Si ya existe uno de hoy, **se sobrescribe** sin preguntar: un análisis es del commit y del día, y el de hoy es el bueno. Los de días anteriores no se tocan nunca — son el historial, y comparar dos fechas es la única forma de ver si la postura mejoró o empeoró.

El archivo se escribe en `docs/seguridad/`, junto a `registro-de-bloqueos.md`, y se commitea con el resto del cambio.

## Al terminar

Decir en el chat, en dos líneas: la ruta del archivo, y el reparto de las diez decisiones (cuántas `mitigado`, cuántas `aceptado`, cuántas `fuera de alcance`). El contenido está en el archivo; no se repite en el chat.
