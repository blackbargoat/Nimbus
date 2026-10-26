import type { Config } from "@netlify/functions";
import { claude, failure, FALLBACK, json, MODEL, readBody, SHARED_RULES, transcriptBlocks } from "../lib/claude.mts";

const SYSTEM = `${SHARED_RULES}

Turn the class transcript into study notes. Cover everything important the teacher taught, in the order it was taught.
- topic: a short name for what the class was about (under 8 words).
- summary: 2 to 4 sentences on the big picture.
- sections: group the lesson into sections with a clear heading and short bullet points. Each bullet is one idea, usually under 20 words. Include examples, dates, names, formulas, and definitions the teacher gave.
- keyTerms: important vocabulary with a one-sentence meaning.
- plainWords: explain the hardest idea from class like you're talking to a friend who was absent, in 3 to 5 sentences.
- homework: every assignment, due date, test, or reminder the teacher mentioned, with the date if said. Empty if none.
- reviewQuestions: 3 to 5 questions the student could be asked about this on a test.
If the transcript is mostly small talk or too short, keep the notes short and honest about it.`;

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["topic", "summary", "sections", "keyTerms", "plainWords", "homework", "reviewQuestions"],
  properties: {
    topic: { type: "string" },
    summary: { type: "string" },
    sections: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["heading", "bullets"],
        properties: { heading: { type: "string" }, bullets: { type: "array", items: { type: "string" } } },
      },
    },
    keyTerms: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["term", "meaning"],
        properties: { term: { type: "string" }, meaning: { type: "string" } },
      },
    },
    plainWords: { type: "string" },
    homework: { type: "array", items: { type: "string" } },
    reviewQuestions: { type: "array", items: { type: "string" } },
  },
};

export default async (req: Request) => {
  try {
    const { title, transcript } = await readBody(req);
    if (transcript.length === 0) return json({ error: "Nothing has been recorded yet." }, 400);

    const response = await claude().beta.messages.create({
      model: MODEL,
      max_tokens: 16000,
      ...FALLBACK,
      cache_control: { type: "ephemeral" },
      output_config: { effort: "low", format: { type: "json_schema", schema: SCHEMA } },
      system: SYSTEM,
      messages: [
        { role: "user", content: [...transcriptBlocks(title, transcript), { type: "text", text: "Write the notes for this class." }] },
      ],
    });

    if (response.stop_reason === "refusal") return json({ error: "Nimbus couldn't write notes for this class." }, 422);
    if (response.stop_reason === "max_tokens") return json({ error: "The notes got too long. Try again." }, 502);
    const text = response.content.flatMap((b) => (b.type === "text" ? [b.text] : [])).join("");
    return json(JSON.parse(text));
  } catch (error) {
    return failure(error);
  }
};

export const config: Config = {
  path: "/api/notes",
  method: "POST",
  rateLimit: { windowLimit: 20, windowSize: 60, aggregateBy: ["ip", "domain"] },
};
