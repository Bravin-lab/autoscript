#!/usr/bin/env python3
import base64
import hashlib
import hmac
import json
import os
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Optional

from flask import Flask, jsonify, request, send_file


ROOT = Path(__file__).resolve().parent
CONFIG_PATH = ROOT / "config.json"


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: Dict[str, Any]) -> None:
    tmp_path = path.with_suffix(path.suffix + ".tmp")
    with tmp_path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    tmp_path.replace(path)


def utc_today_str() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def b64url_encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")


def b64url_decode(s: str) -> bytes:
    pad = "=" * ((4 - len(s) % 4) % 4)
    return base64.urlsafe_b64decode((s + pad).encode("utf-8"))


def sign_token(payload: Dict[str, Any], secret: str) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    h = b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    p = b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    msg = f"{h}.{p}".encode("utf-8")
    sig = hmac.new(secret.encode("utf-8"), msg, hashlib.sha256).digest()
    return f"{h}.{p}.{b64url_encode(sig)}"


def verify_token(token: str, secret: str) -> Optional[Dict[str, Any]]:
    try:
        h, p, s = token.split(".")
        msg = f"{h}.{p}".encode("utf-8")
        calc = hmac.new(secret.encode("utf-8"), msg, hashlib.sha256).digest()
        if not hmac.compare_digest(calc, b64url_decode(s)):
            return None
        payload = json.loads(b64url_decode(p).decode("utf-8"))
        if int(payload.get("exp", 0)) < int(time.time()):
            return None
        return payload
    except Exception:
        return None


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sign_file_b64(path: Path, private_key_pem: Path) -> str:
    with tempfile.NamedTemporaryFile(prefix="payload-sig-", delete=False) as sig_file:
        sig_path = Path(sig_file.name)
    try:
        subprocess.run(
            [
                "openssl",
                "dgst",
                "-sha256",
                "-sign",
                str(private_key_pem),
                "-out",
                str(sig_path),
                str(path),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return base64.b64encode(sig_path.read_bytes()).decode("utf-8")
    finally:
        try:
            sig_path.unlink(missing_ok=True)
        except Exception:
            pass


def find_license(licenses: Dict[str, Any], key: str) -> Optional[Dict[str, Any]]:
    for item in licenses.get("licenses", []):
        if item.get("license_key") == key:
            return item
    return None


def is_license_active(item: Dict[str, Any]) -> bool:
    if item.get("status") != "active":
        return False
    exp = item.get("expires_at", "")
    if exp and exp != "LIFETIME":
        return utc_today_str() <= exp
    return True


def load_runtime_config() -> Dict[str, Any]:
    if not CONFIG_PATH.exists():
        raise RuntimeError(f"Missing config file: {CONFIG_PATH}")

    cfg = load_json(CONFIG_PATH)
    required = [
        "base_url",
        "token_secret",
        "token_ttl_seconds",
        "payload_file",
        "private_key_pem",
        "licenses_file",
    ]
    for k in required:
        if not cfg.get(k):
            raise RuntimeError(f"Missing required config key: {k}")

    return cfg


cfg = load_runtime_config()
app = Flask(__name__)


@app.get("/healthz")
def healthz():
    return jsonify({"status": "ok"})


@app.post("/v1/bootstrap/authorize")
def authorize():
    body = request.get_json(silent=True) or {}
    license_key = str(body.get("license_key", "")).strip()
    ip = str(body.get("ip", "")).strip()
    hwid = str(body.get("hwid", "")).strip()

    if not license_key or not ip:
        return jsonify({"status": "deny", "message": "license_key and ip are required"}), 400

    licenses_path = Path(cfg["licenses_file"]).expanduser().resolve()
    payload_path = Path(cfg["payload_file"]).expanduser().resolve()
    private_key_path = Path(cfg["private_key_pem"]).expanduser().resolve()

    if not licenses_path.exists():
        return jsonify({"status": "deny", "message": "licenses file not found"}), 500
    if not payload_path.exists():
        return jsonify({"status": "deny", "message": "payload file not found"}), 500
    if not private_key_path.exists():
        return jsonify({"status": "deny", "message": "private key not found"}), 500

    db = load_json(licenses_path)
    lic = find_license(db, license_key)
    if not lic:
        return jsonify({"status": "deny", "message": "license not found"}), 403

    if not is_license_active(lic):
        return jsonify({"status": "deny", "message": "license expired or inactive"}), 403

    allowed_ips = lic.get("allowed_ips", [])
    max_ips = int(lic.get("max_ips", 0) or 0)

    if allowed_ips and ip not in allowed_ips:
        if max_ips > 0 and len(allowed_ips) < max_ips:
            allowed_ips.append(ip)
            lic["allowed_ips"] = allowed_ips
            save_json(licenses_path, db)
        else:
            return jsonify({"status": "deny", "message": "ip not whitelisted"}), 403

    bind_hwid = bool(lic.get("bind_hwid_on_first_use", False))
    bound_hwid = str(lic.get("bound_hwid", "")).strip()
    if bind_hwid:
        if not hwid:
            return jsonify({"status": "deny", "message": "hwid required for this license"}), 403
        if not bound_hwid:
            lic["bound_hwid"] = hwid
            save_json(licenses_path, db)
        elif bound_hwid != hwid:
            return jsonify({"status": "deny", "message": "hwid mismatch"}), 403

    payload_sha256 = sha256_file(payload_path)
    payload_sig_b64 = sign_file_b64(payload_path, private_key_path)

    now = int(time.time())
    exp = now + int(cfg.get("token_ttl_seconds", 300))
    token_payload = {
        "sub": license_key,
        "ip": ip,
        "exp": exp,
        "sha256": payload_sha256,
    }
    token = sign_token(token_payload, str(cfg["token_secret"]))

    base_url = str(cfg["base_url"]).rstrip("/")
    payload_url = f"{base_url}/v1/bootstrap/payload?token={token}"

    return jsonify(
        {
            "status": "ok",
            "message": "authorized",
            "payload_url": payload_url,
            "payload_sha256": payload_sha256,
            "payload_sig_b64": payload_sig_b64,
        }
    )


@app.get("/v1/bootstrap/payload")
def payload():
    token = request.args.get("token", "")
    if not token:
        return jsonify({"status": "deny", "message": "missing token"}), 400

    data = verify_token(token, str(cfg["token_secret"]))
    if not data:
        return jsonify({"status": "deny", "message": "invalid or expired token"}), 403

    # Optional source IP match (recommended when not behind proxy).
    req_ip = request.headers.get("X-Forwarded-For", request.remote_addr or "")
    req_ip = req_ip.split(",")[0].strip()
    token_ip = str(data.get("ip", "")).strip()
    if token_ip and req_ip and token_ip != req_ip:
        return jsonify({"status": "deny", "message": "token ip mismatch"}), 403

    payload_path = Path(cfg["payload_file"]).expanduser().resolve()
    if not payload_path.exists():
        return jsonify({"status": "deny", "message": "payload not found"}), 404

    return send_file(str(payload_path), mimetype="text/x-shellscript", as_attachment=False)


if __name__ == "__main__":
    app.run(host=str(cfg.get("host", "0.0.0.0")), port=int(cfg.get("port", 8080)))
