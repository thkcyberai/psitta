import type { MetadataRoute } from "next";

export const dynamic = "force-static";

const baseUrl = "https://psitta.ai";
const lastModified = new Date();

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  return [
    { url: `${baseUrl}/`, lastModified, changeFrequency: "weekly", priority: 1.0 },
    { url: `${baseUrl}/product/`, lastModified, changeFrequency: "monthly", priority: 0.9 },
    { url: `${baseUrl}/pricing/`, lastModified, changeFrequency: "monthly", priority: 0.9 },
    { url: `${baseUrl}/download/`, lastModified, changeFrequency: "monthly", priority: 0.8 },
    { url: `${baseUrl}/about/`, lastModified, changeFrequency: "monthly", priority: 0.7 },
    { url: `${baseUrl}/contact/`, lastModified, changeFrequency: "yearly", priority: 0.6 },
    { url: `${baseUrl}/privacy/`, lastModified, changeFrequency: "yearly", priority: 0.3 },
    { url: `${baseUrl}/terms/`, lastModified, changeFrequency: "yearly", priority: 0.3 },
  ];
}
