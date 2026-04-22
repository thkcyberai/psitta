import type { Metadata } from "next";
import { Inter } from "next/font/google";
import Header from "@/components/layout/Header";
import Footer from "@/components/layout/Footer";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://psitta.ai"),
  title: {
    default: "Psitta — Listen to your documents. Improve your writing.",
    template: "%s · Psitta",
  },
  description:
    "Psitta turns your documents into audio so writers and editors can hear their work. Catch awkward phrasing, rhythm issues, and unclear passages by listening — the way your readers will experience it.",
  keywords: [
    "document to audio",
    "text to speech for writers",
    "editing by ear",
    "proofread by listening",
    "TTS writing tool",
    "Psitta",
  ],
  authors: [{ name: "Facti AI LLC" }],
  creator: "Facti AI LLC",
  publisher: "Facti AI LLC",
  openGraph: {
    type: "website",
    locale: "en_US",
    url: "https://psitta.ai",
    siteName: "Psitta",
    title: "Psitta — Listen to your documents. Improve your writing.",
    description:
      "Psitta turns your documents into audio so writers and editors can hear their work.",
    images: [
      {
        url: "/brand/psitta-og-card.png",
        width: 1200,
        height: 630,
        alt: "Psitta — Listen to your documents. Improve your writing.",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "Psitta — Listen to your documents. Improve your writing.",
    description:
      "Psitta turns your documents into audio so writers and editors can hear their work.",
    images: ["/brand/psitta-og-card.png"],
  },
  icons: {
    icon: [
      { url: "/brand/favicon-16.png", sizes: "16x16", type: "image/png" },
      { url: "/brand/favicon-32.png", sizes: "32x32", type: "image/png" },
      { url: "/brand/favicon-48.png", sizes: "48x48", type: "image/png" },
      { url: "/brand/favicon.ico" },
    ],
    apple: [
      { url: "/brand/apple-touch-icon-180.png", sizes: "180x180" },
    ],
    other: [
      { rel: "icon", url: "/brand/android-chrome-192.png", sizes: "192x192" },
      { rel: "icon", url: "/brand/android-chrome-512.png", sizes: "512x512" },
    ],
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
    },
  },
  verification: {
    other: {
      "msvalidate.01": "38B8699E77707FFF67F6B16342D50D8B",
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="min-h-screen bg-paper antialiased font-sans">
        <Header />
        <main>{children}</main>
        <Footer />
      </body>
    </html>
  );
}
