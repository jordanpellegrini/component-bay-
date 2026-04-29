#!/usr/bin/env python3
"""
Components Bay - Local Slide Server
Ecoute sur localhost:5001 et genere le PPTX quand l'app le demande
Lance au demarrage de Windows via la tache planifiee
"""

import http.server
import json
import subprocess
import os
import sys
import threading
from datetime import datetime

PORT = 5001
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GENERATOR  = os.path.join(SCRIPT_DIR, "generate-weekly-slide.py")
LOG_DIR    = os.path.join(os.path.expanduser("~"), "Documents", "ComponentsBay_Backups")
LOG_FILE   = os.path.join(LOG_DIR, "slide_server_log.txt")

os.makedirs(LOG_DIR, exist_ok=True)

def log(msg):
    line = f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}"
    print(line)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(line + "\n")

class SlideHandler(http.server.BaseHTTPRequestHandler):

    def do_OPTIONS(self):
        # CORS preflight
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        if self.path == '/status':
            self.respond(200, {'status': 'ok', 'server': 'ComponentsBay Slide Server'})
        else:
            self.respond(404, {'error': 'Not found'})

    def do_POST(self):
        if self.path == '/generate':
            log("Demande de generation recue depuis l'app...")
            self.respond(200, {'status': 'generating', 'message': 'Generation en cours...'})
            # Run generator in background thread
            threading.Thread(target=self.run_generator, daemon=True).start()
        else:
            self.respond(404, {'error': 'Not found'})

    def run_generator(self):
        try:
            log("Lancement generate-weekly-slide.py...")
            result = subprocess.run(
                [sys.executable, GENERATOR],
                capture_output=True, text=True, timeout=120
            )
            if result.returncode == 0:
                log(f"SUCCES: {result.stdout.strip()}")
            else:
                log(f"ERREUR: {result.stderr.strip()}")
        except subprocess.TimeoutExpired:
            log("TIMEOUT: Generation trop longue (>2min)")
        except Exception as e:
            log(f"ERREUR: {e}")

    def respond(self, code, data):
        body = json.dumps(data).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Content-Length', len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # Silence default HTTP logs

if __name__ == '__main__':
    log(f"ComponentsBay Slide Server demarrage sur port {PORT}...")
    server = http.server.HTTPServer(('localhost', PORT), SlideHandler)
    log(f"Serveur actif sur http://localhost:{PORT}")
    log(f"Generateur: {GENERATOR}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log("Serveur arrete.")
