import type { Metadata } from "next";
import Container from "@/components/ui/Container";

export const metadata: Metadata = {
  title: "About",
  description:
    "Psitta is built by Facti AI LLC — a writer-led project to make it easy to listen to your own drafts and hear what your readers will hear.",
};

export default function About() {
  return (
    <section className="py-section">
      <Container className="max-w-3xl">
        <h1 className="text-ink-primary text-center">About Psitta</h1>
        <p className="lead mt-4 text-center text-ink-muted">
          Built by a writer who wanted to hear his own work.
        </p>

        <div className="mt-16">
          <h2 className="text-xl font-semibold text-ink-primary">The story</h2>
          <p className="mt-4 text-ink-body leading-relaxed">
            I built Psitta because I wanted to have my writings read back to
            me. Spelling and grammar checkers told me what was technically
            wrong — but they couldn&apos;t tell me how my writing actually
            felt. They couldn&apos;t catch a sentence that was correct but
            clumsy, or a paragraph that made sense on paper but stumbled when
            spoken aloud.
          </p>
          <p className="mt-4 text-ink-body leading-relaxed">
            So I built a tool that reads my documents back to me, because my
            ear catches what my eye misses. That&apos;s what Psitta is — a way
            to hear your own writing before your readers do.
          </p>
          <p className="mt-6 text-sm font-medium text-ink-muted">
            — Luis Oliveira, Founder & CEO
          </p>
        </div>

        <div className="mt-16">
          <h2 className="text-xl font-semibold text-ink-primary">
            The company
          </h2>
          <p className="mt-4 text-ink-body leading-relaxed">
            Psitta is built by Facti AI LLC, a software company based in
            Colorado. We build products across two domains: tools that help
            people write, think, and communicate more clearly — and
            cybersecurity solutions that protect businesses from identity
            fraud and emerging digital threats.
          </p>
        </div>

        <div className="mt-16">
          <h2 className="text-xl font-semibold text-ink-primary">
            Why the name?
          </h2>
          <p className="mt-4 text-ink-body leading-relaxed">
            Psitta comes from Psittacidae — the scientific family name for
            parrots. Parrots listen and repeat. Psitta listens to your writing
            and reads it back to you — so you can hear what you actually
            wrote.
          </p>
        </div>
      </Container>
    </section>
  );
}
