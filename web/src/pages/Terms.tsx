import LegalLayout from "@/components/LegalLayout";
import { TERMS_SECTIONS } from "@/lib/legal";

export default function Terms() {
  return <LegalLayout title="Terms of Service" sections={TERMS_SECTIONS} />;
}
