import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENROUTER_API_KEY = Deno.env.get("OPENROUTER_API_KEY") ?? "";
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL") ?? "";
const OPENROUTER_FALLBACK_MODEL = Deno.env.get("OPENROUTER_FALLBACK_MODEL") ?? "";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

const SYSTEM_PROMPTS: Record<string, string> = {
  answer: `Tu es un assistant pédagogique expert. Tu aides les étudiants à comprendre leurs cours.
Réponds de façon claire, concise et structurée. Utilise des exemples quand c'est pertinent.
Si tu ne connais pas la réponse, dis-le honnêtement.`,
  summary: `Tu es un assistant qui résume des sessions de cours en direct.
Produis un résumé clair en 3-5 points clés, en français.`,
  exercise: `Tu es un enseignant qui crée des exercices QCM.
Génère un exercice avec : la question, 4 options (A-D), la réponse correcte, et une explication courte.
Format ton output de façon lisible.`,
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, content-type, x-client-info, apikey",
      },
    });
  }

  try {
    const { prompt, session_id, context, mode } = await req.json();

    if (!prompt) {
      return new Response(JSON.stringify({ error: "prompt required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const systemPrompt = SYSTEM_PROMPTS[mode] || SYSTEM_PROMPTS.answer;

    const messages = [
      { role: "system", content: systemPrompt },
    ];

    if (context) {
      messages.push({
        role: "system",
        content: `Contexte de la session${session_id ? ` (${session_id})` : ""}: ${context}`,
      });
    }

    messages.push({ role: "user", content: prompt });

    const modelsToTry = [OPENROUTER_MODEL, OPENROUTER_FALLBACK_MODEL].filter(m => m);
    const errors: string[] = [];

    for (const model of modelsToTry) {
      const response = await fetch(OPENROUTER_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${OPENROUTER_API_KEY}`,
          "HTTP-Referer": "https://academia-app.nexiomgroup.space",
          "X-Title": "Academia AI Assistant",
        },
        body: JSON.stringify({
          model,
          messages,
          max_tokens: 1024,
          temperature: 0.7,
        }),
      });

      if (!response.ok) {
        const errText = await response.text();
        errors.push(`${model} (${response.status}): ${errText.slice(0, 100)}`);
        continue;
      }

      const data = await response.json();
      const content = data?.choices?.[0]?.message?.content ?? '';
      if (content) {
        return new Response(JSON.stringify({ reply: content }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      errors.push(`${model}: empty content`);
    }

    return new Response(JSON.stringify({ error: `All models failed: ${errors.join(' | ')}` }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("Academia AI Assistant error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", details: (error as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
