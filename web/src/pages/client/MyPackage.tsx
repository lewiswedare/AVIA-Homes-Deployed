import { CheckCircle2, ChevronRight, Clock, LayoutGrid, MapPin } from "lucide-react";
import { useMemo } from "react";
import { Link } from "react-router-dom";

import { BentoCard, EmptyState, Spinner, StatusPill } from "@/components/avia/ui";
import { CoverImage, findDesignByName } from "@/components/catalog/shared";
import { useAuth } from "@/hooks/useAuth";
import { assignmentForPackage, eoiStatusLabel, responseFor, visiblePackages } from "@/lib/catalog";
import { useFacades, useHomeDesigns, usePackageAssignments, usePackages } from "@/lib/queries";
import {
  RESPONSE_ACCEPTED,
  RESPONSE_DECLINED,
  RESPONSE_PENDING,
  asSpecTier,
  specTierLabel,
  specTierTagline,
} from "@/lib/types";

/** Client shared-packages review — mirrors iOS ClientPackageReviewView. */
export default function MyPackage() {
  const { role, userId } = useAuth();
  const packagesQ = usePackages();
  const assignmentsQ = usePackageAssignments();
  const designsQ = useHomeDesigns();
  const facadesQ = useFacades();

  const shared = useMemo(
    () => visiblePackages(role, userId, packagesQ.data, assignmentsQ.data),
    [role, userId, packagesQ.data, assignmentsQ.data],
  );

  const statusOf = (pkgId: string) => {
    const a = assignmentForPackage(assignmentsQ.data, pkgId);
    const resp = responseFor(a, userId);
    return { assignment: a, status: resp?.status ?? RESPONSE_PENDING };
  };

  const awaiting = shared.filter((p) => statusOf(p.id).status === RESPONSE_PENDING).length;
  const accepted = shared.filter((p) => statusOf(p.id).status === RESPONSE_ACCEPTED).length;

  if (packagesQ.isLoading || assignmentsQ.isLoading) return <Spinner />;

  return (
    <div className="animate-fade-in space-y-5">
      <div>
        <h1 className="text-[26px] font-medium text-avia-black">My Package</h1>
        <p className="text-[13px] text-avia-black/50">Packages shared with you for review</p>
      </div>

      {shared.length === 0 ? (
        <BentoCard className="p-6">
          <EmptyState
            icon={LayoutGrid}
            title="No Packages Shared Yet"
            subtitle="When our team or your partner shares a house & land package with you, it will appear here for review."
          />
        </BentoCard>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3">
            <BentoCard className="flex items-center gap-3 p-4">
              <Clock className="h-5 w-5 text-avia-brown" />
              <div>
                <div className="text-[20px] font-medium text-avia-black">{awaiting}</div>
                <div className="text-[11px] font-medium uppercase tracking-wider text-avia-black/40">Awaiting Review</div>
              </div>
            </BentoCard>
            <BentoCard className="flex items-center gap-3 p-4">
              <CheckCircle2 className="h-5 w-5 text-green-700" />
              <div>
                <div className="text-[20px] font-medium text-avia-black">{accepted}</div>
                <div className="text-[11px] font-medium uppercase tracking-wider text-avia-black/40">Accepted</div>
              </div>
            </BentoCard>
          </div>

          <div className="space-y-4">
            {shared.map((pkg) => {
              const { assignment, status } = statusOf(pkg.id);
              const design = !pkg.is_custom ? findDesignByName(designsQ.data, pkg.home_design) : null;
              const facade = (facadesQ.data ?? []).find((f) => f.id === pkg.selected_facade_id) ?? null;
              const tier = asSpecTier(pkg.spec_tier);
              const eoi = assignment?.eoi_status ?? "none";
              return (
                <BentoCard key={pkg.id} className="overflow-hidden">
                  <Link to={`/packages/${encodeURIComponent(pkg.id)}`} className="block">
                    <CoverImage src={pkg.image_url} alt={pkg.title} className="h-44">
                      <span className="absolute right-3 top-3">
                        <StatusPill
                          label={status}
                          tone={status === RESPONSE_ACCEPTED ? "brown" : status === RESPONSE_DECLINED ? "muted" : "warning"}
                          className="bg-white/85 backdrop-blur"
                        />
                      </span>
                    </CoverImage>
                    <div className="space-y-1 p-4 pb-3">
                      <div className="text-[16px] font-medium text-avia-black">{pkg.title}</div>
                      <div className="flex items-center gap-1 text-[12px] text-avia-black/50">
                        <MapPin className="h-3.5 w-3.5" /> {pkg.location}
                      </div>
                      <div className="text-[17px] font-semibold text-avia-brown">{pkg.price}</div>
                    </div>
                  </Link>
                  <div className="divide-y divide-avia-line/60 border-t border-avia-line/60 px-4">
                    {design && (
                      <RowLink to={`/designs/${encodeURIComponent(design.id)}`} title={design.name} subtitle={`${design.bedrooms} bed · ${design.bathrooms} bath · ${Math.round(design.square_meters)}m²`} />
                    )}
                    <RowLink to={`/spec-ranges/${tier}`} title={`${specTierLabel[tier]} Specification`} subtitle={specTierTagline[tier]} />
                    {facade && <RowLink to={`/facades/${encodeURIComponent(facade.id)}`} title={`${facade.name} Facade`} subtitle={facade.style ?? "Included facade"} />}
                    {eoi !== "none" && (
                      <div className="flex items-center justify-between py-3">
                        <span className="text-[13px] text-avia-black/55">EOI Status</span>
                        <StatusPill label={eoiStatusLabel(eoi)} />
                      </div>
                    )}
                    {status === RESPONSE_PENDING && eoi === "none" && (
                      <Link to={`/packages/${encodeURIComponent(pkg.id)}`} className="flex items-center justify-between py-3 text-[13px] font-medium text-avia-brown">
                        Tap to review & respond <ChevronRight className="h-4 w-4" />
                      </Link>
                    )}
                  </div>
                </BentoCard>
              );
            })}
          </div>
        </>
      )}
    </div>
  );
}

function RowLink({ to, title, subtitle }: { to: string; title: string; subtitle: string }) {
  return (
    <Link to={to} className="flex items-center justify-between gap-3 py-3">
      <div className="min-w-0">
        <div className="truncate text-[13px] font-medium text-avia-black">{title}</div>
        <div className="truncate text-[12px] text-avia-black/45">{subtitle}</div>
      </div>
      <ChevronRight className="h-4 w-4 shrink-0 text-avia-black/35" />
    </Link>
  );
}
