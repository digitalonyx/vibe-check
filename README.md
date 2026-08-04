# Backend Security Checkers for Flutter

Quick, dependency-light bash scripts — invoked via a Claude Code, Gemini CLI, or Codex skill, or run directly — to externally verify that your Supabase and Firebase backends are properly secured.

These tools help catch common misconfigurations **before** they become the next headline (see: Moltbook Supabase exposure and Tea app Firebase Storage breach).

## Why This Matters

Many Flutter apps use `supabase_flutter` or Firebase packages. Both platforms are powerful but easy to misconfigure:

- **Supabase**: Missing Row Level Security (RLS) on tables means anyone with the anon key can read/write everything.
- **Firebase Realtime Database**: Rules set to `".read": true` or `".write": true` make data publicly accessible.

These scripts simulate what an external attacker or security researcher sees when using only public, non-secret inputs: the Supabase anon key, or just the Firebase project ID (no key at all).

## Included Scripts

| Script | Purpose | Best For |
|--------|---------|----------|
| `check_supabase_rls.sh` | Verifies RLS is protecting Supabase tables | All Supabase-backed Flutter apps |
| `check_firebase_realtime_exposure.sh` | Checks if Firebase Realtime Database paths are publicly readable | Firebase Realtime Database users |

> **Note**: For Firebase Storage (the issue in the Tea breach), use proper [Storage Security Rules](https://firebase.google.com/docs/storage/security) instead of a runtime checker.

## Two Ways to Run These Checks

| | Best for |
|---|---|
| **[AI coding assistant](#using-with-an-ai-coding-assistant-skill)** (recommended) — Claude Code, Gemini CLI, or Codex | Interactive use inside a Flutter project — the assistant finds your config, decides what's worth probing, and explains results in context |
| **[Direct script usage](#direct-script-usage-cli--ci)** | CI pipelines, scripted use, or anywhere without an AI coding assistant |

All three assistant integrations, and direct usage, run the exact same two scripts underneath — they're wrappers around the scripts, not different implementations.

---

## Using with an AI Coding Assistant (Skill)

This repo ships the same skill logic for three assistants — `SKILL.md` (Claude Code), `.gemini/skills/vibe-check/SKILL.md` (Gemini CLI), and `AGENTS.md` (Codex). Each wraps `check_supabase_rls.sh` and `check_firebase_realtime_exposure.sh` with project-aware discovery and interpretation: it finds your Supabase/Firebase identifiers from your own project files instead of making you paste them, infers which tables and database paths are worth probing from your actual Dart code, runs the same two scripts under the hood, and turns the raw output into a prioritized, schema-aware remediation plan.

### How credential discovery works (and why it's safe)

The skill needs your Supabase URL/anon key and Firebase project ID to run the checks. Neither is a secret:

- The **Supabase anon key** is designed to be public — it ships inside your compiled Flutter app's bundle, and Supabase's security model assumes anyone can read it. RLS (what these scripts test) is the actual security boundary, not keeping the anon key hidden. See [Supabase's docs on API keys](https://supabase.com/docs/guides/api/api-keys).
- The **Firebase project ID** is likewise public by design — it's embedded in every Firebase client app and visible in any request URL (`https://<project-id>.firebaseio.com`).

That said, a `.env` file may *also* hold genuinely sensitive values unrelated to this skill — a Supabase **service role** key, third-party API secrets, database passwords. All three integrations are explicitly instructed **not** to read a `.env` file wholesale into context. Instead they:

- Prefer letting `check_supabase_rls.sh` load `.env` itself — the script already auto-loads `SUPABASE_URL`/`SUPABASE_ANON_KEY` on its own, so the anon key never has to pass through the assistant's context at all.
- If a value has to be read directly (e.g. it lives in `firebase_options.dart` or `google-services.json`, or `.env` auto-load isn't available), extract only that specific named identifier via a targeted match — never the full file contents, and never any unrelated `.env` line.

### Claude Code

1. Clone or copy this repository so that `SKILL.md` sits alongside your Flutter project (or is reachable from it).
2. Place the skill where Claude Code looks for it:
   - **Personal, all projects:** copy this repo's contents into `~/.claude/skills/vibe-check/` (so `~/.claude/skills/vibe-check/SKILL.md` exists).
   - **Project-scoped:** copy this repo's contents into `.claude/skills/vibe-check/` inside your Flutter project (so `.claude/skills/vibe-check/SKILL.md` exists).
3. Claude Code auto-loads any `SKILL.md` found under a `skills/<name>/` directory on startup — no further registration step is needed.
4. In a Claude Code session inside your Flutter project, invoke it with `/vibe-check`, or just ask something like "check my backend for exposed tables" — the skill's description is matched automatically for natural-language requests too.

```
$ claude
> /vibe-check
Discovering Supabase/Firebase config in this project...
Found SUPABASE_URL and SUPABASE_ANON_KEY via .env auto-load (not read into context).
Found Firebase project ID "my-flutter-app-12345" in lib/firebase_options.dart.
Inferred tables from lib/**/*.dart: profiles, messages, posts.
Running check_supabase_rls.sh and check_firebase_realtime_exposure.sh...
⚠ 'messages' is exposed — your ChatScreen writes sender_id/recipient_id/body here.
  Proposed fix: ALTER TABLE messages ENABLE ROW LEVEL SECURITY; CREATE POLICY ...
Apply this fix now? (y/n)
```

### Gemini CLI

1. Clone or copy this repository so that `.gemini/skills/vibe-check/SKILL.md` sits alongside your Flutter project (or is reachable from it).
2. Place the skill where Gemini CLI looks for it:
   - **Personal, all projects:** copy this repo's `.gemini/skills/vibe-check/` directory into `~/.gemini/skills/vibe-check/` (so `~/.gemini/skills/vibe-check/SKILL.md` exists).
   - **Project-scoped:** keep `.gemini/skills/vibe-check/SKILL.md` as-is inside your Flutter project — Gemini CLI picks up `.gemini/skills/` from the project root automatically.
3. In a Gemini CLI session inside your Flutter project, invoke it with `/vibe-check`, or ask naturally, e.g. "vibe check my backend for exposed tables."

```
$ gemini
> /vibe-check
Discovering Supabase/Firebase config in this project...
Found SUPABASE_URL and SUPABASE_ANON_KEY via .env auto-load (not read into context).
Found Firebase project ID "my-flutter-app-12345" in lib/firebase_options.dart.
Inferred tables from lib/**/*.dart: profiles, messages, posts.
Running check_supabase_rls.sh and check_firebase_realtime_exposure.sh...
⚠ 'messages' is exposed — your ChatScreen writes sender_id/recipient_id/body here.
  Proposed fix: ALTER TABLE messages ENABLE ROW LEVEL SECURITY; CREATE POLICY ...
Apply this fix now? (y/n)
```

### Codex

1. Clone or copy this repository so that `AGENTS.md` sits at the root of your Flutter project (or a directory Codex is working in).
2. No separate registration step: Codex reads `AGENTS.md` automatically as project instructions whenever it's working in this repo.
3. Ask naturally, e.g. "check my backend for exposed tables," or type `/vibe-check` as shorthand for the same request — `AGENTS.md` documents that phrase explicitly so Codex recognizes it.

```
$ codex
> /vibe-check
Discovering Supabase/Firebase config in this project...
Found SUPABASE_URL and SUPABASE_ANON_KEY via .env auto-load (not read into context).
Found Firebase project ID "my-flutter-app-12345" in lib/firebase_options.dart.
Inferred tables from lib/**/*.dart: profiles, messages, posts.
Running check_supabase_rls.sh and check_firebase_realtime_exposure.sh...
⚠ 'messages' is exposed — your ChatScreen writes sender_id/recipient_id/body here.
  Proposed fix: ALTER TABLE messages ENABLE ROW LEVEL SECURITY; CREATE POLICY ...
Apply this fix now? (y/n)
```

---

## Direct Script Usage (CLI / CI)

Prefer this path for CI pipelines, scripted use, or anywhere outside an AI coding assistant. Both scripts are standalone — no skill, no assistant dependency — and take everything as flags or environment variables.

### `check_supabase_rls.sh` – Supabase RLS Checker

Checks whether tables are protected when accessed with only the public `anon` key.

#### Features
- Auto-loads credentials from `.env` (looks in current and parent directory)
- Supports multiple tables in one run
- Clear color-coded output (green = protected, red = exposed)
- Works with or without `jq`

#### Usage

```bash
# 1. Make executable
chmod +x check_supabase_rls.sh

# 2. Run with .env file (recommended)
./check_supabase_rls.sh --tables "profiles,users,private_messages,posts"

# Or with explicit values
./check_supabase_rls.sh \
  --url https://your-project.supabase.co \
  --key eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... \
  --table profiles
```

#### Expected Output

- **Green** → RLS is working (empty result or 403/401)
- **Red** → Table is exposed — enable RLS + policies immediately

#### Requirements
- `curl` (usually pre-installed)
- `jq` (optional but recommended)

### `check_firebase_realtime_exposure.sh` – Firebase Realtime DB Checker

Quickly tests whether a Firebase Realtime Database (or specific path) is publicly readable.

#### Usage

```bash
chmod +x check_firebase_realtime_exposure.sh

./check_firebase_realtime_exposure.sh your-firebase-project-id
./check_firebase_realtime_exposure.sh your-firebase-project-id /users
./check_firebase_realtime_exposure.sh your-firebase-project-id /private_messages
```

#### Output
- Returns real data → **Exposed** (fix your security rules)
- "Permission denied" or empty → Good

### Recommended Workflow for Flutter Projects

1. Add both scripts to your repo (e.g. in a `scripts/security/` folder)
2. Add your Supabase/Firebase keys to a `.env` file (never commit it)
3. Run the Supabase checker before every internal release / TestFlight build
4. Run the Firebase checker when using Realtime Database
5. Consider adding them to CI (simple GitHub Action)

Example `.env` snippet:
```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## Known Limitations

- **Point-in-time checks only.** These scripts test the current state of your rules/policies at the moment you run them — they don't continuously monitor for drift. Re-run after every deploy or rules change.
- **Supabase checker:**
  - Only audits the tables you explicitly pass with `--table`/`--tables` — it does not enumerate your schema, so tables you forget to list are not checked.
  - Only tests unauthenticated `SELECT` access with the anon key. It does not validate `INSERT`/`UPDATE`/`DELETE` policies, RPC functions, or Storage bucket rules, and does not test behavior for authenticated users.
  - An empty result is treated as "protected," but a table that is genuinely empty (with no RLS enabled) will look identical to a properly protected one — always confirm RLS is enabled via the Supabase dashboard, not just this script's output.
- **Firebase checker:**
  - Only checks Realtime Database rules for a single path per run — it does not recursively scan your whole database tree, and does not check Cloud Firestore, Storage, or Auth rules.
  - A `null`/empty response is treated as "protected," but an unprotected path with no data yet will look the same — verify rules directly in the Firebase Console as well.
- **Not a full security audit.** These are lightweight external "black box" probes using only public keys/IDs. They catch common misconfigurations but are not a substitute for a proper security review of your backend rules and policies.

## Related Resources

- [Supabase Row Level Security Docs](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Firebase Storage Security Rules](https://firebase.google.com/docs/storage/security) (for preventing public bucket leaks)

---

## License

MIT — feel free to use, modify, and share these scripts in your own projects.

---

**Stay safe out there.** Basic configuration hygiene beats headlines every time.
