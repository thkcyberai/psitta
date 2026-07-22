import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";
import NewsletterForm from "@/components/NewsletterForm";

export const metadata: Metadata = {
  title: "Download Psitta for Windows",
  description:
    "Psitta is the writing platform for people finishing books — draft, structure, get honest AI insight, and hear your words in a natural human voice, all in your own language. Install free for Windows 10/11.",
};

const valuePoints: Array<{ title: string; body: string }> = [
  {
    title: "A real place to write.",
    body: "The Writing Desk is where your book actually gets written — your work held in Projects and a Library, so drafting feels like a desk that's yours, not a blank screen.",
  },
  {
    title: "Give your book its bones.",
    body: "Break your manuscript into parts, chapters, and sections with Blueprints — a real, navigable outline where you always know where you are.",
  },
  {
    title: "Frameworks that hold your arc.",
    body: "Check your story against the structures that work — three-act, save-the-cat, hero's journey, seven-point, snowflake — beat by beat, so the arc holds up after the first spark fades.",
  },
  {
    title: "AI that tells you the truth.",
    body: "Summarize It gives honest, chapter-by-chapter recaps of what you actually wrote — not what you meant to. Story-Coach nudges you back on course when the writing drifts.",
  },
  {
    title: "Edit by ear.",
    body: "Hear your draft read back in a natural human voice with word-by-word highlighting, in premium voices across languages. The clumsy sentence gives itself away the moment you hear it.",
  },
  {
    title: "In your language, start to finish.",
    body: "English, Portuguese, Spanish, French — one flag click switches the entire platform. Already have a draft? Bring your Word or PDF manuscript in and get the full Writing Nook on work you've started.",
  },
];

const requirements: Array<{ label: string; value: string }> = [
  { label: "Operating system", value: "Windows 10 or Windows 11" },
  { label: "Architecture", value: "64-bit (x64)" },
  { label: "Disk space", value: "~150 MB" },
  {
    label: "Internet",
    value: "Required for natural voices, AI, and account sync",
  },
];

const installSteps: string[] = [
  "Click the Download button above",
  "Open the downloaded psitta.appinstaller file",
  "Click Install — no admin rights required",
  "Psitta appears in your Start menu. Launch and create your free account.",
];

export default function Download() {
  return (
    <section className="py-section">
      <Container className="max-w-3xl">
        {/* Hero */}
        <h1 className="text-center text-ink-primary">
          Write it. Shape it. Hear it come to life.
        </h1>
        <p className="lead mx-auto mt-5 max-w-2xl text-center text-ink-muted">
          Psitta is the writing platform for people finishing books — draft,
          structure, get honest AI insight, and hear your words in a natural
          human voice, all in your own language. Everything you need to finish
          a book you&apos;re proud of, in one place.
        </p>

        {/* Download card */}
        <div className="mt-12 rounded-2xl border border-edge-subtle p-8 text-center md:p-12">
          <p className="text-sm font-medium text-psitta-600">
            The professional writing platform for authors — Windows desktop
          </p>

          <Button
            href="https://download.psitta.ai/psitta.appinstaller"
            variant="primary"
            size="lg"
            className="mt-6"
          >
            Download Psitta
          </Button>

          <p className="mx-auto mt-4 max-w-md text-xs text-ink-muted">
            Start with the full Writing Nook experience free for 14 days — no
            card until you subscribe. Auto-updates as new versions ship.
          </p>
        </div>

        {/* Value sections */}
        <div className="mt-20 grid gap-8 sm:grid-cols-2">
          {valuePoints.map((point) => (
            <div key={point.title}>
              <h3 className="text-base font-semibold text-ink-primary">
                {point.title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-ink-body">
                {point.body}
              </p>
            </div>
          ))}
        </div>

        {/* Conversion block */}
        <div className="mt-20 rounded-2xl border border-edge-subtle bg-paper-subtle p-8 text-center md:p-12">
          <h2 className="text-xl font-semibold text-ink-primary">
            Keep the platform that finishes your book.
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-sm leading-relaxed text-ink-body">
            Your 14-day trial opens the complete Writing Nook — the Writing
            Desk, Blueprints, narrative frameworks, Summarize It, Story-Coach,
            and Reading &amp; Revision, all working together on your book. One
            platform, every stage of your manuscript — so the book you&apos;re
            proud of actually gets finished.
          </p>
          <Button href="/pricing" variant="primary" size="md" className="mt-6">
            See everything included in Writing Nook
          </Button>
        </div>

        {/* Newsletter */}
        <div className="mt-20">
          <h2 className="text-lg font-semibold text-ink-primary">
            Notes from the writing desk.
          </h2>
          <p className="mt-2 max-w-2xl text-sm text-ink-body">
            Craft that helps you finish, plus the new Psitta features built to
            get you there — a few times a month, never noise.
          </p>
          <div className="mt-6 max-w-lg">
            <NewsletterForm />
          </div>
        </div>

        {/* System requirements */}
        <div className="mt-20">
          <h2 className="text-lg font-semibold text-ink-primary">
            System requirements
          </h2>
          <dl className="mt-6 space-y-4">
            {requirements.map((req) => (
              <div key={req.label} className="flex flex-col sm:flex-row sm:gap-4">
                <dt className="shrink-0 text-sm font-medium text-ink-primary sm:w-40">
                  {req.label}
                </dt>
                <dd className="text-sm text-ink-body">{req.value}</dd>
              </div>
            ))}
          </dl>
        </div>

        {/* How to install */}
        <div className="mt-16">
          <h2 className="text-lg font-semibold text-ink-primary">
            How to install
          </h2>
          <ol className="mt-6 list-inside list-decimal space-y-4 text-sm text-ink-body">
            {installSteps.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ol>
        </div>
      </Container>
    </section>
  );
}
