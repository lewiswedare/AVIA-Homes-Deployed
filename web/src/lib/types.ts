/**
 * Row types mirroring the Supabase tables shared with the AVIA Homes iOS app.
 * Column names intentionally match the database (snake_case).
 */

export type UserRole =
  | "Pending"
  | "Client"
  | "Staff"
  | "Admin"
  | "Partner"
  | "SalesAdmin"
  | "SalesPartner"
  | "SuperAdmin"
  | "PreConstruction"
  | "BuildingSupport";

export const ADMIN_ROLES: UserRole[] = ["Admin", "SalesAdmin", "SuperAdmin"];
export const STAFF_ROLES: UserRole[] = ["Staff", "PreConstruction", "BuildingSupport"];
export const PARTNER_ROLES: UserRole[] = ["Partner", "SalesPartner"];

export function isAdminRole(role: UserRole): boolean {
  return ADMIN_ROLES.includes(role);
}
export function isStaffRole(role: UserRole): boolean {
  return STAFF_ROLES.includes(role);
}
export function isPartnerRole(role: UserRole): boolean {
  return PARTNER_ROLES.includes(role);
}
export function isClientRole(role: UserRole): boolean {
  return role === "Client" || role === "Pending";
}

export const roleDescription: Record<UserRole, string> = {
  Pending: "Awaiting role assignment",
  Client: "View and manage your home build",
  Staff: "View and add info to assigned client builds",
  Admin: "Full access to update and edit all data",
  SalesAdmin: "Full access to update and edit all data",
  SuperAdmin: "Full access with staff performance oversight",
  Partner: "View associated client portfolios",
  SalesPartner: "View associated client portfolios",
  PreConstruction: "Manage clients during pre-construction phase",
  BuildingSupport: "Support clients during construction phase",
};

export interface ProfileRow {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  phone: string | null;
  address: string | null;
  home_design: string | null;
  lot_number: string | null;
  contract_date: string | null;
  profile_completed: boolean;
  role: string;
  assigned_client_ids: string[] | null;
  assigned_staff_id: string | null;
  sales_partner_id: string | null;
  display_title: string | null;
  avatar_url: string | null;
  is_active: boolean | null;
  created_at: string | null;
}

export interface BuildRow {
  id: string;
  client_id: string;
  additional_client_ids: string[] | null;
  home_design: string;
  lot_number: string;
  estate: string;
  contract_date: string;
  assigned_staff_id: string;
  sales_partner_id: string | null;
  preconstruction_staff_id: string | null;
  building_support_staff_id: string | null;
  handover_triggered_at: string | null;
  status: string;
  is_custom: boolean | null;
  selected_facade_id: string | null;
  spec_tier: string | null;
  estimated_start_date: string | null;
  estimated_completion_date: string | null;
  actual_start_date: string | null;
  actual_completion_date: string | null;
}

export type StageStatus = "Completed" | "In Progress" | "Upcoming" | "Delayed";

export interface BuildStageRow {
  id: string;
  build_id: string;
  name: string;
  description: string | null;
  status: string;
  progress: number | null;
  start_date: string | null;
  completion_date: string | null;
  notes: string | null;
  photo_count: number | null;
  sort_order: number | null;
  estimated_start_date: string | null;
  estimated_end_date: string | null;
  actual_start_date: string | null;
  actual_end_date: string | null;
}

export type TaskPriority = "low" | "normal" | "high";

export interface ClientTaskRow {
  id: string;
  client_id: string | null;
  title: string;
  detail: string | null;
  due_at: string | null;
  completed_at: string | null;
  assignee_id: string | null;
  created_by: string | null;
  priority: string | null;
  created_at: string | null;
}

export type LeadStatusKey =
  | "new"
  | "contacted"
  | "qualified"
  | "proposal"
  | "negotiation"
  | "won"
  | "lost";

export const LEAD_STATUSES: LeadStatusKey[] = [
  "new",
  "contacted",
  "qualified",
  "proposal",
  "negotiation",
  "won",
  "lost",
];

export const leadStatusLabel: Record<LeadStatusKey, string> = {
  new: "New",
  contacted: "Contacted",
  qualified: "Qualified",
  proposal: "Proposal",
  negotiation: "Negotiation",
  won: "Won",
  lost: "Lost",
};

export type LeadTemperatureKey = "hot" | "warm" | "cold";

export type LeadKindKey = "lead" | "opportunity" | "client";

export type LeadSourceKey =
  | "website"
  | "social"
  | "referral"
  | "walk_in"
  | "phone"
  | "event"
  | "other";

export const leadSourceLabel: Record<LeadSourceKey, string> = {
  website: "Website",
  social: "Social Media",
  referral: "Referral",
  walk_in: "Walk-in",
  phone: "Phone",
  event: "Event",
  other: "Other",
};

export interface LeadRow {
  id: string;
  name: string;
  email: string | null;
  phone: string | null;
  source: string;
  message: string | null;
  status: string;
  temperature: string;
  owner_id: string | null;
  notes: string | null;
  converted_client_id: string | null;
  kind: string | null;
  estimated_value: number | null;
  expected_close_date: string | null;
  workflow_completions: string[] | null;
  converted_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface ClientCRMProfileRow {
  client_id: string;
  lead_status: string;
  lead_temperature: string;
  tags: string[] | null;
  owner_id: string | null;
  last_contacted_at: string | null;
  next_follow_up_at: string | null;
  lifetime_value: number | null;
  updated_at: string | null;
}

export type ScheduleItemType =
  | "Site Visit"
  | "Walkthrough"
  | "Colour Due"
  | "Inspection"
  | "Meeting"
  | "Handover";

export interface ScheduleItemRow {
  id: string;
  client_id: string;
  title: string;
  subtitle: string | null;
  icon: string | null;
  date: string;
  type: string;
}

export interface NotificationRow {
  id: string;
  recipient_id: string;
  sender_id: string | null;
  sender_name: string;
  type: string;
  title: string;
  message: string;
  reference_id: string | null;
  reference_type: string | null;
  created_at: string;
  is_read: boolean;
}

export interface ClientDocumentRow {
  id: string;
  client_id: string;
  name: string;
  category: string;
  date_added: string;
  file_size: string | null;
  is_new: boolean;
  file_url: string | null;
  build_id: string | null;
  build_stage_id: string | null;
}

export interface LibraryDocumentRow {
  id: string;
  name: string;
  category: string;
  description: string | null;
  file_url: string;
  file_size: string | null;
  file_type: string | null;
  uploaded_by: string | null;
  sort_order: number | null;
  created_at: string | null;
}

export interface EmailSendRow {
  id: string;
  client_id: string;
  sender_id: string | null;
  sender_email: string | null;
  sender_name: string | null;
  to_email: string;
  subject: string;
  body_preview: string | null;
  document_id: string | null;
  document_name: string | null;
  document_url: string | null;
  status: string | null;
  open_count: number | null;
  first_opened_at: string | null;
  last_opened_at: string | null;
  created_at: string | null;
}

export interface ConversationRow {
  id: string;
  participant_ids: string[];
  last_message: string | null;
  last_message_date: string;
  last_sender_id: string | null;
  unread_count: number | null;
  created_at: string;
  conversation_type: string | null;
}

export interface ChatMessageRow {
  id: string;
  conversation_id: string;
  sender_id: string;
  content: string;
  created_at: string;
  is_read: boolean;
  attachment_url: string | null;
  attachment_type: string | null;
}

export interface ClientNoteRow {
  id: string;
  client_id: string;
  author_id: string | null;
  body: string;
  pinned: boolean | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface BuildSpecSelectionRow {
  id: string;
  build_id: string;
  category_id: string;
  spec_item_id: string;
  spec_tier: string;
  selection_type: string;
  client_notes: string | null;
  client_confirmed: boolean;
  admin_confirmed: boolean;
  locked_for_client: boolean;
  status: string;
  snapshot_name: string;
  snapshot_description: string | null;
  snapshot_image_url: string | null;
  snapshot_category_name: string;
  sort_order: number;
  upgrade_cost: number | null;
  upgrade_cost_note: string | null;
}

export interface ServiceRequestRow {
  id: string;
  client_id: string;
  title: string;
  status: string;
}
