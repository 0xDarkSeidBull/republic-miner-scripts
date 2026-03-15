#!/bin/bash
# ============================================================
# Republic AI Testnet — Pending Execution Fixer
# Automatically resubmits missed/stuck jobs
# Author: 0xDarkSeidBull | https://github.com/0xDarkSeidBull
# ============================================================
# CONFIGURATION — PUT YOUR DETAILS HERE
WALLET="YOUR_WALLET_NAME"               # e.g. 0xDarkSeidBull
VALOPER="YOUR_VALOPER_ADDRESS"          # e.g. raivaloper1xxxx
VPS_IP="YOUR_VPS_IP"                    
CHAIN_ID="raitestnet_77701-1"
FEES="200000000000000arai"
CHECK_INTERVAL=600                      # Check every 10 minutes
LOCKFILE="/tmp/republic_tx.lock"
LOG="/root/worker_logs/fix_exec.log"
# ============================================================

mkdir -p /root/worker_logs
echo "$(date '+%H:%M:%S') Pending Execution Fixer Started" | tee -a $LOG

while true; do
  # Fetch all PendingExecution jobs for this validator
  JOBS=$(republicd query computevalidation list-job -o json --limit 120000 2>/dev/null | \
    jq -r '.jobs[] | select(.status == "PendingExecution" and .target_validator == "'$VALOPER'") | .id')

  TOTAL=$(echo "$JOBS" | grep -c '[0-9]' 2>/dev/null || echo 0)
  echo "$(date '+%H:%M:%S') PendingExecution jobs: $TOTAL" | tee -a $LOG

  for JOB_ID in $JOBS; do
    # Check if result file exists
    RESULT="/root/result_${JOB_ID}.json"
    BACKUP="/root/results_backup/result_${JOB_ID}.json"

    if [ -f "$RESULT" ]; then
      FILE="$RESULT"
    elif [ -f "$BACKUP" ]; then
      cp "$BACKUP" "$RESULT"
      FILE="$RESULT"
    else
      echo "[$JOB_ID] No result file — skipping" | tee -a $LOG
      continue
    fi

    SHA256=$(sha256sum "$FILE" | awk '{print $1}')
    UNSIGNED="/tmp/fix_unsigned_${JOB_ID}.json"
    UNSIGNED_FIXED="/tmp/fix_fixed_${JOB_ID}.json"
    SIGNED="/tmp/fix_signed_${JOB_ID}.json"

    echo "[$JOB_ID] Submitting..." | tee -a $LOG

    republicd tx computevalidation submit-job-result \
      "$JOB_ID" \
      "http://${VPS_IP}:8080/result_${JOB_ID}.json" \
      "example-verification:latest" \
      "$SHA256" \
      --from "$WALLET" \
      --chain-id "$CHAIN_ID" \
      --fees "$FEES" \
      --generate-only > "$UNSIGNED" 2>>$LOG

    [ ! -s "$UNSIGNED" ] && echo "[$JOB_ID] Generate failed" | tee -a $LOG && continue

    python3 - <<PYEOF 2>>$LOG
import json, sys
try:
    tx = json.load(open("$UNSIGNED"))
    tx["body"]["messages"][0]["validator"] = "$VALOPER"
    json.dump(tx, open("$UNSIGNED_FIXED","w"))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF

    [ $? -ne 0 ] && continue

    (
      flock -x 200
      republicd tx sign "$UNSIGNED_FIXED" \
        --from "$WALLET" \
        --chain-id "$CHAIN_ID" \
        --output-document "$SIGNED" 2>>$LOG

      TX=$(republicd tx broadcast "$SIGNED" \
        --node tcp://localhost:26657 -o json 2>>$LOG | jq -r '.txhash')

      echo "[$JOB_ID] ✅ TX: $TX" | tee -a $LOG
      sleep 7
    ) 200>$LOCKFILE

    rm -f "$UNSIGNED" "$UNSIGNED_FIXED" "$SIGNED"
  done

  echo "$(date '+%H:%M:%S') Cycle done — sleeping ${CHECK_INTERVAL}s" | tee -a $LOG
  sleep $CHECK_INTERVAL
done
