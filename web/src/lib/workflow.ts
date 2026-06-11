import type { LucideIcon } from "lucide-react";
import {
  BadgeCheck,
  CalendarPlus,
  CreditCard,
  DollarSign,
  FileDown,
  FileText,
  Home,
  MessagesSquare,
  PenLine,
} from "lucide-react";

/**
 * Web port of the iOS `OpportunityWorkflow` — the sales workflow an opportunity
 * moves through before it can become a client. Step ids match the iOS app
 * exactly so `leads.workflow_completions` stays in sync across platforms.
 */

export type WorkflowStage = "qualified" | "proposal" | "negotiation";

export interface OpportunityStep {
  id: string;
  title: string;
  detail: string;
  icon: LucideIcon;
}

export const WORKFLOW_STAGES: WorkflowStage[] = ["qualified", "proposal", "negotiation"];

/** Requirement id that gates client conversion — a build contract must be allocated. */
export const CONTRACT_STEP_ID = "negotiation.contract";

export const workflowStageLabel: Record<WorkflowStage, string> = {
  qualified: "Qualified",
  proposal: "Proposal",
  negotiation: "Negotiation",
};

export const workflowStageSubtitle: Record<WorkflowStage, string> = {
  qualified: "Confirm their goals, budget and timeline before proposing.",
  proposal: "Deliver a tailored proposal and walk them through it.",
  negotiation: "Close the deal — allocating the build contract converts them to a client.",
};

/** Maps any incoming lead status into a valid workflow stage. */
export function normalizedStage(status: string): WorkflowStage {
  switch (status) {
    case "proposal":
      return "proposal";
    case "negotiation":
    case "won":
      return "negotiation";
    default:
      return "qualified";
  }
}

export function nextStage(status: string): WorkflowStage | null {
  const idx = WORKFLOW_STAGES.indexOf(normalizedStage(status));
  return idx >= 0 && idx + 1 < WORKFLOW_STAGES.length ? WORKFLOW_STAGES[idx + 1] : null;
}

export function previousStage(status: string): WorkflowStage | null {
  const idx = WORKFLOW_STAGES.indexOf(normalizedStage(status));
  return idx > 0 ? WORKFLOW_STAGES[idx - 1] : null;
}

const STAGE_STEPS: Record<WorkflowStage, OpportunityStep[]> = {
  qualified: [
    {
      id: "qualified.discovery",
      title: "Discovery call completed",
      detail: "Understand their goals, site, and motivation.",
      icon: MessagesSquare,
    },
    {
      id: "qualified.budget",
      title: "Budget & timeline confirmed",
      detail: "Qualify affordability and when they want to build.",
      icon: DollarSign,
    },
    {
      id: "qualified.designs",
      title: "Preferred designs shortlisted",
      detail: "Agree on the designs or range they love.",
      icon: Home,
    },
  ],
  proposal: [
    {
      id: "proposal.sent",
      title: "Tailored proposal sent",
      detail: "Deliver pricing and inclusions for their selection.",
      icon: FileText,
    },
    {
      id: "proposal.pack",
      title: "Floorplan & spec pack shared",
      detail: "Send the full plan and specification documents.",
      icon: FileDown,
    },
    {
      id: "proposal.meeting",
      title: "Review meeting booked",
      detail: "Schedule a walkthrough of the proposal together.",
      icon: CalendarPlus,
    },
  ],
  negotiation: [
    {
      id: "negotiation.terms",
      title: "Terms & inclusions agreed",
      detail: "Lock scope, price, and any variations.",
      icon: BadgeCheck,
    },
    {
      id: "negotiation.deposit",
      title: "Deposit / EOI received",
      detail: "Confirm commitment with an initial payment.",
      icon: CreditCard,
    },
    {
      id: CONTRACT_STEP_ID,
      title: "Build contract allocated",
      detail: "Allocate the build contract — this converts them to a client.",
      icon: PenLine,
    },
  ],
};

export function stepsForStage(status: string): OpportunityStep[] {
  return STAGE_STEPS[normalizedStage(status)];
}

/** Mirrors iOS: all but one step must be done before the stage can advance. */
export function canAdvanceStage(status: string, completions: string[]): boolean {
  if (nextStage(status) === null) return false;
  const steps = stepsForStage(status);
  if (steps.length === 0) return true;
  const done = steps.filter((s) => completions.includes(s.id)).length;
  return done >= Math.max(1, steps.length - 1);
}

export function canConvertToClient(status: string, completions: string[]): boolean {
  return normalizedStage(status) === "negotiation" && completions.includes(CONTRACT_STEP_ID);
}
