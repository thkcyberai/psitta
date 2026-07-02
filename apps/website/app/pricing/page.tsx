import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import PricingTiers from "@/components/pricing/PricingTiers";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "Start free, then choose your Nook: Reading ($14.99/mo), Writing ($17.99/mo), or Creative ($29.99/mo — coming soon). Billed monthly or annually, ~15% off yearly.",
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
