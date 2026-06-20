#!/bin/bash
#
# check_firebase_realtime_exposure.sh
# Quick check if your Firebase Realtime Database is publicly readable
# (common misconfiguration when rules are set to ".read": true)
#
# For Flutter + Firebase developers.
#
# Usage: ./check_firebase_realtime_exposure.sh YOUR-PROJECT-ID [/optional/path]
# Example: ./check_firebase_realtime_exposure.sh my-flutter-app-12345
#          ./check_firebase_realtime_exposure.sh my-flutter-app-12345 /users
#

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <firebase-project-id> [path]"
  echo "Example: $0 my-project-abc123"
  echo "         $0 my-project-abc123 /private_messages"
  exit 1
fi

PROJECT_ID="$1"
PATH_PART="${2:-/.json}"

URL="https://${PROJECT_ID}.firebaseio.com${PATH_PART}"

echo "[*] Checking Firebase Realtime Database exposure..."
echo "    URL: ${URL}"
echo

response=$(curl -sS -w "\nHTTPSTATUS:%{http_code}" \
  --max-time 10 \
  "${URL}?print=pretty" 2>&1 || echo -e "\nHTTPSTATUS:000")

body=$(echo "$response" | sed -e 's/HTTPSTATUS\:.*//g')
status_line=$(echo "$response" | grep -o 'HTTPSTATUS:[0-9]*' || echo "HTTPSTATUS:000")
http_code="${status_line##*:}"

if [[ "$http_code" == "200" ]]; then
  # Check for permission denied string or very small/empty response
  if echo "$body" | grep -qi "permission denied"; then
    echo "[+] GOOD: Permission denied returned. Rules appear to be protecting this path."
  elif [[ "$body" == "null" || "$body" == "{}" || ${#body} -lt 20 ]]; then
    echo "[+] GOOD: Empty or null response. Likely protected or no data at path."
  else
    echo "[!] DANGER: Real data returned without authentication!"
    echo "    Your database (or this path) is publicly readable."
    echo
    echo "Sample output (first 400 chars):"
    echo "$body" | head -c 400
    echo
    echo "Fix: Update your security rules in Firebase Console → Realtime Database → Rules"
    echo "     Set appropriate .read conditions (e.g. auth != null or specific user checks)."
  fi
else
  echo "[-] HTTP ${http_code}"
  echo "$body" | head -c 300
fi

echo
echo "Note: This checks Realtime Database. For Cloud Firestore, use the Rules Simulator"
echo "      in Firebase Console or write integration tests with the Admin SDK."
