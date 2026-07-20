import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import PricingTiers from "@/components/pricing/PricingTiers";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "Start free, then upgrade to Writing Nook — 14-day free trial, $17.99/mo or $183/yr (~15% off yearly). Creative Nook coming soon.",
};

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

        <PricingTiers />
      </Container>
    </section>
  );
}
