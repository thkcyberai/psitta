import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import Logo from "@/components/brand/Logo";
import MakerNote from "@/components/home/MakerNote";
import FeatureStrip from "@/components/home/FeatureStrip";
import WhyListening from "@/components/home/WhyListening";

export default function Home() {
  return (
    <>
      <section className="pt-section pb-section-lg">
        <Container className="text-center">
          <div className="flex justify-center mb-8">
            <Logo variant="bird" size="3xl" priority />
          </div>

          <h1 className="text-ink-primary max-w-4xl mx-auto">
            Listen to your documents.
            <br />
            <span className="text-gradient-soft">Improve your writing.</span>
          </h1>

          <p className="lead mt-8 max-w-2xl mx-auto">
            Hear your writing the way your readers will. Psitta reads your documents aloud —
            so you catch awkward phrasing, broken rhythm, and unclear passages before anyone else does.
          </p>

          <div className="mt-10 flex flex-wrap items-center justify-center gap-4">
            <Button href="/download" variant="primary" size="lg">
              Download for Windows
            </Button>
            <Button href="/pricing" variant="secondary" size="lg">
              See pricing
            </Button>
          </div>

          <p className="mt-8 text-sm text-ink-muted">
            Free tier available · No credit card required to start
          </p>

          <p className="mt-4 text-sm text-ink-muted">
            Not ready to download?{" "}
            <a href="/signup" className="text-psitta-600 hover:text-psitta-700 underline-offset-4 hover:underline">
              Get notified when we ship new features →
            </a>
          </p>
        </Container>
      </section>

      <FeatureStrip />

      <WhyListening />

      <MakerNote />
    </>
  );
}
