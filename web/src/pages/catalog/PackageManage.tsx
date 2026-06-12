import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  Check,
  CheckCircle2,
  FileSignature,
  Lock,
  PackageOpen,
  Pencil,
  Plus,
  Search,
  Send,
  Trash2,
  Users,
  X,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Navigate, useNavigate } from "react-router-dom";
import { toast } from "sonner";

import {
  BentoCard,
  EmptyState,
  FieldLabel,
  InitialsAvatar,
  Modal,
  PrimaryButton,
  SecondaryButton,
  Spinner,
  StatusPill,
  inputClass,
} from "@/components/avia/ui";
import { CoverImage } from "@/components/catalog/shared";
import { SharePackageModal } from "@/pages/catalog/PackageDetail";
import { useAuth } from "@/hooks/useAuth";
import {
  assignmentForPackage,
  emptyAssignment,
  eoiStatusLabel,
  notifyUsers,
  saveAssignment,
} from "@/lib/catalog";
import { fmtDateTime, fullNameOf, initialsOf, nowISO, uuid } from "@/lib/format";
import {
  useEOISubmissions,
  useFacades,
  useHomeDesigns,
  usePackageAssignments,
  usePackages,
  useProfiles,
} from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import type {
  EOISubmissionRow,
  HouseLandPackageRow,
  PackageAssignmentRow,
  ProfileRow,
  SpecTierKey,
  UserRole,
} from "@/lib/types";
import {
  RESPONSE_ACCEPTED,
  RESPONSE_DECLINED,
  RESPONSE_PENDING,
  SPEC_TIERS,
  asSpecTier,
  canManagePackages,
  isPartnerRole,
  specTierLabel,
} from "@/lib/types";
import { cn } from "@/lib/utils";

const DEFAULT_INCLUSIONS: string[] = [
  "Fixed site costs",
  "Turnkey inclusions",
  "Driveway & landscaping",
  "Blinds & flyscreens",
  "Air conditioning",
];

type ResponseFilter = "" | "pending" | "accepted" | "declined";

/** Admin package management — mirrors iOS PackageManagementView. */
export default function PackageManage() {
  const { role } = useAuth();
  const navigate = useNavigate();
  const packagesQ = usePackages();
  const assignmentsQ = usePackageAssignments();
  const profilesQ = useProfiles();
  const eoiQ = useEOISubmissions();
  const [search, setSearch] = useState<string>("");
  const [responseFilter, setResponseFilter] = useState<ResponseFilter>("");
  const [editorPkg, setEditorPkg] = useState<HouseLandPackageRow | "new" | null>(null);
  const [sharePkg, setSharePkg] = useState<HouseLandPackageRow | null>(null);
  const [managePkg, setManagePkg] = useState<HouseLandPackageRow | null>(null);
  const [eoiOpen, setEoiOpen] = useState<boolean>(false);

  const packages = packagesQ.data ?? [];
  const assignments = assignmentsQ.data ?? [];

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    let list = packages;
    if (q) list = list.filter((p) => [p.title, p.location].some((v) => v.toLowerCase().includes(q)));
    if (responseFilter) {
      const want = responseFilter === "pending" ? RESPONSE_PENDING : responseFilter === "accepted" ? RESPONSE_ACCEPTED : RESPONSE_DECLINED;
      list = list.filter((p) => {
        const a = assignmentForPackage(assignments, p.id);
        return (a?.client_responses ?? []).some((r) => r.status === want);
      });
    }
    return list;
  }, [packages, assignments, search, responseFilter]);

  const sharedCount = assignments.filter((a) => (a.shared_with_client_ids ?? []).length > 0).length;
  const countBy = (status: string) =>
    assignments.filter((a) => (a.client_responses ?? []).some((r) => r.status === status)).length;
  const pendingEOIs = (eoiQ.data ?? []).filter((e) => e.status === "submitted" || e.status === "resubmitted").length;

  if (!canManagePackages(role)) return <Navigate to="/packages" replace />;
  if (packagesQ.isLoading || assignmentsQ.isLoading) return <Spinner />;

  return (
    <div className="animate-fade-in space-y-5">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="flex items-center gap-1.5 text-[13px] font-medium text-avia-black/55 transition-colors hover:text-avia-black"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-[26px] font-medium text-avia-black">Package Management</h1>
          <p className="text-[13px] text-avia-black/50">Create, assign and convert house & land packages</p>
        </div>
        <button
          type="button"
          onClick={() => setEditorPkg("new")}
          className="flex items-center gap-1.5 rounded-full bg-avia-brown px-4 py-2 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
        >
          <Plus className="h-4 w-4" /> New Package
        </button>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        <StatCard label="Total" value={packages.length} active={false} onClick={() => setResponseFilter("")} />
        <StatCard label="Shared" value={sharedCount} active={false} onClick={() => setResponseFilter("")} />
        <StatCard label="Pending" value={countBy(RESPONSE_PENDING)} active={responseFilter === "pending"} onClick={() => setResponseFilter(responseFilter === "pending" ? "" : "pending")} />
        <StatCard label="Accepted" value={countBy(RESPONSE_ACCEPTED)} active={responseFilter === "accepted"} onClick={() => setResponseFilter(responseFilter === "accepted" ? "" : "accepted")} />
        <StatCard label="Declined" value={countBy(RESPONSE_DECLINED)} active={responseFilter === "declined"} onClick={() => setResponseFilter(responseFilter === "declined" ? "" : "declined")} />
      </div>

      <button
        type="button"
        onClick={() => setEoiOpen(true)}
        className="flex w-full items-center gap-3 rounded-[13px] bg-avia-card p-4 text-left transition-colors hover:bg-avia-cardAlt"
      >
        <FileSignature className="h-5 w-5 text-avia-brown" />
        <span className="flex-1 text-[14px] font-medium text-avia-black">EOI Submissions</span>
        {pendingEOIs > 0 && (
          <span className="rounded-full bg-avia-brown px-2 py-0.5 text-[11px] font-medium text-white">{pendingEOIs}</span>
        )}
      </button>

      <div className="relative">
        <Search className="absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-avia-black/35" />
        <input
          className="w-full rounded-full border border-avia-line bg-avia-card py-2.5 pl-10 pr-4 text-[14px] outline-none placeholder:text-avia-black/35 focus:border-avia-brown"
          placeholder="Search packages…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {filtered.length === 0 ? (
        <EmptyState icon={PackageOpen} title="No packages" subtitle="Create your first package to start sharing." />
      ) : (
        <div className="space-y-3">
          {filtered.map((pkg) => (
            <ManageRow
              key={pkg.id}
              pkg={pkg}
              assignment={assignmentForPackage(assignments, pkg.id)}
              onEdit={() => setEditorPkg(pkg)}
              onShare={() => setSharePkg(pkg)}
              onManage={() => setManagePkg(pkg)}
            />
          ))}
        </div>
      )}

      {editorPkg !== null && (
        <PackageEditorModal pkg={editorPkg === "new" ? null : editorPkg} onClose={() => setEditorPkg(null)} />
      )}
      {sharePkg && (
        <SharePackageModal
          open
          onClose={() => setSharePkg(null)}
          packageId={sharePkg.id}
          packageTitle={sharePkg.title}
          assignment={assignmentForPackage(assignments, sharePkg.id)}
        />
      )}
      {managePkg && (
        <ManageAssignmentModal
          pkg={managePkg}
          assignment={assignmentForPackage(assignments, managePkg.id)}
          profiles={profilesQ.data ?? []}
          onClose={() => setManagePkg(null)}
        />
      )}
      {eoiOpen && <EOIReviewModal onClose={() => setEoiOpen(false)} packages={packages} profiles={profilesQ.data ?? []} />}
    </div>
  );
}

function StatCard({ label, value, active, onClick }: { label: string; value: number; active: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "rounded-[13px] border p-3 text-left transition-colors",
        active ? "border-avia-brown bg-avia-brown/10" : "border-transparent bg-avia-card hover:bg-avia-cardAlt",
      )}
    >
      <div className="text-[22px] font-medium text-avia-black">{value}</div>
      <div className="text-[11px] font-medium uppercase tracking-wider text-avia-black/40">{label}</div>
    </button>
  );
}

function ManageRow({
  pkg,
  assignment,
  onEdit,
  onShare,
  onManage,
}: {
  pkg: HouseLandPackageRow;
  assignment: PackageAssignmentRow | null;
  onEdit: () => void;
  onShare: () => void;
  onManage: () => void;
}) {
  const responses = assignment?.client_responses ?? [];
  const count = (s: string) => responses.filter((r) => r.status === s).length;
  const tier = asSpecTier(pkg.spec_tier);

  return (
    <BentoCard className="space-y-3 p-4">
      <div className="flex items-center gap-3">
        <CoverImage src={pkg.image_url} alt={pkg.title} className="h-16 w-16 shrink-0 rounded-[10px]" />
        <div className="min-w-0 flex-1">
          <div className="truncate text-[15px] font-medium text-avia-black">{pkg.title}</div>
          <div className="text-[12px] text-avia-black/50">
            {pkg.price} · {specTierLabel[tier]}
          </div>
        </div>
        {assignment?.converted_to_build_id && <StatusPill label="Build Created" />}
      </div>
      <div className="flex flex-wrap items-center gap-2 text-[12px]">
        <span className="rounded-full bg-avia-black/5 px-2.5 py-1 text-avia-black/60">
          {(assignment?.shared_with_client_ids ?? []).length} clients · {(assignment?.assigned_partner_ids ?? []).length} partners
        </span>
        {count(RESPONSE_PENDING) > 0 && <StatusPill label={`${count(RESPONSE_PENDING)} pending`} tone="warning" />}
        {count(RESPONSE_ACCEPTED) > 0 && <StatusPill label={`${count(RESPONSE_ACCEPTED)} accepted`} />}
        {count(RESPONSE_DECLINED) > 0 && <StatusPill label={`${count(RESPONSE_DECLINED)} declined`} tone="muted" />}
        {assignment && (assignment.eoi_status ?? "none") !== "none" && (
          <StatusPill label={eoiStatusLabel(assignment.eoi_status)} tone="black" />
        )}
      </div>
      <div className="flex gap-2">
        <RowAction icon={Send} label="Assign" onClick={onShare} />
        <RowAction icon={Pencil} label="Edit" onClick={onEdit} />
        <RowAction icon={Users} label="Manage" onClick={onManage} />
      </div>
    </BentoCard>
  );
}

function RowAction({ icon: Icon, label, onClick }: { icon: typeof Send; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex flex-1 items-center justify-center gap-1.5 rounded-[10px] border border-avia-line bg-avia-cardAlt py-2 text-[13px] font-medium text-avia-black/70 transition-colors hover:border-avia-brown/40 hover:text-avia-brown"
    >
      <Icon className="h-4 w-4" /> {label}
    </button>
  );
}

/** Create/edit a package — condensed version of the iOS 4-step wizard. */
function PackageEditorModal({ pkg, onClose }: { pkg: HouseLandPackageRow | null; onClose: () => void }) {
  const queryClient = useQueryClient();
  const designsQ = useHomeDesigns();
  const facadesQ = useFacades();
  const [draft, setDraft] = useState<Partial<HouseLandPackageRow>>({
    title: pkg?.title ?? "",
    location: pkg?.location ?? "",
    lot_number: pkg?.lot_number ?? "",
    lot_size: pkg?.lot_size ?? "",
    lot_frontage: pkg?.lot_frontage ?? "",
    lot_depth: pkg?.lot_depth ?? "",
    title_date: pkg?.title_date ?? "",
    council: pkg?.council ?? "",
    zoning: pkg?.zoning ?? "",
    build_time_estimate: pkg?.build_time_estimate ?? "",
    is_new: pkg?.is_new ?? true,
    home_design: pkg?.home_design ?? "",
    spec_tier: pkg?.spec_tier ?? "messina",
    selected_facade_id: pkg?.selected_facade_id ?? null,
    image_url: pkg?.image_url ?? "",
    price: pkg?.price ?? "",
    land_price: pkg?.land_price ?? "",
    house_price: pkg?.house_price ?? "",
    is_custom: pkg?.is_custom ?? false,
    custom_bedrooms: pkg?.custom_bedrooms ?? 4,
    custom_bathrooms: pkg?.custom_bathrooms ?? 2,
    custom_garages: pkg?.custom_garages ?? 2,
    custom_storeys: pkg?.custom_storeys ?? 1,
    custom_square_meters: pkg?.custom_square_meters ?? null,
  });
  const [inclusions, setInclusions] = useState<string[]>(pkg?.inclusions ?? DEFAULT_INCLUSIONS);
  const [newInclusion, setNewInclusion] = useState<string>("");
  const [confirmDelete, setConfirmDelete] = useState<boolean>(false);

  const set = (patch: Partial<HouseLandPackageRow>) => setDraft((d) => ({ ...d, ...patch }));

  const save = useMutation({
    mutationFn: async () => {
      if (!(draft.title ?? "").trim() || !(draft.location ?? "").trim()) throw new Error("Title and location are required");
      const row = {
        ...draft,
        id: pkg?.id ?? uuid(),
        inclusions,
        selected_facade_id: draft.selected_facade_id || null,
      };
      const { error } = await supabase.from("house_land_packages").upsert(row, { onConflict: "id" });
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["house_land_packages"] });
      toast.success("Package saved");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const remove = useMutation({
    mutationFn: async () => {
      if (!pkg) return;
      const { error } = await supabase.from("house_land_packages").delete().eq("id", pkg.id);
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["house_land_packages"] });
      toast.success("Package deleted");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const pickDesign = (designId: string) => {
    const d = (designsQ.data ?? []).find((x) => x.id === designId);
    if (!d) {
      set({ home_design: "" });
      return;
    }
    const estate = (draft.location ?? "").split(",")[0]?.trim() ?? "";
    set({
      home_design: `${d.name} ${Math.round(d.square_meters)}`,
      image_url: draft.image_url || d.image_url,
      title: draft.title || `${d.name} ${Math.round(d.square_meters)}${estate ? ` at ${estate}` : ""}`,
    });
  };

  const text = (label: string, key: keyof HouseLandPackageRow, placeholder?: string) => (
    <div className="space-y-1.5">
      <FieldLabel>{label}</FieldLabel>
      <input
        className={inputClass}
        value={(draft[key] as string | null) ?? ""}
        placeholder={placeholder}
        onChange={(e) => set({ [key]: e.target.value } as Partial<HouseLandPackageRow>)}
      />
    </div>
  );

  return (
    <Modal open onClose={onClose} title={pkg ? "Edit Package" : "New Package"}>
      <div className="text-[11px] font-medium uppercase tracking-wider text-avia-black/40">Land</div>
      {text("Title", "title")}
      {text("Location", "location", "Estate, Suburb QLD")}
      <div className="grid grid-cols-2 gap-3">
        {text("Lot Number", "lot_number")}
        {text("Lot Size", "lot_size", "e.g. 400m²")}
      </div>
      <div className="grid grid-cols-2 gap-3">
        {text("Frontage", "lot_frontage")}
        {text("Depth", "lot_depth")}
      </div>
      <div className="grid grid-cols-2 gap-3">
        {text("Title Status", "title_date", "e.g. Registered")}
        {text("Council", "council")}
      </div>
      <div className="grid grid-cols-2 gap-3">
        {text("Zoning", "zoning")}
        {text("Build Time", "build_time_estimate", "e.g. 20–24 weeks")}
      </div>
      <label className="flex items-center gap-2 text-[13px] font-medium text-avia-black/70">
        <input type="checkbox" checked={draft.is_new ?? false} onChange={(e) => set({ is_new: e.target.checked })} className="h-4 w-4 accent-avia-brown" />
        Mark as New Listing
      </label>

      <div className="pt-1 text-[11px] font-medium uppercase tracking-wider text-avia-black/40">House</div>
      <label className="flex items-center gap-2 text-[13px] font-medium text-avia-black/70">
        <input type="checkbox" checked={draft.is_custom ?? false} onChange={(e) => set({ is_custom: e.target.checked })} className="h-4 w-4 accent-avia-brown" />
        Custom Home
      </label>
      {draft.is_custom ? (
        <>
          {text("Design Name", "home_design")}
          <div className="grid grid-cols-2 gap-3">
            <NumField label="Size (m²)" value={draft.custom_square_meters ?? 0} onChange={(v) => set({ custom_square_meters: v || null })} />
            <NumField label="Storeys" value={draft.custom_storeys ?? 1} onChange={(v) => set({ custom_storeys: v })} />
          </div>
          <div className="grid grid-cols-3 gap-2">
            <NumField label="Bed" value={draft.custom_bedrooms ?? 4} onChange={(v) => set({ custom_bedrooms: v })} />
            <NumField label="Bath" value={draft.custom_bathrooms ?? 2} onChange={(v) => set({ custom_bathrooms: v })} />
            <NumField label="Car" value={draft.custom_garages ?? 2} onChange={(v) => set({ custom_garages: v })} />
          </div>
        </>
      ) : (
        <div className="space-y-1.5">
          <FieldLabel>Home Design</FieldLabel>
          <select
            className={inputClass}
            value={(designsQ.data ?? []).find((d) => (draft.home_design ?? "").toLowerCase().startsWith(d.name.toLowerCase()))?.id ?? ""}
            onChange={(e) => pickDesign(e.target.value)}
          >
            <option value="">Select a design…</option>
            {(designsQ.data ?? []).map((d) => (
              <option key={d.id} value={d.id}>
                {d.name} — {Math.round(d.square_meters)}m² · {d.bedrooms} bed
              </option>
            ))}
          </select>
        </div>
      )}
      <div className="space-y-1.5">
        <FieldLabel>Spec Tier</FieldLabel>
        <div className="flex gap-2">
          {SPEC_TIERS.map((t: SpecTierKey) => (
            <button
              key={t}
              type="button"
              onClick={() => set({ spec_tier: t })}
              className={cn(
                "flex-1 rounded-[10px] border px-2 py-2.5 text-[12px] font-medium transition-colors",
                draft.spec_tier === t ? "border-avia-brown bg-avia-brown text-avia-white" : "border-avia-line bg-avia-card text-avia-black/60",
              )}
            >
              {specTierLabel[t]}
            </button>
          ))}
        </div>
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Facade (optional)</FieldLabel>
        <select className={inputClass} value={draft.selected_facade_id ?? ""} onChange={(e) => set({ selected_facade_id: e.target.value || null })}>
          <option value="">None</option>
          {(facadesQ.data ?? []).map((f) => (
            <option key={f.id} value={f.id}>{f.name}</option>
          ))}
        </select>
      </div>
      {text("Image URL", "image_url", "https://…")}

      <div className="pt-1 text-[11px] font-medium uppercase tracking-wider text-avia-black/40">Pricing</div>
      {text("Total Price", "price", "$675,000")}
      <div className="grid grid-cols-2 gap-3">
        {text("Land Price", "land_price")}
        {text("House Price", "house_price")}
      </div>
      <div className="space-y-2">
        <FieldLabel>Inclusions</FieldLabel>
        {inclusions.map((inc, i) => (
          <div key={`${inc}-${i}`} className="flex items-center gap-2">
            <span className="flex-1 rounded-[10px] bg-avia-card px-3 py-2 text-[13px] text-avia-black/75">{inc}</span>
            <button type="button" aria-label="Remove inclusion" onClick={() => setInclusions(inclusions.filter((_, j) => j !== i))} className="rounded-full p-1.5 text-avia-black/40 hover:bg-avia-black/5">
              <X className="h-4 w-4" />
            </button>
          </div>
        ))}
        <div className="flex gap-2">
          <input className={inputClass} value={newInclusion} placeholder="Add inclusion…" onChange={(e) => setNewInclusion(e.target.value)} />
          <button
            type="button"
            onClick={() => {
              if (newInclusion.trim()) {
                setInclusions([...inclusions, newInclusion.trim()]);
                setNewInclusion("");
              }
            }}
            className="shrink-0 rounded-[10px] bg-avia-brown px-4 text-[13px] font-medium text-white"
          >
            Add
          </button>
        </div>
      </div>

      <PrimaryButton onClick={() => save.mutate()} loading={save.isPending}>Save Package</PrimaryButton>
      {pkg && (
        confirmDelete ? (
          <div className="flex gap-2">
            <SecondaryButton onClick={() => setConfirmDelete(false)} className="flex-1">Cancel</SecondaryButton>
            <button
              type="button"
              onClick={() => remove.mutate()}
              className="flex h-[50px] flex-1 items-center justify-center gap-2 rounded-[11px] bg-red-700 text-[15px] font-medium text-white"
            >
              <Trash2 className="h-4 w-4" /> Delete
            </button>
          </div>
        ) : (
          <button type="button" onClick={() => setConfirmDelete(true)} className="w-full text-center text-[13px] font-medium text-red-700">
            Delete Package
          </button>
        )
      )}
    </Modal>
  );
}

function NumField({ label, value, onChange }: { label: string; value: number; onChange: (v: number) => void }) {
  return (
    <div className="space-y-1.5">
      <FieldLabel>{label}</FieldLabel>
      <input className={inputClass} type="number" min={0} value={value} onChange={(e) => onChange(Number(e.target.value) || 0)} />
    </div>
  );
}

/** Partners / exclusivity / responses — mirrors iOS PackageAssignmentSheet. */
function ManageAssignmentModal({
  pkg,
  assignment,
  profiles,
  onClose,
}: {
  pkg: HouseLandPackageRow;
  assignment: PackageAssignmentRow | null;
  profiles: ProfileRow[];
  onClose: () => void;
}) {
  const { userId } = useAuth();
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<"partners" | "responses">("partners");

  const partners = profiles.filter((p) => isPartnerRole(p.role as UserRole));
  const partnerSet = new Set((assignment?.assigned_partner_ids ?? []).map((id) => id.toLowerCase()));

  const togglePartner = useMutation({
    mutationFn: async (partner: ProfileRow) => {
      const base = assignment ?? emptyAssignment(pkg.id);
      const pid = partner.id.toLowerCase();
      const ids = new Set((base.assigned_partner_ids ?? []).map((id) => id.toLowerCase()));
      const adding = !ids.has(pid);
      if (adding) ids.add(pid);
      else ids.delete(pid);
      await saveAssignment({ ...base, assigned_partner_ids: Array.from(ids), assigned_by: base.assigned_by ?? userId });
      if (adding) {
        await notifyUsers({
          recipientIds: [partner.id],
          senderId: userId,
          senderName: "AVIA Homes",
          type: "package_shared",
          title: "Package Assigned",
          message: `${pkg.title} has been assigned to you.`,
          referenceId: pkg.id,
          referenceType: "package",
        });
      }
    },
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["package_assignments"] }),
    onError: (err: Error) => toast.error(err.message),
  });

  const toggleExclusive = useMutation({
    mutationFn: async () => {
      const base = assignment ?? emptyAssignment(pkg.id);
      await saveAssignment({ ...base, is_exclusive: !(base.is_exclusive ?? false) });
    },
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ["package_assignments"] }),
    onError: (err: Error) => toast.error(err.message),
  });

  const nameOf = (id: string) =>
    fullNameOf(profiles.find((p) => p.id.toLowerCase() === id.toLowerCase()) ?? { email: "Unknown" });

  return (
    <Modal open onClose={onClose} title={`Manage — ${pkg.title}`}>
      <div className="flex gap-2">
        <TabButton label="Partners" active={tab === "partners"} onClick={() => setTab("partners")} />
        <TabButton label="Responses" active={tab === "responses"} onClick={() => setTab("responses")} />
      </div>

      {tab === "partners" && (
        <div className="space-y-3">
          <button
            type="button"
            onClick={() => toggleExclusive.mutate()}
            className="flex w-full items-center gap-3 rounded-[12px] bg-avia-card p-3.5 text-left"
          >
            <Lock className="h-4 w-4 text-avia-brown" />
            <div className="flex-1">
              <div className="text-[14px] font-medium text-avia-black">Exclusive Assignment</div>
              <div className="text-[12px] text-avia-black/50">Only assigned partners may share this package</div>
            </div>
            <span
              className={cn(
                "rounded-full px-2.5 py-0.5 text-[11px] font-medium",
                assignment?.is_exclusive ? "bg-avia-brown text-white" : "bg-avia-black/10 text-avia-black/55",
              )}
            >
              {assignment?.is_exclusive ? "On" : "Off"}
            </span>
          </button>
          <div className="max-h-72 space-y-1 overflow-y-auto">
            {partners.map((p) => {
              const active = partnerSet.has(p.id.toLowerCase());
              return (
                <button
                  key={p.id}
                  type="button"
                  disabled={togglePartner.isPending}
                  onClick={() => togglePartner.mutate(p)}
                  className="flex w-full items-center gap-3 rounded-[10px] px-2 py-2 text-left transition-colors hover:bg-avia-black/5"
                >
                  <InitialsAvatar initials={initialsOf(p.first_name, p.last_name)} className="h-8 w-8 text-[11px]" />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-medium text-avia-black">{fullNameOf(p)}</div>
                    <div className="truncate text-[12px] text-avia-black/45">{p.role}</div>
                  </div>
                  {active ? <StatusPill label="Assigned" /> : <span className="text-[12px] text-avia-black/35">Assign</span>}
                </button>
              );
            })}
            {partners.length === 0 && <div className="py-6 text-center text-[13px] text-avia-black/45">No partners yet</div>}
          </div>
        </div>
      )}

      {tab === "responses" && (
        <div className="max-h-80 space-y-2 overflow-y-auto">
          {(assignment?.client_responses ?? []).length === 0 && (
            <div className="py-6 text-center text-[13px] text-avia-black/45">No client responses yet</div>
          )}
          {(assignment?.client_responses ?? []).map((r) => (
            <div key={r.client_id} className="flex items-center gap-3 rounded-[12px] bg-avia-card p-3">
              <InitialsAvatar initials={initialsOf(nameOf(r.client_id))} className="h-8 w-8 text-[11px]" />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-medium text-avia-black">{nameOf(r.client_id)}</div>
                {r.responded_date && <div className="text-[11px] text-avia-black/45">{fmtDateTime(r.responded_date)}</div>}
                {r.notes && <div className="text-[12px] text-avia-black/60">{r.notes}</div>}
              </div>
              <StatusPill
                label={r.status}
                tone={r.status === RESPONSE_ACCEPTED ? "brown" : r.status === RESPONSE_DECLINED ? "muted" : "warning"}
              />
            </div>
          ))}
        </div>
      )}
    </Modal>
  );
}

function TabButton({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "flex-1 rounded-[10px] py-2 text-[13px] font-medium transition-colors",
        active ? "bg-avia-brown text-white" : "bg-avia-card text-avia-black/55",
      )}
    >
      {label}
    </button>
  );
}

/** Review submitted EOIs — approve / request changes / decline. */
function EOIReviewModal({
  onClose,
  packages,
  profiles,
}: {
  onClose: () => void;
  packages: HouseLandPackageRow[];
  profiles: ProfileRow[];
}) {
  const { userId } = useAuth();
  const eoiQ = useEOISubmissions();
  const assignmentsQ = usePackageAssignments();
  const queryClient = useQueryClient();
  const [notes, setNotes] = useState<Record<string, string>>({});

  // Latest submission per assignment (list is already newest-first).
  const latest = useMemo(() => {
    const seen = new Set<string>();
    const out: EOISubmissionRow[] = [];
    for (const e of eoiQ.data ?? []) {
      if (seen.has(e.package_assignment_id)) continue;
      seen.add(e.package_assignment_id);
      out.push(e);
    }
    return out.filter((e) => e.status === "submitted" || e.status === "resubmitted");
  }, [eoiQ.data]);

  const review = useMutation({
    mutationFn: async ({ eoi, decision }: { eoi: EOISubmissionRow; decision: "approved" | "declined" | "changes_requested" }) => {
      const adminNote = (notes[eoi.id] ?? "").trim() || null;
      const { error } = await supabase
        .from("eoi_submissions")
        .update({ status: decision, admin_notes: adminNote, reviewed_by: userId, reviewed_at: nowISO(), updated_at: nowISO() })
        .eq("id", eoi.id);
      if (error) throw error;
      const assignment = (assignmentsQ.data ?? []).find((a) => a.id === eoi.package_assignment_id);
      if (assignment) await saveAssignment({ ...assignment, eoi_status: decision });
      const pkgTitle = packages.find((p) => p.id === eoi.package_id)?.title ?? "your package";
      const typeMap = { approved: "eoi_approved", declined: "package_declined", changes_requested: "eoi_changes_requested" } as const;
      const msgMap = {
        approved: `Your EOI for ${pkgTitle} has been approved. We'll prepare your contract next.`,
        declined: `Your EOI for ${pkgTitle} was declined. Contact us to discuss next steps.`,
        changes_requested: `Changes were requested on your EOI for ${pkgTitle}${adminNote ? `: ${adminNote}` : "."}`,
      } as const;
      await notifyUsers({
        recipientIds: [eoi.client_id],
        senderId: userId,
        senderName: "AVIA Homes",
        type: typeMap[decision],
        title: decision === "approved" ? "EOI Approved" : decision === "declined" ? "EOI Declined" : "EOI Changes Requested",
        message: msgMap[decision],
        referenceId: eoi.package_id,
        referenceType: "package",
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["eoi_submissions"] });
      void queryClient.invalidateQueries({ queryKey: ["package_assignments"] });
      toast.success("EOI updated");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const nameOf = (id: string) =>
    fullNameOf(profiles.find((p) => p.id.toLowerCase() === id.toLowerCase()) ?? { email: "Unknown client" });

  return (
    <Modal open onClose={onClose} title="EOI Submissions">
      {latest.length === 0 && <div className="py-8 text-center text-[13px] text-avia-black/45">No EOIs awaiting review</div>}
      <div className="max-h-[60vh] space-y-3 overflow-y-auto">
        {latest.map((eoi) => {
          const pkg = packages.find((p) => p.id === eoi.package_id);
          return (
            <div key={eoi.id} className="space-y-2.5 rounded-[12px] bg-avia-card p-4">
              <div className="flex items-center justify-between gap-2">
                <div className="min-w-0">
                  <div className="truncate text-[14px] font-medium text-avia-black">{pkg?.title ?? eoi.package_id}</div>
                  <div className="text-[12px] text-avia-black/50">
                    {nameOf(eoi.client_id)} · {fmtDateTime(eoi.created_at)}
                  </div>
                </div>
                <StatusPill label={eoi.status === "resubmitted" ? "Resubmitted" : "Submitted"} tone="warning" />
              </div>
              <div className="grid grid-cols-2 gap-x-4 gap-y-1 text-[12px] text-avia-black/65">
                <span>Buyer: {eoi.buyer1_name}</span>
                <span>Phone: {eoi.buyer1_phone}</span>
                {eoi.buyer2_name && <span>Buyer 2: {eoi.buyer2_name}</span>}
                <span>Solicitor: {eoi.solicitor_company}</span>
                <span>Occupancy: {eoi.occupancy_type ?? "—"}</span>
                {eoi.street_suburb && <span>Address: {eoi.street_suburb}</span>}
              </div>
              <input
                className={inputClass}
                placeholder="Admin notes (sent to client for change requests)…"
                value={notes[eoi.id] ?? ""}
                onChange={(e) => setNotes((n) => ({ ...n, [eoi.id]: e.target.value }))}
              />
              <div className="flex gap-2">
                <button
                  type="button"
                  disabled={review.isPending}
                  onClick={() => review.mutate({ eoi, decision: "approved" })}
                  className="flex flex-1 items-center justify-center gap-1.5 rounded-[10px] bg-green-700 py-2 text-[13px] font-medium text-white disabled:opacity-50"
                >
                  <CheckCircle2 className="h-4 w-4" /> Approve
                </button>
                <button
                  type="button"
                  disabled={review.isPending}
                  onClick={() => review.mutate({ eoi, decision: "changes_requested" })}
                  className="flex flex-1 items-center justify-center gap-1.5 rounded-[10px] bg-avia-brown py-2 text-[13px] font-medium text-white disabled:opacity-50"
                >
                  <Pencil className="h-4 w-4" /> Changes
                </button>
                <button
                  type="button"
                  disabled={review.isPending}
                  onClick={() => review.mutate({ eoi, decision: "declined" })}
                  className="flex flex-1 items-center justify-center gap-1.5 rounded-[10px] bg-red-700 py-2 text-[13px] font-medium text-white disabled:opacity-50"
                >
                  <X className="h-4 w-4" /> Decline
                </button>
              </div>
            </div>
          );
        })}
      </div>
      <div className="flex items-center gap-2 text-[11px] text-avia-black/40">
        <Check className="h-3.5 w-3.5" /> Approving updates the package status and notifies the client.
      </div>
    </Modal>
  );
}
