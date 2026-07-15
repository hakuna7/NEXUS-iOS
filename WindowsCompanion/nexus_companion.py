import ctypes
import json
import os
import secrets
import socket
import threading
import tkinter as tk
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from tkinter import ttk

import pyautogui
import pyperclip


HTTP_PORT = 8766
UDP_PORT = 8767
PAIRING_TOKEN = os.environ.get("NEXUS_TOKEN") or f"{secrets.randbelow(1_000_000):06d}"
pyautogui.FAILSAFE = False
status_callback = None


def local_ip():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        sock.close()


def set_status(message):
    if status_callback:
        status_callback(message)


def execute_action(action, value):
    if action == "ping":
        return
    if action == "play_pause":
        pyautogui.press("playpause")
    elif action == "lock":
        ctypes.windll.user32.LockWorkStation()
    elif action == "show_desktop":
        pyautogui.hotkey("win", "d")
    elif action == "clipboard":
        pyperclip.copy(value or "")
    else:
        raise ValueError("Unsupported action")


class ActionHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/action":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            if payload.get("token") != PAIRING_TOKEN:
                self.send_error(403)
                return
            execute_action(payload.get("action", ""), payload.get("value"))
            set_status(f"收到指令：{payload.get('action', '')}")
            body = b'{"ok":true}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except Exception as exc:
            self.send_error(400, str(exc))

    def log_message(self, *_):
        return


def run_http():
    ThreadingHTTPServer(("0.0.0.0", HTTP_PORT), ActionHandler).serve_forever()


def run_motion():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", UDP_PORT))
    while True:
        data, _ = sock.recvfrom(4096)
        try:
            payload = json.loads(data.decode("utf-8"))
            if payload.get("token") != PAIRING_TOKEN:
                continue
            dx = max(-80, min(80, float(payload.get("dx", 0))))
            dy = max(-80, min(80, float(payload.get("dy", 0))))
            pyautogui.moveRel(dx, dy, duration=0)
        except (ValueError, TypeError, json.JSONDecodeError):
            continue


def main():
    global status_callback
    root = tk.Tk()
    root.title("NEXUS Windows Bridge")
    root.geometry("520x390")
    root.resizable(False, False)
    root.configure(bg="#071012")

    style = ttk.Style(root)
    style.theme_use("clam")
    style.configure("TFrame", background="#071012")
    style.configure("Title.TLabel", background="#071012", foreground="#54d6c8", font=("Segoe UI", 14, "bold"))
    style.configure("Body.TLabel", background="#071012", foreground="#ffffff", font=("Segoe UI", 11))
    style.configure("Muted.TLabel", background="#071012", foreground="#91a0a0", font=("Segoe UI", 10))
    style.configure("Code.TLabel", background="#111f20", foreground="#b7f36b", font=("Consolas", 30, "bold"), padding=16)
    style.configure("Accent.TButton", background="#54d6c8", foreground="#071012", font=("Segoe UI", 10, "bold"), padding=10)

    frame = ttk.Frame(root, padding=28)
    frame.pack(fill="both", expand=True)
    ttk.Label(frame, text="NEXUS WINDOWS BRIDGE", style="Title.TLabel").pack(anchor="w")
    ttk.Label(frame, text="让 iPhone 体感控制这台电脑", style="Body.TLabel").pack(anchor="w", pady=(6, 24))

    ttk.Label(frame, text="配对码", style="Muted.TLabel").pack(anchor="w")
    ttk.Label(frame, text=PAIRING_TOKEN, style="Code.TLabel").pack(fill="x", pady=(6, 18))

    ip = local_ip()
    ttk.Label(frame, text=f"电脑地址：{ip}", style="Body.TLabel").pack(anchor="w")
    ttk.Label(frame, text=f"手机中填写地址和上方配对码，然后点击测试连接。", style="Muted.TLabel").pack(anchor="w", pady=(5, 16))

    status_var = tk.StringVar(value="等待手机连接")
    ttk.Label(frame, textvariable=status_var, style="Body.TLabel").pack(anchor="w", pady=(8, 16))

    def update_status(message):
        root.after(0, status_var.set, message)

    def copy_pairing():
        pyperclip.copy(f"{ip}\n{PAIRING_TOKEN}")
        status_var.set("地址和配对码已复制")

    status_callback = update_status
    ttk.Button(frame, text="复制连接信息", style="Accent.TButton", command=copy_pairing).pack(anchor="w")

    threading.Thread(target=run_http, daemon=True).start()
    threading.Thread(target=run_motion, daemon=True).start()
    root.mainloop()


if __name__ == "__main__":
    main()
