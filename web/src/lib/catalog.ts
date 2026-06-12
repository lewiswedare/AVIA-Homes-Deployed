import { nowISO, uuid } from "./format";
import { supabase } from "./supabase";
import type {
  ClientPackageResponse,
  HouseLandPackageRow,
  PackageAssignmentRow,
  ProfileRow,
  UserRole,
} from "./types";
import { RESPONSE_DECLINED, RESPONSE_PENDING } from "./types";

/** Estate name derived from a package location — first comma segment (iOS parity). */
export function estateOf(pkg: Pick<HouseLandPackageRow, "location">): string {
  return (pkg.location.split(",")[0] ?? "").trim();
}

export function pkgBedrooms(pkg: HouseLandPackageRow): number {
  return pkg.custom_bedrooms ?? 4;
}
export function pkgBathrooms(pkg: HouseLandPackageRow): number {
  return pkg.custom_bathrooms ?? 2;
}
export function pkgGarages(pkg: HouseLandPackageRow): number {
  return pkg.custom_garages ?? 2;
}

export function assignmentForPackage(
  assignments: PackageAssignmentRow[] | undefined,
  packageId: string,
): PackageAssignmentRow | null {
  return (assignments ?? []).find((a) => a.package_id === packageId) ?? null;
}

export function responseFor(
  assignment: PackageAssignmentRow | null,
  userId: string | null,
): ClientPackageResponse | null {
  if (!assignment || !userId) return null;
  const uid = userId.toLowerCase();
  return (assignment.client_responses ?? []).find((r) => r.client_id.toLowerCase() === uid) ?? null;
}

/**
 * Role-scoped package visibility — mirrors iOS `packagesForCurrentUser`, with
 * the SuperAdmin gap fixed (they see everything like other admins).
 */
export function visiblePackages(
  role: UserRole,
  userId: string | null,
  packages: HouseLandPackageRow[] | undefined,
  assignments: PackageAssignmentRow[] | undefined,
): HouseLandPackageRow[] {
  const all = packages ?? [];
  const uid = (userId ?? "").toLowerCase();
  if (["Staff", "Admin", "SalesAdmin", "SuperAdmin", "PreConstruction", "BuildingSupport"].includes(role)) {
    return all;
  }
  if (role === "Partner" || role === "SalesPartner") {
    const mine = new Set(
      (assignments ?? [])
        .filter((a) => (a.assigned_partner_ids ?? []).some((id) => id.toLowerCase() === uid))
        .map((a) => a.package_id),
    );
    return all.filter((p) => mine.has(p.id));
  }
  if (role === "Client" || role === "Pending") {
    const shared = new Set(
      (assignments ?? [])
        .filter((a) => {
          if (!(a.shared_with_client_ids ?? []).some((id) => id.toLowerCase() === uid)) return false;
          const resp = responseFor(a, uid);
          return resp?.status !== RESPONSE_DECLINED;
        })
        .map((a) => a.package_id),
    );
    return all.filter((p) => shared.has(p.id));
  }
  return [];
}

export function eoiStatusLabel(status: string | null | undefined): string {
  switch (status ?? "none") {
    case "submitted": return "EOI Submitted";
    case "resubmitted": return "EOI Resubmitted";
    case "approved": return "EOI Approved";
    case "declined": return "EOI Declined";
    case "changes_requested": return "Changes Requested";
    default: return "No EOI";
  }
}

export function contractStatusLabel(status: string | null | undefined): string {
  switch (status ?? "none") {
    case "awaiting_contract": return "Contract Being Prepared";
    case "awaiting_signature": return "Awaiting Signature";
    case "awaiting_confirmation": return "Awaiting Confirmation";
    case "signed": return "Contract Signed";
    default: return "No Contract";
  }
}

/** R2 fallback hero images per spec tier (iOS DiscoverFeedView parity). */
export const SPEC_TIER_FALLBACK_HERO: Record<string, string> = {
  volos: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg",
  messina: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg",
  portobello: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg",
};

export const DISCOVER_HERO_IMAGE =
  "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg";

/**
 * Bulk in-app notification fan-out — mirrors the iOS batch insert.
 * Recipient ids are lowercased to match the iOS convention.
 */
export async function notifyUsers(params: {
  recipientIds: string[];
  senderId: string | null;
  senderName: string;
  type: string;
  title: string;
  message: string;
  referenceId?: string | null;
  referenceType?: string | null;
}): Promise<void> {
  const unique = Array.from(new Set(params.recipientIds.map((id) => id.toLowerCase()))).filter(
    (id) => id.length > 0 && id !== (params.senderId ?? "").toLowerCase(),
  );
  if (unique.length === 0) return;
  const rows = unique.map((recipient) => ({
    id: uuid(),
    recipient_id: recipient,
    sender_id: params.senderId,
    sender_name: params.senderName,
    type: params.type,
    title: params.title,
    message: params.message,
    reference_id: params.referenceId ?? null,
    reference_type: params.referenceType ?? null,
    created_at: nowISO(),
    is_read: false,
  }));
  const { error } = await supabase.from("notifications").insert(rows);
  if (error) console.error("[catalog] notification fan-out failed", error.message);
}

/** Staff + admin recipient ids for fan-outs (mirrors iOS notify-all-staff). */
export function staffAndAdminIds(profiles: ProfileRow[] | undefined): string[] {
  return (profiles ?? [])
    .filter((p) => ["Staff", "Admin", "SalesAdmin", "SuperAdmin", "PreConstruction", "BuildingSupport"].includes(p.role as UserRole))
    .map((p) => p.id);
}

/**
 * Saves a package assignment with the RLS-safe select-then-insert/update
 * pattern (deliberately NOT upsert — INSERT and UPDATE have different
 * policies on package_assignments).
 */
export async function saveAssignment(row: PackageAssignmentRow): Promise<void> {
  const { data, error: selErr } = await supabase
    .from("package_assignments")
    .select("id")
    .eq("id", row.id)
    .limit(1);
  if (selErr) throw selErr;
  const payload = { ...row, updated_at: nowISO() };
  if ((data ?? []).length > 0) {
    const { error } = await supabase.from("package_assignments").update(payload).eq("id", row.id);
    if (error) throw error;
  } else {
    const { error } = await supabase.from("package_assignments").insert(payload);
    if (error) throw error;
  }
}

export function emptyAssignment(packageId: string): PackageAssignmentRow {
  return {
    id: uuid(),
    package_id: packageId,
    assigned_partner_ids: [],
    shared_with_client_ids: [],
    client_responses: [],
    is_exclusive: false,
    assigned_by: null,
    deposit_status: "pending",
    deposit_amount: null,
    deposit_due_date: null,
    admin_confirmed_by: null,
    admin_confirmed_at: null,
    eoi_status: "none",
    contract_status: "none",
    converted_to_build_id: null,
    converted_at: null,
    created_at: nowISO(),
    updated_at: nowISO(),
  };
}

/** Adds/refreshes a client share on an assignment (pending response row). */
export function withClientShared(assignment: PackageAssignmentRow, clientId: string): PackageAssignmentRow {
  const uid = clientId.toLowerCase();
  const shared = new Set((assignment.shared_with_client_ids ?? []).map((id) => id.toLowerCase()));
  shared.add(uid);
  const responses = (assignment.client_responses ?? []).filter((r) => r.client_id.toLowerCase() !== uid);
  responses.push({ client_id: uid, status: RESPONSE_PENDING, responded_date: null, notes: null });
  return { ...assignment, shared_with_client_ids: Array.from(shared), client_responses: responses };
}

export function withClientUnshared(assignment: PackageAssignmentRow, clientId: string): PackageAssignmentRow {
  const uid = clientId.toLowerCase();
  return {
    ...assignment,
    shared_with_client_ids: (assignment.shared_with_client_ids ?? []).filter((id) => id.toLowerCase() !== uid),
    client_responses: (assignment.client_responses ?? []).filter((r) => r.client_id.toLowerCase() !== uid),
  };
}

/** Records a client's accept/decline response on an assignment. */
export function withClientResponse(
  assignment: PackageAssignmentRow,
  clientId: string,
  status: string,
  notes?: string | null,
): PackageAssignmentRow {
  const uid = clientId.toLowerCase();
  const responses = (assignment.client_responses ?? []).filter((r) => r.client_id.toLowerCase() !== uid);
  responses.push({ client_id: uid, status, responded_date: nowISO(), notes: notes ?? null });
  return { ...assignment, client_responses: responses };
}
