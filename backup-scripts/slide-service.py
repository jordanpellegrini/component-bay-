#!/usr/bin/env python3
"""
ComponentsBay Slide Server - Windows Service
Installe avec: python slide-service.py install
Demarre avec:  python slide-service.py start
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
GENERATOR  = os.path.join(SCRIPT_DIR, "generate-weekly-slide.py")
PORT       = 5001
LOG_DIR    = os.path.join(os.path.expanduser("~"), "Documents", "ComponentsBay_Backups")
LOG_FILE   = os.path.join(LOG_DIR, "slide_server_log.txt")

os.makedirs(LOG_DIR, exist_ok=True)

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
            html = """<!DOCTYPE html>
<html><head><meta charset="UTF-8">
<style>
  body{font-family:Arial,sans-serif;background:#1a1a2e;color:white;
       display:flex;align-items:center;justify-content:center;
       height:100vh;margin:0;text-align:center;}
  .box{padding:30px;background:#16213e;border-radius:12px;min-width:320px;}
  h2{margin:0 0 16px;font-size:18px;}
  .ico{font-size:48px;margin:16px 0;}
  p{color:#94a3b8;font-size:13px;margin:8px 0;}
  button{background:#3b82f6;color:white;border:none;padding:10px 24px;
         border-radius:8px;cursor:pointer;font-size:14px;margin-top:16px;}
</style></head>
<body><div class="box">
  <h2>📊 Components Bay</h2>
  <div class="ico" id="ico">⏳</div>
  <p id="msg">Generation du PowerPoint en cours...</p>
  <p id="sub"></p>
  <button onclick="window.close()">Fermer</button>
</div>
<script>
  fetch('/generate',{method:'POST'})
    .then(r=>r.json())
    .then(()=>{
      document.getElementById('ico').textContent='✅';
      document.getElementById('msg').textContent='Generation lancee!';
      document.getElementById('sub').textContent='Fichier dans APP 5.5 dans ~15 secondes.';
      setTimeout(()=>window.close(),5000);
    })
    .catch(()=>{
      document.getElementById('ico').textContent='❌';
      document.getElementById('msg').textContent='Erreur de generation';
    });
</script></body></html>"""
            self.wfile.write(html.encode('utf-8'))
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
            log("Lancement generateur...")
            r = subprocess.run([sys.executable, GENERATOR],
                               capture_output=True, text=True, timeout=120)
            if r.returncode == 0:
                log("SUCCES generation")
            else:
                log(f"ERREUR: {r.stderr[:200]}")
        except Exception as e:
            log(f"ERREUR: {e}")

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
