const fs = require('fs');
const path = require('path');

class PDFDocument {
  constructor() {
    this.width = 595.28;  // A4 width in points
    this.height = 841.89; // A4 height in points
    this.margin = 50;
    this.contentWidth = this.width - (this.margin * 2);

    this.pages = [];
    this.currentPage = null;
    this.currentY = 0;
    this.pageNumber = 0;

    this.addNewPage();
  }

  addNewPage() {
    this.pageNumber++;
    this.currentPage = {
      number: this.pageNumber,
      commands: []
    };
    this.pages.push(this.currentPage);
    this.currentY = this.height - 70; // start below top header

    // Draw header
    this.drawHeader();
  }

  drawHeader() {
    // Header background accent bar
    this.currentPage.commands.push(`0.098 0.165 0.353 rg`); // Navy #192A5A
    this.currentPage.commands.push(`50 ${this.height - 45} ${this.contentWidth} 2 re f`);

    // Header text
    this.currentPage.commands.push(`0.4 0.45 0.55 rg`); // Gray
    this.currentPage.commands.push(`BT /F2 8 Tf 50 ${this.height - 38} Td (SAHIREPORT  |  SECURITY AUDIT & VULNERABILITY REMEDIATION REPORT) Tj ET`);
    this.currentPage.commands.push(`BT /F1 8 Tf ${this.width - 150} ${this.height - 38} Td (CONFIDENTIAL) Tj ET`);
  }

  drawFooter() {
    for (const page of this.pages) {
      // Footer line
      page.commands.push(`0.85 0.88 0.92 RG 1 w`);
      page.commands.push(`50 45 m ${this.width - 50} 45 l S`);

      // Footer text
      page.commands.push(`0.45 0.5 0.6 rg`);
      page.commands.push(`BT /F1 8 Tf 50 32 Td (SahiReport Comprehensive Security Remediation - Technical Documentation) Tj ET`);
      const pageStr = `Page ${page.number} of ${this.pages.length}`;
      page.commands.push(`BT /F2 8 Tf ${this.width - 110} 32 Td (${pageStr}) Tj ET`);
    }
  }

  ensureSpace(neededPoints) {
    if (this.currentY - neededPoints < 60) { // footer boundary
      this.addNewPage();
    }
  }

  escapeText(str) {
    return str
      .replace(/\\/g, '\\\\')
      .replace(/\(/g, '\\(')
      .replace(/\)/g, '\\)');
  }

  addTitle(text) {
    this.ensureSpace(40);
    this.currentPage.commands.push(`0.098 0.165 0.353 rg`); // Navy
    this.currentPage.commands.push(`BT /F2 20 Tf 50 ${this.currentY} Td (${this.escapeText(text)}) Tj ET`);
    this.currentY -= 28;
  }

  addSubtitle(text) {
    this.ensureSpace(24);
    this.currentPage.commands.push(`0.35 0.42 0.55 rg`); // Slate
    this.currentPage.commands.push(`BT /F1 11 Tf 50 ${this.currentY} Td (${this.escapeText(text)}) Tj ET`);
    this.currentY -= 20;
  }

  addSectionHeading(title) {
    this.ensureSpace(35);
    this.currentY -= 8;
    // Blue section block
    this.currentPage.commands.push(`0.92 0.95 0.99 rg`);
    this.currentPage.commands.push(`50 ${this.currentY - 4} ${this.contentWidth} 22 re f`);
    this.currentPage.commands.push(`0.1 0.25 0.55 RG 1.5 w`);
    this.currentPage.commands.push(`50 ${this.currentY - 4} m 50 ${this.currentY + 18} l S`);

    this.currentPage.commands.push(`0.08 0.18 0.42 rg`);
    this.currentPage.commands.push(`BT /F2 13 Tf 58 ${this.currentY + 2} Td (${this.escapeText(title)}) Tj ET`);
    this.currentY -= 22;
  }

  addSubheading(title) {
    this.ensureSpace(26);
    this.currentY -= 4;
    this.currentPage.commands.push(`0.15 0.25 0.45 rg`);
    this.currentPage.commands.push(`BT /F2 10.5 Tf 50 ${this.currentY} Td (${this.escapeText(title)}) Tj ET`);
    this.currentY -= 16;
  }

  addBadge(text, type = 'info') {
    let r = 0.9, g = 0.95, b = 1.0, textR = 0.05, textG = 0.2, textB = 0.5;
    if (type === 'critical') { r = 1.0; g = 0.9; b = 0.9; textR = 0.7; textG = 0.1; textB = 0.1; }
    if (type === 'high')     { r = 1.0; g = 0.94; b = 0.88; textR = 0.8; textG = 0.4; textB = 0.0; }
    if (type === 'success')  { r = 0.88; g = 0.98; b = 0.9; textR = 0.1; textG = 0.55; textB = 0.2; }

    const badgeWidth = text.length * 6 + 14;
    this.currentPage.commands.push(`${r} ${g} ${b} rg`);
    this.currentPage.commands.push(`50 ${this.currentY - 2} ${badgeWidth} 14 re f`);
    this.currentPage.commands.push(`${textR} ${textG} ${textB} rg`);
    this.currentPage.commands.push(`BT /F2 8 Tf 57 ${this.currentY + 2} Td (${this.escapeText(text)}) Tj ET`);
    this.currentY -= 16;
  }

  addParagraph(text, font = 'F1', size = 9.5, lineHeight = 13) {
    const words = text.split(' ');
    let line = '';
    const maxCharsPerLine = 92;

    this.currentPage.commands.push(`0.18 0.22 0.28 rg`); // Charcoal text

    for (let i = 0; i < words.length; i++) {
      const testLine = line + (line ? ' ' : '') + words[i];
      if (testLine.length > maxCharsPerLine && line) {
        this.ensureSpace(lineHeight);
        this.currentPage.commands.push(`BT /${font} ${size} Tf 50 ${this.currentY} Td (${this.escapeText(line)}) Tj ET`);
        this.currentY -= lineHeight;
        line = words[i];
      } else {
        line = testLine;
      }
    }
    if (line) {
      this.ensureSpace(lineHeight);
      this.currentPage.commands.push(`BT /${font} ${size} Tf 50 ${this.currentY} Td (${this.escapeText(line)}) Tj ET`);
      this.currentY -= lineHeight;
    }
    this.currentY -= 4; // spacing after paragraph
  }

  addBullet(title, description) {
    const fullText = (title ? title + ': ' : '') + description;
    const words = fullText.split(' ');
    let line = '';
    const maxChars = 86;
    let isFirstLine = true;

    for (let i = 0; i < words.length; i++) {
      const testLine = line + (line ? ' ' : '') + words[i];
      if (testLine.length > maxChars && line) {
        this.ensureSpace(13);
        if (isFirstLine) {
          // Draw bullet dot
          this.currentPage.commands.push(`0.1 0.3 0.6 rg`);
          this.currentPage.commands.push(`54 ${this.currentY + 3} 3 3 re f`);
          this.currentPage.commands.push(`0.2 0.24 0.3 rg`);
          this.currentPage.commands.push(`BT /F1 9.5 Tf 65 ${this.currentY} Td (${this.escapeText(line)}) Tj ET`);
          isFirstLine = false;
        } else {
          this.currentPage.commands.push(`0.2 0.24 0.3 rg`);
          this.currentPage.commands.push(`BT /F1 9.5 Tf 65 ${this.currentY} Td (${this.escapeText(line)}) Tj ET`);
        }
        this.currentY -= 13;
        line = words[i];
      } else {
        line = testLine;
      }
    }
    if (line) {
      this.ensureSpace(13);
      if (isFirstLine) {
        this.currentPage.commands.push(`0.1 0.3 0.6 rg`);
        this.currentPage.commands.push(`54 ${this.currentY + 3} 3 3 re f`);
        this.currentPage.commands.push(`0.2 0.24 0.3 rg`);
        this.currentPage.commands.push(`BT /F1 9.5 Tf 65 ${this.currentY} Td (${this.escapeText(line)}) Tj ET`);
      } else {
        this.currentPage.commands.push(`0.2 0.24 0.3 rg`);
        this.currentPage.commands.push(`BT /F1 9.5 Tf 65 ${this.currentY} Td (${this.escapeText(line)}) Tj ET`);
      }
      this.currentY -= 13;
    }
    this.currentY -= 2;
  }

  addFileEntry(filePath, description) {
    this.ensureSpace(28);
    // Gray badge for path
    this.currentPage.commands.push(`0.94 0.96 0.98 rg`);
    this.currentPage.commands.push(`50 ${this.currentY - 3} ${this.contentWidth} 16 re f`);
    this.currentPage.commands.push(`0.1 0.2 0.45 rg`);
    this.currentPage.commands.push(`BT /F3 8.5 Tf 56 ${this.currentY} Td (${this.escapeText(filePath)}) Tj ET`);
    this.currentY -= 17;

    // Description
    this.addParagraph(description, 'F1', 8.8, 12);
  }

  addCodeBlock(codeLines) {
    const blockHeight = codeLines.length * 11 + 12;
    this.ensureSpace(blockHeight + 10);

    // Background container
    this.currentPage.commands.push(`0.96 0.97 0.98 rg`);
    this.currentPage.commands.push(`50 ${this.currentY - blockHeight + 10} ${this.contentWidth} ${blockHeight} re f`);
    this.currentPage.commands.push(`0.82 0.85 0.9 RG 0.8 w`);
    this.currentPage.commands.push(`50 ${this.currentY - blockHeight + 10} ${this.contentWidth} ${blockHeight} re S`);

    let y = this.currentY;
    this.currentPage.commands.push(`0.15 0.2 0.3 rg`);
    for (const codeLine of codeLines) {
      this.currentPage.commands.push(`BT /F3 7.8 Tf 58 ${y} Td (${this.escapeText(codeLine)}) Tj ET`);
      y -= 11;
    }
    this.currentY -= (blockHeight + 6);
  }

  addTable(headers, rows, colWidths) {
    const rowHeight = 18;
    const totalHeight = (rows.length + 1) * rowHeight;
    this.ensureSpace(totalHeight + 10);

    let startX = 50;

    // Header row background
    this.currentPage.commands.push(`0.1 0.18 0.38 rg`);
    this.currentPage.commands.push(`50 ${this.currentY - 14} ${this.contentWidth} ${rowHeight} re f`);

    // Header text
    this.currentPage.commands.push(`1 1 1 rg`);
    let currentX = startX;
    for (let i = 0; i < headers.length; i++) {
      this.currentPage.commands.push(`BT /F2 8.5 Tf ${currentX + 4} ${this.currentY - 9} Td (${this.escapeText(headers[i])}) Tj ET`);
      currentX += colWidths[i];
    }
    this.currentY -= rowHeight;

    // Data rows
    for (let r = 0; r < rows.length; r++) {
      this.ensureSpace(rowHeight);
      const isEven = r % 2 === 0;
      if (isEven) {
        this.currentPage.commands.push(`0.97 0.98 0.99 rg`);
        this.currentPage.commands.push(`50 ${this.currentY - 14} ${this.contentWidth} ${rowHeight} re f`);
      }
      // Row bottom border
      this.currentPage.commands.push(`0.88 0.9 0.93 RG 0.5 w`);
      this.currentPage.commands.push(`50 ${this.currentY - 14} m ${50 + this.contentWidth} ${this.currentY - 14} l S`);

      currentX = startX;
      for (let c = 0; c < rows[r].length; c++) {
        const cell = rows[r][c];
        if (c === 0) {
          this.currentPage.commands.push(`0.1 0.2 0.4 rg`);
          this.currentPage.commands.push(`BT /F2 8 Tf ${currentX + 4} ${this.currentY - 9} Td (${this.escapeText(cell)}) Tj ET`);
        } else if (cell === 'CRITICAL') {
          this.currentPage.commands.push(`0.8 0.1 0.1 rg`);
          this.currentPage.commands.push(`BT /F2 8 Tf ${currentX + 4} ${this.currentY - 9} Td (${this.escapeText(cell)}) Tj ET`);
        } else if (cell === 'HIGH') {
          this.currentPage.commands.push(`0.8 0.4 0.0 rg`);
          this.currentPage.commands.push(`BT /F2 8 Tf ${currentX + 4} ${this.currentY - 9} Td (${this.escapeText(cell)}) Tj ET`);
        } else if (cell === 'MEDIUM') {
          this.currentPage.commands.push(`0.6 0.45 0.0 rg`);
          this.currentPage.commands.push(`BT /F1 8 Tf ${currentX + 4} ${this.currentY - 9} Td (${this.escapeText(cell)}) Tj ET`);
        } else if (cell === 'RESOLVED') {
          this.currentPage.commands.push(`0.1 0.55 0.2 rg`);
          this.currentPage.commands.push(`BT /F2 8 Tf ${currentX + 4} ${this.currentY - 9} Td (${this.escapeText(cell)}) Tj ET`);
        } else {
          this.currentPage.commands.push(`0.2 0.24 0.3 rg`);
          this.currentPage.commands.push(`BT /F1 8 Tf ${currentX + 4} ${this.currentY - 9} Td (${this.escapeText(cell)}) Tj ET`);
        }
        currentX += colWidths[c];
      }
      this.currentY -= rowHeight;
    }
    this.currentY -= 6;
  }

  buildPDF() {
    this.drawFooter();

    const objects = [];
    let objId = 1;

    // 1: Catalog
    const catalogId = objId++;
    // 2: Pages
    const pagesId = objId++;

    // 3: F1 Font (Helvetica)
    const font1Id = objId++;
    // 4: F2 Font (Helvetica-Bold)
    const font2Id = objId++;
    // 5: F3 Font (Courier)
    const font3Id = objId++;

    const pageObjIds = [];
    const contentObjIds = [];

    for (let i = 0; i < this.pages.length; i++) {
      pageObjIds.push(objId++);
      contentObjIds.push(objId++);
    }

    // Build object contents
    objects[catalogId] = `<< /Type /Catalog /Pages ${pagesId} 0 R >>`;
    objects[pagesId] = `<< /Type /Pages /Kids [${pageObjIds.map(id => `${id} 0 R`).join(' ')}] /Count ${this.pages.length} >>`;

    objects[font1Id] = `<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>`;
    objects[font2Id] = `<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>`;
    objects[font3Id] = `<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>`;

    for (let i = 0; i < this.pages.length; i++) {
      const pId = pageObjIds[i];
      const cId = contentObjIds[i];
      const page = this.pages[i];

      objects[pId] = `<< /Type /Page /Parent ${pagesId} 0 R /Resources << /Font << /F1 ${font1Id} 0 R /F2 ${font2Id} 0 R /F3 ${font3Id} 0 R >> >> /MediaBox [0 0 ${this.width} ${this.height}] /Contents ${cId} 0 R >>`;

      const streamContent = page.commands.join('\n');
      const streamLen = Buffer.byteLength(streamContent, 'utf-8');
      objects[cId] = `<< /Length ${streamLen} >>\nstream\n${streamContent}\nendstream`;
    }

    // Assemble file with cross-reference table
    let out = `%PDF-1.4\n%âãÏÓ\n`;
    const offsets = [];

    for (let id = 1; id < objId; id++) {
      offsets[id] = Buffer.byteLength(out, 'utf-8');
      out += `${id} 0 obj\n${objects[id]}\nendobj\n`;
    }

    const startXref = Buffer.byteLength(out, 'utf-8');
    out += `xref\n0 ${objId}\n0000000000 65535 f \n`;

    for (let id = 1; id < objId; id++) {
      const offStr = String(offsets[id]).padStart(10, '0');
      out += `${offStr} 00000 n \n`;
    }

    out += `trailer\n<< /Size ${objId} /Root ${catalogId} 0 R >>\nstartxref\n${startXref}\n%%EOF\n`;

    return Buffer.from(out, 'utf-8');
  }
}

// ── Populate Document Content ─────────────────────────────────

const doc = new PDFDocument();

// Cover Header
doc.addTitle("SahiReport - Security Audit & Remediation");
doc.addSubtitle("Technical Analysis, Step-by-Step Fixes & Codebase Changes Map");
doc.addParagraph("Date: November 2026  |  Scope: Client Application, Supabase Backend, Manifests & Migrations");

doc.addSectionHeading("1. Executive Summary");
doc.addParagraph("SahiReport underwent a comprehensive security review covering mobile client logic, backend database access controls (Row-Level Security), cryptographic payment verification, GPS tamper protection, and app store compliance standards. All identified vulnerabilities have been remediated across the codebase.");
doc.addParagraph("This document provides technical documentation of each flaw, the attack vector mitigated, the exact source files modified, and verification procedures.");

doc.addSectionHeading("2. Vulnerability & Remediation Matrix");

const headers = ["ID", "Severity", "Category", "Vulnerability Description", "Status"];
const colWidths = [35, 60, 85, 255, 60];
const rows = [
  ["1.1", "CRITICAL", "Payment Security", "Client-side plan upgrade / Payment bypass", "RESOLVED"],
  ["1.2", "CRITICAL", "API Authorization", "Unauthenticated FCM push notification Edge Function", "RESOLVED"],
  ["2.1", "HIGH", "Data Integrity", "GPS-verified spoofing via Mock Location apps", "RESOLVED"],
  ["2.2", "HIGH", "Access Control", "Co-Owner authentication & RLS session mismatch", "RESOLVED"],
  ["2.3", "HIGH", "Authentication", "Low entropy on admin access codes (brute-force)", "RESOLVED"],
  ["3.1", "MEDIUM", "Storage Security", "Anonymous storage uploads without MIME validation", "RESOLVED"],
  ["3.2", "MEDIUM", "Compliance", "Incomplete account deletion (App Store Guideline 5.1.1)", "RESOLVED"],
  ["3.3", "MEDIUM", "Store Policy", "Unused ACCESS_BACKGROUND_LOCATION in Android", "RESOLVED"],
  ["3.4", "MEDIUM", "Compliance", "Placeholder legal & privacy policy URLs", "RESOLVED"],
  ["4.1", "LOW", "User Experience", "Registration redirect mismatch (Email link vs SMS)", "RESOLVED"],
  ["4.2", "LOW", "Storage Leak", "Orphaned storage image files on project deletion", "RESOLVED"]
];
doc.addTable(headers, rows, colWidths);

// Section 3: Critical Vulnerabilities
doc.addSectionHeading("3. Critical Security Fixes");

doc.addSubheading("3.1 Server-Side Payment Signature Verification (Payment Bypass)");
doc.addBadge("CRITICAL VULNERABILITY MITIGATED", "critical");
doc.addBullet("Problem", "When Razorpay completed on the client, billing_screen.dart directly executed an UPDATE query on the owners table to grant pro_project_slots without any server-side cryptographic proof.");
doc.addBullet("Risk", "Any user with the Supabase anon key could craft a direct database request to grant themselves unlimited annual Pro project slots without ever paying.");
doc.addBullet("Remediation", "Created verify-payment Supabase Edge Function that computes HMAC-SHA256 signature using RAZORPAY_KEY_SECRET. If the signature matches razorpay_signature, the function updates the database using the service_role key.");
doc.addBullet("Database Trigger", "Added PostgreSQL trigger trg_protect_owner_subscription_fields blocking any direct client updates to plan_type, pro_project_slots, or pro_expires_at.");
doc.addCodeBlock([
  "// verify-payment/index.ts HMAC-SHA256 validation",
  "const signaturePayload = `${razorpay_order_id}|${razorpay_payment_id}`;",
  "const cryptoKey = await crypto.subtle.importKey('raw', encoder.encode(secret), ...);",
  "const signatureBuffer = await crypto.subtle.sign('HMAC', cryptoKey, payload);",
  "if (!timingSafeEqual(expectedSignature, razorpay_signature)) {",
  "  return json({ error: 'Invalid payment signature. Possible fraud attempt.' }, 400);",
  "}"
]);

doc.addSubheading("3.2 Securing send-notification Edge Function");
doc.addBadge("CRITICAL VULNERABILITY MITIGATED", "critical");
doc.addBullet("Problem", "The send-notification Edge Function used the service-role key but did not check incoming Authorization headers, allowing public invocation from any HTTP client.");
doc.addBullet("Remediation", "Added strict Supabase Bearer JWT verification, validating token structure and signature before accepting submission_id or triggering Google Firebase FCM messages.");

// Section 4: High Severity Fixes
doc.addSectionHeading("4. High-Severity Security Fixes");

doc.addSubheading("4.1 GPS Tamper Protection & Mock Location Detection");
doc.addBadge("HIGH SEVERITY MITIGATED", "high");
doc.addBullet("Problem", "The app claimed 'GPS-Verified' daily progress reports, but never inspected pos.isMocked from geolocator. Users could use Fake GPS apps to submit false reports from home.");
doc.addBullet("Remediation", "Added mandatory pos.isMocked validation in field_home_screen.dart. If mock location is active, submission is blocked with an alert.");
doc.addCodeBlock([
  "final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);",
  "if (pos.isMocked) {",
  "  setState(() { _gpsError = 'Mock location detected. Please disable Fake GPS.'; });",
  "  return;",
  "}"
]);

doc.addSubheading("4.2 Access Code Entropy Upgrade (Brute-Force Prevention)");
doc.addBadge("HIGH SEVERITY MITIGATED", "high");
doc.addBullet("Problem", "Co-Owner administrative access codes previously used 4 random characters (ADMN-XXXX), yielding under 925,000 combinations. An attacker could enumerate codes in hours.");
doc.addBullet("Remediation", "Expanded suffix to 8 random alphanumeric characters (ADMN-XXXXXXXX), yielding over 850 billion combinations. Added rate limiting in auth_rate_limits table.");

// Section 5: Medium & Compliance Fixes
doc.addSectionHeading("5. Regulatory Compliance & Platform Hardening");

doc.addSubheading("5.1 Storage Bucket MIME and File Size Constraints");
doc.addBullet("Hardening", "Configured storage.buckets policy for submission-images enforcing a 5 MB maximum size limit and restricting MIME types to image/jpeg, image/png, and image/webp.");

doc.addSubheading("5.2 App Store Account Deletion Compliance (Apple Guideline 5.1.1)");
doc.addBullet("Requirement", "Apple requires in-app account deletion to purge all user data, not just set a soft-delete flag.");
doc.addBullet("Remediation", "Wired softDeleteAccount() in auth_provider.dart to invoke delete-account Edge Function. Added daily pg_cron job purge_soft_deleted_accounts() to automatically wipe data older than 30 days.");

doc.addSubheading("5.3 Native Platform Configuration Updates (Android & iOS)");
doc.addBullet("Android Manifest", "Removed unused ACCESS_BACKGROUND_LOCATION permission. Added FCM default notification channel (sahi_report_submissions). Added <queries> for url_launcher.");
doc.addBullet("Android ProGuard", "Added proguard-rules.pro keeping Razorpay JavaScript interfaces (@JavascriptInterface), AdMob, and Firebase reflection classes.");
doc.addBullet("iOS Info.plist", "Removed NSLocationAlwaysAndWhenInUseUsageDescription to prevent App Store rejection. Added CFBundleURLTypes for fieldtrack:// deep linking. Expanded SKAdNetworkItems.");
doc.addBullet("iOS Podfile", "Fixed uppercase GCC_PREPROCESSOR_DEFINITIONS for permission_handler.");

// Section 6: Low Severity & Maintenance Fixes
doc.addSectionHeading("6. Workflow & Storage Optimization");
doc.addBullet("Registration OTP Flow", "Fixed owner_register_screen.dart to redirect users to ConfirmEmailScreen rather than expecting an SMS OTP that was never dispatched.");
doc.addBullet("Storage Cleanup", "Updated deleteProject() in ProjectRepository to collect all image paths from submission_images and purge them from Supabase Storage before dropping the project row.");

// Section 7: Codebase Changes Directory & File Map
doc.addSectionHeading("7. Codebase Changes Directory & File Map");
doc.addParagraph("The following is the complete, folder-by-folder inventory of all source files modified or created to remediate vulnerabilities and ensure store compliance:");

doc.addSubheading("Folder: lib/ (Application Source Code)");

doc.addFileEntry(
  "lib/core/constants/app_constants.dart",
  "Added centralized production legal URLs (privacyPolicyUrl, termsOfServiceUrl) replacing hardcoded placeholder strings throughout the application."
);

doc.addFileEntry(
  "lib/features/auth/screens/code_login_screen.dart",
  "Updated access code segment width and length validation to support 8-character suffixes for the upgraded high-entropy Co-Owner access codes (ADMN-XXXXXXXX)."
);

doc.addFileEntry(
  "lib/features/auth/screens/owner_register_screen.dart",
  "Corrected registration redirection bug: routes newly registered owners to ConfirmEmailScreen (for Supabase email confirmation link) instead of waiting for an SMS OTP."
);

doc.addFileEntry(
  "lib/features/field_user/screens/field_home_screen.dart",
  "Integrated pos.isMocked hardware verification from Geolocator to detect and block Fake GPS and mock location spoofing apps."
);

doc.addFileEntry(
  "lib/features/owner/billing/screens/billing_screen.dart",
  "Eliminated client-side database updates on payment. Calls verify-payment Edge Function with payment ID, order ID, and signature for cryptographic server-side validation."
);

doc.addFileEntry(
  "lib/features/owner/settings/screens/owner_settings_screen.dart",
  "Connected legal and privacy policy links directly to AppConstants, removing placeholder YOUR-SITE.com domains."
);

doc.addFileEntry(
  "lib/providers/auth_provider.dart",
  "Enhanced softDeleteAccount() to immediately trigger the delete-account Edge Function for complete account data purge (App Store compliance)."
);

doc.addFileEntry(
  "lib/repositories/auth_repository.dart",
  "Added triggerAccountDeletion() method calling the backend delete-account Edge Function."
);

doc.addFileEntry(
  "lib/repositories/co_owner_repository.dart",
  "Upgraded Co-Owner access code generator from 4 to 8 random alphanumeric characters (ADMN-XXXXXXXX), expanding entropy to over 850 billion combinations."
);

doc.addFileEntry(
  "lib/repositories/project_repository.dart",
  "Updated deleteProject() to retrieve all image storage_paths from submission_images and purge them from Supabase Storage before removing the project record."
);

doc.addSubheading("Folder: supabase/ (Backend, Edge Functions & Migrations)");

doc.addFileEntry(
  "supabase/functions/verify-payment/index.ts [NEW]",
  "New Edge Function with replay attack prevention via payment_transactions table, dual HMAC-SHA256 and Razorpay REST API verification, and secure service_role plan slot allocation."
);

doc.addFileEntry(
  "supabase/functions/send-notification/index.ts",
  "Added Bearer token verification supporting both anonymous project tokens and user JWTs, plus strict submission-to-project ownership binding to eliminate notification forgery."
);

doc.addFileEntry(
  "supabase/migrations/20261102_security_hardening.sql [NEW]",
  "PostgreSQL migration containing subscription field protection triggers, auth rate limiting, payment_transactions replay table, 5MB/MIME storage limits, pg_cron purge, and RPCs."
);

doc.addSubheading("Folder: android/ (Native Android Configuration)");

doc.addFileEntry(
  "android/app/build.gradle.kts",
  "Configured release build type to link custom ProGuard rules (proguard-rules.pro) for R8 optimization and reflection safety."
);

doc.addFileEntry(
  "android/app/proguard-rules.pro [NEW]",
  "Custom rules preserving Razorpay WebView JavascriptInterface methods (@JavascriptInterface, onPayment*), AdMob, and Firebase Cloud Messaging reflection classes."
);

doc.addFileEntry(
  "android/app/src/main/AndroidManifest.xml",
  "Removed ACCESS_BACKGROUND_LOCATION permission. Added default FCM notification channel (sahi_report_submissions). Added deep linking intent filters (fieldtrack://, sahireport://). Added <queries> for url_launcher on Android 11+."
);

doc.addSubheading("Folder: ios/ (Native iOS Configuration)");

doc.addFileEntry(
  "ios/Podfile",
  "Corrected typo GCC_PREPROCESSOR_definitions to uppercase GCC_PREPROCESSOR_DEFINITIONS in post_install so camera and location permission macros compile into permission_handler."
);

doc.addFileEntry(
  "ios/Runner/Info.plist",
  "Removed NSLocationAlwaysAndWhenInUseUsageDescription to satisfy Apple Guideline 5.1.5. Standardized CFBundleName to SahiReport. Added CFBundleURLTypes for deep linking. Expanded SKAdNetworkItems for AdMob."
);

doc.addSubheading("Documentation & Artifacts");

doc.addFileEntry(
  "docs/ANDROID_AND_IOS_UPDATES.md (and root)",
  "Dedicated technical guide detailing every native platform update, configuration diffs, and Android/iOS build verification commands."
);

doc.addFileEntry(
  "docs/SAHIREPORT_SECURITY_AUDIT_AND_FIXES.pdf (and root)",
  "This publication-grade PDF report documenting executive summary, vulnerability matrix, technical fixes, and codebase change map."
);

// Section 8: Deployment Instructions
doc.addSectionHeading("8. Deployment & Verification Checklist");
doc.addBullet("Step 1 (Database)", "Open Supabase Dashboard -> SQL Editor and execute supabase/migrations/20261102_security_hardening.sql.");
doc.addBullet("Step 2 (Edge Functions)", "Run: supabase secrets set RAZORPAY_KEY_SECRET='your_secret' && supabase functions deploy verify-payment && supabase functions deploy send-notification.");
doc.addBullet("Step 3 (Android Build)", "Execute: flutter build appbundle --release.");
doc.addBullet("Step 4 (iOS Build)", "Execute: cd ios && pod install && cd .. && flutter build ipa --release.");

// Generate output
const pdfBuffer = doc.buildPDF();
const outputPath = path.join(__dirname, 'docs', 'SAHIREPORT_SECURITY_AUDIT_AND_FIXES.pdf');
fs.writeFileSync(outputPath, pdfBuffer);
const rootOutputPath = path.join(__dirname, 'SAHIREPORT_SECURITY_AUDIT_AND_FIXES.pdf');
fs.writeFileSync(rootOutputPath, pdfBuffer);
console.log(`PDF successfully generated at: ${outputPath} and ${rootOutputPath} (${pdfBuffer.length} bytes)`);
