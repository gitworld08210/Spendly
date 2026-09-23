// Spendly — ai-insights
//
// Turns a compact spending summary into short, natural-language money tips
// using an Azure-hosted LLM. Model-agnostic: works with Azure OpenAI
// (…openai.azure.com) and Azure AI Foundry (…services.ai.azure.com) since both
// expose an OpenAI-compatible /chat/completions API.
//
// The API key never leaves the server. The client sends only aggregated,
// non-identifying figures (category totals) — never raw transactions or SMS.
//
// Secrets:
//   AZURE_AI_ENDPOINT    e.g. https://my-res.openai.azure.com  (no trailing /)
//   AZURE_AI_API_KEY     the key
//   AZURE_AI_DEPLOYMENT  deployment/model name (e.g. gpt-4o-mini, DeepSeek-R1)
//   AZURE_AI_API_VERSION optional (default 2024-08-01-preview; Azure OpenAI only)

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

interface CategoryTotal {
  category: string;
  thisMonth: number;
  avg3Month: number;
}

interface RequestBody {
  currency?: string;
  income?: number;
  expense?: number;
  categories?: CategoryTotal[];
  subscriptions?: { name: string; amount: number }[];
}

function buildChatUrl(): { url: string; useApiKeyHeader: boolean } {
  const endpoint = (Deno.env.get("AZURE_AI_ENDPOINT") ?? "").replace(/\/+$/, "");
  const deployment = Deno.env.get("AZURE_AI_DEPLOYMENT") ?? "";
  const apiVersion =
    Deno.env.get("AZURE_AI_API_VERSION") ?? "2024-08-01-preview";

  if (endpoint.includes("openai.azure.com")) {
    // Azure OpenAI style.
    return {
      url:
        `${endpoint}/openai/deployments/${deployment}/chat/completions?api-version=${apiVersion}`,
      useApiKeyHeader: true, // uses "api-key" header
    };
  }
  // Azure AI Foundry / OpenAI-compatible style.
  return {
    url: `${endpoint}/chat/completions`,
    useApiKeyHeader: false, // uses "Authorization: Bearer"
  };
}

function systemPrompt(currency: string): string {
  return [
    "You are Spendly's friendly money coach for Indian users.",
    `All amounts are in ${currency}.`,
    "Given a monthly spending summary, return 3-5 short, specific, actionable",
    "tips to save money. Be encouraging, concrete, and reference the actual",
    "categories/numbers. Avoid generic advice. Keep each tip to one sentence.",
    "Return STRICT JSON: {\"tips\":[{\"title\":string,\"detail\":string,",
    "\"category\":string|null,\"potentialSaving\":number}]}. No prose outside JSON.",
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
    const body = (await req.json().catch(() => ({}))) as RequestBody;
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

    const payload = {
      model: deployment,
      messages: [
        { role: "system", content: systemPrompt(currency) },
        { role: "user", content: JSON.stringify(summary) },
      ],
      temperature: 0.4,
      response_format: { type: "json_object" },
    };

    const res = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const detail = await res.text().catch(() => "");
      console.error("AI upstream error:", res.status, detail.slice(0, 300));
      return json({ error: "AI request failed", status: res.status }, 502);
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
