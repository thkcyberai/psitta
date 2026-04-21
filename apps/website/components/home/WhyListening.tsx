import Container from "@/components/ui/Container";

export default function WhyListening() {
  return (
    <section className="py-section bg-paper-surface">
      <Container className="max-w-3xl text-center">
        <h2 className="text-ink-primary">
          Your ear catches what your eye misses
        </h2>
        <p className="lead mt-6 text-ink-body leading-relaxed">
          Reading silently, your brain auto-corrects. It fills in missing words,
          smooths over clumsy transitions, and skips right past that sentence
          you rewrote three times but never finished fixing. Listening breaks
          the spell. When you hear your writing spoken aloud, every stumble
          becomes obvious — and the fix usually follows within seconds.
        </p>
      </Container>
    </section>
  );
}
