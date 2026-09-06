# AGENTS.md

## What this repo is

Voicebox — a local-first AI voice studio (voice cloning, TTS, dictation, MCP agent voice I/O). A Tauri desktop app whose React frontend talks over HTTP on `localhost:17493` to a bundled Python FastAPI backend. See `README.md` for features and `docs/PROJECT_STATUS.md` for the living roadmap (architecture, priorities, engine evaluation).

## Layout

- `app/` — the real React frontend (components, hooks, stores, i18n, API client). Shared by all frontends via the `@` alias.
- `tauri/` — desktop wrapper. `tauri/src/` is the entry point; `tauri/src-tauri/` is the Rust shell (sidecar spawn, global hotkeys, audio capture, accessibility/auto-paste).
- `web/` — thin Vite wrapper for browser mode; only provides `webPlatform` and re-renders `app/src/App`.
- `backend/` — FastAPI server. Layered: `routes/` (thin HTTP handlers) → `services/` (all business logic) → `backends/` (TTS/STT engines) → `utils/`. Plus `database/` (SQLAlchemy + auto-migrations) and `mcp_server/` / `mcp_shim/` (MCP integration for AI agents).
- `landing/`, `docs/` — separate Next.js apps (marketing site, docs site), each with its own `package.json`.
- `scripts/` — build/release scripts. `justfile` is the command hub.

## Commands

Run `just setup` first (creates `backend/venv` + installs JS deps). Everything goes through `just`; `just --list` for all.

- Dev: `just dev` (backend + desktop), `just dev-web` (backend + web, no Rust build), `just dev-backend`, `just kill`
- Checks: `just check` (Biome + ruff, lint + format), `bun run typecheck` (tsc for app + web), `just fix`
- Tests: `just test` (pytest in `backend/tests`), `just test-models` (e2e generation against the frozen binary; `--only <engine>` to filter)
- Build: `just build` (server sidecar binary + Tauri installer); sidecar alone: `just build-server`
- API client regen: `just generate-api` (requires backend running on 17493; outputs into `app/src/lib/api/` — `core/`, `models/`, `schemas/`, `services/` are generated, don't hand-edit them)

Backend port is **17493** everywhere (dev, docs at `/docs`, sidecar).

## Architecture rules

- Backend: routes stay thin — validate, delegate to a service, format the response. Never call a TTS backend's `generate()` from a route; all GPU inference is serialized through `services/task_queue.py`. CPU-bound work goes through `asyncio.to_thread()`.
- New TTS/STT engine: implement the `TTSBackend`/`STTBackend` protocol and register a `ModelConfig` in `backend/backends/__init__.py`. **Use the `add-tts-engine` skill** (`.agents/skills/add-tts-engine/SKILL.md`) — it covers dependency audit, backend impl, frontend wiring, and PyInstaller bundling.
- Frontend: shared UI/logic goes in `app/`. Platform differences live behind the `PlatformContext` abstraction (`app/src/platform/types.ts`) with implementations in `tauri/src/platform` and `web/src/platform`. Don't import Tauri APIs from `app/`.
- In dev the app connects to a manually-started server; the bundled sidecar binary is only used in production builds.

## Conventions

- Python (target 3.12+): ruff (120 cols, double quotes, trailing commas), type hints, Google docstrings, `logging` (never `print`, use `%s` placeholders), lazy imports for torch/transformers/mlx with `# lazy: heavy import`. Full rules in `backend/STYLE_GUIDE.md` — read it before touching backend code.
- TypeScript: Biome only (no ESLint/Prettier) — single quotes, 100 line width, trailing commas. Functional components with hooks, named exports, strict TS.
- justfile: every recipe has `[unix]` and `[windows]` variants — keep both in sync when editing.

## Gotchas

- `backend/venv` must exist for most `just` recipes. Python 3.13+ triggers a compatibility warning — prefer 3.12.
- Dependency pinning is delicate: `chatterbox-tts`, `hume-tada`, and (on Apple Silicon) `mlx-lm`/`mlx-audio` are installed with `--no-deps` because their declared pins conflict with ours. Don't "fix" these; see comments in the justfile and `requirements-mlx.txt`.
- Backend runs as a PyInstaller sidecar in production — anything new under `backend/` may need hidden-import hooks (`pyi_hooks/`, `voicebox-server.spec`). Heavy ML deps are intentionally imported lazily to keep startup fast.
- Run `bun run convert:assets` before committing new images/videos (PNG→WebP, MOV→WebM; it deletes originals). Requires `webp` + `ffmpeg`.
- Releases: bumpversion syncs the version across `tauri.conf.json`, `Cargo.toml`, all `package.json`s, and `backend/main.py` (`.bumpversion.cfg`); pushing a tag triggers GitHub Actions. Use the `release-bump` skill; update `CHANGELOG.md` `[Unreleased]` (draft via `draft-release-notes` skill).

## Docs to read before sensitive changes

- `backend/STYLE_GUIDE.md` — Python conventions, async rules, error-handling pattern (domain exceptions → HTTPException in routes)
- `backend/README.md` — backend architecture, endpoint map, data directory layout
- `docs/PROJECT_STATUS.md` — roadmap; update it when you ship a significant feature or close/backlog an engine integration
- `.agents/skills/` — project skills: `add-tts-engine`, `release-bump`, `draft-release-notes`, `triage-prs`
