import LegalLayout from "@/components/LegalLayout";
import { PRIVACY_SECTIONS } from "@/lib/legal";

export default function Privacy() {
  return <LegalLayout title="Privacy Policy" sections={PRIVACY_SECTIONS} />;
}
