import type { Metadata } from "next";
import Container from "@/components/ui/Container";
import SignupForm from "@/components/signup/SignupForm";

export const metadata: Metadata = {
  title: "Get notified",
  robots: { index: false, follow: true },
};

export default function Signup() {
  return (
    <section className="py-section">
      <Container className="max-w-2xl">
        <h1 className="text-ink-primary text-center">Get notified</h1>
        <p className="lead mt-4 text-center text-ink-muted max-w-xl mx-auto">
          Psitta is launching soon. Drop your email and we&apos;ll let you
          know the moment it&apos;s ready for you.
        </p>

        <div className="mt-12">
          <SignupForm />
        </div>

        <p className="mt-8 text-center text-sm text-ink-muted">
          We&apos;ll email you about Psitta updates. No spam, unsubscribe
          anytime.
        </p>
      </Container>
    </section>
  );
}
