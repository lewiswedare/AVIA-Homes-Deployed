import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  Bath,
  BedDouble,
  Car,
  Check,
  CheckCircle2,
  ChevronRight,
  Clock,
  FileSignature,
  Mail,
  MapPin,
  Maximize,
  PenLine,
  Phone,
  Send,
  XCircle,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { toast } from "sonner";

import {
  BentoCard,
  EmptyState,
  InitialsAvatar,
  Modal,
  PrimaryButton,
  SecondaryButton,
  Spinner,
  StatusPill,
} from "@/components/avia/ui";
import EOIFormModal from "@/components/catalog/EOIFormModal";
import { CatalogSection, CoverImage, DetailRow, SpecStat, findDesignByName } from "@/components/catalog/shared";
import { useAuth } from "@/hooks/useAuth";
import {
  SPEC_TIER_FALLBACK_HERO,
  assignmentForPackage,
  contractStatusLabel,
  emptyAssignment,
  eoiStatusLabel,
  estateOf,
  notifyUsers,
  pkgBathrooms,
  pkgBedrooms,
  pkgGarages,
  responseFor,
  saveAssignment,
  withClientResponse,
  withClientShared,
  withClientUnshared,
} from "@/lib/catalog";
import { fmtDate, fullNameOf, initialsOf } from "@/lib/format";
import {
  useEstates,
  useFacades,
  useHomeDesigns,
  usePackageAssignments,
  usePackages,
  useProfiles,
  useSpecRangeTiers,
} from "@/lib/queries";
import type { PackageAssignmentRow, ProfileRow } from "@/lib/types";
import {
  RESPONSE_ACCEPTED,
  RESPONSE_DECLINED,
  RESPONSE_PENDING,
  asSpecTier,
  canAllocatePackages,
  isClientRole,
  specTierLabel,
  specTierTagline,
} from "@/lib/types";

/** Package detail — mirrors iOS PackageDetailView with role-gated CTAs. */
export default function PackageDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { role, userId, profile } = useAuth();
  const packagesQ = usePackages();
  const assignmentsQ = usePackageAssignments();
  const designsQ = useHomeDesigns();
  const facadesQ = useFacades();
  const estatesQ = useEstates();
  const tiersQ = useSpecRangeTiers();
  const profilesQ = useProfiles();
  const queryClient = useQueryClient();

  const [eoiOpen, setEoiOpen] = useState<boolean>(false);
  const [eoiResubmit, setEoiResubmit] = useState<boolean>(false);
  const [shareOpen, setShareOpen] = useState<boolean>(false);
  const [declineOpen, setDeclineOpen] = useState<boolean>(false);

  const pkg = useMemo(() => (packagesQ.data ?? []).find((p) => p.id === id) ?? null, [packagesQ.data, id]);
  const assignment = useMemo(() => assignmentForPackage(assignmentsQ.data, id ?? ""), [assignmentsQ.data, id]);
  const myResponse = useMemo(() => responseFor(assignment, userId), [assignment, userId]);
  const design = useMemo(
    () => (pkg && !pkg.is_custom ? findDesignByName(designsQ.data, pkg.home_design) : null),
    [designsQ.data, pkg],
  );
  const facade = useMemo(
    () => (facadesQ.data ?? []).find((f) => f.id === pkg?.selected_facade_id) ?? null,
    [facadesQ.data, pkg],
  );
  const estate = useMemo(
    () => (estatesQ.data ?? []).find((e) => pkg && e.name === estateOf(pkg)) ?? null,
    [estatesQ.data, pkg],
  );
  const tier = pkg ? asSpecTier(pkg.spec_tier) : "messina";
  const tierRow = (tiersQ.data ?? []).find((t) => t.tier === tier) ?? null;

  const decline = useMutation({
    mutationFn: async () => {
      if (!pkg || !userId) return;
      const base = assignment ?? emptyAssignment(pkg.id);
      await saveAssignment(withClientResponse(base, userId, RESPONSE_DECLINED));
      const staffIds = (profilesQ.data ?? [])
        .filter((p) => ["Staff", "Admin", "SalesAdmin", "SuperAdmin"].includes(p.role))
        .map((p) => p.id);
      const partnerIds = (base.assigned_partner_ids ?? []);
      await notifyUsers({
        recipientIds: [...staffIds, ...partnerIds],
        senderId: userId,
        senderName: profile ? fullNameOf(profile) : "Client",
        type: "package_declined",
        title: "Package Declined",
        message: `${profile ? fullNameOf(profile) : "A client"} declined ${pkg.title}`,
        referenceId: pkg.id,
        referenceType: "package",
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["package_assignments"] });
      toast.success("Package declined");
      setDeclineOpen(false);
      navigate("/my-package");
    },
    onError: (err: Error) => toast.error(`Couldn't record your response: ${err.message}`),
  });

  if (packagesQ.isLoading || assignmentsQ.isLoading) return <Spinner />;
  if (!pkg) {
    return <EmptyState icon={XCircle} title="Package not found" subtitle="It may have been removed or unshared." />;
  }

  const client = isClientRole(role);
  const canShare = canAllocatePackages(role) || role === "Staff";
  const eoiStatus = assignment?.eoi_status ?? "none";
  const contractStatus = assignment?.contract_status ?? "none";

  return (
    <div className="animate-fade-in space-y-5">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="flex items-center gap-1.5 text-[13px] font-medium text-avia-black/55 transition-colors hover:text-avia-black"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      {/* Hero */}
      <BentoCard className="overflow-hidden">
        <CoverImage src={pkg.image_url} alt={pkg.title} className="h-64 sm:h-80">
          <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/70 to-transparent p-5 pt-16">
            <div className="flex flex-wrap items-center gap-2">
              {pkg.is_new && (
                <span className="rounded-full bg-avia-brown px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-white">
                  New Listing
                </span>
              )}
              <span className="rounded-full border border-white/50 px-2 py-0.5 text-[10px] font-medium text-white">
                Available
              </span>
            </div>
            <h1 className="mt-2 text-[24px] font-medium leading-tight text-white">{pkg.title}</h1>
            <div className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1">
              <span className="text-[20px] font-semibold text-white">{pkg.price}</span>
              <span className="flex items-center gap-1 text-[13px] text-white/80">
                <MapPin className="h-3.5 w-3.5" /> {pkg.location}
              </span>
            </div>
          </div>
        </CoverImage>
      </BentoCard>

      <div className="grid gap-5 lg:grid-cols-[2fr,1fr]">
        <div className="space-y-5">
          {/* Price breakdown */}
          <CatalogSection title="Package Price">
            <BentoCard className="p-4">
              <div className="flex items-center justify-between">
                <span className="text-[24px] font-semibold text-avia-brown">{pkg.price}</span>
                <StatusPill label="Turnkey" />
              </div>
              <div className="mt-3 grid grid-cols-3 gap-3 border-t border-avia-line/60 pt-3">
                <PriceCell label="Land" value={pkg.land_price} />
                <PriceCell label="House" value={pkg.house_price} />
                <PriceCell label="Specification" value={specTierLabel[tier]} />
              </div>
            </BentoCard>
          </CatalogSection>

          {/* Land details */}
          <CatalogSection title="Land Details">
            <BentoCard className="px-4 py-1.5">
              <DetailRow label="Lot" value={pkg.lot_number} />
              <DetailRow label="Lot Size" value={pkg.lot_size} />
              <DetailRow label="Frontage" value={pkg.lot_frontage} />
              <DetailRow label="Depth" value={pkg.lot_depth} />
              <DetailRow label="Estate" value={estateOf(pkg)} />
              <DetailRow label="Council" value={pkg.council} />
              <DetailRow label="Zoning" value={pkg.zoning} />
              <DetailRow label="Title Status" value={pkg.title_date} />
            </BentoCard>
          </CatalogSection>

          {/* Home design */}
          <CatalogSection title="Home Design">
            {design ? (
              <Link to={`/designs/${encodeURIComponent(design.id)}`} className="block">
                <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                  <CoverImage src={design.image_url} alt={design.name} className="h-52">
                    {design.storeys === 2 && (
                      <span className="absolute left-3 top-3 rounded-full bg-avia-black/50 px-2 py-0.5 text-[10px] font-medium uppercase text-white backdrop-blur">
                        2 Storey
                      </span>
                    )}
                  </CoverImage>
                  <div className="space-y-3 p-4">
                    <div className="flex items-baseline justify-between">
                      <span className="text-[18px] font-medium text-avia-black">{design.name}</span>
                      <span className="text-[13px] text-avia-black/55">{design.square_meters}m²</span>
                    </div>
                    <div className="flex flex-wrap gap-4">
                      <SpecStat icon={BedDouble} label={`${design.bedrooms} Bed`} />
                      <SpecStat icon={Bath} label={`${design.bathrooms} Bath`} />
                      <SpecStat icon={Car} label={`${design.garages} Car`} />
                      {design.living_areas != null && <SpecStat icon={Maximize} label={`${design.living_areas} Living`} />}
                    </div>
                    {design.description && (
                      <p className="line-clamp-3 text-[13px] leading-relaxed text-avia-black/60">{design.description}</p>
                    )}
                    <div className="flex items-center gap-1 text-[13px] font-medium text-avia-brown">
                      View full {design.name} design details <ChevronRight className="h-4 w-4" />
                    </div>
                  </div>
                </BentoCard>
              </Link>
            ) : (
              <BentoCard className="px-4 py-1.5">
                <DetailRow label="Design" value={pkg.home_design} />
                <DetailRow label="Bedrooms" value={String(pkgBedrooms(pkg))} />
                <DetailRow label="Bathrooms" value={String(pkgBathrooms(pkg))} />
                <DetailRow label="Garage" value={String(pkgGarages(pkg))} />
                {pkg.custom_square_meters != null && <DetailRow label="Size" value={`${pkg.custom_square_meters}m²`} />}
              </BentoCard>
            )}
          </CatalogSection>

          {/* Facade */}
          {facade && (
            <CatalogSection title="Included Facade">
              <Link to={`/facades/${encodeURIComponent(facade.id)}`} className="block">
                <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                  <CoverImage src={facade.hero_image_url} alt={facade.name} className="h-40" />
                  <div className="flex items-center justify-between p-4">
                    <div>
                      <div className="text-[15px] font-medium text-avia-black">{facade.name}</div>
                      {facade.style && <div className="text-[12px] text-avia-black/50">{facade.style}</div>}
                    </div>
                    <StatusPill
                      label={facade.pricing_type === "upgrade" ? `Upgrade ${facade.pricing_amount ?? ""}`.trim() : "Included"}
                    />
                  </div>
                </BentoCard>
              </Link>
            </CatalogSection>
          )}

          {/* Spec range */}
          <CatalogSection
            title="Specification Range"
            action={
              <Link to="/spec-ranges" className="text-[12px] font-medium text-avia-brown">
                Compare all ranges
              </Link>
            }
          >
            <Link to={`/spec-ranges/${tier}`} className="block">
              <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                <CoverImage src={tierRow?.hero_image_url ?? SPEC_TIER_FALLBACK_HERO[tier]} alt={specTierLabel[tier]} className="h-40">
                  <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/70 to-transparent p-4 pt-10">
                    <div className="text-[16px] font-medium text-white">{specTierLabel[tier]}</div>
                    <div className="text-[12px] text-white/75">{specTierTagline[tier]}</div>
                  </div>
                </CoverImage>
                <div className="flex items-center justify-between p-4">
                  <StatusPill label="Included" />
                  <span className="flex items-center gap-1 text-[13px] font-medium text-avia-brown">
                    Explore range <ChevronRight className="h-4 w-4" />
                  </span>
                </div>
              </BentoCard>
            </Link>
          </CatalogSection>

          {/* Inclusions */}
          {(pkg.inclusions ?? []).length > 0 && (
            <CatalogSection title="Package Inclusions">
              <BentoCard className="px-4 py-2">
                {(pkg.inclusions ?? []).map((inc, i) => (
                  <div key={`${inc}-${i}`} className="flex items-start gap-2.5 border-b border-avia-line/60 py-2.5 last:border-0">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
                    <span className="text-[13px] text-avia-black/75">{inc}</span>
                  </div>
                ))}
              </BentoCard>
            </CatalogSection>
          )}

          {/* Estate */}
          {estate && (
            <CatalogSection title="Estate">
              <Link to={`/estates/${encodeURIComponent(estate.id)}`} className="block">
                <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
                  <CoverImage src={estate.image_url} alt={estate.name} className="h-36" />
                  <div className="flex items-center justify-between p-4">
                    <div>
                      <div className="text-[15px] font-medium text-avia-black">{estate.name}</div>
                      <div className="text-[12px] text-avia-black/50">{estate.location}</div>
                    </div>
                    <ChevronRight className="h-4 w-4 text-avia-black/40" />
                  </div>
                </BentoCard>
              </Link>
            </CatalogSection>
          )}

          {pkg.build_time_estimate && (
            <BentoCard className="flex items-center gap-3 p-4">
              <Clock className="h-5 w-5 text-avia-brown" />
              <div>
                <div className="text-[13px] font-medium text-avia-black">Estimated Build Time</div>
                <div className="text-[12px] text-avia-black/55">{pkg.build_time_estimate}</div>
              </div>
            </BentoCard>
          )}
        </div>

        {/* CTA column */}
        <div className="space-y-4 lg:sticky lg:top-8 lg:self-start">
          {client ? (
            <ClientCTA
              eoiStatus={eoiStatus}
              contractStatus={contractStatus}
              responseStatus={myResponse?.status ?? null}
              respondedDate={myResponse?.responded_date ?? null}
              onSubmitEOI={() => {
                setEoiResubmit(false);
                setEoiOpen(true);
              }}
              onResubmitEOI={() => {
                setEoiResubmit(true);
                setEoiOpen(true);
              }}
              onDecline={() => setDeclineOpen(true)}
            />
          ) : canShare ? (
            <StaffCTA assignment={assignment} profiles={profilesQ.data} onShare={() => setShareOpen(true)} />
          ) : (
            <BentoCard className="space-y-3 p-4">
              <div className="text-[14px] font-medium text-avia-black">Interested in this package?</div>
              <a href="tel:0756545123" className="flex items-center gap-2 text-[13px] font-medium text-avia-brown">
                <Phone className="h-4 w-4" /> 07 5654 5123
              </a>
              <a href="mailto:sales@aviahomes.com.au" className="flex items-center gap-2 text-[13px] font-medium text-avia-brown">
                <Mail className="h-4 w-4" /> sales@aviahomes.com.au
              </a>
            </BentoCard>
          )}
        </div>
      </div>

      {eoiOpen && (
        <EOIFormModal
          open={eoiOpen}
          onClose={() => setEoiOpen(false)}
          pkg={pkg}
          assignment={assignment ?? emptyAssignment(pkg.id)}
          resubmit={eoiResubmit}
        />
      )}

      <Modal open={declineOpen} onClose={() => setDeclineOpen(false)} title="Decline Package">
        <p className="text-[14px] text-avia-black/70">
          Are you sure you want to decline {pkg.title}? You can ask your contact to re-share it later.
        </p>
        <div className="flex gap-2">
          <SecondaryButton onClick={() => setDeclineOpen(false)} className="flex-1">
            Cancel
          </SecondaryButton>
          <PrimaryButton onClick={() => decline.mutate()} loading={decline.isPending} className="flex-1">
            Decline
          </PrimaryButton>
        </div>
      </Modal>

      {shareOpen && (
        <SharePackageModal
          open={shareOpen}
          onClose={() => setShareOpen(false)}
          packageId={pkg.id}
          packageTitle={pkg.title}
          assignment={assignment}
        />
      )}
    </div>
  );
}

function PriceCell({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-[10px] font-medium uppercase tracking-wider text-avia-black/40">{label}</div>
      <div className="mt-0.5 text-[14px] font-medium text-avia-black">{value || "—"}</div>
    </div>
  );
}

function Banner({
  tone,
  icon: Icon,
  title,
  subtitle,
}: {
  tone: "success" | "warning" | "danger";
  icon: typeof CheckCircle2;
  title: string;
  subtitle: string;
}) {
  const styles = {
    success: "border-green-700/25 bg-green-700/10 text-green-900",
    warning: "border-avia-brown/30 bg-avia-brown/10 text-avia-brown",
    danger: "border-red-700/25 bg-red-700/10 text-red-900",
  } as const;
  return (
    <div className={`flex items-start gap-3 rounded-[12px] border p-4 ${styles[tone]}`}>
      <Icon className="mt-0.5 h-5 w-5 shrink-0" />
      <div>
        <div className="text-[14px] font-medium">{title}</div>
        <div className="text-[12px] opacity-80">{subtitle}</div>
      </div>
    </div>
  );
}

/** Client response section — banner priority mirrors iOS PackageDetailView. */
function ClientCTA({
  eoiStatus,
  contractStatus,
  responseStatus,
  respondedDate,
  onSubmitEOI,
  onResubmitEOI,
  onDecline,
}: {
  eoiStatus: string;
  contractStatus: string;
  responseStatus: string | null;
  respondedDate: string | null;
  onSubmitEOI: () => void;
  onResubmitEOI: () => void;
  onDecline: () => void;
}) {
  if (["awaiting_contract", "awaiting_signature", "awaiting_confirmation"].includes(contractStatus)) {
    return (
      <Banner
        tone="warning"
        icon={FileSignature}
        title={contractStatusLabel(contractStatus)}
        subtitle="Your contract is in progress — our team will guide you through signing and confirmation."
      />
    );
  }
  if (contractStatus === "signed") {
    return <Banner tone="success" icon={CheckCircle2} title="Contract Signed" subtitle="Congratulations — your contract is fully signed." />;
  }
  if (eoiStatus === "submitted" || eoiStatus === "resubmitted") {
    return <Banner tone="warning" icon={Clock} title={eoiStatusLabel(eoiStatus)} subtitle="Your EOI is under review — we'll be in touch shortly." />;
  }
  if (eoiStatus === "approved") {
    return <Banner tone="success" icon={CheckCircle2} title="EOI Approved" subtitle="Awaiting contract preparation." />;
  }
  if (eoiStatus === "changes_requested") {
    return (
      <div className="space-y-3">
        <Banner tone="warning" icon={PenLine} title="Changes Requested" subtitle="Review the notes from our team and resubmit your EOI." />
        <PrimaryButton onClick={onResubmitEOI}>Resubmit EOI</PrimaryButton>
      </div>
    );
  }
  if (responseStatus === RESPONSE_ACCEPTED) {
    return (
      <Banner
        tone="success"
        icon={CheckCircle2}
        title="Package Approved"
        subtitle={respondedDate ? `Accepted ${fmtDate(respondedDate)}` : "You accepted this package."}
      />
    );
  }
  if (responseStatus === RESPONSE_DECLINED) {
    return (
      <div className="space-y-3">
        <Banner tone="danger" icon={XCircle} title="Package Declined" subtitle="You can change your response below." />
        <PrimaryButton onClick={onSubmitEOI}>Accept & Submit EOI</PrimaryButton>
      </div>
    );
  }
  return (
    <div className="space-y-3">
      <BentoCard className="p-4">
        <div className="text-[14px] font-medium text-avia-black">Ready to move forward?</div>
        <p className="mt-1 text-[12px] text-avia-black/55">
          Accepting starts your Expression of Interest — buyer and solicitor details, then deposit instructions.
        </p>
      </BentoCard>
      <PrimaryButton onClick={onSubmitEOI}>Accept & Submit EOI</PrimaryButton>
      <SecondaryButton onClick={onDecline}>Decline Package</SecondaryButton>
    </div>
  );
}

function StaffCTA({
  assignment,
  profiles,
  onShare,
}: {
  assignment: PackageAssignmentRow | null;
  profiles: ProfileRow[] | undefined;
  onShare: () => void;
}) {
  const shared = assignment?.shared_with_client_ids ?? [];
  const responses = assignment?.client_responses ?? [];
  const accepted = responses.filter((r) => r.status === RESPONSE_ACCEPTED).length;
  const pending = responses.filter((r) => r.status === RESPONSE_PENDING).length;
  const partnerCount = (assignment?.assigned_partner_ids ?? []).length;
  const nameOf = (id: string) =>
    fullNameOf((profiles ?? []).find((p) => p.id.toLowerCase() === id.toLowerCase()) ?? { email: "Unknown" });

  return (
    <div className="space-y-3">
      <BentoCard className="space-y-3 p-4">
        <div className="flex items-center justify-between">
          <div className="text-[14px] font-medium text-avia-black">Assignment</div>
          {assignment?.is_exclusive && <StatusPill label="Exclusive" tone="black" />}
        </div>
        <div className="grid grid-cols-2 gap-2 text-center">
          <MiniStat label="Partners" value={partnerCount} />
          <MiniStat label="Shared" value={shared.length} />
          <MiniStat label="Accepted" value={accepted} />
          <MiniStat label="Pending" value={pending} />
        </div>
        {assignment && (assignment.eoi_status ?? "none") !== "none" && (
          <div className="flex items-center justify-between border-t border-avia-line/60 pt-3">
            <span className="text-[12px] text-avia-black/50">EOI</span>
            <StatusPill label={eoiStatusLabel(assignment.eoi_status)} />
          </div>
        )}
        {shared.length > 0 && (
          <div className="space-y-2 border-t border-avia-line/60 pt-3">
            {shared.slice(0, 5).map((cid) => (
              <div key={cid} className="flex items-center gap-2">
                <InitialsAvatar initials={initialsOf(nameOf(cid))} className="h-7 w-7 text-[10px]" />
                <span className="flex-1 truncate text-[13px] text-avia-black/75">{nameOf(cid)}</span>
                <span className="text-[11px] text-avia-black/45">
                  {responses.find((r) => r.client_id.toLowerCase() === cid.toLowerCase())?.status ?? RESPONSE_PENDING}
                </span>
              </div>
            ))}
          </div>
        )}
      </BentoCard>
      <PrimaryButton onClick={onShare}>
        <Send className="h-4 w-4" /> {shared.length > 0 ? "Share with Clients" : "Assign & Share Package"}
      </PrimaryButton>
    </div>
  );
}

function MiniStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-[10px] bg-avia-black/5 px-2 py-2">
      <div className="text-[18px] font-medium text-avia-black">{value}</div>
      <div className="text-[10px] font-medium uppercase tracking-wider text-avia-black/40">{label}</div>
    </div>
  );
}

/** Share/unshare a package with clients — staff, admin & partner flow. */
export function SharePackageModal({
  open,
  onClose,
  packageId,
  packageTitle,
  assignment,
}: {
  open: boolean;
  onClose: () => void;
  packageId: string;
  packageTitle: string;
  assignment: PackageAssignmentRow | null;
}) {
  const { userId, profile, role } = useAuth();
  const profilesQ = useProfiles();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState<string>("");

  const clients = useMemo(
    () =>
      (profilesQ.data ?? [])
        .filter((p) => p.role === "Client" || p.role === "Pending")
        .filter((p) => fullNameOf(p).toLowerCase().includes(search.toLowerCase()) || p.email.toLowerCase().includes(search.toLowerCase())),
    [profilesQ.data, search],
  );

  const sharedSet = new Set((assignment?.shared_with_client_ids ?? []).map((id) => id.toLowerCase()));

  const toggle = useMutation({
    mutationFn: async (client: ProfileRow) => {
      const isPartner = role === "Partner" || role === "SalesPartner";
      let base = assignment ?? emptyAssignment(packageId);
      if (isPartner && userId) {
        const partnerIds = new Set((base.assigned_partner_ids ?? []).map((p) => p.toLowerCase()));
        partnerIds.add(userId.toLowerCase());
        base = { ...base, assigned_partner_ids: Array.from(partnerIds) };
      }
      const currentlyShared = sharedSet.has(client.id.toLowerCase());
      const updated = currentlyShared ? withClientUnshared(base, client.id) : withClientShared(base, client.id);
      if (!updated.assigned_by && userId) updated.assigned_by = userId.toLowerCase();
      await saveAssignment(updated);
      if (!currentlyShared) {
        await notifyUsers({
          recipientIds: [client.id],
          senderId: userId,
          senderName: profile ? fullNameOf(profile) : "AVIA Homes",
          type: "package_shared",
          title: "New Package Shared",
          message: `${packageTitle} has been shared with you — review it in your packages.`,
          referenceId: packageId,
          referenceType: "package",
        });
      }
      return !currentlyShared;
    },
    onSuccess: (nowShared) => {
      void queryClient.invalidateQueries({ queryKey: ["package_assignments"] });
      toast.success(nowShared ? "Package shared" : "Share removed");
    },
    onError: (err: Error) => toast.error(`Couldn't update sharing: ${err.message}`),
  });

  return (
    <Modal open={open} onClose={onClose} title="Share with Clients">
      <input
        className="w-full rounded-[10px] border border-avia-line bg-avia-card px-4 py-2.5 text-[16px] outline-none placeholder:text-avia-black/35 focus:border-avia-brown sm:text-[14px]"
        placeholder="Search clients…"
        aria-label="Search clients"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
      />
      <div className="max-h-80 space-y-1 overflow-y-auto">
        {clients.map((c) => {
          const shared = sharedSet.has(c.id.toLowerCase());
          return (
            <button
              key={c.id}
              type="button"
              disabled={toggle.isPending}
              onClick={() => toggle.mutate(c)}
              className="flex w-full items-center gap-3 rounded-[10px] px-2 py-2 text-left transition-colors hover:bg-avia-black/5 disabled:opacity-60"
            >
              <InitialsAvatar initials={initialsOf(c.first_name, c.last_name)} className="h-8 w-8 text-[11px]" />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-medium text-avia-black">{fullNameOf(c)}</div>
                <div className="truncate text-[12px] text-avia-black/45">{c.email}</div>
              </div>
              {shared ? (
                <StatusPill label="Shared" />
              ) : (
                <span className="rounded-full border border-avia-line px-2.5 py-0.5 text-[11px] text-avia-black/45">Share</span>
              )}
            </button>
          );
        })}
        {clients.length === 0 && <div className="py-8 text-center text-[13px] text-avia-black/45">No clients found</div>}
      </div>
    </Modal>
  );
}
