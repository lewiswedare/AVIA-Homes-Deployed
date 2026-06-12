import { ArrowLeft, ChevronLeft, ChevronRight, Download, FileText, Sparkles } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";

import { BentoCard, Modal, Spinner, StatusPill } from "@/components/avia/ui";
import { CatalogSection, CoverImage } from "@/components/catalog/shared";
import { SPEC_TIER_FALLBACK_HERO } from "@/lib/catalog";
import { useSpecRangeTiers } from "@/lib/queries";
import type { SpecRangeHighlight, SpecRangeTierRow } from "@/lib/types";
import { SPEC_TIERS, asSpecTier, specTierLabel, specTierTagline } from "@/lib/types";

function heroFor(tier: string, row: SpecRangeTierRow | null): string {
  return row?.hero_image_url ?? SPEC_TIER_FALLBACK_HERO[tier] ?? "";
}

/**
 * Spec ranges — /spec-ranges shows the three-tier comparison overview,
 * /spec-ranges/:tier shows the full range detail (iOS SpecRangeDetailView).
 */
export default function SpecRange() {
  const { tier: tierParam } = useParams<{ tier?: string }>();
  const tiersQ = useSpecRangeTiers();

  if (tiersQ.isLoading) return <Spinner />;
  if (!tierParam) return <SpecRangeOverview rows={tiersQ.data ?? []} />;
  return <SpecRangeDetail tier={asSpecTier(tierParam)} rows={tiersQ.data ?? []} />;
}

function SpecRangeOverview({ rows }: { rows: SpecRangeTierRow[] }) {
  return (
    <div className="animate-fade-in space-y-5">
      <div>
        <h1 className="text-[26px] font-medium text-avia-black">Spec Ranges</h1>
        <p className="text-[13px] text-avia-black/50">Three levels of inclusions — compare and explore each range</p>
      </div>
      <div className="grid gap-4 lg:grid-cols-3">
        {SPEC_TIERS.map((tier) => {
          const row = rows.find((r) => r.tier === tier) ?? null;
          return (
            <Link key={tier} to={`/spec-ranges/${tier}`} className="block">
              <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                <CoverImage src={heroFor(tier, row)} alt={specTierLabel[tier]} className="h-56">
                  <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/75 to-transparent p-4 pt-14">
                    <div className="text-[20px] font-medium text-white">{specTierLabel[tier]}</div>
                    <div className="text-[12px] text-white/75">{specTierTagline[tier]}</div>
                    <span className="mt-2 inline-flex items-center gap-1 rounded-full bg-white/15 px-3 py-1 text-[12px] font-medium text-white backdrop-blur">
                      Explore {specTierLabel[tier]} <ChevronRight className="h-3.5 w-3.5" />
                    </span>
                  </div>
                </CoverImage>
              </BentoCard>
            </Link>
          );
        })}
      </div>
    </div>
  );
}

function SpecRangeDetail({ tier, rows }: { tier: "volos" | "messina" | "portobello"; rows: SpecRangeTierRow[] }) {
  const navigate = useNavigate();
  const row = useMemo(() => rows.find((r) => r.tier === tier) ?? null, [rows, tier]);
  const [roomIndex, setRoomIndex] = useState<number>(0);
  const [highlightOpen, setHighlightOpen] = useState<SpecRangeHighlight | null>(null);

  const highlights = row?.highlights ?? [];
  const roomImages = row?.room_images ?? [];
  const partnerLogos = row?.partner_logos ?? [];

  const highlightsTitle =
    tier === "volos" ? "Range Highlights" : tier === "messina" ? "Key Upgrades from Volos" : "Key Upgrades from Messina";

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
        <CoverImage src={heroFor(tier, row)} alt={specTierLabel[tier]} className="h-64 sm:h-80">
          <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/70 to-transparent p-5 pt-16">
            <div className="text-[12px] font-medium uppercase tracking-[0.18em] text-white/70">{specTierTagline[tier]}</div>
            <h1 className="text-[28px] font-medium text-white">{specTierLabel[tier]}</h1>
          </div>
        </CoverImage>
      </BentoCard>

      {row?.summary && (
        <CatalogSection title="About This Range">
          <BentoCard className="p-4">
            <p className="text-[14px] leading-relaxed text-avia-black/70">{row.summary}</p>
          </BentoCard>
        </CatalogSection>
      )}

      <Link to="/spec-ranges" className="block">
        <BentoCard className="flex items-center justify-between p-4 transition-colors hover:bg-avia-cardAlt">
          <div className="flex items-center gap-3">
            <Sparkles className="h-5 w-5 text-avia-brown" />
            <span className="text-[14px] font-medium text-avia-black">Compare All Spec Ranges</span>
          </div>
          <ChevronRight className="h-4 w-4 text-avia-black/40" />
        </BentoCard>
      </Link>

      {highlights.length > 0 && (
        <CatalogSection title={highlightsTitle}>
          <BentoCard className="divide-y divide-avia-line/60 px-4">
            {highlights.map((h, i) => (
              <button
                key={`${h.title}-${i}`}
                type="button"
                onClick={() => setHighlightOpen(h)}
                className="flex w-full items-center gap-3 py-3.5 text-left"
              >
                {h.icon_image_url ? (
                  <img src={h.icon_image_url} alt="" className="h-9 w-9 rounded-full object-cover" />
                ) : (
                  <div className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
                    <Sparkles className="h-4 w-4" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <div className="text-[14px] font-medium text-avia-black">{h.title}</div>
                  {h.subtitle && <div className="truncate text-[12px] text-avia-black/55">{h.subtitle}</div>}
                </div>
                <ChevronRight className="h-4 w-4 shrink-0 text-avia-black/35" />
              </button>
            ))}
          </BentoCard>
        </CatalogSection>
      )}

      {roomImages.length > 0 && (
        <CatalogSection title="Room Gallery">
          <BentoCard className="overflow-hidden">
            <CoverImage src={roomImages[roomIndex]?.image_url} alt={roomImages[roomIndex]?.name ?? "Room"} className="h-60 sm:h-72">
              {roomImages.length > 1 && (
                <>
                  <button
                    type="button"
                    aria-label="Previous room"
                    onClick={() => setRoomIndex((roomIndex - 1 + roomImages.length) % roomImages.length)}
                    className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-avia-black/40 p-2 text-white backdrop-blur transition-colors hover:bg-avia-black/60"
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </button>
                  <button
                    type="button"
                    aria-label="Next room"
                    onClick={() => setRoomIndex((roomIndex + 1) % roomImages.length)}
                    className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-avia-black/40 p-2 text-white backdrop-blur transition-colors hover:bg-avia-black/60"
                  >
                    <ChevronRight className="h-4 w-4" />
                  </button>
                </>
              )}
            </CoverImage>
            <div className="flex items-center justify-between p-3.5">
              <span className="text-[13px] font-medium text-avia-black">{roomImages[roomIndex]?.name}</span>
              <span className="text-[12px] text-avia-black/45">
                {roomIndex + 1} / {roomImages.length}
              </span>
            </div>
          </BentoCard>
        </CatalogSection>
      )}

      {partnerLogos.length > 0 && (
        <CatalogSection title="Trusted Brand Partners">
          <BentoCard className="p-4">
            <div className="grid grid-cols-3 gap-4 sm:grid-cols-4">
              {partnerLogos.map((p, i) => (
                <div key={`${p.name}-${i}`} className="flex flex-col items-center gap-1.5">
                  <div className="flex h-14 w-full items-center justify-center rounded-[10px] bg-white p-2">
                    <img src={p.image_url} alt={p.name} className="max-h-10 w-auto object-contain" loading="lazy" />
                  </div>
                  <span className="text-[10px] text-avia-black/45">{p.name}</span>
                </div>
              ))}
            </div>
            <p className="mt-3 text-[11px] text-avia-black/40">
              Brands shown are indicative — final inclusions are confirmed in your specification documents.
            </p>
          </BentoCard>
        </CatalogSection>
      )}

      {row?.pdf_url && (
        <CatalogSection title="Spec Range PDF">
          <BentoCard className="overflow-hidden">
            {row.pdf_preview_image_url && (
              <CoverImage src={row.pdf_preview_image_url} alt={`${specTierLabel[tier]} PDF preview`} className="h-56" />
            )}
            <div className="flex items-center gap-3 p-4">
              <FileText className="h-5 w-5 text-avia-brown" />
              <div className="min-w-0 flex-1">
                <div className="text-[14px] font-medium text-avia-black">{specTierLabel[tier]} Specification</div>
                <div className="text-[12px] text-avia-black/50">Full inclusions list</div>
              </div>
              <a
                href={row.pdf_url}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-1.5 rounded-full bg-avia-brown px-4 py-2 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
              >
                <Download className="h-4 w-4" /> Download PDF
              </a>
            </div>
          </BentoCard>
        </CatalogSection>
      )}

      <Modal open={highlightOpen !== null} onClose={() => setHighlightOpen(null)} title={highlightOpen?.title ?? ""}>
        {highlightOpen?.detail_image_url && (
          <img src={highlightOpen.detail_image_url} alt={highlightOpen.title} className="w-full rounded-[12px] object-cover" />
        )}
        {highlightOpen?.subtitle && <p className="text-[14px] leading-relaxed text-avia-black/70">{highlightOpen.subtitle}</p>}
        <StatusPill label={specTierLabel[tier]} />
      </Modal>
    </div>
  );
}
