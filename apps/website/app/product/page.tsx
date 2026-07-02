import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import JsonLd from "@/components/seo/JsonLd";
import CreativityWaitlistForm from "@/components/waitlist/CreativityWaitlistForm";

export const metadata: Metadata = {
  title: "Features — Read, Listen & Write",
  description:
    "Psitta reads your PDFs, Word docs, e-books and more aloud with synced word-level highlighting — then gives writers a full platform with Blueprints, Story-Coach, and writing analytics to finish their book. Free tier, Windows.",
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
      name: "Reading Nook Free",
      price: "0",
      priceCurrency: "USD",
      description: "Free tier with 10 documents per month and Edge TTS voices",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (monthly)",
      price: "14.99",
      priceCurrency: "USD",
      description:
        "Premium voices, word-level highlighting, and 50 documents per month",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (annual)",
      price: "152",
      priceCurrency: "USD",
      description: "Annual Reading Nook Pro — saves ~15% vs monthly",
    },
    {
      "@type": "Offer",
      name: "Writing Nook Pro (monthly)",
      price: "17.99",
      priceCurrency: "USD",
      description:
        "Everything in Reading Nook plus the full Writing Desk, Blueprints, Story-Coach, and writing analytics",
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

const readingFeatures: Feature[] = [
  {
    title: "PDF and DOCX support",
    description:
      "Upload any PDF or Word document and Psitta extracts the text, preserving structure and reading order. Page-based chunking ensures accurate playback even for long documents.",
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
      "Pro subscribers get word-by-word highlighting synchronized to the audio. See exactly which word is being spoken at any moment — ideal for catching individual word-choice issues.",
    icon: (
      <svg {...iconProps}>
        <rect x="4" y="8" width="3" height="8" rx="0.5" fill="currentColor" stroke="none" />
        <rect x="10.5" y="8" width="3" height="8" rx="0.5" opacity="0.35" fill="currentColor" stroke="none" />
        <rect x="17" y="8" width="3" height="8" rx="0.5" opacity="0.35" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
  {
    title: "Premium neural voices",
    description:
      "Choose from natural-sounding voices powered by ElevenLabs and Microsoft Azure Neural TTS. Free tier includes Edge TTS voices at no cost — upgrade to Pro for the full voice catalog.",
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
    title: "Listening improves writing",
    description:
      "Reading silently, your brain auto-corrects. Listening breaks the spell. Hear awkward phrasing, broken rhythm, and unclear passages that your eye skips over — the fix usually follows within seconds.",
    icon: (
      <svg {...iconProps}>
        <path d="M11 5 6 9H3v6h3l5 4z" />
        <path d="M15.5 8.5a5 5 0 0 1 0 7" />
        <path d="M18.5 5.5a9 9 0 0 1 0 13" />
      </svg>
    ),
  },
  {
    title: "Built for Windows",
    description:
      "Psitta is a native Windows desktop application — not a browser extension or web app. It runs locally on your machine with a clean, distraction-free interface designed for focused document review.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="4" width="18" height="12" rx="1.5" />
        <path d="M8 20h8" />
        <path d="M12 16v4" />
      </svg>
    ),
  },
];

const writingFeatures: Feature[] = [
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
    title: "Blueprints & 25+ narrative structures",
    description:
      "Structure your book with Blueprints and 25+ proven frameworks — Three-Act, Save the Cat, Seven-Point, Snowflake and more — each with an interactive, step-by-step guide.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="3" width="7" height="7" rx="1" />
        <rect x="14" y="3" width="7" height="7" rx="1" />
        <rect x="3" y="14" width="7" height="7" rx="1" />
        <rect x="14" y="14" width="7" height="7" rx="1" />
      </svg>
    ),
  },
  {
    title: "Scene mapping & progress tracking",
    description:
      "Map scenes onto your outline and watch your manuscript's progress build automatically as you write toward the finish.",
    icon: (
      <svg {...iconProps}>
        <path d="M9 3 4 5v16l5-2 6 2 5-2V3l-5 2-6-2z" />
        <path d="M9 3v16" />
        <path d="M15 5v16" />
      </svg>
    ),
  },
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
        <rect x="7" y="12" width="3" height="6" />
        <rect x="12" y="8" width="3" height="10" />
        <rect x="17" y="5" width="3" height="13" />
      </svg>
    ),
  },
];

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
      "All Writing Nook features — premium voices, word-by-word highlighting, the full Writing Desk, Blueprints, Story-Coach, and analytics — plus the creative workflow tools below. One subscription.",
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
        <h3 className="text-base font-semibold text-ink-primary">
          {feature.title}
        </h3>
        <p className="mt-1 text-sm text-ink-body leading-relaxed">
          {feature.description}
        </p>
      </div>
    </div>
  );
}

export default function Product() {
  const readingIconClass =
    "shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-psitta-50 text-psitta-600";
  const writingIconClass =
    "shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-psitta-50 text-psitta-600";
  const creativeIconClass =
    "shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-gray-100 text-ink-muted";

  return (
    <section className="py-section">
      <JsonLd data={softwareApplicationSchema} />
      <Container className="max-w-4xl">
        <h1 className="text-ink-primary text-center">
          Hear your words. Finish your book.
        </h1>
        <p className="lead mt-4 text-center text-ink-muted max-w-2xl mx-auto">
          Psitta reads any document aloud so you can hear what you actually
          wrote — then gives you a full writing platform to structure, draft,
          and finish your book.
        </p>

        <div className="mt-16">
          <h2 className="text-2xl font-bold text-ink-primary">
            Reading Nook
          </h2>
          <p className="mt-2 text-ink-body leading-relaxed max-w-xl">
            Listen to your documents with pixel-accurate highlighting and
            premium neural voices. Free and Pro tiers available.
          </p>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 mt-12 items-start">
            <div className="flex justify-center">
              <img
                src="/brand/reading-nook-illustration_blended.png"
                alt="Reading Nook — parrot reading a book with highlighted text and sound waves"
                width={480}
                height={480}
                className="w-72 sm:w-80 lg:w-96 h-auto rounded-3xl bg-[#FAFAF7] mix-blend-multiply"
              />
            </div>
            <div className="space-y-6">
              {readingFeatures.map((feature) => (
                <FeatureCard
                  key={feature.title}
                  feature={feature}
                  iconContainerClass={readingIconClass}
                />
              ))}
            </div>
          </div>
        </div>

        <div className="mt-20 border-t border-edge-subtle pt-16">
          <div className="flex items-center gap-3">
            <h2 className="text-2xl font-bold text-ink-primary">
              Writing Nook
            </h2>
            <span className="rounded-full bg-psitta-600 px-3 py-0.5 text-xs font-semibold text-white">
              Most popular
            </span>
          </div>
          <p className="mt-2 text-ink-body leading-relaxed max-w-xl">
            Everything in Reading Nook, plus a full writing platform — structure
            your book, write with Psitta reading every line back to you, and
            finish with an AI coach that keeps you on track.
          </p>

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
            <div className="space-y-6 lg:order-1">
              {writingFeatures.map((feature) => (
                <FeatureCard
                  key={feature.title}
                  feature={feature}
                  iconContainerClass={writingIconClass}
                />
              ))}
            </div>
          </div>
        </div>

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
            everything in Writing Nook.
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
