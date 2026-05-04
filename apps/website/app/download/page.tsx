import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import Button from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Download Psitta for Windows",
};

const requirements: Array<{ label: string; value: string }> = [
  { label: "Operating system", value: "Windows 10 or Windows 11" },
  { label: "Architecture", value: "64-bit (x64)" },
  { label: "Disk space", value: "~150 MB" },
  {
    label: "Internet",
    value: "Required for premium TTS voices and account sync",
  },
];

const installSteps: string[] = [
  "Click the Download button above",
  "Open the downloaded psitta.appinstaller file",
  "Click Install — no admin rights required",
  "Psitta appears in your Start menu. Launch and sign in.",
];

export default function Download() {
  return (
    <section className="py-section">
      <Container className="max-w-3xl">
        <h1 className="text-ink-primary text-center">
          Download Psitta for Windows
        </h1>
        <p className="lead mt-4 text-center text-ink-muted">
          Listen to your documents. Improve your writing.
        </p>

        <div className="mt-16 rounded-2xl border border-edge-subtle p-8 md:p-12 text-center">
          <div className="mx-auto mb-6 flex h-20 w-20 items-center justify-center rounded-2xl bg-psitta-50 text-psitta-600">
            <svg
              width={24}
              height={24}
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={1.75}
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden
            >
              <path d="M12 4v12" />
              <path d="m6 10 6 6 6-6" />
              <path d="M4 20h16" />
            </svg>
          </div>

          <p className="text-sm text-ink-muted">
            Version 1.0.5.0 · Windows 10/11 · 64-bit
          </p>

          <Button
            href="https://download.psitta.ai/psitta.appinstaller"
            variant="primary"
            size="lg"
            className="mt-6"
          >
            Download for Windows
          </Button>

          <p className="mt-4 text-xs text-ink-muted">
            One-click install · Auto-updates as new versions ship
          </p>
        </div>

        <div className="mt-16">
          <h2 className="text-lg font-semibold text-ink-primary">
            System requirements
          </h2>
          <dl className="mt-6 space-y-4">
            {requirements.map((req) => (
              <div key={req.label} className="flex flex-col sm:flex-row sm:gap-4">
                <dt className="text-sm font-medium text-ink-primary sm:w-40 shrink-0">
                  {req.label}
                </dt>
                <dd className="text-sm text-ink-body">{req.value}</dd>
              </div>
            ))}
          </dl>
        </div>

        <div className="mt-16">
          <h2 className="text-lg font-semibold text-ink-primary">
            How to install
          </h2>
          <ol className="mt-6 space-y-4 list-decimal list-inside text-sm text-ink-body">
            {installSteps.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ol>
        </div>
      </Container>
    </section>
  );
}
