import { useQuery, type UseQueryResult } from "@tanstack/react-query";

import { supabase } from "./supabase";
import type {
  BlogPostRow,
  BuildRow,
  BuildSpecSelectionRow,
  BuildStageRow,
  ChatMessageRow,
  ClientCRMProfileRow,
  ClientDocumentRow,
  ClientNoteRow,
  ClientTaskRow,
  ConversationRow,
  DisplayHomeRow,
  DisplayHomeVisitRow,
  EmailSendRow,
  EOISubmissionRow,
  FacadeRow,
  HomeDesignRow,
  HouseLandPackageRow,
  LandEstateRow,
  LeadRow,
  LibraryDocumentRow,
  NotificationRow,
  PackageAssignmentEOIRow,
  PackageAssignmentRow,
  ProfileRow,
  ScheduleItemRow,
  ServiceRequestRow,
  SpecCategoryRow,
  SpecItemRow,
  SpecProductColourRow,
  SpecProductRow,
  SpecRangeItemProductRow,
  SpecRangeTierRow,
  StocklistEstateRow,
  StocklistItemRow,
} from "./types";

async function selectAll<T>(table: string): Promise<T[]> {
  const { data, error } = await supabase.from(table).select("*");
  if (error) throw error;
  return (data ?? []) as T[];
}

export function useProfiles(): UseQueryResult<ProfileRow[]> {
  return useQuery({
    queryKey: ["profiles"],
    queryFn: async (): Promise<ProfileRow[]> => {
      const { data, error } = await supabase.from("profiles").select("*").order("last_name");
      if (error) throw error;
      return (data ?? []) as ProfileRow[];
    },
  });
}

export function useProfile(userId: string | null): UseQueryResult<ProfileRow | null> {
  return useQuery({
    queryKey: ["profile", userId],
    enabled: Boolean(userId),
    queryFn: async (): Promise<ProfileRow | null> => {
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", userId ?? "")
        .maybeSingle();
      if (error) throw error;
      return (data as ProfileRow | null) ?? null;
    },
  });
}

export function useOpenTasks(enabled: boolean = true): UseQueryResult<ClientTaskRow[]> {
  return useQuery({
    queryKey: ["client_tasks", "open"],
    enabled,
    queryFn: async (): Promise<ClientTaskRow[]> => {
      const { data, error } = await supabase
        .from("client_tasks")
        .select("*")
        .is("completed_at", null)
        .order("due_at", { ascending: true, nullsFirst: false });
      if (error) throw error;
      return (data ?? []) as ClientTaskRow[];
    },
  });
}

export function useTasksForClient(clientId: string): UseQueryResult<ClientTaskRow[]> {
  return useQuery({
    queryKey: ["client_tasks", "client", clientId],
    queryFn: async (): Promise<ClientTaskRow[]> => {
      const { data, error } = await supabase
        .from("client_tasks")
        .select("*")
        .eq("client_id", clientId)
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as ClientTaskRow[];
    },
  });
}

export function useCRMProfiles(enabled: boolean = true): UseQueryResult<ClientCRMProfileRow[]> {
  return useQuery({
    queryKey: ["client_crm_profile"],
    enabled,
    queryFn: async (): Promise<ClientCRMProfileRow[]> => selectAll<ClientCRMProfileRow>("client_crm_profile"),
  });
}

export function useLeads(): UseQueryResult<LeadRow[]> {
  return useQuery({
    queryKey: ["leads"],
    queryFn: async (): Promise<LeadRow[]> => {
      const { data, error } = await supabase
        .from("leads")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as LeadRow[];
    },
  });
}

export function useBuilds(): UseQueryResult<BuildRow[]> {
  return useQuery({
    queryKey: ["builds"],
    queryFn: async (): Promise<BuildRow[]> => {
      const { data, error } = await supabase
        .from("builds")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as BuildRow[];
    },
  });
}

export function useMyBuild(userId: string | null): UseQueryResult<BuildRow | null> {
  return useQuery({
    queryKey: ["builds", "mine", userId],
    enabled: Boolean(userId),
    queryFn: async (): Promise<BuildRow | null> => {
      const uid = userId ?? "";
      const { data, error } = await supabase
        .from("builds")
        .select("*")
        .or(`client_id.eq.${uid},additional_client_ids.cs.{${uid}}`)
        .limit(1);
      if (error) throw error;
      const rows = (data ?? []) as BuildRow[];
      return rows.length > 0 ? rows[0] : null;
    },
  });
}

export function useAllStages(): UseQueryResult<BuildStageRow[]> {
  return useQuery({
    queryKey: ["build_stages", "all"],
    queryFn: async (): Promise<BuildStageRow[]> => {
      const { data, error } = await supabase
        .from("build_stages")
        .select("*")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as BuildStageRow[];
    },
  });
}

export function useStages(buildId: string | null): UseQueryResult<BuildStageRow[]> {
  return useQuery({
    queryKey: ["build_stages", buildId],
    enabled: Boolean(buildId),
    queryFn: async (): Promise<BuildStageRow[]> => {
      const { data, error } = await supabase
        .from("build_stages")
        .select("*")
        .eq("build_id", buildId ?? "")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as BuildStageRow[];
    },
  });
}

export function useAllSchedule(): UseQueryResult<ScheduleItemRow[]> {
  return useQuery({
    queryKey: ["schedule_items", "all"],
    queryFn: async (): Promise<ScheduleItemRow[]> => {
      const { data, error } = await supabase
        .from("schedule_items")
        .select("*")
        .order("date", { ascending: true });
      if (error) throw error;
      return (data ?? []) as ScheduleItemRow[];
    },
  });
}

export function useScheduleForClient(clientId: string | null): UseQueryResult<ScheduleItemRow[]> {
  return useQuery({
    queryKey: ["schedule_items", clientId],
    enabled: Boolean(clientId),
    queryFn: async (): Promise<ScheduleItemRow[]> => {
      const { data, error } = await supabase
        .from("schedule_items")
        .select("*")
        .eq("client_id", clientId ?? "")
        .order("date", { ascending: true });
      if (error) throw error;
      return (data ?? []) as ScheduleItemRow[];
    },
  });
}

export function useNotifications(userId: string | null): UseQueryResult<NotificationRow[]> {
  return useQuery({
    queryKey: ["notifications", userId],
    enabled: Boolean(userId),
    // Realtime invalidation handles immediacy; this is only a fallback.
    refetchInterval: 90000,
    queryFn: async (): Promise<NotificationRow[]> => {
      const { data, error } = await supabase
        .from("notifications")
        .select("*")
        .eq("recipient_id", userId ?? "")
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return (data ?? []) as NotificationRow[];
    },
  });
}

export function useClientDocuments(clientId: string | null): UseQueryResult<ClientDocumentRow[]> {
  return useQuery({
    queryKey: ["documents", clientId],
    enabled: Boolean(clientId),
    queryFn: async (): Promise<ClientDocumentRow[]> => {
      const { data, error } = await supabase
        .from("documents")
        .select("*")
        .eq("client_id", clientId ?? "")
        .order("date_added", { ascending: false });
      if (error) throw error;
      return (data ?? []) as ClientDocumentRow[];
    },
  });
}

export function useDocumentLibrary(): UseQueryResult<LibraryDocumentRow[]> {
  return useQuery({
    queryKey: ["document_library"],
    queryFn: async (): Promise<LibraryDocumentRow[]> => {
      const { data, error } = await supabase
        .from("document_library")
        .select("*")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as LibraryDocumentRow[];
    },
  });
}

export function useEmailSends(clientId: string | null): UseQueryResult<EmailSendRow[]> {
  return useQuery({
    queryKey: ["email_sends", clientId],
    enabled: Boolean(clientId),
    queryFn: async (): Promise<EmailSendRow[]> => {
      const { data, error } = await supabase
        .from("email_sends")
        .select("*")
        .eq("client_id", clientId ?? "")
        .order("created_at", { ascending: false })
        .limit(100);
      if (error) throw error;
      return (data ?? []) as EmailSendRow[];
    },
  });
}

export function useClientNotes(clientId: string | null): UseQueryResult<ClientNoteRow[]> {
  return useQuery({
    queryKey: ["client_notes", clientId],
    enabled: Boolean(clientId),
    queryFn: async (): Promise<ClientNoteRow[]> => {
      const { data, error } = await supabase
        .from("client_notes")
        .select("*")
        .eq("client_id", clientId ?? "")
        .order("created_at", { ascending: false })
        .limit(200);
      if (error) throw error;
      return (data ?? []) as ClientNoteRow[];
    },
  });
}

export function useConversations(userId: string | null): UseQueryResult<ConversationRow[]> {
  return useQuery({
    queryKey: ["conversations", userId],
    enabled: Boolean(userId),
    // Realtime invalidation handles immediacy; this is only a fallback.
    refetchInterval: 90000,
    queryFn: async (): Promise<ConversationRow[]> => {
      const { data, error } = await supabase
        .from("conversations")
        .select("*")
        .contains("participant_ids", [userId ?? ""])
        .order("last_message_date", { ascending: false });
      if (error) throw error;
      return (data ?? []) as ConversationRow[];
    },
  });
}

export function useMessages(conversationId: string | null): UseQueryResult<ChatMessageRow[]> {
  return useQuery({
    queryKey: ["messages", conversationId],
    enabled: Boolean(conversationId),
    // Realtime invalidation handles immediacy; this is only a fallback.
    refetchInterval: 60000,
    queryFn: async (): Promise<ChatMessageRow[]> => {
      // Newest 300 — long threads previously loaded every message ever sent.
      const { data, error } = await supabase
        .from("messages")
        .select("*")
        .eq("conversation_id", conversationId ?? "")
        .order("created_at", { ascending: false })
        .limit(300);
      if (error) throw error;
      return ((data ?? []) as ChatMessageRow[]).reverse();
    },
  });
}

/**
 * Per-conversation unread counts for the current user. Mirrors the iOS
 * MessagingService.fetchUnreadCounts — the `conversations.unread_count` column
 * isn't maintained server-side, so the real count is derived from message rows
 * (unread, not sent by me) across the user's conversations.
 */
export function useUnreadCounts(
  userId: string | null,
  conversationIds: string[],
): UseQueryResult<Record<string, number>> {
  const key = [...conversationIds].sort().join(",");
  return useQuery({
    queryKey: ["messages", "unread", userId, key],
    enabled: Boolean(userId) && conversationIds.length > 0,
    // Realtime invalidation handles immediacy; this is only a fallback.
    refetchInterval: 90000,
    queryFn: async (): Promise<Record<string, number>> => {
      const { data, error } = await supabase
        .from("messages")
        .select("conversation_id")
        .in("conversation_id", conversationIds)
        .eq("is_read", false)
        .neq("sender_id", userId ?? "");
      if (error) throw error;
      const counts: Record<string, number> = {};
      for (const row of (data ?? []) as { conversation_id: string }[]) {
        counts[row.conversation_id] = (counts[row.conversation_id] ?? 0) + 1;
      }
      return counts;
    },
  });
}

export function useSpecSelections(buildId: string | null): UseQueryResult<BuildSpecSelectionRow[]> {
  return useQuery({
    queryKey: ["build_spec_selections", buildId],
    enabled: Boolean(buildId),
    queryFn: async (): Promise<BuildSpecSelectionRow[]> => {
      const { data, error } = await supabase
        .from("build_spec_selections")
        .select("*")
        .eq("build_id", buildId ?? "")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as BuildSpecSelectionRow[];
    },
  });
}

export function useOpenRequests(): UseQueryResult<ServiceRequestRow[]> {
  return useQuery({
    queryKey: ["service_requests", "open"],
    queryFn: async (): Promise<ServiceRequestRow[]> => {
      const { data, error } = await supabase.from("service_requests").select("id,client_id,title,status");
      if (error) throw error;
      const rows = (data ?? []) as ServiceRequestRow[];
      return rows.filter((r) => (r.status ?? "").toLowerCase() === "open");
    },
  });
}

/**
 * Spec selections awaiting admin review — mirrors the iOS
 * `fetchAllPendingSpecReviews` query (status = awaiting_admin, drafts excluded).
 */
export function usePendingSpecReviews(enabled: boolean = true): UseQueryResult<BuildSpecSelectionRow[]> {
  return useQuery({
    queryKey: ["build_spec_selections", "pending"],
    enabled,
    queryFn: async (): Promise<BuildSpecSelectionRow[]> => {
      const { data, error } = await supabase
        .from("build_spec_selections")
        .select("*")
        .eq("status", "awaiting_admin")
        .neq("selection_type", "upgrade_draft");
      if (error) throw error;
      return (data ?? []) as BuildSpecSelectionRow[];
    },
  });
}

/** EOI statuses across package assignments, for the Action Required panel. */
export function useEOIAssignments(enabled: boolean = true): UseQueryResult<PackageAssignmentEOIRow[]> {
  return useQuery({
    queryKey: ["package_assignments", "eoi"],
    enabled,
    queryFn: async (): Promise<PackageAssignmentEOIRow[]> => {
      const { data, error } = await supabase
        .from("package_assignments")
        .select("id,package_id,eoi_status");
      if (error) throw error;
      return (data ?? []) as PackageAssignmentEOIRow[];
    },
  });
}

// ---------------------------------------------------------------------------
// Catalog & discover — mirrors the iOS content loaders.
// ---------------------------------------------------------------------------

export function usePackages(enabled: boolean = true): UseQueryResult<HouseLandPackageRow[]> {
  return useQuery({
    queryKey: ["house_land_packages"],
    enabled,
    queryFn: async (): Promise<HouseLandPackageRow[]> => {
      const { data, error } = await supabase
        .from("house_land_packages")
        .select("*")
        .order("id", { ascending: true });
      if (error) throw error;
      return (data ?? []) as HouseLandPackageRow[];
    },
  });
}

export function useHomeDesigns(): UseQueryResult<HomeDesignRow[]> {
  return useQuery({
    queryKey: ["home_designs"],
    queryFn: async (): Promise<HomeDesignRow[]> => {
      const { data, error } = await supabase.from("home_designs").select("*").order("name");
      if (error) throw error;
      return (data ?? []) as HomeDesignRow[];
    },
  });
}

export function useEstates(): UseQueryResult<LandEstateRow[]> {
  return useQuery({
    queryKey: ["land_estates"],
    queryFn: async (): Promise<LandEstateRow[]> => {
      const { data, error } = await supabase.from("land_estates").select("*").order("name");
      if (error) throw error;
      return (data ?? []) as LandEstateRow[];
    },
  });
}

export function useFacades(): UseQueryResult<FacadeRow[]> {
  return useQuery({
    queryKey: ["facades"],
    queryFn: async (): Promise<FacadeRow[]> => {
      const { data, error } = await supabase.from("facades").select("*").order("name");
      if (error) throw error;
      return (data ?? []) as FacadeRow[];
    },
  });
}

export function useSpecRangeTiers(): UseQueryResult<SpecRangeTierRow[]> {
  return useQuery({
    queryKey: ["spec_range_tiers"],
    queryFn: async (): Promise<SpecRangeTierRow[]> => selectAll<SpecRangeTierRow>("spec_range_tiers"),
  });
}

// Spec product catalogue (fittings & fixtures). Cached aggressively — the
// catalogue changes rarely and is shared across every spec-range view.
const CATALOG_STALE_MS = 5 * 60 * 1000;

export function useSpecCategories(): UseQueryResult<SpecCategoryRow[]> {
  return useQuery({
    queryKey: ["spec_categories"],
    staleTime: CATALOG_STALE_MS,
    queryFn: async (): Promise<SpecCategoryRow[]> => {
      const { data, error } = await supabase
        .from("spec_categories")
        .select("id,name,icon,sort_order,image_url")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as SpecCategoryRow[];
    },
  });
}

export function useSpecItems(): UseQueryResult<SpecItemRow[]> {
  return useQuery({
    queryKey: ["spec_items"],
    staleTime: CATALOG_STALE_MS,
    queryFn: async (): Promise<SpecItemRow[]> => {
      const { data, error } = await supabase
        .from("spec_items")
        .select("id,category_id,name,sort_order")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as SpecItemRow[];
    },
  });
}

export function useSpecProducts(): UseQueryResult<SpecProductRow[]> {
  return useQuery({
    queryKey: ["spec_products"],
    staleTime: CATALOG_STALE_MS,
    queryFn: async (): Promise<SpecProductRow[]> => {
      const { data, error } = await supabase
        .from("spec_products")
        .select("*")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as SpecProductRow[];
    },
  });
}

export function useSpecProductColours(): UseQueryResult<SpecProductColourRow[]> {
  return useQuery({
    queryKey: ["spec_product_colours"],
    staleTime: CATALOG_STALE_MS,
    queryFn: async (): Promise<SpecProductColourRow[]> => {
      const { data, error } = await supabase
        .from("spec_product_colours")
        .select("*")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as SpecProductColourRow[];
    },
  });
}

export function useSpecRangeItemProducts(): UseQueryResult<SpecRangeItemProductRow[]> {
  return useQuery({
    queryKey: ["spec_range_item_products"],
    staleTime: CATALOG_STALE_MS,
    queryFn: async (): Promise<SpecRangeItemProductRow[]> =>
      selectAll<SpecRangeItemProductRow>("spec_range_item_products"),
  });
}

/** Full assignment rows — RLS scopes what each role can see (same as iOS). */
export function usePackageAssignments(enabled: boolean = true): UseQueryResult<PackageAssignmentRow[]> {
  return useQuery({
    queryKey: ["package_assignments", "full"],
    enabled,
    queryFn: async (): Promise<PackageAssignmentRow[]> => selectAll<PackageAssignmentRow>("package_assignments"),
  });
}

export function useEOISubmissions(enabled: boolean = true): UseQueryResult<EOISubmissionRow[]> {
  return useQuery({
    queryKey: ["eoi_submissions"],
    enabled,
    queryFn: async (): Promise<EOISubmissionRow[]> => {
      const { data, error } = await supabase
        .from("eoi_submissions")
        .select("*")
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as EOISubmissionRow[];
    },
  });
}

export function useStocklistEstates(enabled: boolean = true): UseQueryResult<StocklistEstateRow[]> {
  return useQuery({
    queryKey: ["stocklist_estates"],
    enabled,
    queryFn: async (): Promise<StocklistEstateRow[]> => {
      const { data, error } = await supabase
        .from("stocklist_estates")
        .select("*")
        .eq("is_active", true)
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as StocklistEstateRow[];
    },
  });
}

export function useStocklistItems(enabled: boolean = true): UseQueryResult<StocklistItemRow[]> {
  return useQuery({
    queryKey: ["stocklist_items"],
    enabled,
    queryFn: async (): Promise<StocklistItemRow[]> => {
      const { data, error } = await supabase
        .from("stocklist_items")
        .select("*")
        .order("sort_order", { ascending: true });
      if (error) throw error;
      return (data ?? []) as StocklistItemRow[];
    },
  });
}

export function useDisplayHomes(includeInactive: boolean = false): UseQueryResult<DisplayHomeRow[]> {
  return useQuery({
    queryKey: ["display_homes", includeInactive],
    queryFn: async (): Promise<DisplayHomeRow[]> => {
      let query = supabase.from("display_homes").select("*");
      if (!includeInactive) query = query.eq("is_active", true);
      const { data, error } = await query
        .order("sort_order", { ascending: true })
        .order("name", { ascending: true });
      if (error) throw error;
      return (data ?? []) as DisplayHomeRow[];
    },
  });
}

export function useMyVisits(userId: string | null): UseQueryResult<DisplayHomeVisitRow[]> {
  return useQuery({
    queryKey: ["display_home_visits", userId],
    enabled: Boolean(userId),
    queryFn: async (): Promise<DisplayHomeVisitRow[]> => {
      const { data, error } = await supabase
        .from("display_home_visits")
        .select("*")
        .eq("client_id", userId ?? "")
        .order("requested_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as DisplayHomeVisitRow[];
    },
  });
}

/** Client view: own requests. Staff view: all requests (pass null clientId). */
export function useServiceRequests(clientId: string | null, all: boolean = false): UseQueryResult<ServiceRequestRow[]> {
  return useQuery({
    queryKey: ["service_requests", all ? "all" : clientId],
    enabled: all || Boolean(clientId),
    queryFn: async (): Promise<ServiceRequestRow[]> => {
      let query = supabase.from("service_requests").select("*");
      if (!all) query = query.eq("client_id", clientId ?? "");
      const { data, error } = await query.order("date_created", { ascending: false });
      if (error) throw error;
      return (data ?? []) as ServiceRequestRow[];
    },
  });
}

export function useBlogPosts(): UseQueryResult<BlogPostRow[]> {
  return useQuery({
    queryKey: ["blog_posts"],
    queryFn: async (): Promise<BlogPostRow[]> => {
      const { data, error } = await supabase
        .from("blog_posts")
        .select("*")
        .order("date", { ascending: false });
      if (error) throw error;
      return (data ?? []) as BlogPostRow[];
    },
  });
}
