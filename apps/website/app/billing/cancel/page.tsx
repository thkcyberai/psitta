import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Checkout Cancelled",
  robots: { index: false, follow: false },
};

export default function BillingCancel() {
  return (
    <section className="py-section">
      <Container className="max-w-2xl text-center">
        <svg
          width={64}
          height={64}
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={1.75}
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
          className="mx-auto mb-8 text-ink-muted"
        >
          <circle cx="12" cy="12" r="10" />
          <path d="m15 9-6 6" />
          <path d="m9 9 6 6" />
        </svg>

        <h1 className="text-ink-primary">Checkout cancelled</h1>

        <p className="lead mt-4 text-ink-body">
          No worries — nothing was charged. You can upgrade anytime from within
          the app.
        </p>

        <Button href="/" variant="primary" size="lg" className="mt-8">
          Back to Psitta
        </Button>

        <p className="mt-4 text-sm text-ink-muted">
          Still have questions?{" "}
          <a
            href="mailto:support@psitta.ai"
            className="text-psitta-600 hover:underline"
          >
            Get in touch
          </a>
        </p>
      </Container>
    </section>
  );
}
