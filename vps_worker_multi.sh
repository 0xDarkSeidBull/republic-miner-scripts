#!/bin/bash
# ============================================================
# Republic AI Testnet — VPS Multi-Slot Worker
# Author: 0xDarkSeidBull | https://github.com/0xDarkSeidBull
# ============================================================
# CONFIGURATION — PUT YOUR DETAILS HERE
WALLET="YOUR_WALLET_NAME"               # e.g. 0xDarkSeidBull
VALOPER="YOUR_VALOPER_ADDRESS"          # e.g. raivaloper1xxxx
CHAIN_ID="raitestnet_77701-1"
FEES="200000000000000arai"
STAKE="1000000arai"
SLOTS=${1:-5}
LOG="/root/worker_logs/vps_worker.log"
LOCKFILE="/tmp/republic_tx.lock"
# ============================================================

mkdir -p /root/worker_logs

echo "VPS Multi-Slot Worker | Slots: $SLOTS"
echo "Wallet: $WALLET"
echo "Valoper: $VALOPER"

submit_job_locked() {
  local SLOT=$1
  local SLOG=$2
  (
    flock -x 200
    TX=$(republicd tx computevalidation submit-job \
      "$VALOPER" \
      republic-llm-inference:latest \
      "http://localhost:8080/upload" \
      "http://localhost:8080/result" \
      example-verification:latest \
      "$STAKE" \
      --from "$WALLET" \
      --chain-id "$CHAIN_ID" \
      --fees "$FEES" \
      -y -o json 2>>$SLOG | jq -r '.txhash')
    echo "$TX"
    sleep 6
  ) 200>$LOCKFILE
}

submit_result_locked() {
  local UNSIGNED=$1
  local SIGNED=$2
  local SLOG=$3
  (
    flock -x 200
    republicd tx sign "$UNSIGNED" \
      --from "$WALLET" \
      --chain-id "$CHAIN_ID" \
      --output-document "$SIGNED" 2>>$SLOG
    sleep 6
  ) 200>$LOCKFILE
}

slot_worker() {
  local SLOT=$1
  local JOBFILE="/root/job_${SLOT}.txt"
  local UNSIGNED="/tmp/unsigned_s${SLOT}.json"
  local UNSIGNED_FIXED="/tmp/unsigned_fixed_s${SLOT}.json"
  local SIGNED="/tmp/signed_s${SLOT}.json"
  local SLOG="/root/worker_logs/slot_${SLOT}.log"

  echo "[SLOT${SLOT}] Started" | tee -a $SLOG

  while true; do
    echo "[SLOT${SLOT}] Submitting job..." | tee -a $SLOG

    TX=$(submit_job_locked $SLOT $SLOG)

    if [ -z "$TX" ] || [ "$TX" == "null" ]; then
      echo "[SLOT${SLOT}] TX failed, retry 15s..." | tee -a $SLOG
      sleep 15
      continue
    fi

    echo "[SLOT${SLOT}] TX: $TX" | tee -a $SLOG
    sleep 8

    JOB_ID=$(republicd query tx "$TX" -o json 2>/dev/null \
      | jq -r '.events[]? | select(.type=="job_submitted") | .attributes[]? | select(.key=="job_id") | .value')

    if [ -z "$JOB_ID" ] || [ "$JOB_ID" == "null" ]; then
      echo "[SLOT${SLOT}] No job_id, retry 10s..." | tee -a $SLOG
      sleep 10
      continue
    fi

    echo "[SLOT${SLOT}] Job: $JOB_ID" | tee -a $SLOG
    echo "$JOB_ID" > "$JOBFILE"

    WAITED=0
    while [ ! -f "/root/result_${JOB_ID}.json" ]; do
      echo "[SLOT${SLOT}] Waiting result... (${WAITED}s)" | tee -a $SLOG
      sleep 5
      WAITED=$((WAITED + 5))
      if [ $WAITED -ge 180 ]; then
        echo "[SLOT${SLOT}] Timeout! Skipping $JOB_ID" | tee -a $SLOG
        rm -f "$JOBFILE"
        break
      fi
    done

    [ ! -f "/root/result_${JOB_ID}.json" ] && continue

    echo "[SLOT${SLOT}] Submitting result..." | tee -a $SLOG
    SHA256=$(sha256sum "/root/result_${JOB_ID}.json" | awk '{print $1}')

    republicd tx computevalidation submit-job-result \
      "$JOB_ID" \
      "http://localhost:8080/result_${JOB_ID}.json" \
      example-verification:latest \
      "$SHA256" \
      --from "$WALLET" \
      --chain-id "$CHAIN_ID" \
      --fees "$FEES" \
      --generate-only > "$UNSIGNED" 2>>$SLOG

    python3 - <<EOF
import json, sys
try:
    tx = json.load(open("$UNSIGNED"))
    tx["body"]["messages"][0]["validator"] = "$VALOPER"
    json.dump(tx, open("$UNSIGNED_FIXED","w"))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    [ $? -ne 0 ] && rm -f "$JOBFILE" && continue

    submit_result_locked $UNSIGNED_FIXED $SIGNED $SLOG

    RESULT_TX=$(republicd tx broadcast "$SIGNED" \
      --node tcp://localhost:26657 -o json 2>>$SLOG | jq -r '.txhash')

    echo "[SLOT${SLOT}] ✅ Job: $JOB_ID | TX: $RESULT_TX" | tee -a $SLOG
    rm -f "$JOBFILE" "$UNSIGNED" "$UNSIGNED_FIXED" "$SIGNED"
    sleep 2
  done
}

for i in $(seq 1 $SLOTS); do
  sleep 3
  slot_worker $i &
  echo "Launched Slot $i (PID: $!)"
done

echo "All $SLOTS slots running!"

while true; do
  sleep 30
  RESULTS=$(ls /root/result_*.json 2>/dev/null | wc -l)
  ACTIVE=$(ls /root/job_*.txt 2>/dev/null | wc -l)
  echo "--- $(date '+%H:%M:%S') | Active: $ACTIVE/$SLOTS | Results: $RESULTS ---" | tee -a $LOG
done
