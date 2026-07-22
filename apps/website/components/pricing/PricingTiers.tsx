"use client";

import { useState } from "react";
import Button from "@/components/ui/Button";
import CreativityWaitlistForm from "@/components/waitlist/CreativityWaitlistForm";

// WA-4 platform alignment: there is ONE product — Writing Nook. Card 1 is
// the Explore STATE of Writing Nook (what you can already do + what's
// locked and waiting), card 2 is the unlocked Writing Nook (14-day free
// trial), card 3 is Creative Nook, Coming Soon (waitlist only — no
// checkout). Mirrors the desktop Plans screen and the Product page's
// capability groups.

type FeatureState = "active" | "excluded" | "coming" | "header" | "locked";

type Feature = {
  label: string;
  state?: FeatureState;
};

type Price = {
  amount: string;
  subtitle: string;
  savings?: string;
};

type Tier = {
  tierName: string;
  title: string;
  monthly: Price;
  annual: Price;
  features: Feature[];
  popular?: boolean;
  comingSoon?: boolean;
  cta?: { label: string; href: string };
  waitlist?: boolean;
};

const EXPLORE: Tier = {
  tierName: "Writing Nook",
  title: "Explore",
  monthly: { amount: "$0", subtitle: "Free forever" },
  annual: { amount: "$0", subtitle: "Free forever" },
  features: [
    // What the writer can already accomplish — inside Writing Nook.
    { label: "Create writing projects" },
    { label: "Organize your manuscript" },
    { label: "Listen to your writing" },
    // Everything waiting to unlock.
    { label: "Waiting for you", state: "header" },
    { label: "Blueprints", state: "locked" },
    { label: "Story-Coach", state: "locked" },
    { label: "Structure Analyzer", state: "locked" },
    { label: "AI writing", state: "locked" },
    { label: "Premium voices", state: "locked" },
    { label: "Word & sentence highlighting", state: "locked" },
    // Implementation limits last — facts, not the story.
    { label: "Technical limits", state: "header" },
    { label: "10 documents per month", state: "excluded" },
    { label: "Standard voices", state: "excluded" },
  ],
  cta: { label: "Download for free", href: "/download" },
};

const WRITING: Tier = {
  tierName: "Writing Nook",
  title: "Write. Structure. Finish.",
  monthly: {
    amount: "$17.99/mo",
    subtitle: "14-day free trial, then billed monthly",
  },
  annual: {
    amount: "$183/yr",
    subtitle: "14-day free trial · $15.25/mo billed annually",
    savings: "Save 15%",
  },
  popular: true,
  features: [
    { label: "Writing Workspace", state: "header" },
    { label: "Full Writing Desk" },
    { label: "Distraction-free daily writing" },
    { label: "Story Development", state: "header" },
    { label: "Blueprints & 25+ Narrative Structures" },
    { label: "Scene Mapping & Progress Tracking" },
    { label: "AI Writing Intelligence", state: "header" },
    { label: "Story-Coach — live drift nudges" },
    { label: "Structure Analyzer" },
    { label: "AI assistance — 1M AI tokens / month" },
    { label: "Writing analytics & priority support" },
    { label: "Reading & Revision", state: "header" },
    { label: "Premium natural voices — 250k characters / month" },
    { label: "Word & sentence highlighting" },
    { label: "Playback speed up to 4×" },
    { label: "Edit & download branded DOCX" },
    { label: "Project Organization", state: "header" },
    { label: "Unlimited projects" },
    { label: "Document Library & manuscript organization" },
    { label: "Native Desktop", state: "header" },
    { label: "Native Windows app — fast, keyboard-driven, offline-friendly" },
  ],
  cta: { label: "Start your 14-day free trial", href: "/download" },
};

const CREATIVE: Tier = {
  tierName: "Creative Nook",
  title: "Create. Refine. Research.",
  monthly: { amount: "$29.99/mo", subtitle: "Launching soon" },
  annual: {
    amount: "$305/yr",
    subtitle: "$25.42/mo billed annually",
  },
  comingSoon: true,
  waitlist: true,
  features: [
    {
      label: "Everything in Writing Nook, plus a Creative Studio",
      state: "header",
    },
    { label: "Inspiration, Character & Research boards", state: "coming" },
    { label: "Story, World & Mood boards", state: "coming" },
    { label: "AI brainstorming & story expansion", state: "coming" },
    { label: "Clone your own voice", state: "coming" },
    { label: "Creative asset management", state: "coming" },
    { label: "400k premium-voice characters / month", state: "coming" },
    { label: "2M AI tokens / month", state: "coming" },
  ],
};

const TIERS: Tier[] = [EXPLORE, WRITING, CREATIVE];

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
      className="mt-0.5 shrink-0 text-green-600"
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
      className="mt-0.5 shrink-0 text-gray-400"
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
      className="mt-0.5 shrink-0 text-ink-muted"
    >
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </svg>
  );
}

function LockIcon() {
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
      className="mt-0.5 shrink-0 text-ink-muted"
    >
      <rect x="5" y="11" width="14" height="9" rx="2" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
    </svg>
  );
}

function FeatureRow({ feature }: { feature: Feature }) {
  const state = feature.state ?? "active";

  if (state === "header") {
    return (
      <li className="pt-3 pb-1 first:pt-0">
        <span className="text-[11px] font-bold uppercase tracking-wide text-ink-muted">
          {feature.label}
        </span>
      </li>
    );
  }
  if (state === "excluded") {
    return (
      <li className="flex items-start gap-3">
        <DashIcon />
        <span className="text-sm text-ink-muted/70">{feature.label}</span>
      </li>
    );
  }
  if (state === "locked") {
    return (
      <li className="flex items-start gap-3">
        <LockIcon />
        <span className="text-sm text-ink-muted">{feature.label}</span>
      </li>
    );
  }
  if (state === "coming") {
    return (
      <li className="flex items-start gap-3">
        <ClockIcon />
        <span className="text-sm italic text-ink-muted">{feature.label}</span>
      </li>
    );
  }
  return (
    <li className="flex items-start gap-3">
      <CheckIcon />
      <span className="text-sm text-ink-body">{feature.label}</span>
    </li>
  );
}

function TierCard({ tier, isAnnual }: { tier: Tier; isAnnual: boolean }) {
  const price = isAnnual ? tier.annual : tier.monthly;
  const highlight = tier.popular;

  return (
    <div
      className={`flex flex-col rounded-2xl p-8 text-left ${
        highlight
          ? "border-2 border-psitta-600 shadow-sm"
          : "border border-edge-subtle"
      }`}
    >
      <div className="flex items-center justify-between gap-2">
        <p className="text-xs font-medium uppercase tracking-wider text-ink-muted">
          {tier.tierName}
        </p>
        {tier.popular && (
          <span className="rounded-full bg-psitta-600 px-3 py-1 text-[11px] font-semibold text-white">
            Most popular
          </span>
        )}
        {tier.comingSoon && (
          <span className="rounded-full bg-ink-muted px-3 py-1 text-[11px] font-semibold text-white">
            Coming soon
          </span>
        )}
      </div>

      <h3 className="mt-1 text-xl font-bold text-ink-primary">{tier.title}</h3>

      <div className="mt-4 flex items-baseline gap-2">
        <span
          className={`text-3xl font-bold ${
            tier.comingSoon ? "text-ink-muted" : "text-ink-primary"
          }`}
        >
          {price.amount}
        </span>
        {price.savings && (
          <span className="rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-700">
            {price.savings}
          </span>
        )}
      </div>
      <p className="mt-1 text-sm text-ink-muted">{price.subtitle}</p>

      <hr className="my-6 border-edge-subtle" />

      <ul className="flex-1 space-y-3">
        {tier.features.map((f) => (
          <FeatureRow key={f.label} feature={f} />
        ))}
      </ul>

      <div className="mt-8">
        {tier.waitlist ? (
          <CreativityWaitlistForm />
        ) : (
          tier.cta && (
            <Button
              href={tier.cta.href}
              variant={highlight ? "primary" : "secondary"}
              size="lg"
              className="w-full"
            >
              {tier.cta.label}
            </Button>
          )
        )}
      </div>
    </div>
  );
}

export default function PricingTiers() {
  const [isAnnual, setIsAnnual] = useState(false);

  return (
    <div className="mt-12">
      {/* Billing period toggle — mirrors the app's Monthly / Annual switch */}
      <div className="flex justify-center">
        <div className="inline-flex items-center gap-1 rounded-full border border-edge-subtle p-1">
          <button
            type="button"
            onClick={() => setIsAnnual(false)}
            className={`rounded-full px-5 py-2 text-sm font-semibold transition-colors ${
              !isAnnual
                ? "bg-psitta-600 text-white"
                : "text-ink-body hover:text-ink-primary"
            }`}
          >
            Monthly
          </button>
          <button
            type="button"
            onClick={() => setIsAnnual(true)}
            className={`flex items-center gap-2 rounded-full px-5 py-2 text-sm font-semibold transition-colors ${
              isAnnual
                ? "bg-psitta-600 text-white"
                : "text-ink-body hover:text-ink-primary"
            }`}
          >
            Annual
            <span
              className={`rounded-full px-2 py-0.5 text-[11px] font-bold ${
                isAnnual ? "bg-white/20 text-white" : "bg-green-100 text-green-700"
              }`}
            >
              Save 15%
            </span>
          </button>
        </div>
      </div>

      <div className="mt-12 grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
        {/* key = title: two cards now legitimately share the "Writing Nook"
            tierName (the product), so tierName is no longer unique. */}
        {TIERS.map((tier) => (
          <TierCard key={tier.title} tier={tier} isAnnual={isAnnual} />
        ))}
      </div>

      <p className="mt-8 text-center text-sm text-ink-muted">
        Download free for Windows. Start your 14-day Writing Nook free trial
        from inside the app — cancel anytime.
      </p>
    </div>
  );
}
