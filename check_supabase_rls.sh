#!/bin/bash
#
# check_supabase_rls.sh
# Quick external verification that Row Level Security (RLS) is protecting
# your Supabase tables when using the public anon key.
#
# Designed for Flutter developers using supabase_flutter.
# Run this from your project root before shipping.
#
# Usage examples:
#   ./check_supabase_rls.sh --url https://your-project.supabase.co --key eyJhbGci... --table profiles
#   SUPABASE_URL=... SUPABASE_ANON_KEY=... ./check_supabase_rls.sh --tables "profiles,users,messages"
#
# If exposed: you will see real data returned. Fix immediately with RLS + policies.
#
# Requires: curl (always), jq (optional but recommended for clean output)
#

set -euo pipefail

# Colors for better readability in terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
  cat << EOF
Usage: $0 [options]

Options:
  -u, --url URL          Supabase project URL (https://xxx.supabase.co)
  -k, --key KEY          Supabase anon / publishable key
  -t, --table NAME       Table to check (can be repeated)
      --tables "t1,t2"   Comma-separated list of tables
  -h, --help             Show this help

Environment variables (used if flags not provided):
  SUPABASE_URL
  SUPABASE_ANON_KEY

Examples:
  $0 --url https://abc.supabase.co --key eyJ... --table profiles
  SUPABASE_URL=... SUPABASE_ANON_KEY=... $0 --tables "users,posts,private_messages"
EOF
}

URL="${SUPABASE_URL:-}"
KEY="${SUPABASE_ANON_KEY:-}"
TABLES=()

# Optional: auto-load .env if present (common in Flutter projects)
if [[ -z "$URL" || -z "$KEY" ]] && [[ -f ".env" ]]; then
  echo -e "${YELLOW}[i] Loading credentials from .env file...${NC}"
  # Simple parser for KEY=VALUE lines, ignoring comments
  while IFS='=' read -r var value || [[ -n "$var" ]]; do
    var=$(echo "$var" | xargs)
    value=$(echo "$value" | xargs | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    if [[ "$var" == "SUPABASE_URL" && -z "$URL" ]]; then
      URL="$value"
    elif [[ "$var" == "SUPABASE_ANON_KEY" && -z "$KEY" ]]; then
      KEY="$value"
    fi
  done < <(grep -E '^[A-Z_]+=' .env || true)
fi

if [[ -z "$URL" || -z "$KEY" ]] && [[ -f "../.env" ]]; then
  echo -e "${YELLOW}[i] Loading credentials from ../.env ...${NC}"
  while IFS='=' read -r var value || [[ -n "$var" ]]; do
    var=$(echo "$var" | xargs)
    value=$(echo "$value" | xargs | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    if [[ "$var" == "SUPABASE_URL" && -z "$URL" ]]; then
      URL="$value"
    elif [[ "$var" == "SUPABASE_ANON_KEY" && -z "$KEY" ]]; then
      KEY="$value"
    fi
  done < <(grep -E '^[A-Z_]+=' ../.env || true)
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--url)
      URL="$2"
      shift 2
      ;;
    -k|--key)
      KEY="$2"
      shift 2
      ;;
    -t|--table)
      TABLES+=("$2")
      shift 2
      ;;
    --tables)
      IFS=',' read -ra extra_tables <<< "$2"
      TABLES+=("${extra_tables[@]}")
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      print_usage
      exit 1
      ;;
  esac
done

# Fallback to env if still empty
if [[ -z "$URL" && -n "${SUPABASE_URL:-}" ]]; then
  URL="$SUPABASE_URL"
fi
if [[ -z "$KEY" && -n "${SUPABASE_ANON_KEY:-}" ]]; then
  KEY="$SUPABASE_ANON_KEY"
fi

if [[ -z "$URL" || -z "$KEY" || ${#TABLES[@]} -eq 0 ]]; then
  echo -e "${RED}Error: Supabase URL, anon key, and at least one table are required.${NC}"
  print_usage
  exit 1
fi

# Clean trailing slash from URL
URL="${URL%/}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Supabase RLS Exposure Check for Flutter Developers        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${YELLOW}Project: ${URL}${NC}"
echo -e "${YELLOW}Tables to audit: ${TABLES[*]}${NC}"
echo

exposed_count=0

for table in "${TABLES[@]}"; do
  endpoint="${URL}/rest/v1/${table}?select=*&limit=1"
  
  echo -e "${YELLOW}[*] Probing table '${table}' with anon key...${NC}"

  # Perform request and capture body + status code
  http_response=$(curl -sS -w "\nHTTPSTATUS:%{http_code}" \
    --max-time 12 \
    -H "apikey: ${KEY}" \
    -H "Authorization: Bearer ${KEY}" \
    -H "User-Agent: Flutter-Security-Audit/1.0 (supabase_flutter best practices)" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$endpoint" 2>&1 || echo -e "\nHTTPSTATUS:000")

  body=$(echo "$http_response" | sed -e 's/HTTPSTATUS\:.*//g')
  status_line=$(echo "$http_response" | grep -o 'HTTPSTATUS:[0-9]*' || echo "HTTPSTATUS:000")
  http_code="${status_line##*:}"

  if [[ "$http_code" == "200" ]]; then
    # Try to parse with jq if available
    if command -v jq >/dev/null 2>&1; then
      row_count=$(echo "$body" | jq 'if type == "array" then length else 0 end' 2>/dev/null || echo "0")
      
      if [[ "$row_count" -gt 0 ]]; then
        echo -e "${RED}[!] DANGER: '${table}' is EXPOSED!${NC}"
        echo -e "    ${RED}→ ${row_count} row(s) readable with only the anon key.${NC}"
        sample=$(echo "$body" | jq -c '.[0]' 2>/dev/null | head -c 150)
        echo -e "    Sample data: ${sample}..."
        echo -e "    ${RED}Fix: ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY;${NC}"
        echo -e "         Then create appropriate CREATE POLICY statements."
        ((exposed_count++))
      else
        echo -e "${GREEN}[+] GOOD: '${table}' returned empty result. RLS is likely active.${NC}"
      fi
    else
      # Fallback without jq - crude but effective
      if echo "$body" | grep -qE '^\s*\[\s*\{'; then
        echo -e "${RED}[!] DANGER: '${table}' returned what looks like real data!${NC}"
        echo -e "    Install 'jq' for better output. Response starts with array of objects."
        ((exposed_count++))
      else
        echo -e "${GREEN}[+] GOOD: '${table}' did not return obvious data rows.${NC}"
      fi
    fi
  elif [[ "$http_code" == "401" || "$http_code" == "403" ]]; then
    echo -e "${GREEN}[+] GOOD: Access denied (HTTP ${http_code}). RLS policies are protecting '${table}'.${NC}"
  elif [[ "$http_code" == "000" ]]; then
    echo -e "${YELLOW}[-] WARNING: Connection failed or timeout for '${table}'. Check URL/key.${NC}"
  else
    echo -e "${YELLOW}[-] WARNING: Unexpected HTTP ${http_code} for '${table}'.${NC}"
    echo "    Body: ${body:0:200}..."
  fi
  echo
done

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
if [[ $exposed_count -gt 0 ]]; then
  echo -e "${RED}RESULT: ${exposed_count} table(s) EXPOSED. Do not ship until fixed!${NC}"
  echo -e "Next steps:"
  echo "  1. Go to Supabase Dashboard → SQL Editor"
  echo "  2. Run: ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;"
  echo "  3. Write policies (example for user-owned data):"
  echo "     CREATE POLICY \"Users can read own data\" ON your_table"
  echo "     FOR SELECT USING (auth.uid() = user_id);"
  echo "  4. Re-run this script to verify."
else
  echo -e "${GREEN}RESULT: All checked tables appear protected by RLS.${NC}"
  echo -e "${YELLOW}Still recommended: Review all tables in your schema and test with real auth users.${NC}"
fi
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo
echo -e "Script by XSP • For Flutter + Supabase developers who ship secure apps."
echo -e "Inspired by the Moltbook incident (Wiz Research, 2026)."
