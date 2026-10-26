import Anthropic from "@anthropic-ai/sdk";

export const MODEL = "claude-opus-5-5";

/** Refusal fallback: if a request is declined, the API retries it on the right model. */
export const FALLBACK: { betas: Anthropic.AnthropicBeta[]; fallbacks: "default" } = {
  betas: ["server-side-fallback-2026-07-01"],
  fallbacks: "default",
};

const MAX_TRANSCRIPT_CHARS = 400_000;

let client: Anthropic | undefined;
export function claude(): Anthropic {
  client ??= new Anthropic({ apiKey: Netlify.env.get("ANTHROPIC_API_KEY") });
  return client;
}

export type Turn = { role: "user" | "assistant"; text: string };

export class BadRequest extends Error {}

/** Reads and checks the JSON body every Nimbus endpoint shares. */
export async function readBody(req: Request): Promise<{
  title: string;
  transcript: string[];
  question?: string;
  history?: Turn[];
  context?: string;
}> {
  if (req.method !== "POST") throw new BadRequest("Use POST.");
  if (!req.headers.get("x-nimbus-client")) throw new BadRequest("Unknown client.");
  let body: any;
  try {
    body = await req.json();
  } catch {
    throw new BadRequest("Body must be JSON.");
  }
  const transcript = Array.isArray(body?.transcript)
    ? body.transcript.filter((c: unknown) => typeof c === "string")
    : [];
  const total = transcript.reduce((n: number, c: string) => n + c.length, 0);
  if (total > MAX_TRANSCRIPT_CHARS) throw new BadRequest("This class is too long to send in one go.");
  return {
    title: typeof body?.title === "string" ? body.title.slice(0, 200) : "Class",
    transcript,
    question: typeof body?.question === "string" ? body.question.slice(0, 4000) : undefined,
    history: Array.isArray(body?.history)
      ? body.history
          .filter((t: any) => (t?.role === "user" || t?.role === "assistant") && typeof t?.text === "string")
          .slice(-12)
          .map((t: any) => ({ role: t.role, text: t.text.slice(0, 8000) }))
      : [],
    context: typeof body?.context === "string" ? body.context.slice(0, 20_000) : undefined,
  };
}

/**
 * The class transcript as content blocks. Chunks arrive in a stable order and
 * earlier chunks never change, so the prompt cache keeps hitting as class goes on.
 */
export function transcriptBlocks(title: string, chunks: string[]): Anthropic.Beta.BetaTextBlockParam[] {
  const head = `Class: ${title}\n<transcript>\n`;
  if (chunks.length === 0) return [{ type: "text", text: head + "(nothing recorded yet)\n</transcript>" }];
  return chunks.map((chunk, i) => ({
    type: "text",
    text: (i === 0 ? head : "") + chunk + (i === chunks.length - 1 ? "\n</transcript>" : ""),
  }));
}

export function json(data: unknown, status = 200): Response {
  return Response.json(data, { status });
}

/** Turns thrown errors into a short message the app can show. */
export function failure(error: unknown): Response {
  if (error instanceof BadRequest) return json({ error: error.message }, 400);
  if (error instanceof Anthropic.RateLimitError) return json({ error: "Nimbus is busy. Try again in a minute." }, 429);
  if (error instanceof Anthropic.AuthenticationError) {
    console.error("Anthropic key missing or invalid");
    return json({ error: "The notes server isn't set up yet (missing API key)." }, 500);
  }
  if (error instanceof Anthropic.APIError) {
    console.error("Claude API error", error.status, error.message);
    return json({ error: "Claude had a problem. Try again." }, 502);
  }
  console.error(error);
  return json({ error: "Something went wrong on the notes server." }, 500);
}

export const SHARED_RULES = `You are Nimbus, a friendly study helper for a high school student. You hear their class through a live speech-to-text transcript, so expect missing punctuation, misheard words, and side chatter. Fix obvious mishearings silently from context. Never invent facts the teacher did not say; when you add general knowledge, keep it accurate and say it is extra. Write in clear, simple language a high school student would use. Never use em dashes.`;
