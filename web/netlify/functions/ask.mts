import type Anthropic from "@anthropic-ai/sdk";
import type { Config } from "@netlify/functions";
import { BadRequest, claude, failure, FALLBACK, json, MODEL, readBody, SHARED_RULES, transcriptBlocks } from "../lib/claude.mts";

const SYSTEM = `${SHARED_RULES}

The student is asking about this class. Answer using what the teacher said first, then add general knowledge if it helps them understand. Be warm and direct. Keep answers short (under 180 words) unless they ask for more. Use a few bullet points when it makes things easier to read. If they ask what they missed at a certain time, use the [mm:ss] timestamps.`;

export default async (req: Request) => {
  try {
    const { title, transcript, question, history = [] } = await readBody(req);
    if (!question) throw new BadRequest("Ask a question first.");

    // The transcript sits in the first turn so it stays cached across follow-ups.
    const messages: Anthropic.Beta.BetaMessageParam[] = [
      {
        role: "user",
        content: [...transcriptBlocks(title, transcript), { type: "text", text: "That's my class so far. I have some questions." }],
      },
      { role: "assistant", content: "Got it. What do you want to know?" },
    ];
    // History ends with the question the app just added, so drop that copy.
    const earlier = history.at(-1)?.role === "user" ? history.slice(0, -1) : history;
    for (const turn of earlier) {
      const last = messages.at(-1)!;
      if (last.role === turn.role) continue; // keep roles alternating
      messages.push({ role: turn.role, content: turn.text });
    }
    if (messages.at(-1)!.role === "user") messages.pop();
    messages.push({ role: "user", content: question });

    const response = await claude().beta.messages.create({
      model: MODEL,
      max_tokens: 4000,
      ...FALLBACK,
      cache_control: { type: "ephemeral" },
      output_config: { effort: "low" },
      system: SYSTEM,
      messages,
    });

    if (response.stop_reason === "refusal") return json({ answer: "I can't help with that one." });
    const answer = response.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("").trim();
    return json({ answer });
  } catch (error) {
    return failure(error);
  }
};

export const config: Config = {
  path: "/api/ask",
  method: "POST",
  rateLimit: { windowLimit: 30, windowSize: 60, aggregateBy: ["ip", "domain"] },
};
