"use client";

import { useState, type FormEvent } from "react";

type FormData = {
  first_name: string;
  email: string;
};

type Status = "idle" | "submitting" | "success" | "error";

const EMPTY_FORM: FormData = {
  first_name: "",
  email: "",
};

const API_URL = "https://api.psitta.ai/api/v1/signup";

const FIELD_CLASS =
  "w-full rounded-lg border border-edge-subtle bg-white px-4 py-3 text-sm text-ink-primary placeholder:text-ink-muted focus:border-psitta-600 focus:outline-none focus:ring-1 focus:ring-psitta-600";

export default function SignupForm() {
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
      first_name: formData.first_name,
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
      <div className="rounded-2xl border border-edge-subtle p-8 md:p-12 text-center">
        <svg
          width={64}
          height={64}
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth={1.75}
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
          className="mx-auto mb-6 text-green-600"
        >
          <circle cx="12" cy="12" r="10" />
          <path d="m8 12.5 2.5 2.5L16 9.5" />
        </svg>
        <h3 className="text-lg font-semibold text-ink-primary">Thanks!</h3>
        <p className="mt-2 text-sm text-ink-body">
          We&apos;ll let you know when Psitta is ready for you.
        </p>
      </div>
    );
  }

  const submitting = status === "submitting";

  return (
    <form onSubmit={handleSubmit} className="text-left" noValidate>
      <input
        type="text"
        required
        placeholder="First name"
        maxLength={100}
        value={formData.first_name}
        onChange={(e) => updateField("first_name", e.target.value)}
        disabled={submitting}
        className={FIELD_CLASS}
        aria-label="First name"
      />

      <input
        type="email"
        required
        placeholder="Email address"
        maxLength={255}
        value={formData.email}
        onChange={(e) => updateField("email", e.target.value)}
        disabled={submitting}
        className={`${FIELD_CLASS} mt-4`}
        aria-label="Email address"
      />

      {status === "error" && errorMessage && (
        <p role="alert" className="mt-4 text-sm text-red-600">
          {errorMessage}
        </p>
      )}

      <button
        type="submit"
        disabled={submitting}
        className="mt-4 w-full rounded-lg bg-psitta-700 px-6 py-3 text-sm font-semibold text-white hover:bg-psitta-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {submitting ? "Submitting..." : "Get notified"}
      </button>
    </form>
  );
}
