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
    absolute: "Psitta — Listen to your documents. Improve your writing.",
  },
  description:
    "Psitta turns your documents into audio so writers and editors can hear their work. Catch awkward phrasing, rhythm issues, and unclear passages by listening.",
};

const organizationSchema = {
  "@context": "https://schema.org",
  "@type": "Organization",
  name: "Facti AI LLC",
  url: "https://psitta.ai",
  logo: "https://psitta.ai/brand/psitta-horizontal.png",
  description:
    "Facti AI LLC builds Psitta, a desktop application that reads your documents aloud so writers and editors can hear their own writing.",
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
    "Psitta reads your documents aloud — PDFs and Word documents — with sentence-level and word-level highlighting synchronized to the audio. Built for writers and editors who want to hear their own writing.",
  url: "https://psitta.ai",
  applicationCategory: "ProductivityApplication",
  operatingSystem: "Windows 10, Windows 11",
  offers: [
    {
      "@type": "Offer",
      name: "Reading Nook Free",
      price: "0",
      priceCurrency: "USD",
      description: "Free tier with 3 documents per month and Edge TTS voices",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (monthly)",
      price: "14.99",
      priceCurrency: "USD",
      description:
        "Unlimited documents, premium voices, word-level highlighting",
    },
    {
      "@type": "Offer",
      name: "Reading Nook Pro (annual)",
      price: "99",
      priceCurrency: "USD",
      description: "Annual subscription, saves ~44% vs monthly",
    },
  ],
  publisher: {
    "@type": "Organization",
    name: "Facti AI LLC",
    url: "https://psitta.ai",
  },
};

export default function Home() {
  return (
    <>
      <JsonLd data={organizationSchema} />
      <JsonLd data={softwareApplicationSchema} />
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
