// Azure Communication Services (ACS) Email sender.
//
// Sends transactional email via the ACS REST API using HMAC-SHA256 request
// signing (the same scheme the Azure SDKs use). We sign manually so the
// function has no heavy SDK dependency.
//
// Required secrets:
//   ACS_CONNECTION_STRING  endpoint=https://<res>.communication.azure.com/;accesskey=<base64key>
//   ACS_SENDER_ADDRESS     a verified sender, e.g. DoNotReply@<domain>
//
// Until real ACS credentials are provided, calls will throw; the calling
// function logs and returns a 500. Set the secrets to go live.

interface SendArgs {
  to: string;
  subject: string;
  plainText: string;
  html?: string;
}

interface AcsConfig {
  endpoint: string; // https://<res>.communication.azure.com
  accessKey: string; // base64
}

function parseConnectionString(cs: string): AcsConfig {
  const parts = Object.fromEntries(
    cs.split(";").map((kv) => {
      const idx = kv.indexOf("=");
      return [kv.slice(0, idx).trim().toLowerCase(), kv.slice(idx + 1).trim()];
    }),
  );
  const endpoint = (parts["endpoint"] ?? "").replace(/\/+$/, "");
  const accessKey = parts["accesskey"] ?? "";
  if (!endpoint || !accessKey) {
    throw new Error("Invalid ACS_CONNECTION_STRING (need endpoint + accesskey).");
  }
  return { endpoint, accessKey };
}

async function sha256Base64(body: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(body),
  );
  return btoa(String.fromCharCode(...new Uint8Array(digest)));
}

async function hmacSha256Base64(keyB64: string, msg: string): Promise<string> {
  const keyBytes = Uint8Array.from(atob(keyB64), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(msg),
  );
  return btoa(String.fromCharCode(...new Uint8Array(sig)));
}

/**
 * Sends an email through Azure Communication Services.
 * Throws on missing config or a non-2xx response.
 */
export async function sendAcsEmail(args: SendArgs): Promise<void> {
  const cs = Deno.env.get("ACS_CONNECTION_STRING");
  const sender = Deno.env.get("ACS_SENDER_ADDRESS");
  if (!cs || !sender) {
    throw new Error(
      "ACS not configured: set ACS_CONNECTION_STRING and ACS_SENDER_ADDRESS.",
    );
  }
  const { endpoint, accessKey } = parseConnectionString(cs);

  const apiVersion = "2023-03-31";
  const pathAndQuery = `/emails:send?api-version=${apiVersion}`;
  const url = `${endpoint}${pathAndQuery}`;
  const host = new URL(endpoint).host;

  const payload = {
    senderAddress: sender,
    content: {
      subject: args.subject,
      plainText: args.plainText,
      html: args.html ?? `<pre>${args.plainText}</pre>`,
    },
    recipients: { to: [{ address: args.to }] },
  };
  const body = JSON.stringify(payload);

  // HMAC request signing per Azure "SharedKey" scheme.
  const dateHeader = new Date().toUTCString();
  const contentHash = await sha256Base64(body);
  const stringToSign =
    `POST\n${pathAndQuery}\n${dateHeader};${host};${contentHash}`;
  const signature = await hmacSha256Base64(accessKey, stringToSign);
  const authorization =
    `HMAC-SHA256 SignedHeaders=x-ms-date;host;x-ms-content-sha256&Signature=${signature}`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-ms-date": dateHeader,
      "x-ms-content-sha256": contentHash,
      "host": host,
      "Authorization": authorization,
    },
    body,
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    throw new Error(`ACS email send failed (${res.status}): ${detail}`);
  }
}
