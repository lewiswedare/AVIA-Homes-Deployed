import { useQuery, type UseQueryResult } from "@tanstack/react-query";

import { supabase } from "./supabase";
import type {
  BuildRow,
  BuildSpecSelectionRow,
  BuildStageRow,
  ChatMessageRow,
  ClientCRMProfileRow,
  ClientDocumentRow,
  ClientNoteRow,
  ClientTaskRow,
  ConversationRow,
  EmailSendRow,
  LeadRow,
  LibraryDocumentRow,
  NotificationRow,
  PackageAssignmentEOIRow,
  ProfileRow,
  ScheduleItemRow,
  ServiceRequestRow,
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
    refetchInterval: 30000,
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
        .order("created_at", { ascending: false });
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
        .order("created_at", { ascending: false });
      if (error) throw error;
      return (data ?? []) as ClientNoteRow[];
    },
  });
}

export function useConversations(userId: string | null): UseQueryResult<ConversationRow[]> {
  return useQuery({
    queryKey: ["conversations", userId],
    enabled: Boolean(userId),
    refetchInterval: 20000,
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
    refetchInterval: 8000,
    queryFn: async (): Promise<ChatMessageRow[]> => {
      const { data, error } = await supabase
        .from("messages")
        .select("*")
        .eq("conversation_id", conversationId ?? "")
        .order("created_at", { ascending: true });
      if (error) throw error;
      return (data ?? []) as ChatMessageRow[];
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
