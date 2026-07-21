import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import JsonLd from "@/components/seo/JsonLd";
import CreativityWaitlistForm from "@/components/waitlist/CreativityWaitlistForm";

export const metadata: Metadata = {
  title: "Features — Write, Structure, Hear It",
  description:
    "Psitta is the complete book-writing studio — draft in a real editor, structure with Blueprints and proven story frameworks, get honest AI insight with Summarize It and Story-Coach, and hear every line read back in a natural voice, all in your language. Free tier, Windows.",
};

const softwareApplicationSchema = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Psitta",
  description:
    "Psitta reads your documents aloud — PDF, DOCX, HTML, TXT, MD, and EPUB — with word-level highlighting synced to the audio, plus a full writing platform (Writing Desk, Blueprints, Story-Coach, analytics) to structure, draft, and finish a book. Built for writers and editors.",
  url: "https://psitta.ai",
  applicationCategory: "ProductivityApplication",
  operatingSystem: "Windows 10, Windows 11",
  offers: [
    {
      "@type": "Offer",
      name: "Psitta Free",
      price: "0",
      priceCurrency: "USD",
      description: "Free tier with 10 documents per month and standard voices",
    },
    {
      "@type": "Offer",
      name: "Writing Nook Pro (monthly)",
      price: "17.99",
      priceCurrency: "USD",
      description:
        "14-day free trial. Full Writing Desk, Blueprints, Story-Coach, premium voices with word-level highlighting, and writing analytics",
    },
    {
      "@type": "Offer",
      name: "Writing Nook Pro (annual)",
      price: "183",
      priceCurrency: "USD",
      description: "Annual Writing Nook Pro — saves ~15% vs monthly",
    },
    {
      "@type": "Offer",
      name: "Creative Nook Pro (monthly)",
      price: "29.99",
      priceCurrency: "USD",
      description:
        "Everything in Writing Nook plus the Creative Studio (coming soon)",
    },
    {
      "@type": "Offer",
      name: "Creative Nook Pro (annual)",
      price: "305",
      priceCurrency: "USD",
      description: "Annual Creative Nook Pro — coming soon",
    },
  ],
  publisher: {
    "@type": "Organization",
    name: "Facti AI LLC",
    url: "https://psitta.ai",
  },
};

type Feature = {
  title: string;
  description: string;
  icon: React.ReactNode;
};

const iconProps = {
  width: 24,
  height: 24,
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.75,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
};

// ── Writing Nook capability groups ──────────────────────────────────────────
// Platform architecture: Writing Nook is the product; everything below —
// including reading and listening — is a capability inside it.

const writingWorkspaceFeatures: Feature[] = [
  {
    title: "Full Writing Desk",
    description:
      "A focused, distraction-free editor for drafting and revising your book — with Psitta reading every line back to you as you write.",
    icon: (
      <svg {...iconProps}>
        <path d="M12 20h9" />
        <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" />
      </svg>
    ),
  },
  {
    title: "Document Library",
    description:
      "Every draft, source, and manuscript in one organized library — import, search, sort, and pick up exactly where you left off.",
    icon: (
      <svg {...iconProps}>
        <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
        <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
      </svg>
    ),
  },
  {
    title: "Unlimited projects",
    description:
      "Organize your work into as many projects as you need — each with its own documents, blueprint, narrative progress, and activity feed.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="3" width="7" height="7" rx="1" />
        <rect x="3" y="14" width="7" height="7" rx="1" />
        <rect x="14" y="14" width="7" height="7" rx="1" />
      </svg>
    ),
  },
];

const storyDevelopmentFeatures: Feature[] = [
  {
    title: "Blueprints",
    description:
      "Structure your book with Blueprints — living outlines that hold your beats, scenes, and intent, and travel with your project from first idea to final draft.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="3" width="18" height="18" rx="2" />
        <path d="M3 9h18" />
        <path d="M9 21V9" />
      </svg>
    ),
  },
  {
    title: "25+ narrative structures",
    description:
      "Proven frameworks — Three-Act, Save the Cat, Seven-Point, Snowflake and more — each with an interactive, step-by-step guide.",
    icon: (
      <svg {...iconProps}>
        <path d="M9 3 4 5v16l5-2 6 2 5-2V3l-5 2-6-2z" />
        <path d="M9 3v16" />
        <path d="M15 5v16" />
      </svg>
    ),
  },
  {
    title: "Scene mapping",
    description:
      "Map scenes onto your outline so every chapter knows where it sits in the story — and drifting scenes become visible at a glance.",
    icon: (
      <svg {...iconProps}>
        <path d="M12 21s-6-4.35-6-9a6 6 0 1 1 12 0c0 4.65-6 9-6 9z" />
        <circle cx="12" cy="11" r="2" />
      </svg>
    ),
  },
  {
    title: "Progress tracking",
    description:
      "Watch your manuscript's progress build automatically as you write toward the finish — beats covered, scenes mapped, words on the page.",
    icon: (
      <svg {...iconProps}>
        <path d="M3 3v18h18" />
        <rect x="7" y="12" width="3" height="6" />
        <rect x="12" y="8" width="3" height="10" />
        <rect x="17" y="5" width="3" height="13" />
      </svg>
    ),
  },
];

const aiIntelligenceFeatures: Feature[] = [
  {
    title: "Story-Coach — live drift nudges",
    description:
      "An always-on coach that flags when a scene drifts from your outline or intent, so you can course-correct in the moment instead of on the rewrite.",
    icon: (
      <svg {...iconProps}>
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        <path d="M12 7v4" />
        <path d="M12 14h.01" />
      </svg>
    ),
  },
  {
    title: "Structure Analyzer",
    description:
      "Analyze your draft against your chosen structure and get concrete, section-by-section feedback on pacing, gaps, and beats.",
    icon: (
      <svg {...iconProps}>
        <circle cx="11" cy="11" r="7" />
        <path d="m21 21-4.3-4.3" />
        <path d="M11 8v6" />
        <path d="M8 11h6" />
      </svg>
    ),
  },
  {
    title: "Writing analytics",
    description:
      "Lifetime words, streaks, sessions and weekly word-trends build automatically as you write in the Desk — so you can see momentum, not guess at it.",
    icon: (
      <svg {...iconProps}>
        <path d="M3 3v18h18" />
        <path d="m7 14 4-4 3 3 5-6" />
      </svg>
    ),
  },
  {
    title: "AI assistance",
    description:
      "Summarize It condenses any document on demand, and focused AI assistance gives honest, concrete feedback on your manuscript — in your language.",
    icon: (
      <svg {...iconProps}>
        <path d="M9 18h6" />
        <path d="M10 21h4" />
        <path d="M12 3a6 6 0 0 0-3.5 10.9c.4.3.5.8.5 1.3v1.8h6v-1.8c0-.5.1-1 .5-1.3A6 6 0 0 0 12 3z" />
      </svg>
    ),
  },
];

// Reading & Revision — the former "Read & Listen" section, now a capability
// group inside Writing Nook (reading is a capability, not a product).
const readingRevisionFeatures: Feature[] = [
  {
    title: "Read aloud — hear every line",
    description:
      "Open any document and press Read / Listen — Psitta narrates it in a natural voice while you follow along, at up to 4× speed.",
    icon: (
      <svg {...iconProps}>
        <path d="M11 5 6 9H3v6h3l5 4z" />
        <path d="M15.5 8.5a5 5 0 0 1 0 7" />
        <path d="M18.5 5.5a9 9 0 0 1 0 13" />
      </svg>
    ),
  },
  {
    title: "PDF, DOCX, HTML, TXT, MD and e-books support",
    description:
      "Upload any PDF, Word (DOCX), HTML page, plain-text (TXT), Markdown (MD), or EPUB e-book. Psitta extracts the text, preserves structure and reading order, and makes every format instantly ready to read, listen to, and edit — all in one place.",
    icon: (
      <svg {...iconProps}>
        <path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z" />
        <path d="M14 3v5h5" />
        <path d="M9 13h6" />
        <path d="M9 17h6" />
      </svg>
    ),
  },
  {
    title: "Premium neural voices",
    description:
      "Choose from natural-sounding voices powered by ElevenLabs and Microsoft Azure Neural TTS. Standard voices are free for everyone — the full premium catalog is included with Writing Nook.",
    icon: (
      <svg {...iconProps}>
        <rect x="9" y="3" width="6" height="12" rx="3" />
        <path d="M5 11a7 7 0 0 0 14 0" />
        <path d="M12 18v3" />
        <path d="M9 21h6" />
      </svg>
    ),
  },
  {
    title: "Sentence-level highlighting",
    description:
      "Every sentence lights up in real time as it's read aloud — pixel-accurate highlighting powered by PDFium character-level bounding boxes. Follow along visually or click any sentence to jump there.",
    icon: (
      <svg {...iconProps}>
        <path d="M4 6h16" />
        <path d="M4 18h10" />
        <rect x="3.25" y="10.5" width="14" height="3" rx="0.75" fill="currentColor" stroke="none" opacity="0.25" />
        <path d="M4 12h14" />
      </svg>
    ),
  },
  {
    title: "Word-level highlighting",
    description:
      "Writing Nook includes word-by-word highlighting synchronized to the audio. See exactly which word is being spoken at any moment — ideal for catching individual word-choice issues.",
    icon: (
      <svg {...iconProps}>
        <rect x="4" y="8" width="3" height="8" rx="0.5" fill="currentColor" stroke="none" />
        <rect x="10.5" y="8" width="3" height="8" rx="0.5" opacity="0.35" fill="currentColor" stroke="none" />
        <rect x="17" y="8" width="3" height="8" rx="0.5" opacity="0.35" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
  {
    title: "Listening improves writing",
    description:
      "Reading silently, your brain auto-corrects. Listening breaks the spell. Hear awkward phrasing, broken rhythm, and unclear passages that your eye skips over — the fix usually follows within seconds.",
    icon: (
      <svg {...iconProps}>
        <path d="M3 12a9 9 0 0 1 18 0" />
        <rect x="3" y="12" width="4" height="7" rx="1.5" />
        <rect x="17" y="12" width="4" height="7" rx="1.5" />
      </svg>
    ),
  },
];

const nativeDesktopFeatures: Feature[] = [
  {
    title: "Native Windows application",
    description:
      "Psitta is a native Windows desktop application — not a browser extension or web app. A clean, distraction-free interface designed for focused writing.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="4" width="18" height="12" rx="1.5" />
        <path d="M8 20h8" />
        <path d="M12 16v4" />
      </svg>
    ),
  },
  {
    title: "Local performance",
    description:
      "Runs on your machine, not in a browser tab — a snappy library, instant navigation, and smooth playback even with long manuscripts.",
    icon: (
      <svg {...iconProps}>
        <path d="M13 2 4.5 13.5H11L10 22l8.5-11.5H12z" />
      </svg>
    ),
  },
  {
    title: "Keyboard shortcuts",
    description:
      "Full keyboard control — play and pause, skip between passages, search your library, and upload documents without leaving the keys.",
    icon: (
      <svg {...iconProps}>
        <rect x="2.5" y="6" width="19" height="12" rx="2" />
        <path d="M7 15h10" />
        <path d="M6.5 10h.01" />
        <path d="M10 10h.01" />
        <path d="M13.5 10h.01" />
        <path d="M17 10h.01" />
      </svg>
    ),
  },
  {
    title: "Offline-friendly workflow",
    description:
      "Cached audio and a local-first interface keep your session smooth when the connection dips — keep reading and revising, and sync when you're back.",
    icon: (
      <svg {...iconProps}>
        <path d="M6.5 19A4.5 4.5 0 0 1 6 10.03 6 6 0 0 1 17.6 8.5 4.75 4.75 0 0 1 17.5 19z" />
        <path d="M9.5 14.5 12 12l2.5 2.5" />
        <path d="M12 12v6" />
      </svg>
    ),
  },
];

// ── Creative Nook (Coming Soon) — unchanged capability set ──────────────────

const creativeFeatures: Feature[] = [
  {
    title: "Creative workspaces",
    description:
      "Organize your writing projects into dedicated workspaces — each with its own documents, voice settings, and revision history.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="4" width="7" height="7" rx="1" />
        <rect x="14" y="4" width="7" height="7" rx="1" />
        <rect x="3" y="14" width="7" height="7" rx="1" />
        <rect x="14" y="14" width="7" height="7" rx="1" />
      </svg>
    ),
  },
  {
    title: "Listen while you write",
    description:
      "Hear your draft as you write. Catch awkward phrasing, broken rhythm, and unclear passages by ear before anyone else does — at any stage of writing.",
    icon: (
      <svg {...iconProps}>
        <path d="M3 12a9 9 0 0 1 18 0" />
        <rect x="3" y="12" width="4" height="7" rx="1.5" />
        <rect x="17" y="12" width="4" height="7" rx="1.5" />
      </svg>
    ),
  },
  {
    title: "Everything in Writing Nook included",
    description:
      "All Writing Nook capabilities — premium voices, word-by-word highlighting, the full Writing Desk, Blueprints, Story-Coach, and analytics — plus the creative workflow tools below. One subscription.",
    icon: (
      <svg {...iconProps}>
        <circle cx="12" cy="12" r="9" />
        <path d="m8 12 3 3 5-6" />
      </svg>
    ),
  },
  {
    title: "Drop in inspiration. Prompt your way to ideas.",
    description:
      "Pull in source material and prompt Psitta to expand sections, generate outlines, or draft new pieces in your voice. Coming soon.",
    icon: (
      <svg {...iconProps}>
        <path d="M9 18h6" />
        <path d="M10 21h4" />
        <path d="M12 3a6 6 0 0 0-3.5 10.9c.4.3.5.8.5 1.3v1.8h6v-1.8c0-.5.1-1 .5-1.3A6 6 0 0 0 12 3z" />
      </svg>
    ),
  },
  {
    title: "Clone Voice reading",
    description:
      "Record a short voice sample and Psitta reads your documents back in your own voice. Built for podcasters, audiobook drafts, and authors who want to hear their own delivery. Coming soon.",
    icon: (
      <svg {...iconProps}>
        <rect x="9" y="3" width="6" height="12" rx="3" />
        <path d="M5 11a7 7 0 0 0 14 0" />
        <path d="M12 18v3" />
        <path d="M9 21h6" />
      </svg>
    ),
  },
];

function FeatureCard({
  feature,
  iconContainerClass,
}: {
  feature: Feature;
  iconContainerClass: string;
}) {
  return (
    <div className="flex gap-4 items-start">
      <div className={iconContainerClass}>{feature.icon}</div>
      <div>
        <h4 className="text-base font-semibold text-ink-primary">
          {feature.title}
        </h4>
        <p className="mt-1 text-sm text-ink-body leading-relaxed">
          {feature.description}
        </p>
      </div>
    </div>
  );
}

export default function Product() {
  const writingIconClass =
    "shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-psitta-50 text-psitta-600";
  const creativeIconClass =
    "shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-gray-100 text-ink-muted";

  return (
    <section className="py-section">
      <JsonLd data={softwareApplicationSchema} />
      <Container className="max-w-4xl">
        <h1 className="text-ink-primary text-center">
          The complete studio{" "}
          <br className="hidden sm:block" />
          for writing your book.
        </h1>
        <p className="lead mt-4 text-center text-ink-muted max-w-2xl mx-auto">
          Draft in a real editor, shape your structure with Blueprints and
          proven story frameworks, get honest AI insight, and hear every line
          read back in a natural human voice — all in your own language. Psitta
          brings your whole writing process into one place, so you actually
          finish.
        </p>

        {/* ── Section 1 — Writing Nook (the product) ─────────────────────── */}
        <div className="mt-16">
          <div className="flex items-center gap-3">
            <h2 className="text-2xl font-bold text-ink-primary">
              Writing Nook
            </h2>
            <span className="rounded-full bg-psitta-600 px-3 py-0.5 text-xs font-semibold text-white">
              Most popular
            </span>
          </div>
          <p className="mt-2 text-ink-body leading-relaxed max-w-xl">
            Everything you need to plan, write, revise and finish your book —
            one application, one workspace, with a 14-day free trial.
          </p>

          {/* Writing Workspace */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 mt-12 items-center">
            <div className="flex justify-center lg:order-2">
              <img
                src="/brand/writing-nook-illustration_blended.png"
                alt="Writing Nook — parrot writing a book with AI writing tools, story analyzer, and writing insights"
                width={480}
                height={320}
                className="w-72 sm:w-80 lg:w-96 h-auto rounded-3xl bg-[#FAFAF7] mix-blend-multiply"
              />
            </div>
            <div className="lg:order-1">
              <h3 className="text-lg font-semibold text-ink-primary">
                Writing Workspace
              </h3>
              <div className="space-y-6 mt-6">
                {writingWorkspaceFeatures.map((feature) => (
                  <FeatureCard
                    key={feature.title}
                    feature={feature}
                    iconContainerClass={writingIconClass}
                  />
                ))}
              </div>
            </div>
          </div>

          {/* Story Development */}
          <div className="mt-14">
            <h3 className="text-lg font-semibold text-ink-primary">
              Story Development
            </h3>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-x-12 gap-y-6 mt-6">
              {storyDevelopmentFeatures.map((feature) => (
                <FeatureCard
                  key={feature.title}
                  feature={feature}
                  iconContainerClass={writingIconClass}
                />
              ))}
            </div>
          </div>

          {/* AI Writing Intelligence */}
          <div className="mt-14">
            <h3 className="text-lg font-semibold text-ink-primary">
              AI Writing Intelligence
            </h3>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-x-12 gap-y-6 mt-6">
              {aiIntelligenceFeatures.map((feature) => (
                <FeatureCard
                  key={feature.title}
                  feature={feature}
                  iconContainerClass={writingIconClass}
                />
              ))}
            </div>
          </div>

          {/* Reading & Revision — formerly the separate "Read & Listen"
              section; these are Writing Nook capabilities, not a product. */}
          <div className="mt-14">
            <h3 className="text-lg font-semibold text-ink-primary">
              Reading &amp; Revision
            </h3>
            <p className="mt-2 text-ink-body leading-relaxed max-w-xl">
              Hear your manuscript with pixel-accurate highlighting and
              premium neural voices — listening is how Psitta turns reading
              into revision.
            </p>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 mt-8 items-start">
              <div className="flex justify-center">
                <img
                  src="/brand/reading-nook-illustration_blended.png"
                  alt="Psitta reading a book aloud with highlighted text and sound waves"
                  width={480}
                  height={480}
                  className="w-72 sm:w-80 lg:w-96 h-auto rounded-3xl bg-[#FAFAF7] mix-blend-multiply"
                />
              </div>
              <div className="space-y-6">
                {readingRevisionFeatures.map((feature) => (
                  <FeatureCard
                    key={feature.title}
                    feature={feature}
                    iconContainerClass={writingIconClass}
                  />
                ))}
              </div>
            </div>
          </div>

          {/* Native Desktop */}
          <div className="mt-14">
            <h3 className="text-lg font-semibold text-ink-primary">
              Native Desktop
            </h3>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-x-12 gap-y-6 mt-6">
              {nativeDesktopFeatures.map((feature) => (
                <FeatureCard
                  key={feature.title}
                  feature={feature}
                  iconContainerClass={writingIconClass}
                />
              ))}
            </div>
          </div>
        </div>

        {/* ── Section 2 — Creative Nook (Coming Soon) ────────────────────── */}
        <div className="mt-20 border-t border-edge-subtle pt-16">
          <div className="flex items-center gap-3">
            <h2 className="text-2xl font-bold text-ink-primary">
              Creative Nook
            </h2>
            <span className="rounded-full bg-ink-muted px-3 py-0.5 text-xs font-semibold text-white">
              Coming soon
            </span>
          </div>
          <p className="mt-2 text-ink-body leading-relaxed max-w-xl">
            Expand beyond writing into a full Creative Studio. Builds on
            everything in Writing Nook — same application, same architecture,
            new capabilities.
          </p>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 mt-12 items-start">
            <div className="space-y-6 order-last lg:order-2">
              {creativeFeatures.map((feature) => (
                <FeatureCard
                  key={feature.title}
                  feature={feature}
                  iconContainerClass={creativeIconClass}
                />
              ))}
            </div>
            <div className="flex justify-center order-first lg:order-1">
              <img
                src="/brand/creative-nook-illustration_blended.png"
                alt="Creative Nook — parrot on a creative workspace with documents and tools"
                width={480}
                height={480}
                className="w-72 sm:w-80 lg:w-96 h-auto rounded-3xl bg-[#FAFAF7] mix-blend-multiply"
              />
            </div>
          </div>

          <div className="mt-12 max-w-md mx-auto">
            <CreativityWaitlistForm />
          </div>
        </div>

        <div className="mt-20 text-center">
          <Button href="/download" variant="primary" size="lg">
            Download for Windows
          </Button>
          <p className="mt-4 text-sm text-ink-muted">
            Free tier available · No credit card required
          </p>
        </div>
      </Container>
    </section>
  );
}
