/**
 * Legal copy for the hosted /terms and /privacy pages. The iOS app ships the
 * same content in `LegalContent.swift` — keep both in sync when editing.
 */

export interface LegalSection {
  heading: string;
  paragraphs: string[];
  bullets?: string[];
  trailing?: string[];
}

export const LEGAL_LAST_UPDATED = "June 2026";

export const TERMS_SECTIONS: LegalSection[] = [
  {
    heading: "1. Acceptance of Terms",
    paragraphs: [
      "By accessing or using the AVIA Homes client portal (the \u201cService\u201d, available as a mobile app and at this web portal), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Service.",
    ],
  },
  {
    heading: "2. Description of Service",
    paragraphs: [
      "The Service provides AVIA Homes clients and partners with tools to manage their new home building journey, including:",
    ],
    bullets: [
      "Viewing build progress and stage updates",
      "Making colour, finish and specification selections",
      "Reviewing packages, expressions of interest, contracts and invoices",
      "Accessing plans, documents and other build records",
      "Submitting requests and support queries",
      "Communicating with the AVIA Homes team",
    ],
  },
  {
    heading: "3. User Accounts",
    paragraphs: [
      "You are responsible for maintaining the confidentiality of your account credentials. You agree to notify AVIA Homes immediately of any unauthorised use of your account. AVIA Homes reserves the right to suspend or terminate accounts that breach these terms. You may delete your account at any time from Profile \u2192 Delete Account; deletion is permanent.",
    ],
  },
  {
    heading: "4. User Conduct",
    paragraphs: ["You agree not to:"],
    bullets: [
      "Use the Service for any unlawful purpose",
      "Attempt to gain unauthorised access to any part of the Service or to data belonging to other users",
      "Interfere with or disrupt the Service's functionality",
      "Upload malicious content or files",
      "Share your account credentials with third parties",
    ],
  },
  {
    heading: "5. Selections, Pricing & Specifications",
    paragraphs: [
      "Colour, material and upgrade selections made through the Service are subject to availability and final written confirmation by AVIA Homes. Digital representations of colours and finishes may vary from actual products. Prices shown for upgrades and packages are indicative until confirmed in your contract documentation. Build timelines and stage information are estimates and subject to change.",
    ],
  },
  {
    heading: "6. Electronic Documents & Signatures",
    paragraphs: [
      "Documents shared through the Service (including contracts and invoices) are provided through secure, time-limited links. Where the Service supports electronic acknowledgement or signing, you agree that such actions have the same effect as a handwritten signature to the extent permitted by law.",
    ],
  },
  {
    heading: "7. Intellectual Property",
    paragraphs: [
      "All content in the Service, including home designs, floor plans, specifications, images and branding, is the property of AVIA Homes and protected by copyright and intellectual property laws. You may not reproduce, distribute or create derivative works without written permission.",
    ],
  },
  {
    heading: "8. Limitation of Liability",
    paragraphs: [
      "The Service is provided \u201cas is\u201d without warranties of any kind. To the maximum extent permitted by law, AVIA Homes shall not be liable for any indirect, incidental or consequential damages arising from your use of the Service. Nothing in these terms excludes rights that cannot be excluded under the Australian Consumer Law.",
    ],
  },
  {
    heading: "9. Privacy",
    paragraphs: [
      "Your use of the Service is also governed by our Privacy Policy. Please review it to understand our data collection and usage practices.",
    ],
  },
  {
    heading: "10. Modifications",
    paragraphs: [
      "AVIA Homes may modify these Terms from time to time. Continued use of the Service after changes constitutes acceptance of the modified Terms. We will notify you of significant changes through the Service.",
    ],
  },
  {
    heading: "11. Governing Law",
    paragraphs: [
      "These Terms are governed by the laws of the State of Queensland, Australia. Any disputes will be subject to the exclusive jurisdiction of the courts of Queensland.",
    ],
  },
  {
    heading: "12. Contact",
    paragraphs: ["For questions about these Terms, please contact:"],
    trailing: ["AVIA Homes", "Email: info@aviahomes.com.au", "Phone: (07) 5654 5123"],
  },
];

export const PRIVACY_SECTIONS: LegalSection[] = [
  {
    heading: "1. Overview",
    paragraphs: [
      "AVIA Homes (\u201cwe\u201d, \u201cour\u201d, \u201cus\u201d) is committed to protecting your personal information. This Privacy Policy explains how we collect, use, disclose and safeguard your information when you use the AVIA Homes client portal (mobile app and web portal). It applies alongside the Australian Privacy Principles (APPs) under the Privacy Act 1988 (Cth).",
    ],
  },
  {
    heading: "2. Information We Collect",
    paragraphs: ["Personal information you provide:"],
    bullets: [
      "Full name and contact details (email, phone, address)",
      "Account credentials",
      "Home build details, lot and estate information",
      "Colour, finish and upgrade selections",
      "Expressions of interest, package and contract details",
      "Documents you upload or we provide to you",
      "Messages, requests and correspondence sent through the Service",
    ],
    trailing: [
      "Automatically collected information: device information (model, operating system), push notification tokens, and log data and error reports.",
    ],
  },
  {
    heading: "3. Email Communications & Open Tracking",
    paragraphs: [
      "Emails sent to you by the AVIA Homes team through the Service may include a small tracking image that tells us whether and when an email was opened. We use this only to follow up effectively on your build and sales enquiries. You can disable this by turning off remote image loading in your email client; emails remain fully readable.",
    ],
  },
  {
    heading: "4. How We Use Your Information",
    paragraphs: ["We use your information to:"],
    bullets: [
      "Provide and maintain the Service and its features",
      "Process and manage your selections, packages and contracts",
      "Deliver build progress updates and notifications",
      "Respond to your requests and queries",
      "Send important communications about your build",
      "Improve our services and user experience",
      "Comply with legal obligations",
    ],
  },
  {
    heading: "5. Information Sharing",
    paragraphs: ["We may share your information with:"],
    bullets: [
      "AVIA Homes staff involved in your build (site supervisors, consultants, administrators)",
      "Sales partners, but only for builds and packages they referred or are assigned to",
      "Trusted third-party service providers who assist in operating the Service (such as secure hosting and push notification delivery)",
      "Partner builders and suppliers as necessary for your build",
      "Legal authorities when required by law",
    ],
    trailing: ["We do not sell your personal information to third parties."],
  },
  {
    heading: "6. Data Security",
    paragraphs: [
      "Your data is protected with encryption in transit and at rest, role-based access controls enforced at the database level, and private document storage accessed only through short-lived signed links. We regularly review our security measures.",
    ],
  },
  {
    heading: "7. Data Retention & Deletion",
    paragraphs: [
      "We retain your personal information for as long as your account is active and for a reasonable period afterward for legal and business purposes. You can permanently delete your account at any time from Profile \u2192 Delete Account in the app or web portal, or by contacting us. Records we are legally required to keep (such as executed contracts) may be retained after account deletion.",
    ],
  },
  {
    heading: "8. Your Rights",
    paragraphs: ["You have the right to:"],
    bullets: [
      "Access the personal information we hold about you",
      "Request correction of inaccurate information",
      "Request deletion of your information",
      "Opt out of non-essential communications",
      "Lodge a complaint with the Office of the Australian Information Commissioner (OAIC)",
    ],
  },
  {
    heading: "9. Push Notifications",
    paragraphs: [
      "With your consent, we send push notifications for build updates, document availability and messages. You can manage notification preferences in the app settings or your device settings.",
    ],
  },
  {
    heading: "10. Children's Privacy",
    paragraphs: [
      "The Service is not intended for use by children under 18. We do not knowingly collect personal information from children.",
    ],
  },
  {
    heading: "11. Changes to This Policy",
    paragraphs: [
      "We may update this Privacy Policy from time to time. We will notify you of any material changes through the Service or via email.",
    ],
  },
  {
    heading: "12. Contact Us",
    paragraphs: ["If you have questions about this Privacy Policy or our data practices, please contact:"],
    trailing: [
      "AVIA Homes \u2014 Privacy Officer",
      "Email: privacy@aviahomes.com.au",
      "Phone: (07) 5654 5123",
      "Address: Gold Coast, Queensland, Australia",
    ],
  },
];
