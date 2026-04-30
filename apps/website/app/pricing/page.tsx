import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Pricing — Psitta",
};

const freeFeatures = [
  "3 documents per month",
  "Edge TTS voices",
  "PDF and DOCX support",
  "Sentence-level highlighting",
];

const proFeatures = [
  "50 documents per month",
  "Premium ElevenLabs and Azure voices",
  "PDF and DOCX support",
  "Sentence-level highlighting",
  "Word-level highlighting",
  "Priority support",
];

const creativeFeatures = [
  "Everything in Reading Nook Pro",
  "4 Creative Nook workspaces",
  "Advanced content tools",
  "More features announced soon",
];

function CheckIcon() {
  return (
    <svg
      width={16}
      height={16}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2.25}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      className="mt-1 shrink-0 text-green-600"
    >
      <path d="m5 12.5 4.5 4.5L19 7" />
    </svg>
  );
}

function FeatureList({ items }: { items: string[] }) {
  return (
    <ul className="space-y-4 text-left text-ink-body">
      {items.map((item) => (
        <li key={item} className="flex items-start gap-3">
          <CheckIcon />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}

export default function Pricing() {
  return (
    <section className="py-section">
      <Container>
        <h1 className="text-ink-primary text-center">
          Simple, transparent pricing
        </h1>
        <p className="lead mt-4 max-w-2xl mx-auto text-center text-ink-muted">
          Start free. Upgrade when Psitta becomes part of your workflow.
        </p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mt-16 max-w-5xl mx-auto">
          <div className="rounded-2xl border border-edge-subtle p-8 text-center">
            <p className="text-xs font-medium uppercase tracking-wider text-ink-muted">
              Reading Nook
            </p>
            <p className="mt-1 text-sm font-semibold uppercase tracking-wider text-ink-muted">
              Free
            </p>
            <p className="mt-4 text-4xl font-bold text-ink-primary">$0</p>
            <p className="mt-1 text-sm text-ink-muted">forever</p>

            <hr className="my-8 border-edge-subtle" />

            <FeatureList items={freeFeatures} />

            <Button
              href="/download"
              variant="secondary"
              size="lg"
              className="mt-8 w-full"
            >
              Download for free
            </Button>
          </div>

          <div className="rounded-2xl border-2 border-psitta-600 p-8 text-center relative">
            <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-psitta-600 px-4 py-1 text-xs font-semibold text-white">
              Most popular
            </span>
            <p className="text-xs font-medium uppercase tracking-wider text-ink-muted">
              Reading Nook
            </p>
            <p className="mt-1 text-sm font-semibold uppercase tracking-wider text-psitta-600">
              Pro
            </p>
            <p className="mt-4 text-4xl font-bold text-ink-primary">$14.99</p>
            <p className="mt-1 text-sm text-ink-muted">per month</p>
            <p className="mt-1 text-sm text-psitta-600 font-medium">
              or $99 / year (save 44%)
            </p>

            <hr className="my-8 border-edge-subtle" />

            <FeatureList items={proFeatures} />

            <Button
              href="/download"
              variant="primary"
              size="lg"
              className="mt-8 w-full"
            >
              Start with Pro
            </Button>
          </div>

          <div className="rounded-2xl border border-edge-subtle p-8 text-center relative">
            <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-ink-muted px-4 py-1 text-xs font-semibold text-white">
              Coming soon
            </span>
            <p className="text-xs font-medium uppercase tracking-wider text-ink-muted">
              Creative Nook
            </p>
            <p className="mt-1 text-sm font-semibold uppercase tracking-wider text-ink-muted">
              Pro
            </p>
            <p className="mt-4 text-4xl font-bold text-ink-primary">$19.99</p>
            <p className="mt-1 text-sm text-ink-muted">per month</p>
            <p className="mt-1 text-sm text-ink-muted font-medium">
              or $199 / year
            </p>
            <p className="mt-2 text-xs text-ink-muted">
              Includes Reading Nook Pro
            </p>

            <hr className="my-8 border-edge-subtle" />

            <FeatureList items={creativeFeatures} />

            <p className="mt-8 text-sm font-medium text-ink-muted text-center">
              Notify me when available
            </p>
          </div>
        </div>

        <p className="mt-12 text-center text-sm text-ink-muted">
          All plans include a free trial. No credit card required to start.
        </p>
      </Container>
    </section>
  );
}
