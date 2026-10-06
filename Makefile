# FlowSync — atajos de desarrollo.
#
# Requisitos: Node.js + npm, Docker (las bases de datos corren en contenedores,
# ver compose.yaml) y GNU Make.
#   - macOS:        make viene con las Command Line Tools de Xcode.
#   - Linux / WSL:  sudo apt install make   (o el equivalente de tu distro)
#
# Windows sin WSL no está soportado: estas recetas usan sintaxis POSIX.
# Desde WSL, trabaja sobre el repo clonado dentro del sistema de ficheros
# de Linux (~/...), no en /mnt/c, o npm install irá muy lento.

SHELL := /bin/bash

BACKEND  := backend
FRONTEND := frontend

.DEFAULT_GOAL := help
.PHONY: help setup start install env db-up db-down migrate migrate-dev migrate-test test clean

# La ayuda se genera a partir de los comentarios `## ...` de cada target, para
# que no haya un segundo listado que mantener a mano y que pueda divergir.
help: ## Muestra esta ayuda
	@echo "FlowSync — targets disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN { FS = ":.*## " }; { printf "  make %-12s %s\n", $$1, $$2 }'
	@echo ""

# ---------------------------------------------------------------------------
# setup
# ---------------------------------------------------------------------------

setup: install env db-up migrate ## Deja el proyecto listo para arrancar
	@echo ""
	@echo "✅ Setup completado. Arranca todo con: make start"

install:
	@command -v node >/dev/null 2>&1 || { echo "❌ Node.js no está instalado."; exit 1; }
	@command -v npm  >/dev/null 2>&1 || { echo "❌ npm no está instalado."; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker no está instalado."; exit 1; }
	@echo "📦 Instalando dependencias del backend..."
	@cd $(BACKEND) && npm install
	@echo "📦 Instalando dependencias del frontend..."
	@cd $(FRONTEND) && npm install

env:
	@if [ ! -f $(BACKEND)/.env ]; then \
		echo "📝 Creando $(BACKEND)/.env desde .env.example..."; \
		cp $(BACKEND)/.env.example $(BACKEND)/.env; \
	else \
		echo "📝 $(BACKEND)/.env ya existe, no se toca."; \
	fi
	@if [ ! -f $(FRONTEND)/.env ]; then \
		echo "📝 Creando $(FRONTEND)/.env desde .env.example..."; \
		cp $(FRONTEND)/.env.example $(FRONTEND)/.env; \
	else \
		echo "📝 $(FRONTEND)/.env ya existe, no se toca."; \
	fi
	@if grep -Eq '^APP_KEY=.+' $(BACKEND)/.env; then \
		echo "🔑 APP_KEY ya definida, no se regenera."; \
	else \
		echo "🔑 Generando APP_KEY..."; \
		cd $(BACKEND) && node ace generate:key; \
	fi

# ---------------------------------------------------------------------------
# bases de datos
# ---------------------------------------------------------------------------

# `--wait` es la pieza que importa: `up -d` a secas vuelve en cuanto los
# contenedores arrancan, y la primera vez PostgreSQL todavía está creando la
# base y rechazando conexiones. Con `--wait`, Compose no devuelve el control
# hasta que las dos comprobaciones de salud de compose.yaml dan verde, así que
# el `migrate` de la línea siguiente ya encuentra las bases en pie.
db-up: ## Levanta las dos bases de datos y espera a que estén sanas
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker no está instalado."; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "❌ El demonio de Docker no responde. Arráncalo y repite."; exit 1; }
	@echo "🐘 Levantando db (54410) y db-test (54411)..."
	@docker compose up -d --wait

# Sin `-v`: el volumen de la base de desarrollo se conserva, que es lo que uno
# espera al parar y volver a arrancar. La de pruebas vive en memoria y se
# pierde aquí de todas formas, a propósito. Para borrarlo todo: `make clean`.
db-down: ## Para las dos bases (los datos de desarrollo se conservan)
	@echo "🐘 Parando las bases de datos..."
	@docker compose down

# Las dos bases, siempre las dos: migrar solo una deja la batería de pruebas
# fallando contra un esquema viejo, y el error que da no apunta a esto.
migrate: db-up migrate-dev migrate-test ## Ejecuta las migraciones en las dos bases

migrate-dev:
	@echo "🗃️  Migrando la base de desarrollo (54410)..."
	@cd $(BACKEND) && node ace migration:run

# `NODE_ENV=test` es lo que hace que el framework cargue `.env.test` por encima
# de `.env`, y ahí es donde está el otro puerto. Sin esa variable, esto
# migraría la base de desarrollo dos veces sin decir nada.
migrate-test:
	@echo "🗃️  Migrando la base de pruebas (54411)..."
	@cd $(BACKEND) && NODE_ENV=test node ace migration:run

# ---------------------------------------------------------------------------
# test
# ---------------------------------------------------------------------------

# Depende de `migrate-test` (y este de `db-up`) porque la base de pruebas es
# efímera: en cuanto se para el contenedor, el esquema desaparece con él.
test: db-up migrate-test ## Corre la batería de pruebas contra la base de pruebas
	@echo "🧪 Corriendo la batería de pruebas..."
	@cd $(BACKEND) && npm test

# ---------------------------------------------------------------------------
# start
# ---------------------------------------------------------------------------

# Lanza los dos servidores en paralelo dentro de la misma receta.
#
# `kill -INT 0` manda un SIGINT a todo el grupo de procesos — exactamente lo
# mismo que hace un Ctrl-C real — y así se lleva por delante ambos servidores y
# sus hijos, sin dejar nodos huérfanos ocupando los puertos. Tiene que ser
# SIGINT y no el SIGTERM por defecto de `kill 0`: con SIGTERM, el wrapper de
# `npm run dev` y el `node ace serve --hmr` sobreviven a la señal y quedan
# colgados. Se dispara desde dos sitios:
#
#   - el trap, cuando llega un Ctrl-C (SIGINT al grupo) o un SIGTERM;
#   - el final de cada subshell, cuando *ese* servidor termina por su cuenta.
#
# Lo segundo es necesario porque `wait` a secas espera a que acaben TODOS los
# jobs: si el backend crashea al arrancar, el frontend seguiría vivo para
# siempre y el usuario no se enteraría. No se usa `wait -n` (que sería lo
# natural) porque llegó en bash 4.3 y macOS trae bash 3.2.
# Ojo: `start` está pensado para uso interactivo, desde una terminal. No lo
# llames desde un script ni desde CI: sin control de trabajos, el grupo de
# procesos incluye al proceso que invocó a make, y el SIGINT se lo llevaría por
# delante a él también. Aislar los servidores en su propio grupo con `set -m`
# no vale: los dejaría en segundo plano y el primer `read` de stdin les
# provocaría un SIGTTIN, colgando el "Press h" de Adonis y los atajos de Vite.
# Depende de `db-up` porque sin la base de datos el backend arranca pero falla
# en la primera consulta, y ese error no dice «levanta Docker».
start: db-up ## Levanta backend y frontend a la vez
	@if [ ! -d $(BACKEND)/node_modules ] || [ ! -d $(FRONTEND)/node_modules ]; then \
		echo "❌ Faltan dependencias. Ejecuta primero: make setup"; exit 1; \
	fi
	@if [ ! -f $(BACKEND)/.env ]; then \
		echo "❌ Falta $(BACKEND)/.env. Ejecuta primero: make setup"; exit 1; \
	fi
	@echo "🚀 Arrancando backend (http://localhost:3333) y frontend (http://localhost:5173)..."
	@echo "   Ctrl-C para parar los dos. Si uno se cae, el otro se cierra también."
	@echo ""
	@trap 'trap - INT TERM EXIT; kill -INT 0' INT TERM EXIT; \
	( cd $(BACKEND)  && npm run dev; \
	  echo ""; echo "⚠️  El backend se ha parado. Cerrando el frontend."; kill -INT 0 ) & \
	( cd $(FRONTEND) && npm run dev; \
	  echo ""; echo "⚠️  El frontend se ha parado. Cerrando el backend."; kill -INT 0 ) & \
	wait

# ---------------------------------------------------------------------------
# clean
# ---------------------------------------------------------------------------

# `-v` se lleva el volumen de la base de desarrollo: esto borra los datos.
clean: ## Borra node_modules y las bases de datos, datos incluidos
	@echo "🧹 Limpiando..."
	@rm -rf $(BACKEND)/node_modules $(FRONTEND)/node_modules
	@docker compose down -v 2>/dev/null || true
	@echo "✅ Listo. Vuelve a ejecutar: make setup"
