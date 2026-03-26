# 🚀 Republic AI Testnet Complete Mining Guide
### CPU Validator (VPS) + GPU Worker (Laptop)

**Author:** 0xDarkSeidBull | [republicstats.xyz](https://republicstats.xyz)
**Twitter:** [@cryptobhartiyax](https://x.com/cryptobhartiyax)
**GitHub:** [0xDarkSeidBull](https://github.com/0xDarkSeidBull)

---

## 📋 Overview

```
VPS (Hetzner / DigitalOcean)          Windows Laptop (NVIDIA GPU)
┌──────────────────────────┐          ┌──────────────────────────┐
│  republicd node (synced) │          │  WSL2 + Ubuntu           │
│  vps_worker_multi.sh     │◀─SSH────▶│  gpu_worker_multi.sh     │
│  5 parallel slots        │◀─SCP────▶│  Docker GPU inference    │
│  fix_exec_loop.sh        │          │                          │
└──────────────────────────┘          └──────────────────────────┘
```

---

# PART 1 — CPU Validator Setup (VPS)

## Get a VPS

- **Hetzner (recommended):** [hetzner.com](https://console.hetzner.com/) — CPX21 or higher
- **DigitalOcean (free credits):** [digitalocean.com](https://m.do.co/c/b91c4951c91b)
- **Minimum specs:** 2 CPU, 4GB RAM, 80GB SSD, Ubuntu 24.04

---
## STEP 0 — Clean Previous Installation (Fresh Start)
```bash
sudo systemctl stop republicd 2>/dev/null || true
pkill republicd 2>/dev/null || true
rm -rf $HOME/.republic
sudo rm -f /usr/local/bin/republicd
```


## 📦 STEP 1 — Install Dependencies


```bash
apt update && apt upgrade -y
apt install curl tar wget clang pkg-config libssl-dev jq build-essential bsdmainutils git make ncdu gcc chrony liblz4-tool -y
```

---

## Step 2 — Install Go

```bash
cd $HOME
sudo rm -rf /usr/local/go
VER="1.22.5"
curl -Ls https://go.dev/dl/go$VER.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
go version
# Expected: go version go1.22.5 linux/amd64
```

---


## STEP 3 — Install republicd v0.1.0 (IMPORTANT)
```bash
cd $HOME
wget https://github.com/RepublicAI/networks/releases/download/v0.1.0/republicd-linux-amd64 -O republicd
chmod +x republicd
mv republicd /usr/local/bin/republicd
```
---


##  STEP 4 — Initialize Node


```bash
republicd init my-node --chain-id raitestnet_77701-1
```

---

## STEP 5 — Download Genesis


```bash
curl -L https://raw.githubusercontent.com/RepublicAI/networks/main/testnet/genesis.json -o $HOME/.republic/config/genesis.json
```

---

## STEP 6 — Add Dynamic Working Peers (CRITICAL FIX)


```bash
peers=$(curl -sS https://rpc-t.republic.vinjan-inc.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd "," -)

sed -i "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.republic/config/config.toml
```

---

## ❌ STEP 7 — Disable State Sync (Use Stable P2P Sync)


```bash
sed -i 's/^enable *=.*/enable = false/' $HOME/.republic/config/config.toml
sed -i 's/^seeds *=.*/seeds = ""/' $HOME/.republic/config/config.toml
```

---

## STEP 8 — Start Node (Foreground Test)
```bash
republicd start --chain-id raitestnet_77701-1
```

You should see:

Ensure peers...
Added peer...
Stop after confirming:

CTRL + C


## STEP 9 — Create Systemd Service
```bash
tee /etc/systemd/system/republicd.service > /dev/null <<EOF
[Unit]
Description=Republic Protocol Node
After=network-online.target

[Service]
User=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/republicd start --chain-id raitestnet_77701-1
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
```

## Step 10 - Snapshot

```bash
sudo apt install lz4 -y
curl -L https://snapshot.vinjan-inc.com/republic/latest.tar.lz4 \
  | lz4 -dc - | tar -xf - -C $HOME/.republic
```

---

## Step 11 - Start node

```bash
wget https://github.com/RepublicAI/networks/releases/download/v0.3.0/republicd-linux-amd64 -O republicd
chmod +x republicd
sudo mv republicd /usr/local/bin/republicd
republicd version
# Expected: 0.3.0
sudo systemctl start republicd
sudo journalctl -u republicd -f -o cat
```

---


## Step 12 — Check Sync Status

```bash
republicd status | jq '.sync_info'
# "catching_up": false ✅
```

---

## CASE 1 — New User (Create Wallet + Backup)

```bash
republicd keys add wallet
```

Example output:
```
address: rai1xwuht66fmkmzvqsud8px79qgalmqglst57nt92
name: wallet
type: local
```

## CASE1A Get Validator PubKey
```bash
republicd comet show-validator
```

## CASE1B Create validator.json
```bash
nano validator.json
```

You will see something like this:
```bash
{
  "pubkey": {
    "@type": "/cosmos.crypto.ed25519.PubKey",
    "key": "PASTE_YOUR_PUBKEY_HERE"
  },
  "amount": "1000000000000000000arai",
  "moniker": "your_moniker",
  "identity": "",
  "website": "",
  "security_contact": "",
  "details": "dirtdark",
  "commission-rate": "0.999",
  "commission-max-rate": "1.000",
  "commission-max-change-rate": "0.999",
  "min-self-delegation": "1"
}
```


Note: you need to enter pubkey from ## CASE1A Get Validator PubKey
  `"key": "PASTE_YOUR_PUBKEY_HERE"` and change your_moniker to your desired name


## CASE1C Create Validator TX

```bash
republicd tx staking create-validator validator.json \
  --from xyzguide \
  --chain-id raitestnet_77701-1 \
  --gas auto \
  --gas-adjustment 1.5 \
  --gas-prices 160000000000000arai  \
  --yes
```

Change xyzguide to your wallet name you get from ## CASE 1 — New User (Create Wallet + Backup)


## CASE1D : Verify Validator

```bash
republicd query staking validator \
$(republicd keys show xyzguide --bech val -a)
```

Change xyzguide to your wallet name you get from ## CASE 1 — New User (Create Wallet + Backup)


Expected:
`BOND_STATUS_BONDED
jailed: false`

## CASE1E: Link Validator to Dashboard
```bash
republicd tx bank send \
  xyzguide \
  $(republicd keys show xyzguide -a) \
  1000000000000000arai \
  --chain-id raitestnet_77701-1 \
  --from xyzguide \
  --note "YOUR_REF_CODE" \
  --gas auto \
  --gas-adjustment 1.5 \
  --gas-prices 160000000000000arai  \
  --yes
```

Change xyzguide to your wallet name you get from ## CASE 1 — New User (Create Wallet + Backup)

"YOUR_REF_CODE" from  https://points.republicai.io



You will also receive a **mnemonic phrase** — save it offline (notepad / paper / password manager). Without it you **cannot recover your wallet**.

### Backup Validator Keys

```bash
mkdir ~/republic_backup

cp ~/.republic/config/priv_validator_key.json ~/republic_backup/
cp ~/.republic/data/priv_validator_state.json ~/republic_backup/
cp ~/.republic/config/node_key.json ~/republic_backup/

tar -czvf republic_backup.tar.gz ~/republic_backup
```

> ⚠️ **Download this backup file to your local PC.**

### Save Node Information

```bash
echo "===== REPUBLIC NODE BACKUP =====" && \
echo "" && \
echo "Wallet Address:" && republicd keys show wallet -a && \
echo "" && \
echo "Validator Address:" && republicd keys show wallet --bech val -a && \
echo "" && \
echo "Validator PubKey:" && republicd comet show-validator && \
echo "" && \
echo "Peer ID:" && republicd comet show-node-id --home ~/.republic && \
echo "" && \
echo "Node Moniker:" && grep -i moniker ~/.republic/config/config.toml
```

---

## CASE 2 — Import Existing Validator

```bash
# Import wallet
republicd keys add importuser --recover
# Enter your BIP39 mnemonic when prompted

# Restore validator private key
nano ~/.republic/config/priv_validator_key.json
# CTRL+K to delete all content
# Paste your backup key
# CTRL+Y → ENTER to save

# Set correct permissions
chmod 600 ~/.republic/config/priv_validator_key.json
chmod 600 ~/.republic/data/priv_validator_state.json
chmod 600 ~/.republic/config/node_key.json

# Restart node
sudo systemctl restart republicd
```

> ⚠️ **Never share:** `priv_validator_key.json`, `node_key.json`, mnemonic phrase, or exported private key. These give full control over your validator.

---

---

# PART 2 — GPU Worker Setup (Windows Laptop)

## Prerequisites
- NVIDIA GPU (any)
- Windows 10/11
- Internet connection

---

## Step 1 — Check NVIDIA Driver

Press `Win + R` → type `cmd` → Enter:
```cmd
nvidia-smi
```
- GPU info visible → driver installed ✅
- Nothing shown → download driver from [nvidia.com](https://nvidia.com/drivers)

---

## Step 2 — Install WSL2

Open PowerShell as Administrator:
```powershell
wsl --install
```
Restart when prompted. After restart, an Ubuntu window will open — set your username and password.

---

## Step 3 — Install Docker Desktop

1. Download: [docker.com/products/docker-desktop](https://docker.com/products/docker-desktop) → Windows AMD64
2. Install with default settings
3. Open Docker Desktop
4. Settings → Resources → WSL Integration → **Ubuntu toggle ON**
5. Apply & Restart

---

## Step 4 — Install NVIDIA Container Toolkit in WSL2

Open Ubuntu terminal (search "Ubuntu" in Start menu):

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Test GPU visibility
nvidia-smi
# Should show same output as Windows ✅
```

---

## Step 5 — Install Dependencies

```bash
sudo apt update && sudo apt install -y curl wget jq git screen python3 python3-pip

# Install republicd
wget https://github.com/RepublicAI/networks/releases/download/v0.3.0/republicd-linux-amd64 -O republicd
chmod +x republicd
sudo mv republicd /usr/local/bin/republicd

republicd version
# Expected: 0.3.0
```

---

## Step 6 — Build Docker Image

```bash
# Clone devtools
git clone https://github.com/RepublicAI/devtools.git
cd devtools
pip3 install -e . --break-system-packages

# Go to inference folder
cd containers/llm-inference

# Fix Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir transformers accelerate --timeout 600
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu --timeout 600

COPY inference.py .

ENV MODEL_ID="gpt2"
ENV PROMPT="What is the future of decentralized AI?"
ENV MAX_NEW_TOKENS=256
ENV TEMPERATURE=0.7
ENV TOP_P=0.9

CMD ["python", "inference.py"]
EOF

# Build image (10-15 minutes)
docker build --network=host -t republic-llm-inference:latest .

# Verify
docker images | grep republic
# Expected: republic-llm-inference   latest   xxxx   X minutes ago   XXXMB ✅
```

---

## Step 7 — SSH Key Setup (Laptop → VPS)

```bash
# Generate SSH key
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Show public key — COPY this output
cat ~/.ssh/id_ed25519.pub
```

On your VPS, paste the public key:
```bash
echo "PASTE_YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Test from laptop:
```bash
ssh root@YOUR_VPS_IP
# Should connect WITHOUT password ✅
```

---

## Step 8 — Download & Configure GPU Worker

```bash
mkdir -p /var/lib/republic/jobs
cd /var/lib/republic/jobs

wget https://raw.githubusercontent.com/0xDarkSeidBull/republic-miner-scripts/main/gpu_worker_multi.sh
chmod +x gpu_worker_multi.sh

# Edit — set your VPS IP
nano gpu_worker_multi.sh
# Change: VPS="YOUR_VPS_IP"  →  e.g. 1.2.3.4
# Save: Ctrl+X → Y → Enter
```

---

## Step 9 — Start GPU Worker

```bash
cd /var/lib/republic/jobs
screen -dmS republic-gpu bash gpu_worker_multi.sh 5

# Verify — enter screen
screen -r republic-gpu
# You should see:
# [GPU1] Got job: 12345
# [GPU1] Uploading result...
# [GPU1] ✅ Done: 12345
# Detach: Ctrl+A then D
```

---

## 🔴 Stop GPU Worker

```bash
# Stop screen session
screen -S republic-gpu -X quit

# Or kill process directly
pkill -f gpu_worker_multi

# Stop all running Docker containers
docker stop $(docker ps -q) 2>/dev/null
```

---

## 📊 Check GPU Logs

```bash
# GPU slot 1 log
tail -f /var/lib/republic/jobs/gpu_slot_1.log

# Enter screen session
screen -r republic-gpu
# Detach: Ctrl+A then D

# Check running Docker containers
docker ps
```

> ⚠️ **Important:** Docker Desktop must be running on Windows at all times for Docker to work inside WSL2.

---

---

# PART 3 — VPS Worker Scripts Setup

> ✅ Complete GPU setup (Part 2) before starting this part.

---

## Step 1 — Start HTTP Server

An HTTP server is required so the GPU worker can upload inference results to the VPS.

```bash
mkdir -p /root/results_backup
screen -dmS republic-upload python3 -m http.server 8080 --directory /root
screen -ls | grep upload
# republic-upload (Detached) should be visible ✅
```

---

## Step 2 — Download & Configure vps_worker_multi.sh

```bash
cd /root
wget https://raw.githubusercontent.com/0xDarkSeidBull/republic-miner-scripts/main/vps_worker_multi.sh
chmod +x vps_worker_multi.sh
nano vps_worker_multi.sh
```

**Change these 2 values:**
```bash
WALLET="YOUR_WALLET_NAME"      # e.g. mywallet
VALOPER="YOUR_VALOPER_ADDRESS" # e.g. raivaloper1xxxx...
```

To find your valoper address:
```bash
republicd keys show YOUR_WALLET_NAME --bech val -a
```

Save: `Ctrl+X → Y → Enter`

---

## Step 3 — Create fix_exec_loop.sh (Bug Fixed Version)

> ⚠️ **The original script had a bug** — a closing quote `"` was missing in the result URL and `YOUR_SERVER_IP` was never replaced, causing the script to crash. The fixed version below uses `localhost` since this script runs on the VPS itself.

```bash
cat > /root/fix_exec_loop.sh << 'EOF'
#!/bin/bash
# ============================================================
# Republic AI Testnet — Fix Exec Loop (FIXED)
# Author: 0xDarkSeidBull
# Fix: closing quote added, localhost used instead of server IP
# ============================================================
WALLET="YOUR_WALLET_NAME"          # ← change this
CHAIN_ID="raitestnet_77701-1"
FEES="200000000000000arai"
VALOPER=$(republicd keys show $WALLET --bech val -a)
LOCKFILE="/tmp/republic_tx.lock"
LOG="/root/worker_logs/fix_exec.log"

mkdir -p /root/worker_logs /root/results_backup

echo "$(date '+%H:%M:%S') Fix Exec Loop Started | Valoper: $VALOPER" | tee -a $LOG

while true; do
  JOBS=$(republicd query computevalidation list-job -o json --limit 120000 2>/dev/null | \
    jq -r '.jobs[] | select(.status == "PendingExecution" and .target_validator == "'$VALOPER'") | .id')

  TOTAL=$(echo "$JOBS" | grep -c '[0-9]' 2>/dev/null || echo 0)
  echo "$(date '+%H:%M:%S') PendingExecution jobs: $TOTAL" | tee -a $LOG

  for JOB_ID in $JOBS; do
    RESULT="/root/result_${JOB_ID}.json"
    BACKUP="/root/results_backup/result_${JOB_ID}.json"

    if [ -f "$RESULT" ]; then
      FILE="$RESULT"
    elif [ -f "$BACKUP" ]; then
      cp "$BACKUP" "$RESULT"
      FILE="$RESULT"
    else
      echo "$(date '+%H:%M:%S') [$JOB_ID] Result file not found, skipping..." | tee -a $LOG
      continue
    fi

    SHA256=$(sha256sum "$FILE" | awk '{print $1}')

    (
      flock -x 200

      republicd tx computevalidation submit-job-result \
        "$JOB_ID" \
        "http://localhost:8080/result_${JOB_ID}.json" \
        "example-verification:latest" \
        "$SHA256" \
        --from "$WALLET" \
        --chain-id "$CHAIN_ID" \
        --fees "$FEES" \
        --generate-only > /tmp/fe_u.json 2>>$LOG

      [ ! -s /tmp/fe_u.json ] && echo "$(date '+%H:%M:%S') [$JOB_ID] generate-only failed" | tee -a $LOG && exit 0

      python3 -c "
import json, sys
try:
    tx = json.load(open('/tmp/fe_u.json'))
    tx['body']['messages'][0]['validator'] = '$VALOPER'
    json.dump(tx, open('/tmp/fe_f.json', 'w'))
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>>$LOG

      [ $? -ne 0 ] && echo "$(date '+%H:%M:%S') [$JOB_ID] Python patch failed" | tee -a $LOG && exit 0

      republicd tx sign /tmp/fe_f.json \
        --from "$WALLET" \
        --chain-id "$CHAIN_ID" \
        --output-document /tmp/fe_s.json 2>>$LOG

      TX=$(republicd tx broadcast /tmp/fe_s.json \
        --node tcp://localhost:26657 -o json 2>>$LOG | jq -r '.txhash')

      echo "$(date '+%H:%M:%S') [$JOB_ID] ✅ Submitted | TX: $TX" | tee -a $LOG
      sleep 7

    ) 200>$LOCKFILE
  done

  echo "$(date '+%H:%M:%S') Cycle complete — sleeping 5 minutes..." | tee -a $LOG
  sleep 300
done
EOF

chmod +x /root/fix_exec_loop.sh
```

Now set your wallet name:
```bash
nano /root/fix_exec_loop.sh
# Change: WALLET="YOUR_WALLET_NAME"  ← your actual wallet name
# Save: Ctrl+X → Y → Enter
```

---

## Step 4 — Start Everything (Correct Order)

```bash
# 1️⃣ HTTP Server (always start first)
screen -dmS republic-upload python3 -m http.server 8080 --directory /root

# 2️⃣ VPS Worker (5 slots)
screen -dmS republic-worker bash /root/vps_worker_multi.sh 5

# 3️⃣ Fix Exec Loop
screen -dmS fix-exec bash /root/fix_exec_loop.sh

# ✅ Verify all screens are running
screen -ls
```

Expected output:
```
3 Sockets in /run/screen/S-root:
  republic-upload   (Detached)
  republic-worker   (Detached)
  fix-exec          (Detached)
```

---

## 📊 Check Logs

```bash
# VPS worker slot logs
tail -f /root/worker_logs/slot_1.log

# Fix exec loop log
tail -f /root/worker_logs/fix_exec.log

# Main summary log
tail -f /root/worker_logs/vps_worker.log

# Enter a screen session
screen -r republic-worker
# Detach: Ctrl+A then D

# Count pending jobs on chain
republicd query computevalidation list-job -o json --limit 10000 | \
  jq '[.jobs[] | select(.status == "PendingExecution")] | length'
```

---

## 🔴 Stop Everything

```bash
# Kill all worker processes at once
pkill -f vps_worker_multi
pkill -f fix_exec_loop
pkill -f "http.server"

# Or close screens individually
screen -S republic-worker -X quit
screen -S fix-exec -X quit
screen -S republic-upload -X quit
```

---

---

# PART 4 — Stats & Monitoring

```bash
curl -s https://api.republicstats.xyz/api/leaderboard?limit=20 | \
  jq '.[] | select(.address == "YOUR_RAI_ADDRESS")'
```

Or visit [republicstats.xyz](https://republicstats.xyz)

---

# ❓ Troubleshooting

| Problem | Fix |
|---------|-----|
| SSH connection refused | Run `ufw allow 22` on VPS |
| `docker: command not found` in WSL2 | Restart WSL terminal; make sure Docker Desktop is open |
| `No job_id, retry 10s` | Normal — chain congestion, script auto-retries |
| Result file missing | GPU inference failed — check `docker logs` and `gpu_slot_1.log` |
| `sequence mismatch` error | Normal — `flock` handles this automatically |
| High RAM on VPS | Run `sudo systemctl restart republicd` |
| Node not syncing | Download a fresh snapshot or add more peers |
| Screen not visible in `screen -ls` | Re-run the `screen -dmS` start command |
| HTTP server port 8080 busy | Run `pkill -f "http.server"` then restart it |

---

# 💡 Tips

- **5 slots is optimal** — running more slots does not improve performance
- **Always keep fix_exec_loop.sh running** — it automatically recovers missed or stuck jobs
- **Restart republicd every 3 days** to prevent RAM leak:
  ```bash
  echo "0 4 */3 * * systemctl restart republicd" | crontab -
  ```
- **Keep Docker Desktop running** on Windows at all times for WSL2 Docker to work
- **Results are backed up** automatically in `/root/results_backup/`

---

# 🐛 Bug Fixed in fix_exec_loop.sh

The original script had a broken line:
```bash
# ❌ ORIGINAL (BROKEN) — closing quote missing, placeholder IP never replaced
"http://YOUR_SERVER_IP:8080/result_${JOB_ID}.json \

# ✅ FIXED — closing quote added, localhost used (script runs on VPS)
"http://localhost:8080/result_${JOB_ID}.json" \
```

---

⭐ **Star the repo if this helped!**

**Author:** 0xDarkSeidBull
**Twitter:** [@cryptobhartiyax](https://x.com/cryptobhartiyax)
**Website:** [republicstats.xyz](https://republicstats.xyz)
**GitHub:** [0xDarkSeidBull](https://github.com/0xDarkSeidBull)
