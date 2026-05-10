import type { Metadata } from "next";
import Link from "next/link";
import Container from "@/components/ui/Container";
import ContactForm from "@/components/contact/ContactForm";

export const metadata: Metadata = {
  title: "Contact",
  description:
    "Reach the Psitta team directly. We answer questions, take feature requests, and read every bug report from real writers using the product.",
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

        <p className="mt-6 text-sm text-ink-muted">
          Need help with installation or playback? Visit our{" "}
          <Link href="/support" className="text-psitta-600 hover:underline">
            support page
          </Link>{" "}
          for FAQs first.
        </p>

        <div className="mt-16">
          <ContactForm />
        </div>

        <p className="mt-8 text-center text-sm text-ink-muted">
          Or email us directly at{" "}
          <a
            href="mailto:support@psitta.ai"
            className="text-psitta-600 hover:underline"
          >
            support@psitta.ai
          </a>
        </p>

        <p className="mt-4 text-center text-sm text-ink-muted">
          Facti AI LLC · Colorado, United States
        </p>
      </Container>
    </section>
  );
}
