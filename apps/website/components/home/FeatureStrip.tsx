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

// WA-2: six capability groups of the Psitta Platform. Each card sells an
// outcome on the road to a finished book — never a technology.
const features: Feature[] = [
  {
    title: "Writing",
    description:
      "A distraction-free Writing Desk built for daily writing. Sit down, pick up exactly where you left off, and put words on the page — every session moves the manuscript forward.",
    icon: (
      <svg {...iconProps}>
        <path d="M12 20h9" />
        <path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z" />
      </svg>
    ),
  },
  {
    title: "Story Development",
    description:
      "Plan the book before it drifts. Blueprints and proven narrative structures turn your idea into a map — plan scenes, track progress, and always know what to write next.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="3" width="18" height="18" rx="2" />
        <path d="M3 9h18" />
        <path d="M9 21V9" />
      </svg>
    ),
  },
  {
    title: "AI Writing Intelligence",
    description:
      "A Story-Coach that catches drift as you write, a Structure Analyzer that shows what's working, AI assistance when you're stuck, and analytics that prove your momentum — honest feedback, exactly when it helps.",
    icon: (
      <svg {...iconProps}>
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        <path d="M12 7v4" />
        <path d="M12 14h.01" />
      </svg>
    ),
  },
  {
    title: "Reading & Revision",
    description:
      "Hear every line read back in a natural voice with synchronized highlighting. Listening turns rereading into revision — you fix what you hear, and the draft gets better with every pass.",
    icon: (
      <svg {...iconProps}>
        <path d="M11 5 6 9H3v6h3l5 4z" />
        <path d="M15.5 8.5a5 5 0 0 1 0 7" />
        <path d="M18.5 5.5a9 9 0 0 1 0 13" />
      </svg>
    ),
  },
  {
    title: "Project Organization",
    description:
      "Every draft, chapter, and source organized in projects and one searchable library. Your whole manuscript lives in one place — never scattered across folders again.",
    icon: (
      <svg {...iconProps}>
        <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
        <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
      </svg>
    ),
  },
  {
    title: "Native Desktop",
    description:
      "A native Windows app that keeps up with you — fast, keyboard-driven, and offline-friendly, so nothing stands between you and the next page.",
    icon: (
      <svg {...iconProps}>
        <rect x="3" y="4" width="18" height="12" rx="1.5" />
        <path d="M8 20h8" />
        <path d="M12 16v4" />
      </svg>
    ),
  },
];

export default function FeatureStrip() {
  return (
    <section className="py-section border-t border-edge-subtle">
      <Container>
        <h2 className="text-ink-primary text-center">
          Everything you need to finish your book
        </h2>
        <p className="lead mt-4 max-w-2xl mx-auto text-center text-ink-muted">
          One writing platform. Every stage of your manuscript.
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
