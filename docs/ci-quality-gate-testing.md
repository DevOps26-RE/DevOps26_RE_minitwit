# CI Quality Gate — Integration, API, UI, and E2E Tests

## The Problem Before

The CI chain had a single test signal: only the API simulator was executed.

That means the pipeline could still miss regressions in:
- UI behavior (what users actually see and click)
- End-to-end behavior across UI and database
- Core web integration flows (auth, timeline visibility, follow/unfollow)

Even though deployment was already gated on tests, the gate only represented one slice of system quality.

---

## What Was Added

The test stage now executes three suites inside one Docker Compose test stack:

1. Integration tests
- File: `test/test_integration_flows.py`
- Focus: register/login/logout, timeline behavior, follow/unfollow behavior
- Level: HTTP integration against the running web app and database-backed state

2. API compatibility simulator
- File: `test/minitwit_simulator.py`
- Focus: existing simulator scenario and compatibility semantics
- Level: API contract and scenario playback

3. UI and end-to-end browser tests
- File: `test/test_itu_minitwit_ui.py`
- Focus: registration through browser and DB-side persistence check
- Level: Selenium browser automation plus direct PostgreSQL verification

---

## How the Gate Works

### Unified test orchestration

A single runner script executes all suites in deterministic order:

- `test/run_all_tests.sh`

It stops immediately on first failing suite and returns a non-zero exit code.

### Compose wiring

The test stack in `docker-compose-tests.yaml` now contains:
- `db` (PostgreSQL)
- `web` (Go MiniTwit app)
- `selenium` (standalone Chromium for headless browser tests)
- `test` (Python runner container)

The `test` service executes:

```sh
sh test/run_all_tests.sh
```

### CI wiring

The test job in `.github/workflows/main.yml` runs:

```sh
docker compose -f docker-compose-tests.yaml up --build --abort-on-container-exit --exit-code-from test
```

and then always tears down the stack:

```sh
docker compose -f docker-compose-tests.yaml down -v
```

Because downstream jobs use `needs: test`, a failing test suite blocks image build and deployment.

---

## Why This Is Better

- Wider regression coverage: web integration, API contract, and full browser behavior
- Stronger release confidence: one strict quality gate before build/deploy
- Reproducible workflow: same command locally and in CI
- Better maintainability: test concerns are split by level but aggregated by one orchestrator

---

## Local Reproduction

Run exactly what CI runs:

```sh
docker compose -f docker-compose-tests.yaml up --build --abort-on-container-exit --exit-code-from test
docker compose -f docker-compose-tests.yaml down -v
```

If the command exits with non-zero status, at least one suite failed and delivery/deployment should not continue.
