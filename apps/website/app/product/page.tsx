import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import JsonLd from "@/components/seo/JsonLd";
import CreativityWaitlistForm from "@/components/waitlist/CreativityWaitlistForm";

export const metadata: Metadata = {
  title: "Features — Psitta",
};

const softwareApplicationSchema = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Psitta",
  description:
    "Psitta reads your documents aloud — PDFs and Word documents — with sentence-level and word-level highlighting synchronized to the audio. Built for writers and editors who want to hear their own writing.",
  url: "https://psitta.ai",
  applicationCategory: "ProductivityApplication",
  operatingSystem: "Windows 10, Windows 11",
  offers: [
    {
      "@type": "Offer",
      name: "Reading Nook Free",
      price: "0",
      priceCurrency: "USD",
      description: "Free tier with 3 documents per month and Edge TTS voices",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (monthly)",
      price: "14.99",
      priceCurrency: "USD",
      description:
        "Unlimited documents, premium voices, word-level highlighting",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (annual)",
      price: "99",
      priceCurrency: "USD",
      description: "Annual subscription, saves ~44% vs monthly",
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
  const creativeIconClass =
    "shrink-0 flex h-11 w-11 items-center justify-center rounded-xl bg-gray-100 text-ink-muted";

  return (
    <section className="py-section">
      <JsonLd data={softwareApplicationSchema} />
      <Container className="max-w-4xl">
        <h1 className="text-ink-primary text-center">
          Everything Psitta does
        </h1>
        <p className="lead mt-4 text-center text-ink-muted max-w-2xl mx-auto">
          A desktop app that reads your documents aloud — so you can hear what
          you actually wrote.
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

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 mt-12 items-start">
            <div className="space-y-6 order-last lg:order-1">
              {creativeFeatures.map((feature) => (
                <FeatureCard
                  key={feature.title}
                  feature={feature}
                  iconContainerClass={creativeIconClass}
                />
              ))}
            </div>
            <div className="flex justify-center order-first lg:order-2">
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
