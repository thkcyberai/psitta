import type { Metadata } from "next";
import Container from "@/components/ui/Container";

export const metadata: Metadata = {
  title: "Terms of Service — Psitta",
};

export default function Terms() {
  return (
    <section className="py-section">
      <Container className="max-w-3xl">
        <h1 className="text-ink-primary">Terms of Service</h1>
        <p className="mt-2 text-sm text-ink-muted">
          Last updated: April 21, 2026
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Agreement to terms
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          By using Psitta you agree to these terms. If you do not agree to any
          part of them, please do not use the service. These terms apply to
          the Psitta desktop application and to the psitta.ai website.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Description of service
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Psitta is a document-to-audio desktop application. It converts PDF
          and DOCX documents into spoken audio with sentence-level highlighting
          synchronized to playback. The service is offered in a free tier and
          one or more paid subscription tiers.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Accounts
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          You must create an account to use Psitta. You are responsible for
          keeping your account credentials secure and for any activity that
          happens under your account. You must provide accurate information
          when signing up and keep it up to date.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Subscriptions and billing
        </h2>
        <ul className="mt-4 space-y-2 list-disc list-inside text-ink-body leading-relaxed">
          <li>
            Free tier — limited to 3 documents per month using Edge TTS voices.
          </li>
          <li>
            Pro tier — $14.99 per month or $99 per year, including premium
            voices and higher usage limits.
          </li>
          <li>
            All payments are processed by Stripe. Prices are in US dollars
            unless otherwise stated.
          </li>
          <li>
            You can cancel at any time. Access to paid features continues
            until the end of the current billing period, after which your
            account reverts to the free tier.
          </li>
          <li>
            Refund requests are handled on a case-by-case basis. To request
            one, email support@psitta.ai.
          </li>
        </ul>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Acceptable use
        </h2>
        <ul className="mt-4 space-y-2 list-disc list-inside text-ink-body leading-relaxed">
          <li>
            You may only upload documents you have the right to use, read, or
            convert to audio.
          </li>
          <li>You may not use Psitta for any illegal purpose.</li>
          <li>
            You may not attempt to reverse-engineer, modify, or redistribute
            the application or its underlying services.
          </li>
          <li>
            We reserve the right to suspend or terminate accounts that violate
            these terms.
          </li>
        </ul>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Intellectual property
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Psitta, including its software, branding, and original content, is
          owned by Facti AI LLC. The documents you upload remain your property
          — we claim no ownership of the content you provide. The audio
          generated from your documents is for your personal use.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Limitation of liability
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Psitta is provided &ldquo;as is,&rdquo; without warranties of any
          kind, either express or implied. To the maximum extent permitted by
          law, Facti AI LLC is not liable for any indirect, incidental,
          special, or consequential damages arising out of your use of the
          service. Our total liability under these terms is limited to the
          amount you paid us in the twelve months preceding the claim.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Termination
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          You may stop using Psitta and close your account at any time. We may
          suspend or terminate your access if you violate these terms. Upon
          termination, your right to use the service ceases immediately, and
          the data-retention rules in our Privacy Policy apply.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Changes to terms
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          We may modify these terms at any time. When we do, we will post the
          revised terms on this page and update the &ldquo;Last updated&rdquo;
          date above. Continued use of Psitta after the changes take effect
          constitutes acceptance of the revised terms.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Governing law
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          These terms are governed by the laws of the State of Colorado,
          United States, without regard to its conflict-of-law provisions.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Contact
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Email: support@psitta.ai
          <br />
          Company: Facti AI LLC
        </p>
      </Container>
    </section>
  );
}
