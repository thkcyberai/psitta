import type { Metadata } from "next";
import Container from "@/components/ui/Container";

export const metadata: Metadata = {
  title: "Contact — Psitta",
};

export default function Contact() {
  return (
    <section className="py-section">
      <Container className="max-w-2xl text-center">
        <h1 className="text-ink-primary">Get in touch</h1>
        <p className="lead mt-4 text-ink-muted">
          Have a question, found a bug, or just want to say hello?
          We&apos;d love to hear from you.
        </p>

        <div className="mt-16 rounded-2xl border border-edge-subtle p-8 md:p-12 inline-block mx-auto">
          <svg
            width={48}
            height={48}
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            strokeLinecap="round"
            strokeLinejoin="round"
            aria-hidden
            className="mx-auto mb-6 text-psitta-600"
          >
            <rect x="3" y="5" width="18" height="14" rx="2" />
            <path d="m3 7 9 6 9-6" />
          </svg>

          <p className="text-sm font-medium text-ink-muted">Email us at</p>
          <a
            href="mailto:support@psitta.ai"
            className="mt-2 block text-xl font-semibold text-psitta-600 hover:text-psitta-700 hover:underline"
          >
            support@psitta.ai
          </a>
        </div>

        <div className="mt-12">
          <p className="text-sm text-ink-muted">
            Facti AI LLC · Colorado, United States
          </p>
        </div>

        <p className="mt-4 text-sm text-ink-muted">
          We typically respond within one business day.
        </p>
      </Container>
    </section>
  );
}
