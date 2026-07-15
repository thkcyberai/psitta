import Image from "next/image";

// Full-screen maintenance page. Rendered by the root layout for EVERY route
// when NEXT_PUBLIC_MAINTENANCE === "1" at build time. No Header/Footer/nav —
// this is the only thing a visitor sees. Flip the flag off and rebuild to
// restore the normal site.
export default function Maintenance() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-paper px-6 py-16">
      <div className="w-full max-w-lg text-center">
        <div className="mb-10 flex items-center justify-center gap-3">
          <Image
            src="/brand/psitta-bird.png"
            alt="Psitta"
            width={40}
            height={40}
            priority
            className="h-10 w-10"
          />
          <span className="text-xl font-semibold tracking-tight text-psitta-700">
            Psitta
          </span>
        </div>

        <div className="inline-flex items-center gap-2 rounded-full border border-psitta-200 bg-paper-surface px-3.5 py-1.5 text-xs font-medium text-psitta-700">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-psitta-400 opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-psitta-500" />
          </span>
          Scheduled maintenance
        </div>

        <h1 className="mt-7 text-3xl font-bold tracking-tight text-ink-primary sm:text-4xl">
          We&rsquo;ll be back shortly
        </h1>

        <p className="mx-auto mt-4 max-w-md text-base leading-relaxed text-ink-body">
          Psitta is temporarily offline while we perform scheduled maintenance
          and roll out improvements to the writing studio. We expect to be back
          online soon.
        </p>

        <p className="mx-auto mt-3 max-w-md text-base leading-relaxed text-ink-body">
          Your account and all of your work are safe. No action is needed on
          your part — please check back in a little while.
        </p>

        <p className="mt-10 text-sm text-ink-muted">
          For urgent matters, contact{" "}
          <a
            href="mailto:luis@psitta.ai"
            className="font-medium text-psitta-700 underline underline-offset-2 hover:text-psitta-600"
          >
            luis@psitta.ai
          </a>
        </p>

        <p className="mt-12 text-xs text-ink-muted">
          &copy; {new Date().getFullYear()} Facti AI LLC
        </p>
      </div>
    </main>
  );
}
