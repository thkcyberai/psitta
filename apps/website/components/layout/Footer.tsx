import Link from "next/link";
import Logo from "@/components/brand/Logo";
import Container from "@/components/ui/Container";

const NAV_SECTIONS = [
  {
    title: "Product",
    links: [
      { label: "Features", href: "/#features" },
      { label: "Pricing", href: "/pricing" },
      { label: "Download", href: "/download" },
    ],
  },
  {
    title: "Company",
    links: [
      { label: "About", href: "/about" },
      { label: "Contact", href: "/contact" },
    ],
  },
  {
    title: "Legal",
    links: [
      { label: "Privacy", href: "/privacy" },
      { label: "Terms", href: "/terms" },
    ],
  },
];

export default function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="mt-section border-t border-edge-subtle bg-paper-subtle">
      <Container className="py-16 md:py-20">
        <div className="grid grid-cols-2 gap-8 md:grid-cols-4 md:gap-8 lg:gap-16">
          <div className="col-span-2 md:col-span-1 md:pr-4">
            <Logo variant="horizontal" size="md" />
            <p className="mt-4 text-sm text-ink-muted">
              Listen to your documents. Improve your writing.
            </p>
          </div>

          {NAV_SECTIONS.map((section) => (
            <div key={section.title}>
              <h4 className="text-sm font-semibold text-ink-primary mb-4">
                {section.title}
              </h4>
              <ul className="space-y-3">
                {section.links.map((link) => (
                  <li key={link.href}>
                    <Link
                      href={link.href}
                      className="text-sm text-ink-muted transition-colors hover:text-ink-primary"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-12 border-t border-edge-subtle pt-8 text-sm text-ink-muted">
          © {year} Facti AI LLC. All rights reserved.
        </div>
      </Container>
    </footer>
  );
}
