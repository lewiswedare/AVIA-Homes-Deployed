import { ArrowLeft, Check, ChevronLeft, ChevronRight, Phone, XCircle } from "lucide-react";
import { useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import { BentoCard, EmptyState, Spinner, StatusPill } from "@/components/avia/ui";
import { CatalogSection, CoverImage } from "@/components/catalog/shared";
import { useFacades } from "@/lib/queries";

/** Facade detail — mirrors iOS FacadeDetailView. */
export default function FacadeDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const facadesQ = useFacades();
  const [galleryIndex, setGalleryIndex] = useState<number>(0);

  const facade = useMemo(() => (facadesQ.data ?? []).find((f) => f.id === id) ?? null, [facadesQ.data, id]);

  if (facadesQ.isLoading) return <Spinner />;
  if (!facade) return <EmptyState icon={XCircle} title="Facade not found" />;

  const gallery = facade.gallery_image_urls ?? [];
  const included = facade.pricing_type !== "upgrade";

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
        <CoverImage src={facade.hero_image_url} alt={facade.name} className="h-64 sm:h-80">
          <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/70 to-transparent p-5 pt-16">
            <span className="rounded-full bg-avia-black/50 px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide text-white backdrop-blur">
              {facade.storeys === 2 ? "Double Storey" : "Single Storey"}
            </span>
            <h1 className="mt-2 text-[26px] font-medium text-white">{facade.name}</h1>
            {facade.style && <div className="text-[13px] text-white/80">{facade.style}</div>}
          </div>
        </CoverImage>
      </BentoCard>

      <BentoCard className="flex items-center justify-between p-4">
        <div>
          <div className="text-[14px] font-medium text-avia-black">{included ? "Included in All Packages" : "Upgrade Facade"}</div>
          {!included && facade.pricing_amount && <div className="text-[13px] text-avia-brown">{facade.pricing_amount}</div>}
        </div>
        <StatusPill label={included ? "Included" : "Upgrade"} />
      </BentoCard>

      {facade.description && (
        <CatalogSection title="About This Facade">
          <BentoCard className="p-4">
            <p className="text-[14px] leading-relaxed text-avia-black/70">{facade.description}</p>
          </BentoCard>
        </CatalogSection>
      )}

      {(facade.features ?? []).length > 0 && (
        <CatalogSection title="Facade Features">
          <BentoCard className="px-4 py-2">
            {(facade.features ?? []).map((f, i) => (
              <div key={`${f}-${i}`} className="flex items-start gap-2.5 border-b border-avia-line/60 py-2.5 last:border-0">
                <Check className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
                <span className="text-[13px] text-avia-black/75">{f}</span>
              </div>
            ))}
          </BentoCard>
        </CatalogSection>
      )}

      {gallery.length > 0 && (
        <CatalogSection title="Gallery">
          <BentoCard className="overflow-hidden">
            <CoverImage src={gallery[galleryIndex]} alt={`${facade.name} gallery`} className="h-60 sm:h-72">
              {gallery.length > 1 && (
                <>
                  <button
                    type="button"
                    aria-label="Previous image"
                    onClick={() => setGalleryIndex((galleryIndex - 1 + gallery.length) % gallery.length)}
                    className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-avia-black/40 p-2 text-white backdrop-blur transition-colors hover:bg-avia-black/60"
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </button>
                  <button
                    type="button"
                    aria-label="Next image"
                    onClick={() => setGalleryIndex((galleryIndex + 1) % gallery.length)}
                    className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-avia-black/40 p-2 text-white backdrop-blur transition-colors hover:bg-avia-black/60"
                  >
                    <ChevronRight className="h-4 w-4" />
                  </button>
                  <span className="absolute bottom-2 right-3 rounded-full bg-avia-black/50 px-2 py-0.5 text-[11px] text-white backdrop-blur">
                    {galleryIndex + 1} / {gallery.length}
                  </span>
                </>
              )}
            </CoverImage>
          </BentoCard>
        </CatalogSection>
      )}

      <BentoCard className="flex flex-wrap items-center justify-between gap-3 p-4">
        <div>
          <div className="text-[14px] font-medium text-avia-black">Questions about this facade?</div>
          <div className="text-[12px] text-avia-black/55">Our team can walk you through options and pricing.</div>
        </div>
        <a
          href="tel:0756545123"
          className="flex items-center gap-2 rounded-full bg-avia-brown px-4 py-2 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
        >
          <Phone className="h-4 w-4" /> Contact Us
        </a>
      </BentoCard>
    </div>
  );
}
