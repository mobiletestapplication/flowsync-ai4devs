#!/usr/bin/env bash
#
# Guardarraíl: impide que cierta clase de dato entre en el repositorio, y deja
# rastro cada vez que actúa.
#
# Registrado como PreToolUse/Bash en .claude/settings.json. Lee el JSON del hook
# por la entrada estándar y mira .tool_input.command, igual que el hook de
# Prettier que ya está registrado.
#
# Solo actúa sobre `git commit`. Salir con 2 bloquea la llamada a la herramienta
# y devuelve la salida de error al agente. Cualquier otro comando sale con 0 sin
# decir nada.
#
set -uo pipefail

entrada="$(cat)"
comando="$(printf '%s' "$entrada" | jq -r '.tool_input.command // empty' 2>/dev/null)"

case "$comando" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

raiz="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$raiz" ]; then
  raiz="$(git rev-parse --show-toplevel 2>/dev/null)"
fi
[ -n "$raiz" ] || exit 0
cd "$raiz" || exit 0

# Si el mismo comando prepara los cambios, lo que va a entrar todavía no está en
# el índice: hay que mirar también el árbol de trabajo y los archivos nuevos sin
# seguimiento.
tambien_prepara=0
case "$comando" in
  *"git add"*) tambien_prepara=1 ;;
esac

GIT=(git -c core.quotePath=false --no-pager)

# Las líneas AÑADIDAS de lo que va a entrar, como "archivo<TAB>contenido".
lineas_anadidas() {
  {
    "${GIT[@]}" diff --cached --no-color --no-ext-diff -U0 --diff-filter=ACMR
    if [ "$tambien_prepara" -eq 1 ]; then
      "${GIT[@]}" diff --no-color --no-ext-diff -U0 --diff-filter=ACMR
    fi
  } | awk '
    /^\+\+\+ /{
      f = $0
      sub(/^\+\+\+ /, "", f)
      if (f == "/dev/null") { f = "" } else { sub(/^b\//, "", f) }
      next
    }
    /^\+/{ if (f != "") print f "\t" substr($0, 2) }
  '

  if [ "$tambien_prepara" -eq 1 ]; then
    while IFS= read -r -d '' nuevo; do
      [ -f "$nuevo" ] || continue
      # Los binarios no se escanean: no hay líneas que leer.
      LC_ALL=C grep -Iq . "$nuevo" 2>/dev/null || continue
      awk -v f="$nuevo" '{ print f "\t" $0 }' "$nuevo"
    done < <("${GIT[@]}" ls-files --others --exclude-standard -z)
  fi
}

# Los archivos que van a entrar, por su ruta.
rutas_que_entran() {
  {
    "${GIT[@]}" diff --cached --name-only --diff-filter=ACMR
    if [ "$tambien_prepara" -eq 1 ]; then
      "${GIT[@]}" diff --name-only --diff-filter=ACMR
      "${GIT[@]}" ls-files --others --exclude-standard
    fi
  } | sort -u
}

# Reglas 1 y 2, sobre el contenido añadido. Emite "regla<TAB>archivo", nunca el
# valor: lo que se ha encontrado no sale de aquí.
hallazgos_contenido() {
  lineas_anadidas | awk -F'\t' '
    BEGIN {
      permitidos["example.com"] = 1
      permitidos["example.org"] = 1
      permitidos["example.net"] = 1
      permitidos["github.com"] = 1
    }
    {
      archivo = $1
      # El contenido puede llevar tabuladores: quita solo el primer campo.
      linea = $0
      sub(/^[^\t]*\t/, "", linea)

      # Regla 1: una clave con forma reconocible. Se exige cuerpo detrás del
      # prefijo, porque una clave lo tiene y una mención en prosa no.
      if (linea ~ /AKIA[A-Z0-9]{16}/ ||
          linea ~ /sk-ant-[A-Za-z0-9_-]{8,}/ ||
          linea ~ /ghp_[A-Za-z0-9]{16,}/ ||
          linea ~ /github_pat_[A-Za-z0-9_]{16,}/ ||
          linea ~ /AIza[A-Za-z0-9_-]{35}/ ||
          linea ~ /xox[bpa]-[A-Za-z0-9-]{8,}/ ||
          linea ~ /-----BEGIN [A-Z ]*PRIVATE KEY-----/ ||
          linea ~ /^APP_KEY=[^[:space:]]/) {
        print "clave\t" archivo
      }

      # Regla 2: un correo cuyo dominio no es de los de ejemplo. Se recorren
      # todos los de la línea, no solo el primero.
      resto = linea
      while (match(resto, /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/)) {
        correo = substr(resto, RSTART, RLENGTH)
        resto = substr(resto, RSTART + RLENGTH)
        dominio = tolower(correo)
        sub(/^[^@]*@/, "", dominio)
        if (!(dominio in permitidos)) {
          print "correo\t" archivo
          break
        }
      }
    }
  '
}

# Regla 3: el fichero .env, ese nombre exacto, en cualquier carpeta. Los
# .env.example y .env.test no cuentan.
hallazgos_rutas() {
  rutas_que_entran | while IFS= read -r ruta; do
    [ -n "$ruta" ] || continue
    if [ "$(basename -- "$ruta")" = ".env" ]; then
      printf 'env\t%s\n' "$ruta"
    fi
  done
}

hallazgos="$( { hallazgos_contenido; hallazgos_rutas; } | sort -u )"
[ -n "$hallazgos" ] || exit 0

# Rastro. Una línea por bloqueo, y nunca el valor encontrado: un registro que
# repite el dato es otra copia del dato.
registro="docs/seguridad/registro-de-bloqueos.md"
mkdir -p "$(dirname "$registro")" 2>/dev/null
if [ ! -f "$registro" ]; then
  printf '%s\n' '# Registro de bloqueos de `.claude/hooks/datos-que-no-salen.sh` — una línea por bloqueo, sin el valor bloqueado.' > "$registro"
fi

primera="$(printf '%s\n' "$hallazgos" | head -n 1)"
regla="${primera%%$'\t'*}"
archivo="${primera#*$'\t'}"
printf '%s BLOQUEADO regla=%s archivo=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$regla" "$archivo" >> "$registro"

{
  echo "BLOQUEADO por .claude/hooks/datos-que-no-salen.sh: el commit no se ha ejecutado."
  echo
  printf '%s\n' "$hallazgos" | while IFS=$'\t' read -r r a; do
    case "$r" in
      clave) echo "  - regla 1, una clave con forma reconocible, en: $a" ;;
      correo) echo "  - regla 2, un correo con dominio real, en: $a" ;;
      env) echo "  - regla 3, el fichero .env, en: $a" ;;
    esac
  done
  echo
  echo "Sustituye el dato por uno inventado y vuelve a intentar el commit:"
  echo "  - correos, en example.com / example.org / example.net"
  echo "  - claves, por un valor de pega que no tenga la forma de una de verdad"
  echo "  - el .env no entra nunca; versiona .env.example, sin valor"
  echo
  echo "No desactives este hook ni lo rodees: el dato se cambia, la regla se queda."
  echo "Queda anotado en $registro, sin el valor. Ese fichero se commitea con el resto: es la evidencia."
} >&2

exit 2
