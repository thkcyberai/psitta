import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Features — Psitta",
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
    title: "Advanced content tools",
    description:
      "Tools designed for content creators — outline generation, section restructuring, and readability analysis powered by your listening workflow.",
    icon: (
      <svg {...iconProps}>
        <path d="M12 3v18" />
        <path d="M5 8h14" />
        <path d="M7 13h10" />
        <path d="M9 18h6" />
      </svg>
    ),
  },
  {
    title: "Multi-format export",
    description:
      "Export your polished documents in multiple formats — branded DOCX, PDF, and more — ready to share with clients or publish directly.",
    icon: (
      <svg {...iconProps}>
        <path d="M12 3v12" />
        <path d="m7 10 5 5 5-5" />
        <path d="M5 21h14" />
      </svg>
    ),
  },
  {
    title: "More on the way",
    description:
      "Creative Nook is actively being developed. Features will be announced as they ship. Join the waitlist to be the first to know.",
    icon: (
      <svg {...iconProps}>
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </svg>
    ),
  },
];

function FeatureBlock({
  feature,
  iconContainerClass,
}: {
  feature: Feature;
  iconContainerClass: string;
}) {
  return (
    <div className="mt-12">
      <div className={iconContainerClass}>{feature.icon}</div>
      <h2 className="text-xl font-semibold text-ink-primary">
        {feature.title}
      </h2>
      <p className="mt-3 text-ink-body leading-relaxed max-w-2xl">
        {feature.description}
      </p>
    </div>
  );
}

function ReadingIllustration() {
  return (
    <svg
      viewBox="0 0 120 120"
      className="w-24 h-24 shrink-0"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {/* Book — open pages forming a shallow V */}
      <path d="M 18 94 L 60 82 L 60 96 Z" />
      <path d="M 102 94 L 60 82 L 60 96 Z" />
      <path d="M 18 96 L 18 100 L 102 100 L 102 96" />
      <path d="M 26 90 L 55 85" opacity="0.45" />
      <path d="M 65 85 L 94 90" opacity="0.45" />

      {/* Parrot body — plump teardrop */}
      <path
        d="M 58 40 Q 78 42 78 62 Q 76 76 60 78 Q 44 78 40 62 Q 40 42 58 40 Z"
        fill="currentColor"
        fillOpacity="0.15"
      />

      {/* Head */}
      <circle cx="52" cy="32" r="10" fill="currentColor" fillOpacity="0.15" />

      {/* Crest — little tuft */}
      <path d="M 46 22 Q 50 14 54 22" />

      {/* Beak */}
      <path
        d="M 60 31 L 67 34 L 60 37 Z"
        fill="currentColor"
        fillOpacity="0.3"
      />

      {/* Eye */}
      <circle cx="54" cy="31" r="1.5" fill="currentColor" stroke="none" />

      {/* Wing */}
      <path d="M 50 55 Q 60 50 70 60" />
      <path d="M 52 62 Q 60 58 68 66" opacity="0.6" />

      {/* Tail feathers trailing down behind */}
      <path d="M 41 68 L 32 82" />
      <path d="M 45 72 L 38 86" />

      {/* Legs onto the book */}
      <path d="M 54 78 L 54 82" />
      <path d="M 62 78 L 62 82" />
    </svg>
  );
}

function CreativeIllustration() {
  return (
    <svg
      viewBox="0 0 120 120"
      className="w-24 h-24 shrink-0"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {/* Canvas on easel */}
      <rect x="14" y="24" width="44" height="52" rx="1.5" />
      {/* Abstract brushstroke on canvas */}
      <path
        d="M 22 44 Q 32 34 42 46 T 52 52"
        opacity="0.4"
      />
      {/* Easel crossbar + legs */}
      <path d="M 18 76 L 54 76" />
      <path d="M 22 76 L 16 98" />
      <path d="M 50 76 L 56 98" />
      <path d="M 36 76 L 36 98" />

      {/* Parrot body */}
      <path
        d="M 90 50 Q 104 52 104 66 Q 102 78 90 80 Q 76 78 76 64 Q 76 50 90 50 Z"
        fill="currentColor"
        fillOpacity="0.1"
      />

      {/* Head */}
      <circle cx="86" cy="44" r="8" fill="currentColor" fillOpacity="0.1" />

      {/* Crest */}
      <path d="M 82 36 Q 85 30 88 36" />

      {/* Beak (holding brush) */}
      <path
        d="M 92 43 L 99 45 L 92 47 Z"
        fill="currentColor"
        fillOpacity="0.25"
      />

      {/* Eye */}
      <circle cx="88" cy="43" r="1.3" fill="currentColor" stroke="none" />

      {/* Paintbrush extending from beak */}
      <path d="M 99 46 L 114 32" />
      {/* Ferrule */}
      <path d="M 110 36 L 113 33" opacity="0.7" />
      {/* Bristles fan */}
      <path d="M 114 32 L 118 28" />
      <path d="M 114 32 L 116 26" />
      <path d="M 114 32 L 119 31" />

      {/* Wing */}
      <path d="M 84 62 Q 92 60 99 68" />
      <path d="M 86 68 Q 92 66 97 72" opacity="0.6" />

      {/* Tail */}
      <path d="M 78 70 L 72 82" />

      {/* Legs + perch */}
      <path d="M 87 80 L 87 88" />
      <path d="M 93 80 L 93 88" />
      <path d="M 70 90 L 106 90" />
    </svg>
  );
}

export default function Product() {
  const readingIconClass =
    "mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-psitta-50 text-psitta-600";
  const creativeIconClass =
    "mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-gray-100 text-ink-muted";

  return (
    <section className="py-section">
      <Container className="max-w-4xl">
        <h1 className="text-ink-primary text-center">
          Everything Psitta does
        </h1>
        <p className="lead mt-4 text-center text-ink-muted max-w-2xl mx-auto">
          A desktop app that reads your documents aloud — so you can hear what
          you actually wrote.
        </p>

        <div className="mt-16 flex flex-col items-center text-center sm:flex-row sm:items-center sm:text-left gap-6">
          <div className="text-psitta-600">
            <ReadingIllustration />
          </div>
          <div>
            <h2 className="text-2xl font-bold text-ink-primary">
              Reading Nook
            </h2>
            <p className="mt-2 text-ink-body leading-relaxed max-w-xl">
              Listen to your documents with pixel-accurate highlighting and
              premium neural voices. Free and Pro tiers available.
            </p>
          </div>
        </div>

        {readingFeatures.map((feature) => (
          <FeatureBlock
            key={feature.title}
            feature={feature}
            iconContainerClass={readingIconClass}
          />
        ))}

        <div className="mt-20 border-t border-edge-subtle pt-16">
          <div className="flex flex-col items-center text-center sm:flex-row sm:items-center sm:text-left gap-6">
            <div className="text-ink-muted">
              <CreativeIllustration />
            </div>
            <div>
              <div className="flex items-center gap-3">
                <h2 className="text-2xl font-bold text-ink-primary">
                  Creative Nook
                </h2>
                <span className="rounded-full bg-ink-muted px-3 py-0.5 text-xs font-semibold text-white">
                  Coming soon
                </span>
              </div>
              <p className="mt-2 text-ink-body leading-relaxed max-w-xl">
                Expand beyond reading into structured content creation.
                Available as an add-on to Reading Nook Pro.
              </p>
            </div>
          </div>

          {creativeFeatures.map((feature) => (
            <FeatureBlock
              key={feature.title}
              feature={feature}
              iconContainerClass={creativeIconClass}
            />
          ))}
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
