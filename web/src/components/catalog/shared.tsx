import { Bath, BedDouble, Car, ImageOff, MapPin, Maximize } from "lucide-react";
import type { ReactNode } from "react";
import { Link } from "react-router-dom";

import { BentoCard } from "@/components/avia/ui";
import { estateOf, pkgBathrooms, pkgBedrooms, pkgGarages } from "@/lib/catalog";
import type { HouseLandPackageRow } from "@/lib/types";
import { cn } from "@/lib/utils";

/** Image block with graceful fallback when the URL is missing/broken. */
export function CoverImage({
  src,
  alt,
  className,
  children,
}: {
  src: string | null | undefined;
  alt: string;
  className?: string;
  children?: ReactNode;
}) {
  return (
    <div className={cn("relative overflow-hidden bg-avia-elevated", className)}>
      {src ? (
        <img src={src} alt={alt} className="absolute inset-0 h-full w-full object-cover" loading="lazy" />
      ) : (
        <div className="absolute inset-0 flex items-center justify-center">
          <ImageOff className="h-7 w-7 text-avia-black/25" />
        </div>
      )}
      {children}
    </div>
  );
}

export function SpecStat({ icon: Icon, label }: { icon: typeof BedDouble; label: string }) {
  return (
    <span className="flex items-center gap-1 text-[12px] text-avia-black/55">
      <Icon className="h-3.5 w-3.5" />
      {label}
    </span>
  );
}

/** Catalog package card — grid tile linking to the package detail page. */
export function PackageCard({ pkg }: { pkg: HouseLandPackageRow }) {
  return (
    <Link to={`/packages/${encodeURIComponent(pkg.id)}`} className="block">
      <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
        <CoverImage src={pkg.image_url} alt={pkg.title} className="h-40">
          <div className="absolute left-2 top-2 flex gap-1.5">
            {pkg.is_new && (
              <span className="rounded-full bg-avia-brown px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-avia-white">
                New
              </span>
            )}
            <span className="rounded-full border border-white/60 bg-avia-black/30 px-2 py-0.5 text-[10px] font-medium text-white backdrop-blur">
              Available
            </span>
          </div>
        </CoverImage>
        <div className="space-y-2 p-3.5">
          <div className="truncate text-[15px] font-medium text-avia-black">{pkg.title}</div>
          <div className="flex items-center gap-1 text-[12px] text-avia-black/55">
            <MapPin className="h-3.5 w-3.5 shrink-0" />
            <span className="truncate">{pkg.location}</span>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <SpecStat icon={BedDouble} label={`${pkgBedrooms(pkg)}`} />
            <SpecStat icon={Bath} label={`${pkgBathrooms(pkg)}`} />
            <SpecStat icon={Car} label={`${pkgGarages(pkg)}`} />
            <SpecStat icon={Maximize} label={pkg.lot_size} />
          </div>
          <div className="flex items-center justify-between gap-2 pt-1">
            <span className="text-[18px] font-semibold text-avia-brown">{pkg.price}</span>
            <span className="truncate rounded-full bg-avia-black/5 px-2 py-0.5 text-[11px] text-avia-black/60">
              {pkg.home_design}
            </span>
          </div>
        </div>
      </BentoCard>
    </Link>
  );
}

/** Labelled row inside a detail card. */
export function DetailRow({ label, value }: { label: string; value: string | null | undefined }) {
  if (!value) return null;
  return (
    <div className="flex items-center justify-between gap-4 border-b border-avia-line/60 py-2.5 last:border-0">
      <span className="text-[13px] text-avia-black/50">{label}</span>
      <span className="text-right text-[13px] font-medium text-avia-black">{value}</span>
    </div>
  );
}

/** Uppercase section heading used across catalog detail pages. */
export function CatalogSection({ title, children, action }: { title: string; children: ReactNode; action?: ReactNode }) {
  return (
    <section className="space-y-2.5">
      <div className="flex items-center justify-between">
        <h2 className="text-[11px] font-medium uppercase tracking-[0.12em] text-avia-black/40">{title}</h2>
        {action}
      </div>
      {children}
    </section>
  );
}

/** Derives the matching home design by name-prefix (iOS parity: first word). */
export function findDesignByName<T extends { name: string }>(designs: T[] | undefined, homeDesign: string): T | null {
  const first = (homeDesign.split(/\s+/)[0] ?? "").toLowerCase();
  if (!first) return null;
  return (
    (designs ?? []).find((d) => d.name.toLowerCase() === first) ??
    (designs ?? []).find((d) => homeDesign.toLowerCase().startsWith(d.name.toLowerCase())) ??
    null
  );
}

export { estateOf };
