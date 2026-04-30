#!/usr/bin/env python3
"""
ComponentsBay Slide Server - Windows Service
Installe avec: python slideservice.py install
Demarre avec:  python slideservice.py start
"""

import sys
import os
import time
import threading
import http.server
import json
import subprocess
import servicemanager
import win32event
import win32service
import win32serviceutil

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GENERATOR  = os.path.join(SCRIPT_DIR, "generate-slide-v2.js")
PORT       = 5001
LOG_DIR    = r"C:\ComponentsBay_Logs"
LOG_FILE   = os.path.join(LOG_DIR, "slide_server_log.txt")
GENERATOR  = os.path.join(SCRIPT_DIR, "generate-slide-v2.js")

PYTHON_EXE = r"C:\Program Files\Python314\python.exe"
if not os.path.exists(PYTHON_EXE):
    PYTHON_EXE = r"C:\Program Files\Python313\python.exe"
if not os.path.exists(PYTHON_EXE):
    PYTHON_EXE = r"C:\Program Files\Python312\python.exe"

def log(msg):
    line = f"[{__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}"
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(line + "\n")
    except: pass

class SlideHandler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        if self.path == '/status':
            self.respond(200, {'status': 'ok', 'server': 'ComponentsBay Slide Server'})
        elif self.path == '/generate-page':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            # Trigger generation immediately on GET
            log("Generation demandee depuis l app...")
            threading.Thread(target=self.run_gen, daemon=True).start()
            html = b"""<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>
body{font-family:Arial,sans-serif;background:#1a1a2e;color:white;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center;}
.box{padding:30px;background:#16213e;border-radius:12px;min-width:320px;}
h2{margin:0 0 16px;font-size:18px;}p{color:#94a3b8;font-size:13px;margin:8px 0;}
button{background:#3b82f6;color:white;border:none;padding:10px 24px;border-radius:8px;cursor:pointer;font-size:14px;margin-top:16px;}
</style></head><body><div class="box">
<h2>Components Bay</h2>
<p style="font-size:36px;margin:20px 0">OK</p>
<p>Generation en cours...</p>
<p>Fichier dans APP 5.5 dans ~15 secondes.</p>
<button onclick="window.close()">Fermer</button>
</div><script>setTimeout(()=>window.close(),6000);</script></body></html>"""
            self.wfile.write(html)
        else:
            self.respond(404, {'error': 'Not found'})

    def do_POST(self):
        if self.path == '/generate':
            log("Generation demandee depuis l'app")
            self.respond(200, {'status': 'generating'})
            threading.Thread(target=self.run_gen, daemon=True).start()
        else:
            self.respond(404, {'error': 'Not found'})

    def run_gen(self):
        try:
            log(f"Lancement generateur: {GENERATOR}")
            log(f"Python: {PYTHON_EXE}")
            r = subprocess.run(
                ["node", GENERATOR],
                capture_output=True, text=True, timeout=120,
                env={**os.environ, 'PYTHONIOENCODING': 'utf-8'}
            )
            if r.returncode == 0:
                log("SUCCES generation")
            else:
                log(f"ERREUR code={r.returncode}: {r.stderr[:500] if r.stderr else 'no stderr'}")
                log(f"STDOUT: {r.stdout[:200] if r.stdout else 'no stdout'}")
        except subprocess.TimeoutExpired:
            log("TIMEOUT: Generation trop longue")
        except Exception as e:
            import traceback
            log(f"ERREUR: {traceback.format_exc()}")

    def respond(self, code, data):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args): pass


class SlideService(win32serviceutil.ServiceFramework):
    _svc_name_        = "ComponentsBaySlideServer"
    _svc_display_name_= "ComponentsBay Slide Server"
    _svc_description_ = "Serveur local pour generation de slides PowerPoint (port 5001)"

    def __init__(self, args):
        win32serviceutil.ServiceFramework.__init__(self, args)
        self.stop_event = win32event.CreateEvent(None, 0, 0, None)
        self.server = None

    def SvcStop(self):
        self.ReportServiceStatus(win32service.SERVICE_STOP_PENDING)
        if self.server:
            self.server.shutdown()
        win32event.SetEvent(self.stop_event)

    def SvcDoRun(self):
        servicemanager.LogMsg(
            servicemanager.EVENTLOG_INFORMATION_TYPE,
            servicemanager.PYS_SERVICE_STARTED,
            (self._svc_name_, '')
        )
        log("Service demarrage...")
        self.server = http.server.HTTPServer(('localhost', PORT), SlideHandler)
        log(f"Service actif sur port {PORT}")
        self.server.serve_forever()


if __name__ == '__main__':
    if len(sys.argv) == 1:
        servicemanager.Initialize()
        servicemanager.PrepareToHostSingle(SlideService)
        servicemanager.StartServiceCtrlDispatcher()
    else:
        win32serviceutil.HandleCommandLine(SlideService)
