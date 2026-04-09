function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function b64urlEncode(bytes) {
  let binary = "";
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i += 1) {
    binary += String.fromCharCode(arr[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function b64urlDecodeToUint8Array(s) {
  const base64 = s.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (s.length % 4)) % 4);
  const binary = atob(base64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

async function importHmacKey(secret) {
  const enc = new TextEncoder();
  return crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

async function signToken(payload, secret) {
  const enc = new TextEncoder();
  const header = { alg: "HS256", typ: "JWT" };
  const h = b64urlEncode(enc.encode(JSON.stringify(header)));
  const p = b64urlEncode(enc.encode(JSON.stringify(payload)));
  const msg = `${h}.${p}`;
  const key = await importHmacKey(secret);
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(msg));
  return `${msg}.${b64urlEncode(sig)}`;
}

async function verifyToken(token, secret) {
  try {
    const [h, p, s] = token.split(".");
    if (!h || !p || !s) return null;

    const enc = new TextEncoder();
    const key = await importHmacKey(secret);
    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      b64urlDecodeToUint8Array(s),
      enc.encode(`${h}.${p}`),
    );

    if (!valid) return null;

    const payloadJson = new TextDecoder().decode(b64urlDecodeToUint8Array(p));
    const payload = JSON.parse(payloadJson);

    if (!payload.exp || Number(payload.exp) < Math.floor(Date.now() / 1000)) {
      return null;
    }

    return payload;
  } catch {
    return null;
  }
}

function todayUtcYmd() {
  return new Date().toISOString().slice(0, 10);
}

function getClientIp(req) {
  const cf = req.headers.get("CF-Connecting-IP");
  if (cf) return cf.trim();
  const xff = req.headers.get("X-Forwarded-For");
  if (xff) return xff.split(",")[0].trim();
  return "";
}

function isLicenseActive(lic) {
  if (String(lic.status || "") !== "active") return false;
  const exp = String(lic.expires_at || "").trim();
  if (!exp || exp === "LIFETIME") return true;
  return todayUtcYmd() <= exp;
}

function validateAuthorizeInput(body) {
  const licenseKey = String(body.license_key || "").trim();
  const ip = String(body.ip || "").trim();
  const hwid = String(body.hwid || "").trim();

  if (!licenseKey || !ip) {
    return { error: "license_key and ip are required" };
  }

  return { licenseKey, ip, hwid };
}

async function handleAuthorize(req, env) {
  let body;
  try {
    body = await req.json();
  } catch {
    return json({ status: "deny", message: "invalid json body" }, 400);
  }

  const parsed = validateAuthorizeInput(body);
  if (parsed.error) return json({ status: "deny", message: parsed.error }, 400);

  const { licenseKey, ip, hwid } = parsed;
  const kvKey = `license:${licenseKey}`;
  const raw = await env.LICENSES.get(kvKey);
  if (!raw) return json({ status: "deny", message: "license not found" }, 403);

  let lic;
  try {
    lic = JSON.parse(raw);
  } catch {
    return json({ status: "deny", message: "invalid license record" }, 500);
  }

  if (!isLicenseActive(lic)) {
    return json({ status: "deny", message: "license expired or inactive" }, 403);
  }

  let dirty = false;
  const allowedIps = Array.isArray(lic.allowed_ips) ? lic.allowed_ips : [];
  const maxIps = Number(lic.max_ips || 0);

  if (allowedIps.length > 0 && !allowedIps.includes(ip)) {
    if (maxIps > 0 && allowedIps.length < maxIps) {
      allowedIps.push(ip);
      lic.allowed_ips = allowedIps;
      dirty = true;
    } else {
      return json({ status: "deny", message: "ip not whitelisted" }, 403);
    }
  }

  const bindHwid = Boolean(lic.bind_hwid_on_first_use);
  const boundHwid = String(lic.bound_hwid || "").trim();
  if (bindHwid) {
    if (!hwid) return json({ status: "deny", message: "hwid required" }, 403);
    if (!boundHwid) {
      lic.bound_hwid = hwid;
      dirty = true;
    } else if (boundHwid !== hwid) {
      return json({ status: "deny", message: "hwid mismatch" }, 403);
    }
  }

  if (dirty) {
    await env.LICENSES.put(kvKey, JSON.stringify(lic));
  }

  const tokenTtl = Number(env.TOKEN_TTL_SECONDS || "300");
  const payloadSha = String(env.PAYLOAD_SHA256 || "").trim();
  const payloadSig = String(env.PAYLOAD_SIG_B64 || "").trim();
  const secret = String(env.TOKEN_SECRET || "").trim();

  if (!payloadSha || !payloadSig || !secret) {
    return json({ status: "deny", message: "server not configured" }, 500);
  }

  const now = Math.floor(Date.now() / 1000);
  const tokenPayload = {
    sub: licenseKey,
    ip,
    exp: now + tokenTtl,
    sha256: payloadSha,
  };

  const token = await signToken(tokenPayload, secret);
  const baseUrl = String(env.BASE_URL || "").trim() || new URL(req.url).origin;
  const payloadUrl = `${baseUrl.replace(/\/$/, "")}/v1/bootstrap/payload?token=${encodeURIComponent(token)}`;

  return json({
    status: "ok",
    message: "authorized",
    payload_url: payloadUrl,
    payload_sha256: payloadSha,
    payload_sig_b64: payloadSig,
  });
}

async function handlePayload(req, env) {
  const url = new URL(req.url);
  const token = url.searchParams.get("token") || "";
  if (!token) return json({ status: "deny", message: "missing token" }, 400);

  const secret = String(env.TOKEN_SECRET || "").trim();
  if (!secret) return json({ status: "deny", message: "server not configured" }, 500);

  const data = await verifyToken(token, secret);
  if (!data) return json({ status: "deny", message: "invalid or expired token" }, 403);

  const reqIp = getClientIp(req);
  if (String(data.ip || "") && reqIp && String(data.ip) !== reqIp) {
    return json({ status: "deny", message: "token ip mismatch" }, 403);
  }

  const key = String(env.PAYLOAD_OBJECT_KEY || "payload.sh");
  const obj = await env.PAYLOAD_BUCKET.get(key);
  if (!obj) return json({ status: "deny", message: "payload not found" }, 404);

  return new Response(await obj.arrayBuffer(), {
    status: 200,
    headers: {
      "content-type": "text/x-shellscript; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);

    if (req.method === "GET" && url.pathname === "/healthz") {
      return json({ status: "ok" });
    }

    if (req.method === "POST" && url.pathname === "/v1/bootstrap/authorize") {
      return handleAuthorize(req, env);
    }

    if (req.method === "GET" && url.pathname === "/v1/bootstrap/payload") {
      return handlePayload(req, env);
    }

    return json({ status: "deny", message: "not found" }, 404);
  },
};
