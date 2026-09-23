// Spendly — ai-insights
//
// Turns a compact spending summary into short, natural-language money tips
// using an Azure-hosted LLM. Supports classic Azure OpenAI and Azure AI
// Foundry v1 endpoints. The API key never leaves the server; the client sends
// only aggregated, non-identifying figures.
//
// Secrets:
//   AZURE_AI_ENDPOINT    e.g.
//     https://<res>.openai.azure.com
//     https://<res>.services.ai.azure.com/api/projects/<proj>/openai/v1/responses
//   AZURE_AI_API_KEY     the key
//   AZURE_AI_DEPLOYMENT  deployment/model name (e.g. gpt-5-mini)
//   AZURE_AI_API_VERSION optional (Azure OpenAI only; default 2024-08-01-preview)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/// Builds the chat/completions URL + auth style from the configured endpoint.
function buildChatUrl(): { url: string; useApiKeyHeader: boolean } {
  let endpoint = (Deno.env.get("AZURE_AI_ENDPOINT") ?? "").trim();
  const deployment = Deno.env.get("AZURE_AI_DEPLOYMENT") ?? "";
  const apiVersion =
    Deno.env.get("AZURE_AI_API_VERSION") ?? "2024-08-01-preview";

  // Classic Azure OpenAI resource.
  if (endpoint.includes("openai.azure.com")) {
    endpoint = endpoint.replace(/\/+$/, "");
    return {
      url:
        `${endpoint}/openai/deployments/${deployment}/chat/completions?api-version=${apiVersion}`,
      useApiKeyHeader: true,
    };
  }

  // Azure AI Foundry v1. The endpoint may be a full path ending in
  // ".../openai/v1/responses" (or "/chat/completions"); normalize to the
  // OpenAI-compatible ".../openai/v1/chat/completions".
  const v1Marker = "/openai/v1";
  const idx = endpoint.indexOf(v1Marker);
  if (idx !== -1) {
    endpoint = endpoint.substring(0, idx + v1Marker.length);
    return { url: `${endpoint}/chat/completions`, useApiKeyHeader: false };
  }

  // Foundry base without the /openai/v1 suffix.
  if (endpoint.includes("services.ai.azure.com")) {
    endpoint = endpoint.replace(/\/+$/, "");
    return {
      url: `${endpoint}/openai/v1/chat/completions`,
      useApiKeyHeader: false,
    };
  }

  // Generic OpenAI-compatible fallback.
  endpoint = endpoint.replace(/\/+$/, "");
  return { url: `${endpoint}/chat/completions`, useApiKeyHeader: false };
}

function systemPrompt(currency: string): string {
  return [
    "You are Spendly's friendly money coach for Indian users.",
    `All amounts are in ${currency}.`,
    "Given a monthly spending summary, return 3-5 short, specific, actionable",
    "tips to save money. Be encouraging, concrete, and reference the actual",
    "categories/numbers. Avoid generic advice. Keep each tip to one sentence.",
    'Return STRICT JSON: {"tips":[{"title":string,"detail":string,' +
    '"category":string|null,"potentialSaving":number}]}. No prose outside JSON.',
  ].join(" ");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const apiKey = Deno.env.get("AZURE_AI_API_KEY");
  const deployment = Deno.env.get("AZURE_AI_DEPLOYMENT");
  const endpoint = Deno.env.get("AZURE_AI_ENDPOINT");
  if (!apiKey || !deployment || !endpoint) {
    return json({ error: "AI not configured", configured: false }, 503);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const currency = body.currency ?? "INR";
    const summary = {
      income: body.income ?? 0,
      expense: body.expense ?? 0,
      categories: body.categories ?? [],
      subscriptions: body.subscriptions ?? [],
    };

    const { url, useApiKeyHeader } = buildChatUrl();
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
    };
    if (useApiKeyHeader) {
      headers["api-key"] = apiKey;
    } else {
      headers["Authorization"] = `Bearer ${apiKey}`;
    }

    // Note: some newer models only allow the default temperature, so we omit it.
    const payload = {
      model: deployment,
      messages: [
        { role: "system", content: systemPrompt(currency) },
        { role: "user", content: JSON.stringify(summary) },
      ],
      response_format: { type: "json_object" },
    };

    const res = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      console.error("AI upstream error:", res.status, url, detail.slice(0, 400));
      return json(
        { error: "AI request failed", status: res.status, url, detail: detail.slice(0, 400) },
        502,
      );
    }

    const data = await res.json();
    const content = data?.choices?.[0]?.message?.content ?? "{}";
    let tips: unknown = [];
    try {
      tips = JSON.parse(content).tips ?? [];
    } catch (_) {
      tips = [];
    }

    return json({ ok: true, tips });
  } catch (err) {
    console.error("ai-insights error:", err);
    return json({ error: "Unexpected error" }, 500);
  }
});
