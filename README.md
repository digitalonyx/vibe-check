# Backend Security Checkers for Flutter

Quick, dependency-light bash scripts to externally verify that your Supabase and Firebase backends are properly secured.

These tools help catch common misconfigurations **before** they become the next headline (see: Moltbook Supabase exposure and Tea app Firebase Storage breach).

## Why This Matters

Many Flutter apps use `supabase_flutter` or Firebase packages. Both platforms are powerful but easy to misconfigure:

- **Supabase**: Missing Row Level Security (RLS) on tables means anyone with the anon key can read/write everything.
- **Firebase Realtime Database**: Rules set to `".read": true` or `".write": true` make data publicly accessible.

These scripts simulate what an external attacker or security researcher sees when using only the public keys.

## Included Scripts

| Script | Purpose | Best For |
|--------|---------|----------|
| `check_supabase_rls.sh` | Verifies RLS is protecting Supabase tables | All Supabase-backed Flutter apps |
| `check_firebase_realtime_exposure.sh` | Checks if Firebase Realtime Database paths are publicly readable | Firebase Realtime Database users |

> **Note**: For Firebase Storage (the issue in the Tea breach), use proper [Storage Security Rules](https://firebase.google.com/docs/storage/security) instead of a runtime checker.

---

## `check_supabase_rls.sh` – Supabase RLS Checker

Checks whether tables are protected when accessed with only the public `anon` key.

### Features
- Auto-loads credentials from `.env` (looks in current and parent directory)
- Supports multiple tables in one run
- Clear color-coded output (green = protected, red = exposed)
- Works with or without `jq`

### Usage

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

### Expected Output

- **Green** → RLS is working (empty result or 403/401)
- **Red** → Table is exposed — enable RLS + policies immediately

### Requirements
- `curl` (usually pre-installed)
- `jq` (optional but recommended)

---

## `check_firebase_realtime_exposure.sh` – Firebase Realtime DB Checker

Quickly tests whether a Firebase Realtime Database (or specific path) is publicly readable.

### Usage

```bash
chmod +x check_firebase_realtime_exposure.sh

./check_firebase_realtime_exposure.sh your-firebase-project-id
./check_firebase_realtime_exposure.sh your-firebase-project-id /users
./check_firebase_realtime_exposure.sh your-firebase-project-id /private_messages
```

### Output
- Returns real data → **Exposed** (fix your security rules)
- "Permission denied" or empty → Good

---

## Recommended Workflow for Flutter Projects

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

## Related Resources

- [Supabase Row Level Security Docs](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Firebase Storage Security Rules](https://firebase.google.com/docs/storage/security) (for preventing public bucket leaks)
- Original article: *The Moltbook and Tea App Incidents* (includes full secure rules examples)

---

## License

MIT — feel free to use, modify, and share these scripts in your own projects.

---

**Stay safe out there.** Basic configuration hygiene beats headlines every time.
