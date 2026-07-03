import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import Logo from "@/components/brand/Logo";
import MakerNote from "@/components/home/MakerNote";
import FeatureStrip from "@/components/home/FeatureStrip";
import WhyListening from "@/components/home/WhyListening";
import JsonLd from "@/components/seo/JsonLd";

export const metadata: Metadata = {
  title: {
    absolute: "Psitta — Hear your words. Finish your book.",
  },
  description:
    "Psitta is a writing platform for authors, students, and everyday writers: outline with Blueprints, draft in a focused Writing Desk with Story-Coach, and hear every line read aloud to catch what your eye misses. Free tier, Windows.",
};

const organizationSchema = {
  "@context": "https://schema.org",
  "@type": "Organization",
  name: "Facti AI LLC",
  url: "https://psitta.ai",
  logo: "https://psitta.ai/brand/psitta-horizontal.png",
  description:
    "Facti AI LLC builds Psitta, a writing platform that helps writers structure, draft, and finish their books — and hear every line read aloud so they catch what their eye misses.",
  email: "support@psitta.ai",
  address: {
    "@type": "PostalAddress",
    addressRegion: "Colorado",
    addressCountry: "US",
  },
};

const softwareApplicationSchema = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Psitta",
  description:
    "Psitta is a writing platform: outline with Blueprints and 25+ narrative structures, draft in a focused Writing Desk with a live Story-Coach, and hear every line read aloud (PDF, DOCX, HTML, TXT, MD, EPUB) with word-level highlighting. Built for authors, students, and everyday writers.",
  url: "https://psitta.ai",
  applicationCategory: "ProductivityApplication",
  operatingSystem: "Windows 10, Windows 11",
  offers: [
    {
      "@type": "Offer",
      name: "Reading Nook Free",
      price: "0",
      priceCurrency: "USD",
      description: "Free tier with 10 documents per month and Edge TTS voices",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (monthly)",
      price: "14.99",
      priceCurrency: "USD",
      description:
        "Premium voices, word-level highlighting, and 50 documents per month",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (annual)",
      price: "152",
      priceCurrency: "USD",
      description: "Annual Reading Nook Pro — saves ~15% vs monthly",
    },
    {
      "@type": "Offer",
      name: "Writing Nook Pro (monthly)",
      price: "17.99",
      priceCurrency: "USD",
      description:
        "Full Writing Desk, Blueprints & 25+ structures, Story-Coach, Structure Analyzer, and writing analytics",
    },
    {
      "@type": "Offer",
      name: "Writing Nook Pro (annual)",
      price: "183",
      priceCurrency: "USD",
      description: "Annual Writing Nook Pro — saves ~15% vs monthly",
    },
    {
      "@type": "Offer",
      name: "Creative Nook Pro (monthly)",
      price: "29.99",
      priceCurrency: "USD",
      description:
        "Everything in Writing Nook plus the Creative Studio (coming soon)",
    },
  ],
  publisher: {
    "@type": "Organization",
    name: "Facti AI LLC",
    url: "https://psitta.ai",
  },
};

type Highlight = { title: string; description: string };

const writingHighlights: Highlight[] = [
  {
    title: "Full Writing Desk",
    description:
      "A focused, distraction-free editor built for long-form. Draft and revise with Psitta reading every line back to you.",
  },
  {
    title: "Blueprints & 25+ structures",
    description:
      "Outline with proven frameworks — Three-Act, Save the Cat, Seven-Point, Snowflake — each with a step-by-step guide.",
  },
  {
    title: "Scene mapping & progress",
    description:
      "Map scenes onto your outline and watch your manuscript's progress build automatically as you write toward the end.",
  },
  {
    title: "Story-Coach",
    description:
      "A live coach that nudges you the moment a scene drifts from your outline — so you course-correct as you write, not on the rewrite.",
  },
  {
    title: "Structure Analyzer",
    description:
      "Analyze your draft against your chosen structure and get concrete, section-by-section feedback on pacing and gaps.",
  },
  {
    title: "Hear every line",
    description:
      "The Psitta core: listen to any draft with word-level highlighting and catch the awkward sentence your eye skips over.",
  },
];

export default function Home() {
  return (
    <>
      <JsonLd data={organizationSchema} />
      <JsonLd data={softwareApplicationSchema} />

      {/* Hero — Writing Nook forward */}
      <section className="pt-4 pb-section">
        <Container className="text-center">
          <div className="flex justify-center mb-2">
            <Logo variant="bird" size="2xl" priority />
          </div>

          <p className="text-xs font-semibold uppercase tracking-[0.2em] text-psitta-600">
            The Writing Nook
          </p>

          <h1 className="text-ink-primary max-w-4xl mx-auto mt-3">
            Hear your words.
            <br />
            <span className="text-gradient-soft">Finish your book.</span>
          </h1>

          <p className="mt-6 max-w-2xl mx-auto text-ink-muted">
            Meet Maya — she&apos;ll let you know more about how Psitta helps you
            structure, draft, and finish your book.
          </p>

          <div className="mt-6 mx-auto max-w-4xl overflow-hidden rounded-2xl border border-edge-subtle bg-paper-surface shadow-sm">
            <video
              className="aspect-video w-full h-full object-cover bg-paper-subtle"
              controls
              preload="auto"
            >
              <source src="/brand/maya-writing-nook.mp4" type="video/mp4" />
              Your browser doesn&apos;t support embedded video.{" "}
              <a href="/brand/maya-writing-nook.mp4">Download the video</a>.
            </video>
          </div>

          <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
            <Button href="/download" variant="primary" size="lg">
              Start writing with Psitta
            </Button>
            <Button href="/pricing" variant="secondary" size="lg">
              See pricing
            </Button>
          </div>

          <p className="mt-6 text-sm text-ink-muted">
            Free tier available · No credit card required to start
          </p>
        </Container>
      </section>

      {/* Writing Nook highlights */}
      <section className="py-section bg-paper-surface">
        <Container>
          <div className="max-w-2xl mx-auto text-center">
            <p className="text-xs font-semibold uppercase tracking-wider text-psitta-600">
              Writing Nook
            </p>
            <h2 className="mt-2 text-ink-primary">
              Everything you need to finish the book
            </h2>
            <p className="lead mt-4 text-ink-muted">
              A full writing platform — not just a reader. Structure it, draft
              it, and hear every line, all in one place.
            </p>
          </div>

          <div className="mt-14 grid grid-cols-1 md:grid-cols-3 gap-x-10 gap-y-10 max-w-5xl mx-auto">
            {writingHighlights.map((h) => (
              <div key={h.title}>
                <h3 className="text-base font-semibold text-ink-primary">
                  {h.title}
                </h3>
                <p className="mt-2 text-sm text-ink-body leading-relaxed">
                  {h.description}
                </p>
              </div>
            ))}
          </div>

          <div className="mt-14 text-center">
            <Button href="/product" variant="secondary" size="lg">
              Explore the Writing Nook
            </Button>
          </div>
        </Container>
      </section>

      <FeatureStrip />

      <WhyListening />

      <MakerNote />
    </>
  );
}
