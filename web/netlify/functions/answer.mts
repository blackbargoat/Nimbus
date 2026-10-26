import type { Config } from "@netlify/functions";
import { BadRequest, claude, failure, FALLBACK, MODEL, readBody, SHARED_RULES } from "../lib/claude.mts";

const SYSTEM = `${SHARED_RULES}

The teacher just asked the class a question out loud and the student wants help answering it right now. They will glance at your answer for a few seconds, so be fast and short.

Reply in exactly this shape, under 80 words total:
**Say:** one or two natural sentences the student could say out loud, in a normal teen voice, not a textbook voice.
- one supporting point or example
- another point (optional)
**Key idea:** a few words naming the concept.

Base it on what was taught in class when possible. For open-ended or opinion questions, give a clear position with one reason. If the "question" is not really a question to the class (like "right?" or "any questions?"), reply only with: SKIP`;

export default async (req: Request) => {
  try {
    const { title, transcript, question, context } = await readBody(req);
    if (!question) throw new BadRequest("No question heard.");

    const stream = claude().beta.messages.stream({
      model: MODEL,
      max_tokens: 2000,
      ...FALLBACK,
      output_config: { effort: "low" },
      system: SYSTEM,
      messages: [
        {
          role: "user",
          content:
            `Class: ${title}\n` +
            (context ? `What the class is about so far: ${context}\n` : "") +
            `<recent_transcript>\n${transcript.join("\n").slice(-12_000)}\n</recent_transcript>\n\n` +
            `The teacher just asked: "${question}"`,
        },
      ],
    });

    const encoder = new TextEncoder();
    const body = new ReadableStream<Uint8Array>({
      async start(controller) {
        try {
          for await (const event of stream) {
            if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
              controller.enqueue(encoder.encode(event.delta.text));
            }
          }
          const final = await stream.finalMessage();
          if (final.stop_reason === "refusal") controller.enqueue(encoder.encode("SKIP"));
        } catch (error) {
          console.error("answer stream failed", error);
          controller.enqueue(encoder.encode("\n\n(Lost connection to Claude. Try again.)"));
        }
        controller.close();
      },
    });

    return new Response(body, {
      headers: { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" },
    });
  } catch (error) {
    return failure(error);
  }
};

export const config: Config = {
  path: "/api/answer",
  method: "POST",
  rateLimit: { windowLimit: 30, windowSize: 60, aggregateBy: ["ip", "domain"] },
};
