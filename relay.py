import socket, threading, urllib.request, ssl, os, hashlib, time

BASE = open('tunnel.txt').read().strip().rstrip('/')
WORKER = 'nk' + hashlib.sha256(os.uname().nodename.encode()).hexdigest()[:8]

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE

def up(d):
    try:
        req = urllib.request.Request(BASE + '/relay/up', data=d, method='POST',
            headers={'Content-Type': 'application/octet-stream', 'X-Worker': WORKER})
        urllib.request.urlopen(req, timeout=20, context=CTX).read()
    except Exception as e:
        print('[relay] up fail:', e, flush=True)

def down():
    try:
        req = urllib.request.Request(BASE + '/relay/down', headers={'X-Worker': WORKER})
        with urllib.request.urlopen(req, timeout=35, context=CTX) as r:
            return r.read()
    except Exception:
        return b''

def handle(c):
    stop = [False]
    def poll():
        while not stop[0]:
            d = down()
            if d:
                try:
                    c.sendall(d)
                except Exception:
                    break
            time.sleep(0.05)
        try:
            c.close()
        except Exception:
            pass

    threading.Thread(target=poll, daemon=True).start()
    try:
        while True:
            d = c.recv(65536)
            if not d:
                break
            up(d)
    except Exception:
        pass
    stop[0] = True
    try:
        c.close()
    except Exception:
        pass

print(f'[relay] worker_id={WORKER}', flush=True)
ls = socket.socket()
ls.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
ls.bind(('127.0.0.1', 33111))
ls.listen(50)
print('[relay] listen 127.0.0.1:33111', flush=True)
while True:
    c, _ = ls.accept()
    threading.Thread(target=handle, args=(c,), daemon=True).start()
