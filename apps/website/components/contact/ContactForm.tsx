"use client";

import { useState, type FormEvent } from "react";

type FormData = {
  first_name: string;
  last_name: string;
  email: string;
  phone: string;
  message: string;
};

type Status = "idle" | "submitting" | "success" | "error";

const EMPTY_FORM: FormData = {
  first_name: "",
  last_name: "",
  email: "",
  phone: "",
  message: "",
};

const API_URL = "https://api.psitta.ai/api/v1/contact";

const FIELD_CLASS =
  "w-full rounded-lg border border-edge-subtle bg-white px-4 py-3 text-sm text-ink-primary placeholder:text-ink-muted focus:border-psitta-600 focus:outline-none focus:ring-1 focus:ring-psitta-600";

export default function ContactForm() {
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
      last_name: formData.last_name,
      email: formData.email,
      phone: formData.phone.trim() === "" ? null : formData.phone,
      message: formData.message,
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

      let message =
        "Something went wrong. Please try again or email support@psitta.ai directly.";
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
        "Could not reach the server. Check your connection and try again, or email support@psitta.ai directly.",
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
        <h3 className="text-lg font-semibold text-ink-primary">Thank you!</h3>
        <p className="mt-2 text-sm text-ink-body">
          We will get back to you soon.
        </p>
      </div>
    );
  }

  const submitting = status === "submitting";

  return (
    <form onSubmit={handleSubmit} className="text-left" noValidate>
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
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
          type="text"
          required
          placeholder="Last name"
          maxLength={100}
          value={formData.last_name}
          onChange={(e) => updateField("last_name", e.target.value)}
          disabled={submitting}
          className={FIELD_CLASS}
          aria-label="Last name"
        />
      </div>

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

      <input
        type="tel"
        placeholder="Phone (optional)"
        maxLength={30}
        value={formData.phone}
        onChange={(e) => updateField("phone", e.target.value)}
        disabled={submitting}
        className={`${FIELD_CLASS} mt-4`}
        aria-label="Phone (optional)"
      />

      <textarea
        required
        rows={5}
        placeholder="Your message"
        maxLength={5000}
        value={formData.message}
        onChange={(e) => updateField("message", e.target.value)}
        disabled={submitting}
        className={`${FIELD_CLASS} mt-4 resize-none`}
        aria-label="Your message"
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
        {submitting ? "Submitting..." : "Send message"}
      </button>
    </form>
  );
}
