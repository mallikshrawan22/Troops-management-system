-- ============================================================================
-- POB Tracker — database schema snapshot (disaster recovery reference)
-- ============================================================================
-- Why this file exists:
--   index.js only ever runs ALTER TABLE ... ADD COLUMN IF NOT EXISTS
--   statements for columns added AFTER the original tables were created,
--   plus CREATE TABLE IF NOT EXISTS for `duties` and `sessions`. The base
--   `troops`, `patrols`, `app_config`, and `audit_log` tables were created
--   directly against Neon at some point outside this repo, so nothing in
--   the codebase could actually rebuild a fresh database from scratch.
--
--   This file closes that gap. It is NOT generated code and index.js does
--   NOT read it — it is a reference snapshot only, captured by querying
--   information_schema.columns against the live database, so every type,
--   nullability, and default below reflects what is actually running
--   today rather than what the application code implies.
--
-- How to use it:
--   Only needed if the Neon database is ever lost and must be rebuilt from
--   nothing. Run this whole file against a fresh database, then deploy
--   index.js as normal — its own migrateSchema() will still run on boot
--   and will find every column already present (all its ALTERs are
--   IF NOT EXISTS, so that's a safe no-op) and will create `duties` and
--   `sessions` itself if they don't already exist.
--
--   Every statement below is IF NOT EXISTS, so this file is also safe to
--   run against the CURRENT live database — it will change nothing there,
--   since everything it describes already exists.
--
-- Captured: 2026-08-02, via:
--   SELECT table_name, column_name, data_type, is_nullable, column_default
--   FROM information_schema.columns WHERE table_schema='public'
--   ORDER BY table_name, ordinal_position;
-- ============================================================================

-- ── app_config ──────────────────────────────────────────────────────────
-- Single-row-per-key settings/state store (settings, config, counter,
-- security, drafts, dutyCounter, dutyContingency, dutyDrafts). Key is the
-- primary key — confirmed by index.js's `ON CONFLICT (key) DO UPDATE`.
CREATE TABLE IF NOT EXISTS app_config (
  key   TEXT  NOT NULL PRIMARY KEY,
  value JSONB NOT NULL
);

-- ── audit_log ───────────────────────────────────────────────────────────
-- id is a real SERIAL/identity column (live default is
-- nextval('audit_log_id_seq'::regclass)) — not application-generated,
-- unlike every other table's id in this schema.
CREATE TABLE IF NOT EXISTS audit_log (
  id  SERIAL PRIMARY KEY,
  ts  TIMESTAMPTZ DEFAULT now(),
  msg TEXT NOT NULL
);

-- ── troops ──────────────────────────────────────────────────────────────
-- id is TEXT and application-generated (uid('t') — see index.html), not a
-- DB default. Columns from blood_group onward were added later via
-- index.js's migrateSchema() ALTERs; kept here in their live column order
-- for an exact match with the running database.
CREATE TABLE IF NOT EXISTS troops (
  id                 TEXT PRIMARY KEY,
  name               TEXT NOT NULL,
  rank               TEXT DEFAULT '',
  unit               TEXT DEFAULT '',
  sn                 TEXT DEFAULT '',
  status             TEXT DEFAULT 'available',
  notes              TEXT DEFAULT '',
  archived           BOOLEAN DEFAULT FALSE,
  created_at         TIMESTAMPTZ DEFAULT now(),
  phone_local        TEXT DEFAULT '',
  phone_wa           TEXT DEFAULT '',
  blood_group        TEXT,
  deployment_date    DATE,
  weapon_number      TEXT,
  gender             TEXT,
  category           TEXT,
  trade              TEXT,
  driver_quals       TEXT,
  target_pct         INTEGER DEFAULT 100,
  never_suggest      BOOLEAN DEFAULT FALSE,
  restricted_range   BOOLEAN DEFAULT FALSE,
  duty_quals         TEXT[],
  is_senior_sergeant BOOLEAN DEFAULT FALSE,
  never_duty         BOOLEAN DEFAULT FALSE,
  status_since       DATE,
  excluded_days      INTEGER DEFAULT 0,
  absences           JSONB DEFAULT '[]',
  dual_admin         BOOLEAN DEFAULT FALSE
);

-- ── patrols ─────────────────────────────────────────────────────────────
-- id is TEXT and application-generated (uid('p')), same pattern as troops.
CREATE TABLE IF NOT EXISTS patrols (
  id             TEXT PRIMARY KEY,
  ptl_id         TEXT DEFAULT '',
  date           DATE NOT NULL,
  type           TEXT DEFAULT '',
  troops         TEXT[] DEFAULT '{}',
  area           TEXT DEFAULT '',
  duration       NUMERIC,
  route          TEXT DEFAULT '',
  remarks        TEXT DEFAULT '',
  created_at     TIMESTAMPTZ DEFAULT now(),
  commander      TEXT,
  commander_auto BOOLEAN,
  ptl_seq        INTEGER
);

-- ── duties ──────────────────────────────────────────────────────────────
-- Already self-created by index.js's migrateSchema() on every boot
-- (CREATE TABLE IF NOT EXISTS) — reproduced here only so this file is a
-- complete single reference for the whole database, not because it's
-- otherwise missing.
CREATE TABLE IF NOT EXISTS duties (
  id               TEXT PRIMARY KEY,
  duty_seq         INTEGER,
  date             DATE,
  logical_date     DATE,
  type             TEXT,
  post_id          TEXT,
  post_name        TEXT,
  start_time       TEXT,
  duration_hours   NUMERIC,
  troops           JSONB DEFAULT '[]',
  remarks          TEXT,
  admin_override   BOOLEAN DEFAULT FALSE,
  replacements     JSONB DEFAULT '[]',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  modified_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  cancelled        BOOLEAN DEFAULT FALSE,
  cancelled_at     TIMESTAMPTZ,
  shift_idx        INTEGER,
  shift_idx_count  INTEGER,
  duty_id          TEXT
);
CREATE INDEX IF NOT EXISTS idx_duties_date ON duties(date);

-- ── sessions ────────────────────────────────────────────────────────────
-- Also already self-created by migrateSchema() — reproduced here for
-- completeness only, same as duties above.
CREATE TABLE IF NOT EXISTS sessions (
  id            TEXT PRIMARY KEY,
  token         TEXT NOT NULL UNIQUE,
  device_label  TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked       BOOLEAN NOT NULL DEFAULT FALSE,
  is_main       BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
