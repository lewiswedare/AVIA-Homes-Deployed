import { ArrowLeft, Check, FileText, Mail, Map as MapIcon, MapPin, Phone, XCircle } from "lucide-react";
import { useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import { BentoCard, EmptyState, Modal, ProgressBar, Spinner, StatusPill } from "@/components/avia/ui";
import { CatalogSection, CoverImage, PackageCard } from "@/components/catalog/shared";
import { useAuth } from "@/hooks/useAuth";
import { estateOf, visiblePackages } from "@/lib/catalog";
import { useEstates, usePackageAssignments, usePackages } from "@/lib/queries";
import { isClientRole } from "@/lib/types";

/** Estate detail — mirrors iOS EstateDetailView. */
export default function EstateDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { role, userId } = useAuth();
  const estatesQ = useEstates();
  const packagesQ = usePackages();
  const assignmentsQ = usePackageAssignments();
  const [siteMapOpen, setSiteMapOpen] = useState<boolean>(false);

  const estate = useMemo(() => (estatesQ.data ?? []).find((e) => e.id === id) ?? null, [estatesQ.data, id]);

  const estatePackages = useMemo(() => {
    if (!estate) return [];
    const scoped = visiblePackages(role, userId, packagesQ.data, assignmentsQ.data);
    return scoped.filter((p) => estateOf(p) === estate.name);
  }, [estate, role, userId, packagesQ.data, assignmentsQ.data]);

  if (estatesQ.isLoading) return <Spinner />;
  if (!estate) return <EmptyState icon={XCircle} title="Estate not found" />;

  const total = estate.total_lots ?? 0;
  const available = estate.available_lots ?? 0;
  const soldPct = total > 0 ? (total - available) / total : 0;
  const upcoming = (estate.status ?? "").toLowerCase() === "upcoming";

  return (
    <div className="animate-fade-in space-y-5">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="flex items-center gap-1.5 text-[13px] font-medium text-avia-black/55 transition-colors hover:text-avia-black"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <BentoCard className="overflow-hidden">
        <CoverImage src={estate.image_url} alt={estate.name} className="h-64 sm:h-80">
          {estate.logo_url && (
            <div className="absolute left-4 top-4 rounded-[10px] bg-white/80 p-2 backdrop-blur">
              <img src={estate.logo_url} alt={`${estate.name} logo`} className="h-9 w-auto object-contain" />
            </div>
          )}
          <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/70 to-transparent p-5 pt-16">
            <div className="flex items-center gap-2">
              <h1 className="text-[26px] font-medium text-white">{estate.name}</h1>
              {upcoming && <StatusPill label="Coming Soon" className="border-white/60 text-white" />}
            </div>
            <div className="flex items-center gap-1 text-[13px] text-white/80">
              <MapPin className="h-3.5 w-3.5" /> {estate.location}
            </div>
          </div>
        </CoverImage>
      </BentoCard>

      <div className="grid grid-cols-3 gap-3">
        <StatCell value={total > 0 ? String(total) : "—"} label="Total Lots" />
        <StatCell value={total > 0 ? String(available) : "—"} label="Available" />
        <StatCell value={estate.price_from ?? "—"} label="Land From" />
      </div>

      {(estate.brochure_url || estate.site_map_url) && (
        <CatalogSection title="Estate Media">
          <BentoCard className="divide-y divide-avia-line/60 px-4">
            {estate.brochure_url && (
              <a href={estate.brochure_url} target="_blank" rel="noreferrer" className="flex items-center gap-3 py-3.5">
                <FileText className="h-5 w-5 text-avia-brown" />
                <span className="flex-1 text-[14px] font-medium text-avia-black">PDF Brochure</span>
                <span className="text-[12px] text-avia-black/45">Open</span>
              </a>
            )}
            {estate.site_map_url && (
              <button type="button" onClick={() => setSiteMapOpen(true)} className="flex w-full items-center gap-3 py-3.5 text-left">
                <MapIcon className="h-5 w-5 text-avia-brown" />
                <span className="flex-1 text-[14px] font-medium text-avia-black">Site Map</span>
                <span className="text-[12px] text-avia-black/45">View</span>
              </button>
            )}
          </BentoCard>
        </CatalogSection>
      )}

      {estate.description && (
        <CatalogSection title="About">
          <BentoCard className="space-y-3 p-4">
            <p className="text-[14px] leading-relaxed text-avia-black/70">{estate.description}</p>
            <div className="flex flex-wrap gap-2">
              {estate.suburb && <StatusPill label={estate.suburb} tone="muted" />}
              {estate.expected_completion && <StatusPill label={estate.expected_completion} tone="muted" />}
            </div>
          </BentoCard>
        </CatalogSection>
      )}

      {(estate.features ?? []).length > 0 && (
        <CatalogSection title="Estate Features">
          <BentoCard className="px-4 py-2">
            {(estate.features ?? []).map((f, i) => (
              <div key={`${f}-${i}`} className="flex items-start gap-2.5 border-b border-avia-line/60 py-2.5 last:border-0">
                <Check className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
                <span className="text-[13px] text-avia-black/75">{f}</span>
              </div>
            ))}
          </BentoCard>
        </CatalogSection>
      )}

      {total > 0 && (
        <CatalogSection title="Availability">
          <BentoCard className="space-y-2 p-4">
            <div className="flex items-center justify-between">
              <span className="text-[14px] font-medium text-avia-black">
                {available > 0 ? `${available} lots available` : "Sold Out"}
              </span>
              <span className="text-[12px] text-avia-black/50">{Math.round(soldPct * 100)}% sold</span>
            </div>
            <ProgressBar value={soldPct} />
          </BentoCard>
        </CatalogSection>
      )}

      {estatePackages.length > 0 && (
        <CatalogSection title={isClientRole(role) ? "Your Packages" : "Available Packages"}>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {estatePackages.map((pkg) => (
              <PackageCard key={pkg.id} pkg={pkg} />
            ))}
          </div>
        </CatalogSection>
      )}

      <BentoCard className="flex flex-wrap items-center gap-x-6 gap-y-3 p-4">
        <span className="text-[14px] font-medium text-avia-black">Want to know more?</span>
        <a href="tel:0756545123" className="flex items-center gap-2 text-[13px] font-medium text-avia-brown">
          <Phone className="h-4 w-4" /> 07 5654 5123
        </a>
        <a href="mailto:sales@aviahomes.com.au" className="flex items-center gap-2 text-[13px] font-medium text-avia-brown">
          <Mail className="h-4 w-4" /> sales@aviahomes.com.au
        </a>
      </BentoCard>

      <Modal open={siteMapOpen} onClose={() => setSiteMapOpen(false)} title={`${estate.name} Site Map`}>
        {estate.site_map_url && (
          <img src={estate.site_map_url} alt={`${estate.name} site map`} className="mx-auto max-h-[70vh] w-auto object-contain" />
        )}
      </Modal>
    </div>
  );
}

function StatCell({ value, label }: { value: string; label: string }) {
  return (
    <BentoCard className="flex flex-col items-center gap-1 py-4">
      <span className="text-[20px] font-medium text-avia-black">{value}</span>
      <span className="text-[10px] font-medium uppercase tracking-wider text-avia-black/40">{label}</span>
    </BentoCard>
  );
}
