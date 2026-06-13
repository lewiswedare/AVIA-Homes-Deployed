import {
  ArrowLeft,
  ChevronLeft,
  ChevronRight,
  Download,
  FileText,
  LayoutGrid,
  List,
  Package,
  Sparkles,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";

import { BentoCard, Modal, Spinner, StatusPill } from "@/components/avia/ui";
import { CatalogSection, CoverImage, DetailRow } from "@/components/catalog/shared";
import {
  type RangeFitting,
  SPEC_TIER_FALLBACK_HERO,
  fittingsForRange,
  indexColoursByProduct,
  productDisplayImage,
} from "@/lib/catalog";
import { formatCost } from "@/lib/format";
import {
  useSpecCategories,
  useSpecItems,
  useSpecProductColours,
  useSpecProducts,
  useSpecRangeItemProducts,
  useSpecRangeTiers,
} from "@/lib/queries";
import type { SpecProductRow, SpecRangeHighlight, SpecRangeTierRow, SpecTierKey } from "@/lib/types";
import { SPEC_TIERS, asSpecTier, specTierLabel, specTierTagline } from "@/lib/types";
import { cn } from "@/lib/utils";

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
  // Key on the tier so local state (room carousel index, open highlight) resets
  // when navigating straight from one range to another.
  return <SpecRangeDetail key={asSpecTier(tierParam)} tier={asSpecTier(tierParam)} rows={tiersQ.data ?? []} />;
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

      <FittingsFixtures tier={tier} />

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

// ---------------------------------------------------------------------------
// Fittings & Fixtures — the catalogue products configured for this range,
// grouped by room. Mirrors the iOS SpecRangeFittingsView.
// ---------------------------------------------------------------------------

type InclusionFilter = "all" | "included" | "upgrade";
type FittingsLayout = "grid" | "list";

function productSecondary(p: SpecProductRow): string | null {
  const parts = [p.brand, p.model].filter((v): v is string => Boolean(v && v.length > 0));
  if (parts.length > 0) return parts.join(" · ");
  return p.description && p.description.length > 0 ? p.description : null;
}

function InclusionBadge({ fitting }: { fitting: RangeFitting }) {
  if (fitting.inclusion === "upgrade") {
    return (
      <span className="inline-flex items-center whitespace-nowrap rounded-full bg-avia-brown/15 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-avia-brown">
        Upgrade{fitting.upgradeCost > 0 ? ` +${formatCost(fitting.upgradeCost)}` : ""}
      </span>
    );
  }
  return (
    <span className="inline-flex items-center whitespace-nowrap rounded-full bg-avia-blue/25 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-avia-blue">
      Included
    </span>
  );
}

function RoomChip({
  selected,
  onClick,
  children,
}: {
  selected: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "rounded-full border px-3.5 py-1.5 text-[12px] font-medium transition-colors",
        selected
          ? "border-avia-black bg-avia-black text-avia-white"
          : "border-avia-line bg-avia-card text-avia-black/70 hover:border-avia-black/40 hover:text-avia-black",
      )}
    >
      {children}
    </button>
  );
}

function FittingsFixtures({ tier }: { tier: SpecTierKey }) {
  const categoriesQ = useSpecCategories();
  const itemsQ = useSpecItems();
  const productsQ = useSpecProducts();
  const membershipsQ = useSpecRangeItemProducts();
  const coloursQ = useSpecProductColours();

  const [room, setRoom] = useState<string | null>(null);
  const [layout, setLayout] = useState<FittingsLayout>("grid");
  const [inclusion, setInclusion] = useState<InclusionFilter>("all");
  const [detail, setDetail] = useState<RangeFitting | null>(null);

  const groups = useMemo(
    () =>
      fittingsForRange({
        rangeId: tier,
        categories: categoriesQ.data ?? [],
        items: itemsQ.data ?? [],
        products: productsQ.data ?? [],
        memberships: membershipsQ.data ?? [],
      }),
    [tier, categoriesQ.data, itemsQ.data, productsQ.data, membershipsQ.data],
  );

  const coloursByProduct = useMemo(() => indexColoursByProduct(coloursQ.data), [coloursQ.data]);

  const visible = useMemo(() => {
    let items = room === null ? groups.flatMap((g) => g.items) : groups.find((g) => g.categoryId === room)?.items ?? [];
    if (inclusion !== "all") items = items.filter((i) => i.inclusion === inclusion);
    return items;
  }, [groups, room, inclusion]);

  const loading = categoriesQ.isLoading || itemsQ.isLoading || productsQ.isLoading || membershipsQ.isLoading;

  if (loading && groups.length === 0) {
    return (
      <CatalogSection title="Fittings & Fixtures">
        <Spinner />
      </CatalogSection>
    );
  }
  if (groups.length === 0) return null;

  const detailColours = detail ? coloursByProduct.get(detail.product.id) ?? [] : [];
  const detailImage = detail ? productDisplayImage(detail.product, coloursByProduct) : null;

  return (
    <CatalogSection
      title="Fittings & Fixtures"
      action={
        <div className="flex items-center gap-0.5 rounded-full bg-avia-card p-0.5">
          <button
            type="button"
            aria-label="Grid view"
            onClick={() => setLayout("grid")}
            className={cn(
              "flex h-7 w-9 items-center justify-center rounded-full transition-colors",
              layout === "grid" ? "bg-avia-brown text-avia-white" : "text-avia-black/45 hover:text-avia-black",
            )}
          >
            <LayoutGrid className="h-3.5 w-3.5" />
          </button>
          <button
            type="button"
            aria-label="List view"
            onClick={() => setLayout("list")}
            className={cn(
              "flex h-7 w-9 items-center justify-center rounded-full transition-colors",
              layout === "list" ? "bg-avia-brown text-avia-white" : "text-avia-black/45 hover:text-avia-black",
            )}
          >
            <List className="h-3.5 w-3.5" />
          </button>
        </div>
      }
    >
      <div className="space-y-3">
        <p className="text-[13px] text-avia-black/55">
          Key fittings &amp; fixtures included in the {specTierLabel[tier]} range — selected from our product catalogue.
        </p>

        <div className="flex flex-wrap gap-2">
          <RoomChip selected={room === null} onClick={() => setRoom(null)}>
            All Rooms
          </RoomChip>
          {groups.map((g) => (
            <RoomChip key={g.categoryId} selected={room === g.categoryId} onClick={() => setRoom(g.categoryId)}>
              {g.categoryName}
            </RoomChip>
          ))}
        </div>

        <div className="flex items-center justify-between gap-2">
          <select
            value={inclusion}
            onChange={(e) => setInclusion(e.target.value as InclusionFilter)}
            className="rounded-full border border-avia-line bg-avia-card px-3.5 py-1.5 text-[13px] font-medium text-avia-black outline-none focus:border-avia-brown"
          >
            <option value="all">All Options</option>
            <option value="included">Included</option>
            <option value="upgrade">Upgrades</option>
          </select>
          <span className="text-[12px] text-avia-black/45">
            {visible.length} {visible.length === 1 ? "item" : "items"}
          </span>
        </div>

        {visible.length === 0 ? (
          <div className="flex flex-col items-center gap-2 rounded-[12px] border border-dashed border-avia-line py-12 text-center">
            <Package className="h-7 w-7 text-avia-black/25" />
            <p className="text-[13px] text-avia-black/55">No items match this filter.</p>
          </div>
        ) : layout === "grid" ? (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {visible.map((f) => (
              <button
                key={f.product.id}
                type="button"
                onClick={() => setDetail(f)}
                className="group block overflow-hidden rounded-[12px] border border-avia-line/70 bg-avia-card text-left transition-transform hover:-translate-y-0.5"
              >
                <CoverImage src={productDisplayImage(f.product, coloursByProduct)} alt={f.product.name} className="h-36">
                  <div className="absolute left-2 top-2">
                    <InclusionBadge fitting={f} />
                  </div>
                </CoverImage>
                <div className="space-y-1 p-3">
                  <div className="line-clamp-2 text-[13px] font-medium leading-snug text-avia-black">{f.product.name}</div>
                  {productSecondary(f.product) && (
                    <div className="truncate text-[12px] text-avia-black/55">{productSecondary(f.product)}</div>
                  )}
                  {f.product.sku && (
                    <div className="truncate text-[11px] uppercase tracking-wide text-avia-black/40">{f.product.sku}</div>
                  )}
                </div>
              </button>
            ))}
          </div>
        ) : (
          <div className="space-y-2">
            {visible.map((f) => (
              <button
                key={f.product.id}
                type="button"
                onClick={() => setDetail(f)}
                className="flex w-full items-center gap-3 rounded-[12px] border border-avia-line/70 bg-avia-card p-2.5 text-left transition-colors hover:bg-avia-cardAlt"
              >
                <CoverImage
                  src={productDisplayImage(f.product, coloursByProduct)}
                  alt={f.product.name}
                  className="h-16 w-16 shrink-0 rounded-[10px]"
                />
                <div className="min-w-0 flex-1 space-y-1">
                  <div className="line-clamp-1 text-[14px] font-medium text-avia-black">{f.product.name}</div>
                  {productSecondary(f.product) && (
                    <div className="truncate text-[12px] text-avia-black/55">{productSecondary(f.product)}</div>
                  )}
                  <div className="flex items-center gap-2">
                    <InclusionBadge fitting={f} />
                    {f.product.sku && (
                      <span className="truncate text-[11px] uppercase tracking-wide text-avia-black/40">{f.product.sku}</span>
                    )}
                  </div>
                </div>
                <ChevronRight className="h-4 w-4 shrink-0 text-avia-black/35" />
              </button>
            ))}
          </div>
        )}
      </div>

      <Modal open={detail !== null} onClose={() => setDetail(null)} title={detail?.product.name ?? ""}>
        {detail && (
          <div className="space-y-4">
            <CoverImage src={detailImage} alt={detail.product.name} className="h-60 rounded-[12px]" />
            <div className="flex flex-wrap items-center gap-2">
              <StatusPill label={detail.categoryName} tone="muted" />
              <StatusPill label={`${specTierLabel[tier]} Range`} tone="brown" />
              <InclusionBadge fitting={detail} />
            </div>
            {detail.product.description && (
              <p className="text-[14px] leading-relaxed text-avia-black/70">{detail.product.description}</p>
            )}
            <div>
              <DetailRow label="Brand" value={detail.product.brand} />
              <DetailRow label="Model" value={detail.product.model} />
              <DetailRow label="Product Code" value={detail.product.sku} />
              <DetailRow label="Dimensions" value={detail.product.dimensions} />
            </div>
            {detailColours.length > 0 && (
              <div className="space-y-2">
                <div className="text-[11px] font-medium uppercase tracking-[0.12em] text-avia-black/40">
                  {detailColours.length === 1 ? "Finish" : "Available Finishes"}
                </div>
                <div className="grid grid-cols-3 gap-3 sm:grid-cols-4">
                  {detailColours.map((c) => (
                    <div key={c.id} className="flex flex-col items-center gap-1.5 text-center">
                      {c.image_url ? (
                        <img
                          src={c.image_url}
                          alt={c.name}
                          className="h-12 w-12 rounded-full border border-avia-line object-cover"
                          loading="lazy"
                        />
                      ) : (
                        <span
                          className="h-12 w-12 rounded-full border border-avia-line"
                          style={{ backgroundColor: `#${(c.hex ?? "CCCCCC").replace(/^#/, "")}` }}
                        />
                      )}
                      <span className="line-clamp-1 text-[11px] text-avia-black/60">{c.name}</span>
                      {(c.extra_cost ?? 0) > 0 && (
                        <span className="text-[10px] font-medium text-avia-brown">+{formatCost(c.extra_cost ?? 0)}</span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}
      </Modal>
    </CatalogSection>
  );
}
