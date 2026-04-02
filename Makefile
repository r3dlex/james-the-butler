.PHONY: setup dev test test-coverage lint archgate clean \
       backend-setup backend-dev backend-test backend-test-coverage backend-lint \
       frontend-setup frontend-dev frontend-test frontend-test-coverage frontend-lint \
       mobile-setup mobile-dev mobile-test mobile-test-coverage mobile-lint \
       pipeline-setup pipeline-test pipeline-test-coverage pipeline-lint \
       cli-setup cli-build cli-test cli-test-coverage cli-lint \
       docs-setup docs-dev docs-build docs \
       up down logs build

# ── Docker targets ──────────────────────────────────────────────────

COMPOSE := $(shell command -v docker-compose 2>/dev/null || echo "docker compose")

up:
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

build:
	$(COMPOSE) build

# ── Aggregate targets ────────────────────────────────────────────────

setup: backend-setup frontend-setup mobile-setup pipeline-setup cli-setup

dev: up
	@echo "Services starting via docker-compose. Use 'make logs' to follow output."

test: backend-test frontend-test mobile-test pipeline-test cli-test

test-coverage: backend-test-coverage frontend-test-coverage mobile-test-coverage pipeline-test-coverage cli-test-coverage

lint: backend-lint frontend-lint mobile-lint pipeline-lint cli-lint

archgate:
	cd tools/pipeline_runner && poetry run pipeline-runner archgate

clean:
	cd backend && mix deps.clean --all || true
	cd frontend && rm -rf node_modules || true
	cd mobile && flutter clean || true
	cd tools/pipeline_runner && poetry env remove --all || true
	cd cli && mix deps.clean --all || true

# ── Backend (Elixir) ────────────────────────────────────────────────

backend-setup:
	cd backend && mix deps.get && mix compile

backend-dev:
	cd backend && mix phx.server

backend-test:
	cd backend && mix test

backend-test-coverage:
	cd backend && mix test --cover

backend-lint:
	cd backend && mix format --check-formatted && mix credo --strict

# ── Frontend (Vue) ───────────────────────────────────────────────────

frontend-setup:
	cd frontend && npm ci

frontend-dev:
	cd frontend && npm run dev

frontend-test:
	cd frontend && npm test

frontend-test-coverage:
	cd frontend && npm run test:coverage

frontend-lint:
	cd frontend && npm run lint

# ── Desktop (Tauri) ─────────────────────────────────────────────────

desktop-dev:
	cd frontend && npm run tauri:dev

desktop-build:
	cd frontend && npm run tauri:build

# ── Mobile (Flutter) ────────────────────────────────────────────────

mobile-setup:
	cd mobile && flutter pub get

mobile-dev:
	cd mobile && flutter run

mobile-test:
	cd mobile && flutter test

mobile-test-coverage:
	cd mobile && flutter test --coverage

mobile-lint:
	cd mobile && dart format --set-exit-if-changed . && flutter analyze

# ── Pipeline Runner (Python) ────────────────────────────────────────

pipeline-setup:
	cd tools/pipeline_runner && poetry install

pipeline-test:
	cd tools/pipeline_runner && poetry run pytest

pipeline-test-coverage:
	cd tools/pipeline_runner && poetry run pytest --cov --cov-report=term-missing --cov-fail-under=90

pipeline-lint:
	cd tools/pipeline_runner && poetry run ruff check . && poetry run ruff format --check .

# ── CLI (Elixir escript) ────────────────────────────────────────────

cli-setup:
	cd cli && mix deps.get && mix compile

cli-build:
	cd cli && mix escript.build

cli-test:
	cd cli && mix test

cli-test-coverage:
	cd cli && mix test --cover

cli-lint:
	cd cli && mix format --check-formatted && mix credo --strict

# ── Docs (VitePress) ────────────────────────────────────────────────

docs-setup:
	cd docs && npm ci

docs-dev:
	cd docs && npm run dev

docs-build:
	cd docs && npm run build

docs: docs-build
