import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Subscription Confirmed",
  robots: { index: false, follow: false },
};

export default function BillingSuccess() {
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
          className="mx-auto mb-8 text-green-600"
        >
          <circle cx="12" cy="12" r="10" />
          <path d="m8 12.5 2.5 2.5L16 9.5" />
        </svg>

        <h1 className="text-ink-primary">You&apos;re all set!</h1>

        <p className="lead mt-4 text-ink-body">
          Your subscription is now active. Open Psitta on your desktop to start
          using premium features.
        </p>

        <p className="mt-4 text-sm text-ink-muted">
          A confirmation email is on its way. If you have any questions, reach
          out to support@psitta.ai.
        </p>

        <Button href="/" variant="primary" size="lg" className="mt-8">
          Back to Psitta
        </Button>
      </Container>
    </section>
  );
}
