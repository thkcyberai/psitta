import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import CreativityWaitlistForm from "@/components/waitlist/CreativityWaitlistForm";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "Free tier with basic voices, or Reading Nook Pro for premium voices, word-level highlighting, and 50 documents a month — billed monthly or annually.",
};

type FeatureState = "active" | "excluded" | "coming";

type Feature = {
  label: string;
  state?: FeatureState;
};

const freeFeatures: Feature[] = [
  { label: "Listen to your documents" },
  { label: "Basic voices" },
  { label: "10 documents per month" },
  { label: "Edit DOCX in real time", state: "excluded" },
  { label: "Premium voices", state: "excluded" },
  { label: "50 documents per month", state: "excluded" },
  { label: "Word-by-word highlighting", state: "excluded" },
  { label: "Download branded DOCX", state: "excluded" },
  { label: "Archive documents", state: "excluded" },
  { label: "Priority support", state: "excluded" },
  { label: "Creative Nooks", state: "excluded" },
];

const proFeatures: Feature[] = [
  { label: "Listen while you write" },
  { label: "Edit DOCX in real time" },
  { label: "Premium voices" },
  { label: "50 documents per month" },
  { label: "Word-by-word highlighting" },
  { label: "Download branded DOCX" },
  { label: "Archive documents" },
  { label: "Priority support" },
  { label: "Creative Nooks", state: "excluded" },
];

const creativeFeatures: Feature[] = [
  { label: "Listen while you write" },
  { label: "Edit DOCX in real time" },
  { label: "Premium voices" },
  { label: "Unlimited documents" },
  { label: "Word-by-word highlighting" },
  { label: "Download branded DOCX" },
  { label: "Archive documents" },
  { label: "Priority support" },
  { label: "Drop in inspiration. Prompt your way to ideas.", state: "coming" },
  { label: "Clone Voice reading (record your own voice)", state: "coming" },
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

function DashIcon() {
  return (
    <svg
      width={16}
      height={16}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      className="mt-1 shrink-0 text-gray-400"
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M8 12h8" />
    </svg>
  );
}

function ClockIcon() {
  return (
    <svg
      width={16}
      height={16}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      className="mt-1 shrink-0 text-ink-muted"
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </svg>
  );
}

function FeatureRow({ feature }: { feature: Feature }) {
  const state = feature.state ?? "active";
  if (state === "excluded") {
    return (
      <li className="flex items-start gap-3">
        <DashIcon />
        <span className="text-ink-muted/70">{feature.label}</span>
      </li>
    );
  }
  if (state === "coming") {
    return (
      <li className="flex items-start gap-3">
        <ClockIcon />
        <span className="text-ink-muted italic">{feature.label}</span>
      </li>
    );
  }
  return (
    <li className="flex items-start gap-3">
      <CheckIcon />
      <span className="text-ink-body">{feature.label}</span>
    </li>
  );
}

function FeatureList({ items }: { items: Feature[] }) {
  return (
    <ul className="space-y-4 text-left">
      {items.map((item) => (
        <FeatureRow key={item.label} feature={item} />
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

            <hr className="my-8 border-edge-subtle" />

            <FeatureList items={creativeFeatures} />

            <div className="mt-8">
              <CreativityWaitlistForm />
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}
