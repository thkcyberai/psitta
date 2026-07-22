import type { Metadata } from "next";
import Link from "next/link";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Support",
  description:
    "FAQs covering install, Writing Nook, trials and subscriptions, document handling, and troubleshooting — plus a direct line to the team behind Psitta when you need a person.",
};

type Faq = {
  q: string;
  a: string[];
};

const faqs: Faq[] = [
  {
    q: "How do I install Psitta?",
    a: [
      "Visit psitta.ai/download on a Windows 10 or 11 PC. Click the Install button to download psitta.appinstaller, then open the downloaded file. Windows App Installer launches automatically — click Install. Psitta appears in your Start menu within 60 seconds. No admin rights required.",
    ],
  },
  {
    q: "Does Psitta have a web or mobile version?",
    a: [
      "Psitta is currently a Windows desktop application — that's where writers do their deepest work. We're focused on shipping the best possible Windows experience first. macOS and mobile companion apps are on our roadmap, but we're not announcing dates yet. Want to be notified when they launch? Email support@psitta.ai and we'll add you to the announcement list.",
    ],
  },
  {
    q: "What document types does Psitta support?",
    a: [
      "Currently: PDF, DOCX, and plain text. We're working on EPUB, HTML, and Markdown for future releases.",
    ],
  },
  {
    q: "Can I use Psitta offline?",
    a: [
      "No. Psitta requires an internet connection to synthesize voice and check for updates. Your documents stay private to your account, but voice generation happens server-side.",
    ],
  },
  {
    q: "What is included in Writing Nook?",
    a: [
      "Writing Nook is the complete Psitta platform: the full Writing Desk, unlimited projects, Blueprints with 25+ narrative structures, scene mapping and progress tracking, Story-Coach, the Structure Analyzer, AI assistance, and writing analytics — plus Reading & Revision with premium natural voices, word-level highlighting, and playback up to 4×.",
      "Each billing period includes 250,000 premium voice characters and a generous AI allowance. If you use up the premium voice allowance, Psitta switches to standard voices for the rest of the period — playback never interrupts — and everything resets at your next billing cycle.",
    ],
  },
  {
    q: "What happens after my Writing Nook trial ends?",
    a: [
      "Your 14-day trial includes everything in Writing Nook. When it ends, your subscription starts on the plan you chose at checkout — nothing changes in the app, you just keep writing.",
      "If you cancel before the trial ends (Settings → Manage Subscription), you won't be charged. You can keep writing on the free experience: your documents and projects stay exactly where they are, listening continues with standard voices, and the premium capabilities simply lock until you subscribe again.",
    ],
  },
  {
    q: "How do upgrades work?",
    a: [
      "Everything starts inside the app. Create your free account, and when you're ready, start your 14-day Writing Nook free trial from the Plans screen — checkout is handled securely by Stripe. You can switch between monthly and annual, or cancel, at any time from Settings → Manage Subscription.",
    ],
  },
  {
    q: "What is Creative Nook?",
    a: [
      "Creative Nook is coming soon. It builds on everything in Writing Nook and adds a full Creative Studio — inside the same Psitta application, no separate app. It isn't purchasable yet; you can join the waitlist on the pricing page and we'll email you when it launches.",
    ],
  },
  {
    q: "How do I change my plan or cancel?",
    a: [
      "Open Psitta → Settings → click Manage Subscription — this opens the Stripe billing portal where you can change plans, update payment method, or cancel. Cancellations remain active through your current billing period.",
    ],
  },
  {
    q: "Windows is showing a warning when I install. Is Psitta safe?",
    a: [
      "Yes. Psitta is signed with our development certificate, but Windows SmartScreen flags any app it hasn't seen many times before. This is normal for new applications. Click 'More info' → 'Run anyway' to proceed. We'll move to a fully verified Microsoft Store distribution later this year.",
    ],
  },
  {
    q: "What if Psitta won't launch, or my document or playback isn't working?",
    a: [
      "Most issues fall into a few categories — try these in order:",
      "Document won't open or upload: Confirm the file is .pdf, .docx, or .txt and under 100 MB. If the file is corrupted or password-protected, Psitta won't be able to read it.",
      "Voice won't play: Check your internet connection — Psitta requires a connection for voice synthesis. If the issue continues, try Settings → restart the app.",
      "App won't launch: Try restarting your computer. If the issue persists, uninstall and reinstall via psitta.ai/download — your account, documents, and progress are saved on our servers and will restore on next sign-in.",
      "Still stuck? Email support@psitta.ai with: your Psitta version (Settings → bottom of page), your Windows version, what you were doing when the issue happened, and any error message you saw. We'll respond within 24 hours.",
    ],
  },
  {
    q: "What are Psitta's support hours?",
    a: [
      "Our support team is available Monday through Friday, 9 AM – 6 PM Mountain Time. Emails received outside those hours are answered the next business day. Critical issues affecting paid subscribers are prioritized — flag your email subject with [Urgent] for fastest response.",
    ],
  },
  {
    q: "I'm an alpha tester. How do I send feedback?",
    a: [
      "Email support@psitta.ai — your feedback shapes v1. Include the issue, what you expected, what happened, and (if useful) your Psitta version from Settings. Our support team typically responds within 24 hours.",
    ],
  },
];

export default function Support() {
  return (
    <section className="py-section">
      <Container className="max-w-3xl">
        <h1 className="text-ink-primary text-center">
          Need help? We&apos;re here.
        </h1>
        <p className="lead mt-4 text-center text-ink-muted">
          Our support team is available Monday through Friday, 9 AM – 6 PM Mountain Time.
        </p>

        <div className="mt-16 rounded-2xl border border-edge-subtle bg-paper-subtle p-8 md:p-12 text-center">
          <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-2xl bg-psitta-50 text-psitta-600">
            <svg
              width={28}
              height={28}
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={1.75}
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden
            >
              <rect x="3" y="5" width="18" height="14" rx="2" />
              <path d="m3 7 9 6 9-6" />
            </svg>
          </div>

          <Button
            href="mailto:support@psitta.ai"
            variant="primary"
            size="lg"
            external
          >
            Email support@psitta.ai
          </Button>

          <p className="mt-4 text-sm text-ink-muted">
            Typical response within 24 hours during business hours.
          </p>
        </div>

        <p className="mt-6 text-center text-sm text-ink-muted">
          For sales, partnerships, or press inquiries, use our{" "}
          <Link
            href="/contact"
            className="text-psitta-600 hover:underline"
          >
            contact form
          </Link>
          .
        </p>

        <div className="mt-20">
          <h2 className="text-xl font-semibold text-ink-primary">
            Frequently asked questions
          </h2>

          <div className="mt-8 space-y-3">
            {faqs.map((faq) => (
              <details
                key={faq.q}
                className="group rounded-xl border border-edge-subtle bg-paper-surface px-5 py-4 [&[open]>summary>svg]:rotate-90"
              >
                <summary className="flex cursor-pointer items-center justify-between gap-4 list-none [&::-webkit-details-marker]:hidden text-base font-medium text-ink-primary">
                  <span>{faq.q}</span>
                  <svg
                    width={18}
                    height={18}
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={2}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    className="shrink-0 text-ink-muted transition-transform duration-200"
                    aria-hidden
                  >
                    <path d="m9 6 6 6-6 6" />
                  </svg>
                </summary>
                <div className="mt-4 space-y-3 text-sm text-ink-body leading-relaxed">
                  {faq.a.map((paragraph, idx) => (
                    <p key={idx}>{paragraph}</p>
                  ))}
                </div>
              </details>
            ))}
          </div>
        </div>

        <p className="mt-16 text-center text-xs text-ink-muted">
          Built and supported by Facti AI LLC · Colorado, United States
        </p>
      </Container>
    </section>
  );
}
