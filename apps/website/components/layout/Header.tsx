import Link from "next/link";
import Logo from "@/components/brand/Logo";
import Button from "@/components/ui/Button";
import Container from "@/components/ui/Container";

const NAV_ITEMS = [
  { label: "Product", href: "/#product" },
  { label: "Pricing", href: "/pricing" },
  { label: "Download", href: "/download" },
];

export default function Header() {
  return (
    <header className="sticky top-0 z-50 border-b border-edge-subtle bg-paper/80 backdrop-blur-md">
      <Container as="nav" className="flex h-20 items-center justify-between">
        <Link href="/" className="flex items-center" aria-label="Psitta home">
          <Logo variant="horizontal" size="lg" priority />
        </Link>

        <div className="flex items-center gap-8">
          <ul className="hidden items-center gap-6 md:flex">
            {NAV_ITEMS.map((item) => (
              <li key={item.href}>
                <Link
                  href={item.href}
                  className="text-sm font-medium text-ink-body transition-colors hover:text-ink-primary"
                >
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>

          <Button href="/download" variant="primary" size="sm">
            Get Started
          </Button>
        </div>
      </Container>
    </header>
  );
}
