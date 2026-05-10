import type { Metadata } from "next";
import Container from "@/components/ui/Container";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How Psitta and Facti AI LLC handle your account data, document content, audio cache, and analytics — written in plain language, not legalese.",
};

export default function Privacy() {
  return (
    <section className="py-section">
      <Container className="max-w-3xl">
        <h1 className="text-ink-primary">Privacy Policy</h1>
        <p className="mt-2 text-sm text-ink-muted">
          Last updated: April 21, 2026
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Who we are
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Psitta is a document-to-audio product built by Facti AI LLC. This
          policy explains what information we collect when you use Psitta, how
          we use it, and the choices you have. Questions about this policy can
          be sent to support@psitta.ai.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          What we collect
        </h2>
        <ul className="mt-4 space-y-2 list-disc list-inside text-ink-body leading-relaxed">
          <li>
            Account information — your email address and display name, provided
            through Amazon Cognito when you sign up.
          </li>
          <li>
            Documents — the PDF and DOCX files you upload so that Psitta can
            convert them into audio.
          </li>
          <li>
            Payment information — handled entirely by Stripe. We never see or
            store your card numbers or banking details.
          </li>
          <li>
            Usage data — basic product analytics such as which pages you visit
            and which features you use. We do not run third-party advertising
            trackers.
          </li>
        </ul>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          How we use your data
        </h2>
        <ul className="mt-4 space-y-2 list-disc list-inside text-ink-body leading-relaxed">
          <li>
            To provide the service — your documents are processed to produce
            text-to-speech audio that you can play back in the app.
          </li>
          <li>
            To manage your account and subscription, including billing and
            plan changes.
          </li>
          <li>
            To improve the product based on aggregate usage patterns.
          </li>
          <li>We do not sell your data to third parties.</li>
          <li>
            We do not use your documents or audio to train AI or
            machine-learning models.
          </li>
        </ul>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Document processing
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Uploaded documents are processed server-side for text extraction and
          sentence segmentation. Audio is then synthesized using third-party
          text-to-speech providers — currently ElevenLabs and Microsoft Azure.
          Document text is sent to these providers solely for audio synthesis;
          per our contracts with them, they do not retain your content.
          Generated audio is cached in AWS S3 so that replaying a document with
          the same voice does not require re-synthesis.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Data storage and security
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Your data is stored on AWS infrastructure in the US-East-1 region.
          All traffic between your device and our servers is encrypted in
          transit with TLS, and data at rest is encrypted using AWS-managed
          keys. Access to production systems is controlled by scoped IAM
          policies, and sensitive actions are written to an append-only audit
          log. We retain your documents and cached audio for as long as your
          account is active.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Third-party services
        </h2>
        <ul className="mt-4 space-y-2 list-disc list-inside text-ink-body leading-relaxed">
          <li>
            Amazon Web Services — hosting, storage, and authentication
            (Cognito).
          </li>
          <li>Stripe — subscription billing and payment processing.</li>
          <li>ElevenLabs — premium neural text-to-speech synthesis.</li>
          <li>Microsoft Azure — neural text-to-speech synthesis.</li>
        </ul>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Your rights
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          You can export or delete your data at any time by emailing
          support@psitta.ai. You can cancel your subscription at any time from
          within the app or from the billing portal. When you delete your
          account, your documents and cached audio are permanently removed
          from our systems within 30 days.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Children&apos;s privacy
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          Psitta is not intended for children under 13. We do not knowingly
          collect personal information from children. If you believe a child
          has provided us with personal information, contact
          support@psitta.ai and we will delete it.
        </p>

        <h2 className="mt-12 text-xl font-semibold text-ink-primary">
          Changes to this policy
        </h2>
        <p className="mt-4 text-ink-body leading-relaxed">
          We may update this policy from time to time. When we do, we will
          post the revised policy on this page and update the &ldquo;Last
          updated&rdquo; date above. Continued use of Psitta after the changes
          take effect constitutes acceptance of the revised policy.
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
