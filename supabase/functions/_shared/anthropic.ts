// Anthropic Messages API helper — turns a spoken/typed story transcript into a
// structured, page-by-page storybook.
//
// We call the REST API directly with fetch (no SDK) to stay dependency-light in
// the Deno edge runtime, matching how _shared/deepgram.ts and _shared/midjourney.ts
// talk to their providers. This is the curl request you had in mind:
//
//   curl https://api.anthropic.com/v1/messages \
//     --header "x-api-key: $ANTHROPIC_API_KEY" \
//     --header "anthropic-version: 2023-06-01" ...
//
// The model is forced to call a single `publish_story` tool, so the response is
// guaranteed to be a validated JSON object (title + cover prompt + ordered pages,
// each with an illustration prompt) rather than free text we'd have to parse.

const ANTHROPIC_ENDPOINT = "https://api.anthropic.com/v1/messages";

// Default to the latest, most capable model. `claude-opus-4-8` produces the best
// page splits + art prompts; swap to `claude-sonnet-4-6` to cut cost/latency.
const MODEL = "claude-opus-4-8";

export class AnthropicError extends Error {
  status?: number;
  constructor(message: string, status?: number) {
    super(message);
    this.name = "AnthropicError";
    this.status = status;
  }
}

export interface ComposedPage {
  /** The page's prose — one beat of the story, sized for a single page. */
  text: string;
  /** A Midjourney prompt for this page's illustration (style baked in). */
  illustration_prompt: string;
}

/**
 * Story-wide page styling the model picks to match the mood + art. Mirrors the
 * `story.style` JSONB column (and Flutter's StoryStyle): a curated font family,
 * a body-size multiplier, text + page-background colors, and text alignment.
 */
export interface ComposedStyle {
  /** One of the curated families the editor/reader understands. */
  fontFamily: "Serif" | "Sans" | "Mono";
  /** Body font-size multiplier, ~0.8–2.0 (1.0 = default). */
  fontSizeScale: number;
  /** Text color, '#RRGGBB'. */
  textColor: string;
  /** Solid page background color, '#RRGGBB'. */
  backgroundColor: string;
  textAlign: "left" | "center" | "right" | "justify";
}

export interface ComposedStory {
  title: string;
  /** A Midjourney prompt for the book-cover art. */
  cover_prompt: string;
  /** Story-wide page styling that fits the mood + chosen art style. */
  style: ComposedStyle;
  pages: ComposedPage[];
}

export interface ComposeOptions {
  /** Optional caller-suggested title; the model may refine it. */
  title?: string;
  /** Desired number of pages (the model treats it as a target, 4–16). */
  pageCount?: number;
}

function apiKey(): string {
  const key = Deno.env.get("ANTHROPIC_API_KEY") ?? Deno.env.get("ANTHROPIC_KEY");
  if (!key) {
    throw new AnthropicError(
      "ANTHROPIC_API_KEY is not set. Add it to supabase/functions/.env (local) " +
        "or the deployed function's secrets.",
      500,
    );
  }
  return key;
}

// Tool schema = the shape we force the model to return. tool_choice pins it to
// this tool, so `content` always contains exactly one tool_use block we can read.
const PUBLISH_STORY_TOOL = {
  name: "publish_story",
  description:
    "Publish the finished, page-by-page storybook. Call this exactly once with " +
    "the complete story.",
  input_schema: {
    type: "object",
    properties: {
      title: {
        type: "string",
        description: "A short, evocative title for the storybook.",
      },
      cover_prompt: {
        type: "string",
        description:
          "A vivid Midjourney prompt for the BOOK COVER illustration. Describe " +
          "the hero/setting and end with the shared art-style phrase so the cover " +
          "matches the interior pages.",
      },
      style: {
        type: "object",
        description:
          "Story-wide page styling that fits the story's mood AND the chosen art " +
          "style. Ensure strong text/background contrast for easy reading.",
        properties: {
          fontFamily: {
            type: "string",
            enum: ["Serif", "Sans", "Mono"],
            description:
              "Serif for classic/whimsical tales, Sans for modern/playful, Mono " +
              "for quirky/techy.",
          },
          fontSizeScale: {
            type: "number",
            description:
              "Body text size multiplier from 0.8 to 1.6 (1.0 = default). Larger " +
              "for very young audiences.",
          },
          textColor: {
            type: "string",
            description: "Page text color as a hex string, e.g. '#2A1B05'.",
          },
          backgroundColor: {
            type: "string",
            description:
              "Solid page background color as a hex string, e.g. '#FBF3E0'. Must " +
              "contrast strongly with textColor.",
          },
          textAlign: {
            type: "string",
            enum: ["left", "center", "right", "justify"],
          },
        },
        required: [
          "fontFamily",
          "fontSizeScale",
          "textColor",
          "backgroundColor",
          "textAlign",
        ],
      },
      pages: {
        type: "array",
        description:
          "The story split into ordered pages. Each page is one beat of the story.",
        items: {
          type: "object",
          properties: {
            text: {
              type: "string",
              description:
                "The prose for this page — 1 to 4 short sentences, sized to be read " +
                "aloud on a single page. No page numbers or labels.",
            },
            illustration_prompt: {
              type: "string",
              description:
                "A vivid Midjourney prompt depicting THIS page's scene. Always end " +
                "with the SAME shared art-style phrase used on every page and the " +
                "cover, so the whole book looks consistent.",
            },
          },
          required: ["text", "illustration_prompt"],
        },
      },
    },
    required: ["title", "cover_prompt", "style", "pages"],
  },
} as const;

function systemPrompt(opts: ComposeOptions): string {
  const target = opts.pageCount && opts.pageCount > 0 ? opts.pageCount : null;
  return [
    "You are a master children's-storybook author and art director.",
    "You are given a rough story told out loud (a transcript). Turn it into a",
    "polished, illustrated storybook.",
    "",
    "Requirements:",
    "- Keep the storyteller's characters, plot, and intent. Tighten the prose,",
    "  fix grammar, and give it a warm, read-aloud rhythm.",
    target
      ? `- Split it into about ${target} pages.`
      : "- Split it into 6–12 pages, one story beat per page.",
    "- Each page's text is 1–4 short sentences — light enough for one page.",
    "- Decide on ONE cohesive visual art style for the whole book (e.g.",
    "  'soft watercolor children's book illustration, warm pastel palette').",
    "  End every illustration_prompt AND the cover_prompt with that exact",
    "  style phrase so the art is consistent across the book.",
    "- Illustration prompts should name the concrete scene/characters on that",
    "  page so the picture matches the text.",
    "- Choose page styling (style) that fits the mood and matches the art's",
    "  palette: a font family, a body size, a text color and a page-background",
    "  color. The text and background MUST contrast strongly so it's easy to",
    "  read (e.g. dark text on a light page, or light text on a deep page).",
    "",
    "Call the publish_story tool exactly once with the finished story.",
  ].join("\n");
}

const FONT_FAMILIES = ["Serif", "Sans", "Mono"] as const;
const TEXT_ALIGNS = ["left", "center", "right", "justify"] as const;

/** Normalize a hex color to '#RRGGBB', or null if unparseable. */
function normalizeHex(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const v = value.trim().replace(/^#/, "");
  if (!/^[0-9a-fA-F]{6}$/.test(v)) return null;
  return `#${v.toUpperCase()}`;
}

/**
 * Coerce the model's style into a safe, valid {@link ComposedStyle}. Falls back
 * to a warm, readable default (dark text on cream) for any missing/invalid field
 * so the book is always themed even if the model returns junk.
 */
function normalizeStyle(raw: unknown): ComposedStyle {
  const s = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;

  const fontFamily = FONT_FAMILIES.includes(s.fontFamily as typeof FONT_FAMILIES[number])
    ? (s.fontFamily as ComposedStyle["fontFamily"])
    : "Serif";

  const rawScale = typeof s.fontSizeScale === "number" ? s.fontSizeScale : 1.0;
  const fontSizeScale = Math.min(2.0, Math.max(0.8, rawScale));

  const textAlign = TEXT_ALIGNS.includes(s.textAlign as typeof TEXT_ALIGNS[number])
    ? (s.textAlign as ComposedStyle["textAlign"])
    : "left";

  const textColor = normalizeHex(s.textColor) ?? "#2A1B05";
  const backgroundColor = normalizeHex(s.backgroundColor) ?? "#FBF3E0";

  return { fontFamily, fontSizeScale, textColor, backgroundColor, textAlign };
}

/**
 * Sends the transcript to Claude and returns the structured storybook.
 * Throws {@link AnthropicError} (carrying an HTTP status) on failure.
 */
export async function composeStoryFromTranscript(
  transcript: string,
  opts: ComposeOptions = {},
): Promise<ComposedStory> {
  const userText = opts.title
    ? `Suggested title: ${opts.title}\n\nStory transcript:\n${transcript}`
    : `Story transcript:\n${transcript}`;

  const res = await fetch(ANTHROPIC_ENDPOINT, {
    method: "POST",
    headers: {
      "x-api-key": apiKey(),
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 16000,
      system: systemPrompt(opts),
      tools: [PUBLISH_STORY_TOOL],
      // Force the model to answer through the tool — guarantees structured JSON.
      tool_choice: { type: "tool", name: "publish_story" },
      messages: [{ role: "user", content: userText }],
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new AnthropicError(`Anthropic request failed: ${body}`, res.status);
  }

  const data = await res.json() as {
    content?: Array<{ type: string; name?: string; input?: unknown }>;
    stop_reason?: string;
  };

  const toolUse = data.content?.find(
    (b) => b.type === "tool_use" && b.name === "publish_story",
  );
  if (!toolUse || typeof toolUse.input !== "object" || toolUse.input === null) {
    throw new AnthropicError(
      `Unexpected Anthropic response (stop_reason=${data.stop_reason}).`,
      502,
    );
  }

  const story = toolUse.input as ComposedStory;
  if (!Array.isArray(story.pages) || story.pages.length === 0) {
    throw new AnthropicError("Anthropic returned a story with no pages.", 502);
  }

  // Defensive: trim and drop empty pages the model may emit.
  story.title = (story.title ?? "Untitled").trim() || "Untitled";
  story.cover_prompt = (story.cover_prompt ?? "").trim();
  story.style = normalizeStyle(story.style);
  story.pages = story.pages
    .map((p) => ({
      text: (p.text ?? "").trim(),
      illustration_prompt: (p.illustration_prompt ?? "").trim(),
    }))
    .filter((p) => p.text.length > 0);

  if (story.pages.length === 0) {
    throw new AnthropicError("Anthropic returned only empty pages.", 502);
  }

  return story;
}
