.PHONY: setup dev test lint clean \
       backend-setup backend-dev backend-test backend-lint \
       frontend-setup frontend-dev frontend-test frontend-lint \
       mobile-setup mobile-dev mobile-test mobile-lint \
       pipeline-setup pipeline-test pipeline-lint

# ── Aggregate targets ────────────────────────────────────────────────

setup: backend-setup frontend-setup mobile-setup pipeline-setup

dev:
	@echo "Start services individually: make backend-dev / frontend-dev / mobile-dev"

test: backend-test frontend-test mobile-test pipeline-test

lint: backend-lint frontend-lint mobile-lint pipeline-lint

clean:
	cd backend && mix deps.clean --all || true
	cd frontend && rm -rf node_modules || true
	cd mobile && flutter clean || true
	cd tools/pipeline_runner && poetry env remove --all || true

# ── Backend (Elixir) ────────────────────────────────────────────────

backend-setup:
	cd backend && mix deps.get && mix compile

backend-dev:
	cd backend && mix phx.server

backend-test:
	cd backend && mix test

backend-lint:
	cd backend && mix format --check-formatted && mix credo --strict

# ── Frontend (Vue) ───────────────────────────────────────────────────

frontend-setup:
	cd frontend && npm ci

frontend-dev:
	cd frontend && npm run dev

frontend-test:
	cd frontend && npm test

frontend-lint:
	cd frontend && npm run lint

# ── Mobile (Flutter) ────────────────────────────────────────────────

mobile-setup:
	cd mobile && flutter pub get

mobile-dev:
	cd mobile && flutter run

mobile-test:
	cd mobile && flutter test

mobile-lint:
	cd mobile && dart format --set-exit-if-changed . && flutter analyze

# ── Pipeline Runner (Python) ────────────────────────────────────────

pipeline-setup:
	cd tools/pipeline_runner && poetry install

pipeline-test:
	cd tools/pipeline_runner && poetry run pytest

pipeline-lint:
	cd tools/pipeline_runner && poetry run ruff check . && poetry run ruff format --check .
