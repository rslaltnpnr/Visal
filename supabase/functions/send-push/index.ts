// VISAL — push bildirim gönderici (Supabase Edge Function, Deno)
//
// Veritabanındaki private.push_queue tetikleyicisi her yeni kayıt için bu
// fonksiyonu { id } ile çağırır. `take_push` kaydı işlemeye alır ama silmez;
// başarılı FCM gönderiminden sonra `complete_push`, geçici hatada `retry_push`
// çağrılır. Böylece ağ/OAuth/FCM hatalarında bildirim sessizce kaybolmaz.

import { createClient } from "npm:@supabase/supabase-js@2";

const CHANNELS: Record<string, string> = {
  message: "visal_messages",
  love: "visal_messages",
  memory: "visal_moments",
  capsule: "visal_moments",
  question: "visal_moments",
  pairing: "visal_moments",
  event: "visal_reminders",
};

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

interface PushPayload {
  tokens: string[];
  hidden: boolean;
  title: string;
  body: string;
  hiddenBody: string;
  type: string;
  route: string;
  collapseKey: string | null;
}

let cachedToken: { value: string; exp: number } | null = null;

function b64url(data: ArrayBuffer | Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function googleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.exp - 60 > now) return cachedToken.value;
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const jwt = `${header}.${claims}.${b64url(sig)}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth-type:jwt-bearer".replace("type", "grant-type"), assertion: jwt }),
  });
  if (!res.ok) throw new Error(`OAuth token alınamadı: ${res.status} ${await res.text()}`);
  const json = await res.json();
  cachedToken = { value: json.access_token, exp: now + (json.expires_in ?? 3600) };
  return cachedToken.value;
}

async function sendFcm(sa: ServiceAccount, p: PushPayload): Promise<string[]> {
  const access = await googleAccessToken(sa);
  const title = p.hidden ? "VISAL" : p.title;
  const body = p.hidden ? p.hiddenBody : p.body;
  const invalid: string[] = [];
  const transientErrors: string[] = [];

  await Promise.all(p.tokens.map(async (token) => {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${access}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: { type: p.type, route: p.route },
          android: {
            priority: "HIGH",
            collapse_key: p.collapseKey ?? undefined,
            notification: {
              channel_id: CHANNELS[p.type] ?? "visal_moments",
              color: "#B68AA0",
              tag: p.collapseKey ?? undefined,
            },
          },
          apns: { payload: { aps: { sound: "default", "thread-id": p.collapseKey ?? p.type } } },
        },
      }),
    });

    if (!res.ok) {
      const text = await res.text();
      if (res.status === 404 || text.includes("UNREGISTERED") || text.includes("INVALID_ARGUMENT")) {
        invalid.push(token);
      } else {
        transientErrors.push(`${res.status}: ${text.slice(0, 300)}`);
      }
    }
  }));

  if (transientErrors.length) {
    throw new Error(`FCM geçici hata: ${transientErrors.join(" | ")}`);
  }
  return invalid;
}

Deno.serve(async (req) => {
  const secret = Deno.env.get("PUSH_SECRET");
  if (!secret || req.headers.get("x-visal-secret") !== secret) {
    return new Response("unauthorized", { status: 401 });
  }

  let id: number | null = null;
  try {
    const body = await req.json();
    id = Number(body.id);
    if (!Number.isSafeInteger(id) || id <= 0) return new Response("bad id", { status: 400 });
  } catch (_) {
    return new Response("bad request", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data, error } = await supabase.rpc("take_push", { p_id: id, p_secret: secret });
  if (error) {
    console.error("take_push", error);
    return new Response("error", { status: 500 });
  }
  const payload = data as PushPayload | null;
  if (!payload) return new Response("skipped");

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) {
    await supabase.rpc("retry_push", {
      p_id: id,
      p_secret: secret,
      p_error: "FCM_SERVICE_ACCOUNT eksik",
    });
    return new Response("fcm not configured", { status: 503 });
  }

  try {
    const invalid = await sendFcm(JSON.parse(raw) as ServiceAccount, payload);
    if (invalid.length) {
      const { error: dropError } = await supabase.rpc("drop_device_tokens", {
        p_tokens: invalid,
        p_secret: secret,
      });
      if (dropError) console.error("drop_device_tokens", dropError);
    }

    const { error: completeError } = await supabase.rpc("complete_push", {
      p_id: id,
      p_secret: secret,
    });
    if (completeError) {
      console.error("complete_push", completeError);
      return new Response("ack error", { status: 500 });
    }
  } catch (e) {
    console.error(e);
    const { error: retryError } = await supabase.rpc("retry_push", {
      p_id: id,
      p_secret: secret,
      p_error: String(e),
    });
    if (retryError) console.error("retry_push", retryError);
    return new Response("fcm error", { status: 502 });
  }

  return new Response("ok");
});
