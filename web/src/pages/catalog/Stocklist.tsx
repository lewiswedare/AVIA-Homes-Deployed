import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Bath,
  BedDouble,
  Car,
  ChevronDown,
  ClipboardList,
  ExternalLink,
  Info,
  Maximize,
  Pencil,
  Plus,
  Search,
  Tv,
} from "lucide-react";
import { useMemo, useState } from "react";
import { Navigate } from "react-router-dom";
import { toast } from "sonner";

import { BentoCard, EmptyState, FieldLabel, Modal, PrimaryButton, SecondaryButton, Spinner, inputClass } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { nowISO } from "@/lib/format";
import { useStocklistEstates, useStocklistItems } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import type { StocklistEstateRow, StocklistItemRow } from "@/lib/types";
import {
  BRISBANE_SUB_REGIONS,
  OWNER_OCC_OPTIONS,
  STOCKLIST_REGIONS,
  STOCKLIST_STATUSES,
  canEditStocklist,
  canViewStocklist,
} from "@/lib/types";
import { cn } from "@/lib/utils";

type SortKey = "default" | "price_asc" | "price_desc" | "land_asc" | "land_desc";

const SORT_LABELS: Record<SortKey, string> = {
  default: "Default",
  price_asc: "Price low → high",
  price_desc: "Price high → low",
  land_asc: "Land size small → large",
  land_desc: "Land size large → small",
};

function numeric(value: string | null | undefined): number {
  const digits = (value ?? "").replace(/[^0-9.]/g, "");
  const n = parseFloat(digits);
  return Number.isNaN(n) ? 0 : n;
}

function statusTone(status: string): string {
  switch (status) {
    case "Available": return "bg-green-700/10 text-green-800 border-green-700/30";
    case "Available (Exclusive)": return "bg-purple-700/10 text-purple-800 border-purple-700/30";
    case "EOI": return "bg-orange-600/10 text-orange-700 border-orange-600/30";
    case "ON HOLD": return "bg-avia-black/10 text-avia-black/60 border-avia-black/20";
    case "COMING SOON": return "bg-blue-700/10 text-blue-800 border-blue-700/30";
    case "Sold": return "bg-red-700/10 text-red-800 border-red-700/30";
    default: return "bg-avia-black/5 text-avia-black/55 border-avia-black/15";
  }
}

/** Stocklist — mirrors iOS StocklistView with admin estate/lot editing. */
export default function Stocklist() {
  const { role } = useAuth();
  const estatesQ = useStocklistEstates();
  const itemsQ = useStocklistItems();
  const [region, setRegion] = useState<string>("Brisbane");
  const [subRegion, setSubRegion] = useState<string>("");
  const [search, setSearch] = useState<string>("");
  const [statusFilter, setStatusFilter] = useState<string>("");
  const [sort, setSort] = useState<SortKey>("default");
  const [editMode, setEditMode] = useState<boolean>(false);
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [estateEditor, setEstateEditor] = useState<StocklistEstateRow | "new" | null>(null);
  const [lotEditor, setLotEditor] = useState<{ item: StocklistItemRow | null; estateId: string } | null>(null);

  const canEdit = canEditStocklist(role);

  const estates = useMemo(
    () =>
      (estatesQ.data ?? [])
        .filter((e) => e.region === region)
        .filter((e) => (region === "Brisbane" && subRegion ? e.sub_region === subRegion : true)),
    [estatesQ.data, region, subRegion],
  );

  const itemsByEstate = useMemo(() => {
    const map = new Map<string, StocklistItemRow[]>();
    const q = search.trim().toLowerCase();
    let items = itemsQ.data ?? [];
    if (q) {
      items = items.filter((i) =>
        [i.lot_number, i.street, i.design_facade, i.stage, i.specification].some((v) => (v ?? "").toLowerCase().includes(q)),
      );
    }
    if (statusFilter) items = items.filter((i) => i.status === statusFilter);
    const sorted = [...items];
    if (sort === "price_asc") sorted.sort((a, b) => numeric(a.package_price ?? a.land_price) - numeric(b.package_price ?? b.land_price));
    if (sort === "price_desc") sorted.sort((a, b) => numeric(b.package_price ?? b.land_price) - numeric(a.package_price ?? a.land_price));
    if (sort === "land_asc") sorted.sort((a, b) => numeric(a.land_size) - numeric(b.land_size));
    if (sort === "land_desc") sorted.sort((a, b) => numeric(b.land_size) - numeric(a.land_size));
    for (const item of sorted) {
      const list = map.get(item.estate_id) ?? [];
      list.push(item);
      map.set(item.estate_id, list);
    }
    return map;
  }, [itemsQ.data, search, statusFilter, sort]);

  if (!canViewStocklist(role)) return <Navigate to="/" replace />;
  if (estatesQ.isLoading || itemsQ.isLoading) return <Spinner />;

  const toggleExpanded = (id: string) => {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  return (
    <div className="animate-fade-in space-y-5">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-[26px] font-medium text-avia-black">Stocklist</h1>
          <p className="text-[13px] text-avia-black/50">Current land & package stock by region</p>
        </div>
        {canEdit && (
          <div className="flex items-center gap-2">
            {editMode && (
              <button
                type="button"
                onClick={() => setEstateEditor("new")}
                className="flex items-center gap-1.5 rounded-full bg-avia-brown px-4 py-2 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
              >
                <Plus className="h-4 w-4" /> Add Estate
              </button>
            )}
            <button
              type="button"
              onClick={() => setEditMode(!editMode)}
              className="rounded-full border border-avia-brown/30 px-4 py-2 text-[13px] font-medium text-avia-brown transition-colors hover:bg-avia-brown/10"
            >
              {editMode ? "Done" : "Edit"}
            </button>
          </div>
        )}
      </div>

      {/* Region selector */}
      <div className="scrollbar-none flex gap-2 overflow-x-auto pb-1">
        {STOCKLIST_REGIONS.map((r) => (
          <button
            key={r}
            type="button"
            onClick={() => {
              setRegion(r);
              setSubRegion("");
            }}
            className={cn(
              "whitespace-nowrap rounded-full px-4 py-2 text-[13px] font-medium transition-colors",
              region === r ? "bg-avia-brown text-avia-white" : "bg-avia-card text-avia-black/60 hover:bg-avia-black/5",
            )}
          >
            {r}
          </button>
        ))}
      </div>

      {region === "Brisbane" && (
        <div className="scrollbar-none flex gap-2 overflow-x-auto pb-1">
          <SubChip label="All" active={subRegion === ""} onClick={() => setSubRegion("")} />
          {BRISBANE_SUB_REGIONS.map((s) => (
            <SubChip key={s} label={s} active={subRegion === s} onClick={() => setSubRegion(s)} />
          ))}
        </div>
      )}

      {/* Search + filters */}
      <div className="flex flex-wrap items-center gap-2">
        <div className="relative min-w-52 flex-1">
          <Search className="absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-avia-black/35" />
          <input
            className="w-full rounded-full border border-avia-line bg-avia-card py-2.5 pl-10 pr-4 text-[14px] outline-none placeholder:text-avia-black/35 focus:border-avia-brown"
            placeholder="Search lots, designs, streets…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <select
          value={sort}
          onChange={(e) => setSort(e.target.value as SortKey)}
          className="rounded-full border border-avia-line bg-avia-card px-3.5 py-2.5 text-[13px] text-avia-black/70 outline-none focus:border-avia-brown"
          aria-label="Sort"
        >
          {(Object.keys(SORT_LABELS) as SortKey[]).map((k) => (
            <option key={k} value={k}>
              {SORT_LABELS[k]}
            </option>
          ))}
        </select>
      </div>

      <div className="scrollbar-none flex gap-2 overflow-x-auto pb-1">
        <SubChip label="All" active={statusFilter === ""} onClick={() => setStatusFilter("")} />
        {STOCKLIST_STATUSES.map((s) => (
          <SubChip key={s} label={s} active={statusFilter === s} onClick={() => setStatusFilter(s)} />
        ))}
      </div>

      {/* Estates */}
      {estates.length === 0 ? (
        <EmptyState icon={ClipboardList} title="No estates in this region" subtitle="Check another region or add stock." />
      ) : (
        <div className="space-y-3">
          {estates.map((estate) => {
            const lots = itemsByEstate.get(estate.id) ?? [];
            const isOpen = expanded.has(estate.id) || Boolean(search.trim()) || Boolean(statusFilter);
            return (
              <BentoCard key={estate.id} className="overflow-hidden">
                <button
                  type="button"
                  onClick={() => (editMode ? setEstateEditor(estate) : toggleExpanded(estate.id))}
                  className="flex w-full items-center gap-3 bg-gradient-to-r from-avia-brown to-avia-black px-4 py-3.5 text-left"
                >
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[15px] font-medium text-white">{estate.name}</div>
                    <div className="text-[12px] text-white/65">
                      {lots.length} lot{lots.length === 1 ? "" : "s"}
                      {estate.sub_region ? ` · ${estate.sub_region}` : ""}
                    </div>
                  </div>
                  {editMode ? (
                    <Pencil className="h-4 w-4 text-white/80" />
                  ) : (
                    <ChevronDown className={cn("h-4 w-4 text-white/80 transition-transform", isOpen && "rotate-180")} />
                  )}
                </button>
                {isOpen && (
                  <div className="space-y-3 p-4">
                    {estate.deposit_terms && (
                      <div className="flex items-start gap-2 rounded-[10px] bg-avia-brown/10 p-3 text-[12px] text-avia-brown">
                        <Info className="mt-0.5 h-4 w-4 shrink-0" />
                        {estate.deposit_terms}
                      </div>
                    )}
                    {editMode && (
                      <button
                        type="button"
                        onClick={() => setLotEditor({ item: null, estateId: estate.id })}
                        className="flex items-center gap-1.5 text-[13px] font-medium text-avia-brown"
                      >
                        <Plus className="h-4 w-4" /> Add Lot
                      </button>
                    )}
                    {lots.length === 0 ? (
                      <div className="py-4 text-center text-[13px] text-avia-black/45">No lots match the filters</div>
                    ) : (
                      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
                        {lots.map((lot) => (
                          <LotCard
                            key={lot.id}
                            lot={lot}
                            estateName={estate.name}
                            editMode={editMode}
                            onEdit={() => setLotEditor({ item: lot, estateId: estate.id })}
                          />
                        ))}
                      </div>
                    )}
                  </div>
                )}
              </BentoCard>
            );
          })}
        </div>
      )}

      {estateEditor !== null && (
        <EstateEditorModal estate={estateEditor === "new" ? null : estateEditor} onClose={() => setEstateEditor(null)} />
      )}
      {lotEditor !== null && (
        <LotEditorModal item={lotEditor.item} estateId={lotEditor.estateId} onClose={() => setLotEditor(null)} />
      )}
    </div>
  );
}

function SubChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "whitespace-nowrap rounded-full border px-3 py-1.5 text-[12px] font-medium transition-colors",
        active ? "border-avia-brown bg-avia-brown/10 text-avia-brown" : "border-avia-line bg-avia-card text-avia-black/55",
      )}
    >
      {label}
    </button>
  );
}

function LotCard({
  lot,
  estateName,
  editMode,
  onEdit,
}: {
  lot: StocklistItemRow;
  estateName: string;
  editMode: boolean;
  onEdit: () => void;
}) {
  const body = (
    <div className="flex h-full flex-col rounded-[12px] border border-avia-line/70 bg-avia-cardAlt transition-transform hover:-translate-y-0.5">
      <div className="flex items-start justify-between gap-2 rounded-t-[12px] bg-avia-black/5 px-3.5 py-2.5">
        <div>
          <div className="text-[14px] font-semibold text-avia-black">Lot {lot.lot_number}</div>
          {lot.stage && <div className="text-[11px] text-avia-black/50">Stage {lot.stage}</div>}
        </div>
        <div className="flex flex-col items-end gap-1">
          <span className={cn("rounded-full border px-2 py-0.5 text-[10px] font-medium", statusTone(lot.status))}>{lot.status}</span>
          {lot.specification && (
            <span className="rounded-full bg-avia-brown/10 px-2 py-0.5 text-[10px] font-medium text-avia-brown">{lot.specification}</span>
          )}
        </div>
      </div>
      <div className="flex flex-1 flex-col gap-2 p-3.5">
        <div className="text-[14px] font-medium text-avia-black">{lot.design_facade ?? "Land only"}</div>
        <div className="text-[11px] text-avia-black/45">{estateName}{lot.street ? ` · ${lot.street}` : ""}</div>
        <div className="flex flex-wrap items-center gap-3 text-[12px] text-avia-black/60">
          {lot.bedrooms && <span className="flex items-center gap-1"><BedDouble className="h-3.5 w-3.5" />{lot.bedrooms}</span>}
          {lot.bathrooms && <span className="flex items-center gap-1"><Bath className="h-3.5 w-3.5" />{lot.bathrooms}</span>}
          {lot.garages && <span className="flex items-center gap-1"><Car className="h-3.5 w-3.5" />{lot.garages}</span>}
          {lot.theatre === "1" && <span className="flex items-center gap-1"><Tv className="h-3.5 w-3.5" />Theatre</span>}
          {lot.land_size && <span className="flex items-center gap-1"><Maximize className="h-3.5 w-3.5" />{lot.land_size}</span>}
        </div>
        <div className="mt-auto flex items-end justify-between gap-2 pt-1">
          <div>
            <div className="text-[16px] font-semibold text-avia-brown">{lot.package_price ?? lot.land_price ?? "—"}</div>
            {!lot.package_price && lot.land_price && <div className="text-[10px] text-avia-black/40">land only</div>}
          </div>
          {lot.build_size && (
            <span className="rounded-full bg-avia-black/5 px-2 py-0.5 text-[10px] text-avia-black/55">{lot.build_size}</span>
          )}
        </div>
        {lot.owner_occ_investor && <div className="text-[10px] text-avia-black/40">{lot.owner_occ_investor}</div>}
      </div>
    </div>
  );

  if (editMode) {
    return (
      <button type="button" onClick={onEdit} className="block w-full text-left">
        {body}
      </button>
    );
  }
  if (lot.sales_package_link) {
    return (
      <a href={lot.sales_package_link} target="_blank" rel="noreferrer" className="relative block">
        {body}
        <ExternalLink className="absolute bottom-3 right-3 h-3.5 w-3.5 text-avia-black/30" />
      </a>
    );
  }
  return body;
}

function EstateEditorModal({ estate, onClose }: { estate: StocklistEstateRow | null; onClose: () => void }) {
  const queryClient = useQueryClient();
  const [name, setName] = useState<string>(estate?.name ?? "");
  const [region, setRegion] = useState<string>(estate?.region ?? "Brisbane");
  const [subRegion, setSubRegion] = useState<string>(estate?.sub_region ?? "");
  const [depositTerms, setDepositTerms] = useState<string>(estate?.deposit_terms ?? "");
  const [sortOrder, setSortOrder] = useState<number>(estate?.sort_order ?? 0);
  const [isActive, setIsActive] = useState<boolean>(estate?.is_active ?? true);
  const [confirmDelete, setConfirmDelete] = useState<boolean>(false);

  const save = useMutation({
    mutationFn: async () => {
      if (!name.trim()) throw new Error("Estate name is required");
      const row = {
        id: estate?.id ?? crypto.randomUUID(),
        name: name.trim(),
        region,
        sub_region: region === "Brisbane" && subRegion ? subRegion : null,
        deposit_terms: depositTerms.trim() || null,
        estate_brochure_url: estate?.estate_brochure_url ?? null,
        rental_appraisal_url: estate?.rental_appraisal_url ?? null,
        eoi_form_url: estate?.eoi_form_url ?? null,
        sort_order: sortOrder,
        is_active: isActive,
        updated_at: nowISO(),
      };
      const { error } = await supabase.from("stocklist_estates").upsert(row, { onConflict: "id" });
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["stocklist_estates"] });
      toast.success("Estate saved");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const remove = useMutation({
    mutationFn: async () => {
      if (!estate) return;
      const { error } = await supabase.from("stocklist_estates").delete().eq("id", estate.id);
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["stocklist_estates"] });
      void queryClient.invalidateQueries({ queryKey: ["stocklist_items"] });
      toast.success("Estate deleted");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <Modal open onClose={onClose} title={estate ? "Edit Estate" : "Add Estate"}>
      <div className="space-y-1.5">
        <FieldLabel>Name</FieldLabel>
        <input className={inputClass} value={name} onChange={(e) => setName(e.target.value)} />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Region</FieldLabel>
        <div className="grid grid-cols-2 gap-2">
          {STOCKLIST_REGIONS.map((r) => (
            <button
              key={r}
              type="button"
              onClick={() => setRegion(r)}
              className={cn(
                "rounded-[10px] border px-2 py-2.5 text-[12px] font-medium transition-colors",
                region === r ? "border-avia-brown bg-avia-brown text-avia-white" : "border-avia-line bg-avia-card text-avia-black/60",
              )}
            >
              {r}
            </button>
          ))}
        </div>
      </div>
      {region === "Brisbane" && (
        <div className="space-y-1.5">
          <FieldLabel>Sub-region</FieldLabel>
          <select className={inputClass} value={subRegion} onChange={(e) => setSubRegion(e.target.value)}>
            <option value="">None</option>
            {BRISBANE_SUB_REGIONS.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </div>
      )}
      <div className="space-y-1.5">
        <FieldLabel>Deposit Terms</FieldLabel>
        <textarea className={`${inputClass} min-h-20 resize-y`} value={depositTerms} onChange={(e) => setDepositTerms(e.target.value)} />
      </div>
      <div className="flex items-center gap-4">
        <div className="flex-1 space-y-1.5">
          <FieldLabel>Sort Order</FieldLabel>
          <input
            className={inputClass}
            type="number"
            min={0}
            max={999}
            value={sortOrder}
            onChange={(e) => setSortOrder(Math.max(0, Math.min(999, Number(e.target.value) || 0)))}
          />
        </div>
        <label className="flex items-center gap-2 pt-5 text-[13px] font-medium text-avia-black/70">
          <input type="checkbox" checked={isActive} onChange={(e) => setIsActive(e.target.checked)} className="h-4 w-4 accent-avia-brown" />
          Active
        </label>
      </div>
      <PrimaryButton onClick={() => save.mutate()} loading={save.isPending}>Save Estate</PrimaryButton>
      {estate && (
        confirmDelete ? (
          <div className="flex gap-2">
            <SecondaryButton onClick={() => setConfirmDelete(false)} className="flex-1">Cancel</SecondaryButton>
            <button
              type="button"
              onClick={() => remove.mutate()}
              className="flex h-[50px] flex-1 items-center justify-center rounded-[11px] bg-red-700 text-[15px] font-medium text-white"
            >
              Delete Estate
            </button>
          </div>
        ) : (
          <button type="button" onClick={() => setConfirmDelete(true)} className="w-full text-center text-[13px] font-medium text-red-700">
            Delete Estate
          </button>
        )
      )}
    </Modal>
  );
}

function LotEditorModal({ item, estateId, onClose }: { item: StocklistItemRow | null; estateId: string; onClose: () => void }) {
  const queryClient = useQueryClient();
  const [draft, setDraft] = useState<Partial<StocklistItemRow>>({
    lot_number: item?.lot_number ?? "",
    stage: item?.stage ?? "",
    street: item?.street ?? "",
    land_size: item?.land_size ?? "",
    land_price: item?.land_price ?? "",
    registered: item?.registered ?? "",
    design_facade: item?.design_facade ?? "",
    build_size: item?.build_size ?? "",
    bedrooms: item?.bedrooms ?? "",
    bathrooms: item?.bathrooms ?? "",
    garages: item?.garages ?? "",
    theatre: item?.theatre ?? "",
    build_price: item?.build_price ?? "",
    package_price: item?.package_price ?? "",
    specification: item?.specification ?? "Volos",
    status: item?.status ?? "Available",
    owner_occ_investor: item?.owner_occ_investor ?? "",
    availability: item?.availability ?? "",
    sales_package_link: item?.sales_package_link ?? "",
    is_coming_soon: item?.is_coming_soon ?? false,
    sort_order: item?.sort_order ?? 0,
  });
  const [confirmDelete, setConfirmDelete] = useState<boolean>(false);

  const set = (patch: Partial<StocklistItemRow>) => setDraft((d) => ({ ...d, ...patch }));

  const save = useMutation({
    mutationFn: async () => {
      if (!(draft.lot_number ?? "").trim()) throw new Error("Lot number is required");
      const row = {
        ...draft,
        id: item?.id ?? crypto.randomUUID(),
        estate_id: estateId,
        lot_number: (draft.lot_number ?? "").trim(),
        stage: draft.stage || null,
        street: draft.street || null,
        land_size: draft.land_size || null,
        land_price: draft.land_price || null,
        registered: draft.registered || null,
        design_facade: draft.design_facade || null,
        build_size: draft.build_size || null,
        bedrooms: draft.bedrooms || null,
        bathrooms: draft.bathrooms || null,
        garages: draft.garages || null,
        theatre: draft.theatre || null,
        build_price: draft.build_price || null,
        package_price: draft.package_price || null,
        specification: draft.specification || null,
        owner_occ_investor: draft.owner_occ_investor || null,
        availability: draft.availability || null,
        sales_package_link: draft.sales_package_link || null,
        updated_at: nowISO(),
      };
      const { error } = await supabase.from("stocklist_items").upsert(row, { onConflict: "id" });
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["stocklist_items"] });
      toast.success("Lot saved");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const remove = useMutation({
    mutationFn: async () => {
      if (!item) return;
      const { error } = await supabase.from("stocklist_items").delete().eq("id", item.id);
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["stocklist_items"] });
      toast.success("Lot deleted");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const text = (label: string, key: keyof StocklistItemRow, placeholder?: string) => (
    <div className="space-y-1.5">
      <FieldLabel>{label}</FieldLabel>
      <input
        className={inputClass}
        value={(draft[key] as string | null) ?? ""}
        placeholder={placeholder}
        onChange={(e) => set({ [key]: e.target.value } as Partial<StocklistItemRow>)}
      />
    </div>
  );

  return (
    <Modal open onClose={onClose} title={item ? `Edit Lot ${item.lot_number}` : "Add Lot"}>
      <div className="grid grid-cols-2 gap-3">
        {text("Lot Number", "lot_number")}
        {text("Stage", "stage")}
      </div>
      {text("Street", "street")}
      <div className="grid grid-cols-2 gap-3">
        {text("Land Size", "land_size", "e.g. 375m²")}
        {text("Land Price", "land_price", "e.g. $250,000")}
      </div>
      {text("Registered", "registered", "e.g. Registered / Mid 2026")}
      {text("Design & Facade", "design_facade")}
      <div className="grid grid-cols-2 gap-3">
        {text("Build Size", "build_size")}
        {text("Build Price", "build_price")}
      </div>
      <div className="grid grid-cols-4 gap-2">
        {text("Bed", "bedrooms")}
        {text("Bath", "bathrooms")}
        {text("Car", "garages")}
        {text("Theatre", "theatre")}
      </div>
      {text("Package Price", "package_price", "e.g. $675,000")}
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <FieldLabel>Specification</FieldLabel>
          <select className={inputClass} value={draft.specification ?? ""} onChange={(e) => set({ specification: e.target.value })}>
            {["Volos", "Messina", "Portobello"].map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Status</FieldLabel>
          <select className={inputClass} value={draft.status ?? "Available"} onChange={(e) => set({ status: e.target.value })}>
            {STOCKLIST_STATUSES.map((s) => (
              <option key={s} value={s}>{s}</option>
            ))}
          </select>
        </div>
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Buyer Type</FieldLabel>
        <select className={inputClass} value={draft.owner_occ_investor ?? ""} onChange={(e) => set({ owner_occ_investor: e.target.value })}>
          <option value="">Not set</option>
          {OWNER_OCC_OPTIONS.map((o) => (
            <option key={o} value={o}>{o}</option>
          ))}
        </select>
      </div>
      {text("Availability", "availability")}
      {text("Sales Package Link", "sales_package_link", "https://…")}
      <div className="flex items-center justify-between">
        <label className="flex items-center gap-2 text-[13px] font-medium text-avia-black/70">
          <input
            type="checkbox"
            checked={draft.is_coming_soon ?? false}
            onChange={(e) => set({ is_coming_soon: e.target.checked })}
            className="h-4 w-4 accent-avia-brown"
          />
          Coming Soon
        </label>
        <div className="flex items-center gap-2">
          <FieldLabel>Sort</FieldLabel>
          <input
            className="w-20 rounded-[10px] border border-avia-line bg-avia-card px-3 py-2 text-[14px] outline-none focus:border-avia-brown"
            type="number"
            value={draft.sort_order ?? 0}
            onChange={(e) => set({ sort_order: Number(e.target.value) || 0 })}
          />
        </div>
      </div>
      <PrimaryButton onClick={() => save.mutate()} loading={save.isPending}>Save Lot</PrimaryButton>
      {item && (
        confirmDelete ? (
          <div className="flex gap-2">
            <SecondaryButton onClick={() => setConfirmDelete(false)} className="flex-1">Cancel</SecondaryButton>
            <button
              type="button"
              onClick={() => remove.mutate()}
              className="flex h-[50px] flex-1 items-center justify-center rounded-[11px] bg-red-700 text-[15px] font-medium text-white"
            >
              Delete Lot
            </button>
          </div>
        ) : (
          <button type="button" onClick={() => setConfirmDelete(true)} className="w-full text-center text-[13px] font-medium text-red-700">
            Delete Lot
          </button>
        )
      )}
    </Modal>
  );
}
