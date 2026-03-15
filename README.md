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
│  fix_exec.sh (auto-fix)  │          │                          │
└──────────────────────────┘          └──────────────────────────┘
```

---

PART 1 — CPU Validator Setup (VPS)
Get a VPS

-Hetzner (recommended): [hetzner.com](https://console.hetzner.com/)  CPX21 or higher
-DigitalOcean (free credits): [digitalocean.com](https://m.do.co/c/b91c4951c91b)
-Minimum: 2 CPU, 4GB RAM, 80GB SSD, Ubuntu 24.04


# 1. Update Server

```
sudo apt update && sudo apt upgrade -y
```

Install dependencies:

```
sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip -y
```

---

# 2. Install Go

```
cd $HOME

sudo rm -rf /usr/local/go

VER="1.25.5"

curl -Ls https://go.dev/dl/go$VER.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
```

Add Go to PATH:

```
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile
```

Verify installation:

```
go version
```

Expected output:

```
go version go1.25.5 linux/amd64
```

---

# 3. Install republicd Binary

```
cd $HOME

wget https://github.com/RepublicAI/networks/releases/download/v0.1.0/republicd-linux-amd64 -O republicd

chmod +x republicd

sudo mv republicd /usr/local/bin/republicd
```

Verify installation:

```
republicd version
```

---

# 4. Download Genesis File

```
curl -L https://raw.githubusercontent.com/RepublicAI/networks/main/testnet/genesis.json \
-o $HOME/.republic/config/genesis.json
```

---

# 5. Configure Peers

Fetch active peers automatically:

```
peers=$(curl -sS https://rpc-t.republic.vinjan-inc.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd "," -)
```

Add them to config:

```
sed -i "s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.republic/config/config.toml
```

Disable seeds:

```
sed -i 's/^enable *=.*/enable = false/' $HOME/.republic/config/config.toml
sed -i 's/^seeds *=.*/seeds = ""/' $HOME/.republic/config/config.toml
```

---

# 6. Start Node (Initial Run)

```
republicd start --chain-id raitestnet_77701-1
```

You will see logs like:

```
finalized block
executed block
committed state
indexed block events
```

Now stop the node:

```
CTRL + C
```

---

# 7. Install Snapshot Tools

```
sudo apt install lz4 -y
```

---

# 8. Download Latest Snapshot

This step **syncs your node instantly** instead of waiting hours.

```
curl -L https://snapshot.vinjan-inc.com/republic/latest.tar.lz4 \
| lz4 -dc - | tar -xf - -C $HOME/.republic
```

---

# 9. Start Node

```
sudo systemctl restart republicd
```

Check logs:

```
sudo journalctl -u republicd -f -o cat
```

Example:

```
INF finalizing commit of block
height=684344
```

Your node will now reach latest block within minutes.

---

# 10. Check Sync Status

```
republicd status | jq '.sync_info'
```

Example output:

```
"catching_up": false
```

If `false`, node is fully synced.

---

# CASE 1 — New User (Create Wallet + Backup)

Create wallet:

```
republicd keys add wallet
```

Example output:

```
address: rai1xwuht66fmkmzvqsud8px79qgalmqglst57nt92
name: wallet
type: local
```

You will also receive a **mnemonic phrase**.

Example:

```
your_mnemonic
```

### IMPORTANT

Save mnemonic offline:

* Notepad
* Password manager
* Paper backup

Without it you **cannot recover your wallet**.

---

# Create Backup Folder

```
mkdir ~/republic_backup
```

---

# Backup Validator Keys

These are **most important files**.

```
cp ~/.republic/config/priv_validator_key.json ~/republic_backup/

cp ~/.republic/data/priv_validator_state.json ~/republic_backup/

cp ~/.republic/config/node_key.json ~/republic_backup/
```

---

# Export Wallet Private Key

```
republicd keys export wallet
```

Example:

```
-----BEGIN TENDERMINT PRIVATE KEY-----
kdf: argon2
salt: 63EC2C786358D1F2CB2B07A5025F2206
type: eth_secp256k1
...
-----END TENDERMINT PRIVATE KEY-----
```

---

# Compress Backup

```
tar -czvf republic_backup.tar.gz ~/republic_backup
```

Download this file to your local PC.

---

# Save Node Information

Run:

```
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

Example output:

```
Wallet Address:
rai1xwuht66fmkmzvqsud8px79qgalmqglst57nt92

Validator Address:
raivaloper1xwuht66fmkmzvqsud8px79qgalmqglstntnkwu

Peer ID:
7756059d95ac36fc89fac2e928931153cd81f6ba
```

---

# Checking Validator Private Key (Most Important)

```
cat ~/.republic/config/priv_validator_key.json
```

Example:

```
{
 "priv_key": {
  "type": "tendermint/PrivKeyEd25519",
  "value": "9p8adOjGj/nRAVjHbxnzoSjG4g3962zBevIbgHt0/X..."
 }
}
```

⚠️ **This key controls your validator. Never share it.**

---

# CASE 2 — Import Existing Validator

Import wallet:

```
republicd keys add importuser --recover
```

Enter your **BIP39 mnemonic**.

---

# Restore Validator Private Key

Edit file:

```
nano ~/.republic/config/priv_validator_key.json
```

Delete existing content:

```
CTRL + K
```

Paste your **old backup key**.

Save:

```
CTRL + Y
ENTER
```

---

# Set Correct Permissions

```
chmod 600 ~/.republic/config/priv_validator_key.json

chmod 600 ~/.republic/data/priv_validator_state.json

chmod 600 ~/.republic/config/node_key.json
```

---

# Restart Node

```
sudo systemctl restart republicd
```

Check logs:

```
journalctl -u republicd -f
```

---

# Verify Validator

```
republicd query staking validator \
$(republicd keys show wallet --bech val -a)
```

Example output:

```
operator_address: raivaloper1v0tuyrzvcdmw7pqvgce7gd905ge80l09yyewrx

status: BOND_STATUS_UNBONDED
```

Your validator is successfully imported.

---

# IMPORTANT SECURITY RULES

Never share:

* `priv_validator_key.json`
* `node_key.json`
* mnemonic phrase
* exported wallet private key

These give **full control over your validator**.



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
If you see GPU info → driver is installed ✅  
If not → download driver from [nvidia.com](https://nvidia.com/drivers)

---

## Step 2 — Install WSL2

Open PowerShell as Administrator:
```powershell
wsl --install
```
Restart when asked. After restart, Ubuntu window opens — set username + password.

---

## Step 3 — Install Docker Desktop

1. Download: [docker.com/products/docker-desktop](https://docker.com/products/docker-desktop) → Windows AMD64
2. Install with default settings
3. Open Docker Desktop
4. Settings → Resources → WSL Integration → **Ubuntu toggle ON**
5. Apply & Restart

---

## Step 4 — Install NVIDIA Toolkit in WSL2

Open Ubuntu terminal (search "Ubuntu" in Start):

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

# Show public key — COPY this
cat ~/.ssh/id_ed25519.pub
```

**On your VPS — paste the public key:**
```bash
echo "PASTE_YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Test from laptop:**
```bash
ssh root@YOUR_VPS_IP
# Should connect WITHOUT password ✅
```

---

## Step 8 — Download & Configure GPU Worker

```bash
# Create job directory
mkdir -p /var/lib/republic/jobs
cd /var/lib/republic/jobs

# Download script
wget https://raw.githubusercontent.com/0xDarkSeidBull/republic-miner-scripts/main/gpu_worker_multi.sh
chmod +x gpu_worker_multi.sh

# Edit — set your VPS IP
nano gpu_worker_multi.sh
# Change: VPS="YOUR_VPS_IP"  →  e.g. VPSIPADDRESS
# Save: Ctrl+X → Y → Enter
```

---

## Step 9 — Start GPU Worker

```bash
cd /var/lib/republic/jobs
screen -dmS republic-gpu bash gpu_worker_multi.sh 5

# Verify
screen -r republic-gpu
# You should see:
# [GPU1] Got job: 12345
# [GPU1] Uploading result...
# [GPU1] ✅ Done: 12345
# Detach: Ctrl+A then D
```

---

---

# PART 3 — Management

## 🟢 Start

**VPS:**
```bash
screen -dmS republic-upload python3 -m http.server 8080 --directory /root
screen -dmS republic-worker bash /root/vps_worker_multi.sh 5
screen -dmS fix-exec bash /root/fix_exec.sh
```

**Laptop:**
```bash
screen -dmS republic-gpu bash /var/lib/republic/jobs/gpu_worker_multi.sh 5
```

---

## 🔴 Stop

**VPS:**
```bash
pkill -f vps_worker_multi
pkill -f fix_exec
```

**Laptop:**
```bash
pkill -f gpu_worker_multi
docker stop $(docker ps -q) 2>/dev/null
```

---

## ✅ Check Status

**VPS:**
```bash
# Worker logs
tail -f /root/worker_logs/slot_1.log

# Active jobs
ls /root/job_*.txt 2>/dev/null

# Pending jobs on chain
republicd query computevalidation list-job -o json --limit 10000 | \
  jq '[.jobs[] | select(.status == "PendingExecution" and .target_validator == "YOUR_VALOPER")] | length'
```

**Laptop:**
```bash
# GPU logs
tail -f /var/lib/republic/jobs/gpu_slot_1.log

# Docker containers
docker ps
```

---

## 📊 Stats

Visit [republicstats.xyz](https://republicstats.xyz) or:

```bash
curl -s https://api.republicstats.xyz/api/leaderboard?limit=20 | \
  jq '.[] | select(.address == "YOUR_RAI_ADDRESS")'
```

---

## ❓ Troubleshooting

| Problem | Fix |
|---------|-----|
| `SSH connection refused` | `ufw allow 22` on VPS |
| `docker: command not found` | Restart WSL terminal |
| `No job_id, retry 10s` | Normal — chain congestion, auto-retries |
| `Result missing` | GPU inference failed — check `docker logs` |
| `sequence mismatch` | Normal — flock handles automatically |
| High RAM on VPS | `systemctl restart republicd` |
| Node not syncing | Add more peers or use fresh snapshot |

---

## 💡 Tips

- **5 slots** gives best performance
- **fix_exec.sh** recovers missed jobs automatically — always keep it running
- Restart `republicd` every 3 days (prevents RAM leak):
  ```bash
  echo "0 4 */3 * * systemctl restart republicd" | crontab -
  ```
- Keep Docker Desktop running on Windows for WSL Docker to work

---

⭐ **Star the repo if this helped!**

**Author:** 0xDarkSeidBull  
**Twitter:** [@cryptobhartiyax](https://x.com/cryptobhartiyax)  
**Website:** [republicstats.xyz](https://republicstats.xyz)  
**GitHub:** [0xDarkSeidBull](https://github.com/0xDarkSeidBull)
