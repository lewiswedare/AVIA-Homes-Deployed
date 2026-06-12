import Foundation

/// Single source of truth for the legal copy shown in `LegalSheetView`.
/// The same content is published on the web portal at /terms and /privacy —
/// keep the two in sync when either changes.
enum LegalContent {
    static let termsLastUpdated = "June 2026"

    static let termsOfService = """
AVIA Homes — Terms of Service

Last updated: \(termsLastUpdated)

1. ACCEPTANCE OF TERMS

By accessing or using the AVIA Homes client portal (the "Service", available as a mobile app and at the AVIA Homes web portal), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the Service.

2. DESCRIPTION OF SERVICE

The Service provides AVIA Homes clients and partners with tools to manage their new home building journey, including:
• Viewing build progress and stage updates
• Making colour, finish and specification selections
• Reviewing packages, expressions of interest, contracts and invoices
• Accessing plans, documents and other build records
• Submitting requests and support queries
• Communicating with the AVIA Homes team

3. USER ACCOUNTS

You are responsible for maintaining the confidentiality of your account credentials. You agree to notify AVIA Homes immediately of any unauthorised use of your account. AVIA Homes reserves the right to suspend or terminate accounts that breach these terms. You may delete your account at any time from Profile → Delete Account; deletion is permanent.

4. USER CONDUCT

You agree not to:
• Use the Service for any unlawful purpose
• Attempt to gain unauthorised access to any part of the Service or to data belonging to other users
• Interfere with or disrupt the Service's functionality
• Upload malicious content or files
• Share your account credentials with third parties

5. SELECTIONS, PRICING & SPECIFICATIONS

Colour, material and upgrade selections made through the Service are subject to availability and final written confirmation by AVIA Homes. Digital representations of colours and finishes may vary from actual products. Prices shown for upgrades and packages are indicative until confirmed in your contract documentation. Build timelines and stage information are estimates and subject to change.

6. ELECTRONIC DOCUMENTS & SIGNATURES

Documents shared through the Service (including contracts and invoices) are provided through secure, time-limited links. Where the Service supports electronic acknowledgement or signing, you agree that such actions have the same effect as a handwritten signature to the extent permitted by law.

7. INTELLECTUAL PROPERTY

All content in the Service, including home designs, floor plans, specifications, images and branding, is the property of AVIA Homes and protected by copyright and intellectual property laws. You may not reproduce, distribute or create derivative works without written permission.

8. LIMITATION OF LIABILITY

The Service is provided "as is" without warranties of any kind. To the maximum extent permitted by law, AVIA Homes shall not be liable for any indirect, incidental or consequential damages arising from your use of the Service. Nothing in these terms excludes rights that cannot be excluded under the Australian Consumer Law.

9. PRIVACY

Your use of the Service is also governed by our Privacy Policy. Please review it to understand our data collection and usage practices.

10. MODIFICATIONS

AVIA Homes may modify these Terms from time to time. Continued use of the Service after changes constitutes acceptance of the modified Terms. We will notify you of significant changes through the Service.

11. GOVERNING LAW

These Terms are governed by the laws of the State of Queensland, Australia. Any disputes will be subject to the exclusive jurisdiction of the courts of Queensland.

12. CONTACT

For questions about these Terms, please contact:
AVIA Homes
Email: info@aviahomes.com.au
Phone: (07) 5654 5123
"""

    static let privacyPolicy = """
AVIA Homes — Privacy Policy

Last updated: \(termsLastUpdated)

1. OVERVIEW

AVIA Homes ("we", "our", "us") is committed to protecting your personal information. This Privacy Policy explains how we collect, use, disclose and safeguard your information when you use the AVIA Homes client portal (mobile app and web portal). It applies alongside the Australian Privacy Principles (APPs) under the Privacy Act 1988 (Cth).

2. INFORMATION WE COLLECT

Personal information you provide:
• Full name and contact details (email, phone, address)
• Account credentials
• Home build details, lot and estate information
• Colour, finish and upgrade selections
• Expressions of interest, package and contract details
• Documents you upload or we provide to you
• Messages, requests and correspondence sent through the Service

Automatically collected information:
• Device information (model, operating system)
• Push notification tokens
• Log data and error reports

3. EMAIL COMMUNICATIONS & OPEN TRACKING

Emails sent to you by the AVIA Homes team through the Service may include a small tracking image that tells us whether and when an email was opened. We use this only to follow up effectively on your build and sales enquiries. You can disable this by turning off remote image loading in your email client; emails remain fully readable.

4. HOW WE USE YOUR INFORMATION

We use your information to:
• Provide and maintain the Service and its features
• Process and manage your selections, packages and contracts
• Deliver build progress updates and notifications
• Respond to your requests and queries
• Send important communications about your build
• Improve our services and user experience
• Comply with legal obligations

5. INFORMATION SHARING

We may share your information with:
• AVIA Homes staff involved in your build (site supervisors, consultants, administrators)
• Sales partners, but only for builds and packages they referred or are assigned to
• Trusted third-party service providers who assist in operating the Service (such as secure hosting and push notification delivery)
• Partner builders and suppliers as necessary for your build
• Legal authorities when required by law

We do not sell your personal information to third parties.

6. DATA SECURITY

Your data is protected with encryption in transit and at rest, role-based access controls enforced at the database level, and private document storage accessed only through short-lived signed links. We regularly review our security measures.

7. DATA RETENTION & DELETION

We retain your personal information for as long as your account is active and for a reasonable period afterward for legal and business purposes. You can permanently delete your account at any time from Profile → Delete Account in the app or web portal, or by contacting us. Records we are legally required to keep (such as executed contracts) may be retained after account deletion.

8. YOUR RIGHTS

You have the right to:
• Access the personal information we hold about you
• Request correction of inaccurate information
• Request deletion of your information
• Opt out of non-essential communications
• Lodge a complaint with the Office of the Australian Information Commissioner (OAIC)

9. PUSH NOTIFICATIONS

With your consent, we send push notifications for build updates, document availability and messages. You can manage notification preferences in the app settings or your device settings.

10. CHILDREN'S PRIVACY

The Service is not intended for use by children under 18. We do not knowingly collect personal information from children.

11. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. We will notify you of any material changes through the Service or via email.

12. CONTACT US

If you have questions about this Privacy Policy or our data practices, please contact:

AVIA Homes — Privacy Officer
Email: privacy@aviahomes.com.au
Phone: (07) 5654 5123
Address: Gold Coast, Queensland, Australia
"""
}
