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
  description?: string | null;
  category?: string | null;
  build_id?: string | null;
  date_created?: string | null;
  last_updated?: string | null;
  responses?: ServiceRequestResponse[] | null;
}

/** Minimal slice of package_assignments used for EOI review counts. */
export interface PackageAssignmentEOIRow {
  id: string;
  package_id: string;
  eoi_status: string | null;
}

export const leadTemperatureLabel: Record<LeadTemperatureKey, string> = {
  hot: "Hot",
  warm: "Warm",
  cold: "Cold",
};

/** Stock library categories — mirrors the iOS `DocumentCategory` enum raw values. */
export const DOCUMENT_CATEGORIES: string[] = [
  "Contracts",
  "Plans",
  "Permits",
  "Certificates",
  "Invoices",
  "Financial",
  "Marketing",
  "Templates",
];

/** Roles an admin can assign to a pending user — mirrors iOS UserManagementView. */
export const ASSIGNABLE_ROLES: UserRole[] = [
  "Client",
  "Staff",
  "PreConstruction",
  "BuildingSupport",
  "Partner",
  "SalesPartner",
  "Admin",
  "SalesAdmin",
];

// ---------------------------------------------------------------------------
// Catalog & discover domain — mirrors the iOS package/stocklist/display-home
// models. Prices are display strings in the DB (e.g. "$675,000"), not numbers.
// ---------------------------------------------------------------------------

export type SpecTierKey = "volos" | "messina" | "portobello";

export const SPEC_TIERS: SpecTierKey[] = ["volos", "messina", "portobello"];

export const specTierLabel: Record<SpecTierKey, string> = {
  volos: "Volos",
  messina: "Messina",
  portobello: "Portobello",
};

export const specTierTagline: Record<SpecTierKey, string> = {
  volos: "Essential Living",
  messina: "Elevated Comfort",
  portobello: "Premium Collection",
};

export function asSpecTier(value: string | null | undefined): SpecTierKey {
  return value === "volos" || value === "portobello" ? value : "messina";
}

export interface HouseLandPackageRow {
  id: string;
  title: string;
  location: string;
  lot_size: string;
  home_design: string;
  price: string;
  image_url: string;
  is_new: boolean;
  lot_number: string;
  lot_frontage: string;
  lot_depth: string;
  land_price: string;
  house_price: string;
  spec_tier: string;
  title_date: string;
  council: string;
  zoning: string;
  build_time_estimate: string;
  inclusions: string[] | null;
  is_custom: boolean | null;
  custom_bedrooms: number | null;
  custom_bathrooms: number | null;
  custom_garages: number | null;
  custom_storeys: number | null;
  custom_square_meters: number | null;
  selected_facade_id: string | null;
}

export interface HomeDesignRow {
  id: string;
  name: string;
  bedrooms: number;
  bathrooms: number;
  garages: number;
  square_meters: number;
  image_url: string;
  price_from: string | null;
  storeys: number;
  lot_width: number | null;
  slug: string | null;
  description: string | null;
  house_width: number | null;
  house_length: number | null;
  living_areas: number | null;
  floorplan_image_url: string | null;
  floorplan_pdf_url: string | null;
  floorplan_pdf_image_url: string | null;
  room_highlights: string[] | null;
  inclusions: string[] | null;
}

export interface LandEstateRow {
  id: string;
  name: string;
  location: string;
  suburb: string | null;
  status: string | null;
  total_lots: number | null;
  available_lots: number | null;
  price_from: string | null;
  image_url: string | null;
  description: string | null;
  features: string[] | null;
  expected_completion: string | null;
  logo_url: string | null;
  brochure_url: string | null;
  site_map_url: string | null;
}

export interface FacadeRow {
  id: string;
  name: string;
  style: string | null;
  description: string | null;
  hero_image_url: string | null;
  gallery_image_urls: string[] | null;
  features: string[] | null;
  pricing_type: string | null;
  pricing_amount: string | null;
  storeys: number | null;
}

export interface SpecRangeHighlight {
  icon: string | null;
  title: string;
  subtitle: string | null;
  icon_image_url?: string | null;
  detail_image_url?: string | null;
}

export interface SpecRangeNamedImage {
  name: string;
  image_url: string;
}

export interface SpecRangeTierRow {
  tier: string;
  hero_image_url: string | null;
  summary: string | null;
  highlights: SpecRangeHighlight[] | null;
  room_images: SpecRangeNamedImage[] | null;
  partner_logos: SpecRangeNamedImage[] | null;
  pdf_url: string | null;
  pdf_preview_image_url: string | null;
}

// ---------------------------------------------------------------------------
// Spec products — catalogue fittings & fixtures, shared with the iOS app.
// product → spec_item → spec_category(room); per-range inclusion lives on
// spec_range_item_products.
// ---------------------------------------------------------------------------

export type ProductRangeInclusion = "included" | "upgrade" | "unavailable";

export interface SpecCategoryRow {
  id: string;
  name: string;
  icon: string;
  sort_order: number;
  image_url: string | null;
}

export interface SpecItemRow {
  id: string;
  category_id: string;
  name: string;
  sort_order: number | null;
}

export interface SpecProductRow {
  id: string;
  spec_item_id: string;
  brand: string | null;
  model: string | null;
  sku: string | null;
  name: string;
  description: string | null;
  image_url: string | null;
  dimensions: string | null;
  is_active: boolean | null;
  sort_order: number | null;
}

export interface SpecProductColourRow {
  id: string;
  product_id: string;
  name: string;
  hex: string | null;
  image_url: string | null;
  is_default: boolean | null;
  is_active: boolean | null;
  sort_order: number | null;
  extra_cost: number | null;
  sku: string | null;
}

export interface SpecRangeItemProductRow {
  id: string | null;
  range_id: string;
  spec_item_id: string;
  product_id: string;
  is_default: boolean | null;
  inclusion_override: string | null;
  upgrade_price_override: number | null;
  sort_order: number | null;
}

/** client_responses JSON entry — status raw values are capitalized phrases. */
export interface ClientPackageResponse {
  client_id: string;
  status: string;
  responded_date?: string | null;
  notes?: string | null;
}

export const RESPONSE_PENDING = "Pending Review";
export const RESPONSE_ACCEPTED = "Accepted";
export const RESPONSE_DECLINED = "Declined";

export type EOIStatusKey =
  | "none"
  | "submitted"
  | "resubmitted"
  | "approved"
  | "declined"
  | "changes_requested";

export type ContractStatusKey =
  | "none"
  | "awaiting_contract"
  | "awaiting_signature"
  | "awaiting_confirmation"
  | "signed";

export interface PackageAssignmentRow {
  id: string;
  package_id: string;
  assigned_partner_ids: string[] | null;
  shared_with_client_ids: string[] | null;
  client_responses: ClientPackageResponse[] | null;
  is_exclusive: boolean | null;
  assigned_by: string | null;
  deposit_status: string | null;
  deposit_amount: number | null;
  deposit_due_date: string | null;
  admin_confirmed_by: string | null;
  admin_confirmed_at: string | null;
  eoi_status: string | null;
  contract_status: string | null;
  converted_to_build_id: string | null;
  converted_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export interface EOISubmissionRow {
  id: string;
  package_assignment_id: string;
  package_id: string;
  client_id: string;
  lot_number: string | null;
  estate_name: string | null;
  street_suburb: string | null;
  occupancy_type: string | null;
  specification_tier: string | null;
  facade_selection: string | null;
  buyer1_name: string;
  buyer1_email: string;
  buyer1_address: string;
  buyer1_phone: string;
  buyer2_name: string | null;
  buyer2_email: string | null;
  buyer2_address: string | null;
  buyer2_phone: string | null;
  solicitor_company: string;
  solicitor_name: string;
  solicitor_email: string;
  solicitor_address: string;
  solicitor_phone: string;
  status: string;
  admin_notes: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string | null;
  updated_at: string | null;
}

export const STOCKLIST_REGIONS = ["Brisbane", "Gold Coast", "Sunshine Coast", "Toowoomba"] as const;
export const BRISBANE_SUB_REGIONS = ["North Brisbane", "West Brisbane", "South Brisbane"] as const;
export const STOCKLIST_STATUSES = [
  "Available",
  "Available (Exclusive)",
  "EOI",
  "ON HOLD",
  "COMING SOON",
  "Sold",
] as const;
export const OWNER_OCC_OPTIONS = ["Owner Occ & Investor", "Owner Occ Only", "Investor Only"] as const;

export interface StocklistEstateRow {
  id: string;
  name: string;
  region: string;
  sub_region: string | null;
  deposit_terms: string | null;
  estate_brochure_url: string | null;
  rental_appraisal_url: string | null;
  eoi_form_url: string | null;
  sort_order: number | null;
  is_active: boolean;
}

export interface StocklistItemRow {
  id: string;
  estate_id: string;
  lot_number: string;
  stage: string | null;
  street: string | null;
  land_size: string | null;
  land_price: string | null;
  registered: string | null;
  design_facade: string | null;
  build_size: string | null;
  bedrooms: string | null;
  bathrooms: string | null;
  garages: string | null;
  theatre: string | null;
  build_price: string | null;
  package_price: string | null;
  specification: string | null;
  status: string;
  owner_occ_investor: string | null;
  availability: string | null;
  sales_package_link: string | null;
  is_coming_soon: boolean | null;
  sort_order: number | null;
}

export interface DisplayHomeRow {
  id: string;
  name: string;
  estate: string | null;
  address: string | null;
  suburb: string | null;
  description: string | null;
  bedrooms: number | null;
  bathrooms: number | null;
  garages: number | null;
  square_meters: number | null;
  home_design_id: string | null;
  image_urls: string[] | null;
  features: string[] | null;
  opening_hours: string | null;
  contact_phone: string | null;
  is_active: boolean;
  sort_order: number | null;
}

export type VisitStatusKey = "pending" | "confirmed" | "completed" | "cancelled" | "no_show" | "rescheduled";

export const visitStatusLabel: Record<VisitStatusKey, string> = {
  pending: "Requested",
  confirmed: "Confirmed",
  completed: "Completed",
  cancelled: "Cancelled",
  no_show: "No Show",
  rescheduled: "Rescheduled",
};

export interface DisplayHomeVisitRow {
  id: string;
  display_home_id: string;
  client_id: string | null;
  requested_at: string;
  duration_minutes: number | null;
  status: string;
  attendee_name: string | null;
  attendee_email: string | null;
  attendee_phone: string | null;
  party_size: number | null;
  notes: string | null;
  admin_notes: string | null;
  confirmed_at: string | null;
  completed_at: string | null;
  cancelled_at: string | null;
  created_at: string | null;
}

export interface BlogPostRow {
  id: string;
  title: string;
  subtitle: string;
  category: string;
  image_url: string;
  date: string;
  read_time: string;
  content: string;
}

export interface ServiceRequestResponse {
  id: string;
  author: string;
  message: string;
  date: string;
  is_from_client: boolean;
}

export const REQUEST_CATEGORIES = ["General", "Defect", "Variation", "Maintenance"] as const;
export const REQUEST_STATUSES = ["Open", "In Progress", "Resolved"] as const;

// --------------------------------------------------------------------------
// Role capability helpers — mirror iOS UserRole capability flags.
// --------------------------------------------------------------------------

export function canViewPackages(role: UserRole): boolean {
  return ["Staff", "Admin", "Partner", "SalesAdmin", "SalesPartner", "SuperAdmin"].includes(role);
}
export function canManagePackages(role: UserRole): boolean {
  return ADMIN_ROLES.includes(role);
}
export function canAllocatePackages(role: UserRole): boolean {
  return ["Admin", "Partner", "SalesAdmin", "SalesPartner", "SuperAdmin"].includes(role);
}
export function canViewStocklist(role: UserRole): boolean {
  return ["Admin", "SalesAdmin", "SuperAdmin", "Partner", "SalesPartner"].includes(role);
}
export function canEditStocklist(role: UserRole): boolean {
  return ADMIN_ROLES.includes(role);
}
