"use client";

import { useState, type FormEvent } from "react";

type FormData = {
  email: string;
};

type Status = "idle" | "submitting" | "success" | "error";

const EMPTY_FORM: FormData = {
  email: "",
};

const API_URL = "https://api.psitta.ai/api/v1/waitlist/creativity-nook";

const FIELD_CLASS =
  "w-full rounded-lg border border-edge-subtle bg-white px-4 py-3 text-sm text-ink-primary placeholder:text-ink-muted focus:border-psitta-600 focus:outline-none focus:ring-1 focus:ring-psitta-600";

export default function CreativityWaitlistForm() {
  const [formData, setFormData] = useState<FormData>(EMPTY_FORM);
  const [status, setStatus] = useState<Status>("idle");
  const [errorMessage, setErrorMessage] = useState<string>("");

  function updateField<K extends keyof FormData>(key: K, value: FormData[K]) {
    setFormData((prev) => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setStatus("submitting");
    setErrorMessage("");

    const payload = {
      email: formData.email,
    };

    try {
      const response = await fetch(API_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (response.ok) {
        setStatus("success");
        return;
      }

      let message = "Something went wrong. Please try again.";
      try {
        const data = (await response.json()) as { message?: string };
        if (typeof data.message === "string" && data.message.length > 0) {
          message = data.message;
        }
      } catch {
        /* response body was not JSON — keep fallback message */
      }
      setErrorMessage(message);
      setStatus("error");
    } catch {
      setErrorMessage(
        "Could not reach the server. Check your connection and try again.",
      );
      setStatus("error");
    }
  }

  if (status === "success") {
    return (
      <div className="rounded-2xl border border-edge-subtle p-6 text-center">
        <svg
          width={48}
          height={48}
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={1.75}
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
          className="mx-auto mb-4 text-green-600"
        >
          <circle cx="12" cy="12" r="10" />
          <path d="m8 12.5 2.5 2.5L16 9.5" />
        </svg>
        <h3 className="text-base font-semibold text-ink-primary">
          You&apos;re on the list.
        </h3>
        <p className="mt-1 text-sm text-ink-body">
          We&apos;ll email you when Creativity Nook launches.
        </p>
      </div>
    );
  }

  const submitting = status === "submitting";

  return (
    <form onSubmit={handleSubmit} className="text-left" noValidate>
      <input
        type="email"
        required
        placeholder="Email address"
        maxLength={255}
        value={formData.email}
        onChange={(e) => updateField("email", e.target.value)}
        disabled={submitting}
        className={FIELD_CLASS}
        aria-label="Email address"
      />

      {status === "error" && errorMessage && (
        <p role="alert" className="mt-3 text-sm text-red-600">
          {errorMessage}
        </p>
      )}

      <button
        type="submit"
        disabled={submitting}
        className="mt-3 w-full rounded-lg bg-psitta-700 px-6 py-3 text-sm font-semibold text-white hover:bg-psitta-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {submitting ? "Submitting..." : "Notify me when it launches"}
      </button>
    </form>
  );
}
