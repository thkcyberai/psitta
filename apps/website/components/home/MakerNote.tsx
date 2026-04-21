import Container from "@/components/ui/Container";

export default function MakerNote() {
  return (
    <section className="py-section border-t border-edge-subtle">
      <Container className="max-w-2xl text-center">
        <h2 className="text-lg font-semibold text-ink-primary">
          A note from the maker
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          I built Psitta because I wanted to have my writings read back to me.
          Spelling and grammar checkers told me what was technically wrong — but
          they couldn&apos;t tell me how my writing actually felt. They
          couldn&apos;t catch a sentence that was correct but clumsy, or a
          paragraph that made sense on paper but stumbled when spoken aloud. So I
          built a tool that reads my documents back to me, because my ear catches
          what my eye misses. That&apos;s what Psitta is — a way to hear your own
          writing before your readers do.
        </p>
        <p className="mt-6 text-sm font-medium text-ink-muted">
          — Luis Oliveira, Founder
        </p>
      </Container>
    </section>
  );
}
