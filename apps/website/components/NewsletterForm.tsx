"use client";

import { useState, type FormEvent } from "react";

// Loops newsletter form endpoint. Create a Form in Loops (Forms → New form,
// connected to your newsletter list) and paste its form ID here — or set
// NEXT_PUBLIC_LOOPS_FORM_ID in the build environment. The endpoint is public
// and CORS-enabled, so no server key is exposed.
const LOOPS_FORM_ID =
  process.env.NEXT_PUBLIC_LOOPS_FORM_ID ?? "REPLACE_WITH_LOOPS_FORM_ID";

type Status = "idle" | "loading" | "success" | "error";

export default function NewsletterForm() {
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState("");

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!email || status === "loading") return;
    setStatus("loading");
    try {
      const res = await fetch(
        `https://app.loops.so/api/newsletter-form/${LOOPS_FORM_ID}`,
        {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({ email }).toString(),
        },
      );
      const data = (await res.json().catch(() => ({}))) as {
        success?: boolean;
        message?: string;
      };
      if (res.ok && data.success !== false) {
        setStatus("success");
        setMessage("You're on the list. Talk soon.");
        setEmail("");
      } else {
        setStatus("error");
        setMessage(data.message || "Something went wrong — please try again.");
      }
    } catch {
      setStatus("error");
      setMessage("Something went wrong — please try again.");
    }
  }

  if (status === "success") {
    return <p className="text-sm font-medium text-psitta-700">{message}</p>;
  }

  return (
    <div>
      <form onSubmit={handleSubmit} className="flex flex-col gap-3 sm:flex-row">
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="you@email.com"
          aria-label="Email address"
          className="flex-1 rounded-md border border-edge-default bg-paper-surface px-4 py-2.5 text-base text-ink-primary placeholder:text-ink-muted focus:border-psitta-600 focus:outline-none"
        />
        <button
          type="submit"
          disabled={status === "loading"}
          className="inline-flex items-center justify-center rounded-md border border-psitta-800/20 bg-psitta-700 px-5 py-2.5 text-base font-semibold text-white shadow-sm transition-colors hover:bg-psitta-600 disabled:opacity-60"
        >
          {status === "loading" ? "Subscribing…" : "Subscribe to the newsletter"}
        </button>
      </form>
      {status === "error" && (
        <p className="mt-2 text-sm text-red-600">{message}</p>
      )}
      <p className="mt-3 text-xs text-ink-muted">
        No spam. Unsubscribe anytime.
      </p>
    </div>
  );
}
