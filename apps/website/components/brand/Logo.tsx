"use client";

import Image from "next/image";

type LogoVariant = "horizontal" | "bird" | "wordmark" | "vertical" | "dark-bg";
type LogoSize = "sm" | "md" | "lg" | "xl" | "2xl" | "3xl";

const VARIANT_TO_FILE: Record<LogoVariant, string> = {
  horizontal: "/brand/psitta-horizontal.png",
  bird: "/brand/psitta-bird.png",
  wordmark: "/brand/psitta-wordmark.png",
  vertical: "/brand/psitta-vertical.png",
  "dark-bg": "/brand/psitta-dark-bg.png",
};

const VARIANT_TO_DIMENSIONS: Record<LogoVariant, { width: number; height: number }> = {
  horizontal: { width: 1456, height: 720 },
  bird: { width: 1024, height: 1024 },
  wordmark: { width: 2064, height: 512 },
  vertical: { width: 720, height: 1456 },
  "dark-bg": { width: 1456, height: 720 },
};

const SIZE_TO_HEIGHT: Record<LogoSize, number> = {
  sm: 28,
  md: 40,
  lg: 56,
  xl: 80,
  "2xl": 120,
  "3xl": 160,
};

interface LogoProps {
  variant?: LogoVariant;
  size?: LogoSize;
  className?: string;
  priority?: boolean;
}

export default function Logo({
  variant = "horizontal",
  size = "md",
  className = "",
  priority = false,
}: LogoProps) {
  const file = VARIANT_TO_FILE[variant];
  const dims = VARIANT_TO_DIMENSIONS[variant];
  const height = SIZE_TO_HEIGHT[size];
  const width = Math.round(height * (dims.width / dims.height));

  return (
    <Image
      src={file}
      alt="Psitta"
      width={width}
      height={height}
      priority={priority}
      className={className}
    />
  );
}
