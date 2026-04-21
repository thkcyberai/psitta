import Container from "@/components/ui/Container";

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

const features: Feature[] = [
  {
    title: "Hear your own writing",
    description:
      "Upload any PDF or DOCX and listen back instantly. Your ear catches awkward phrasing, broken rhythm, and unclear passages that your eye skips over.",
    icon: (
      <svg {...iconProps}>
        <path d="M11 5 6 9H3v6h3l5 4z" />
        <path d="M15.5 8.5a5 5 0 0 1 0 7" />
        <path d="M18.5 5.5a9 9 0 0 1 0 13" />
      </svg>
    ),
  },
  {
    title: "Sentence-level highlighting",
    description:
      "Every sentence lights up as it's read aloud — pixel-accurate, synchronized to the audio. Follow along or jump to any passage with a click.",
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
    title: "Premium voices",
    description:
      "Choose from natural-sounding neural voices powered by ElevenLabs and Azure. Free tier included — upgrade when you're ready.",
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

export default function FeatureStrip() {
  return (
    <section className="py-section border-t border-edge-subtle">
      <Container>
        <h2 className="text-ink-primary text-center">What Psitta does</h2>
        <p className="lead mt-4 max-w-2xl mx-auto text-center text-ink-muted">
          Three capabilities that turn reading into revision.
        </p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-12 mt-16">
          {features.map((feature) => (
            <div key={feature.title} className="text-center">
              <div className="mx-auto mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-psitta-50 text-psitta-600">
                {feature.icon}
              </div>
              <h3 className="text-lg font-semibold text-ink-primary">
                {feature.title}
              </h3>
              <p className="mt-3 text-ink-body leading-relaxed">
                {feature.description}
              </p>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
