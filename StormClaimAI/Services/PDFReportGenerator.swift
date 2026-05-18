import Foundation
import UIKit

struct PDFReportGenerator {
    func generatePDF(
        for stormCase: StormCase,
        photos: [StormPhoto],
        findings: [DamageFinding],
        draft: StormReportDraft,
        includeLogo: Bool,
        brandedCover: Bool
    ) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "StormClaim AI",
            kCGPDFContextTitle as String: draft.title
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let url = try FileManager.default.stormClaimReportsDirectory()
            .appendingPathComponent(safeFilename(for: stormCase))

        try renderer.writePDF(to: url) { context in
            var y: CGFloat = 64

            if brandedCover {
                context.beginPage()
                drawCover(stormCase: stormCase, draft: draft, includeLogo: includeLogo, pageRect: pageRect)
                y = 64
            }

            context.beginPage()
            drawHeader(title: draft.title, includeLogo: includeLogo, pageRect: pageRect, y: &y)
            drawSection("Property details", body: [
                "Address: \(stormCase.propertyAddress)",
                "Client: \(stormCase.clientName)",
                "Insurance company: \(stormCase.insuranceCompany.isEmpty ? "Not provided" : stormCase.insuranceCompany)",
                "Policy/reference: \(stormCase.policyReference.isEmpty ? "Not provided" : stormCase.policyReference)"
            ], pageRect: pageRect, context: context, y: &y)

            drawSection("Storm event details", body: [
                "Storm date: \(StormDateFormatter.medium.string(from: stormCase.stormDate))",
                "Storm type: \(stormCase.stormTypeValue.displayName)",
                "Case created: \(StormDateFormatter.medium.string(from: stormCase.createdAt))"
            ], pageRect: pageRect, context: context, y: &y)

            drawSection("Inspection summary", body: [draft.summary], pageRect: pageRect, context: context, y: &y)
            drawSection("Contractor notes", body: [draft.contractorNotes], pageRect: pageRect, context: context, y: &y)

            let approvedFindings = findings.filter(\.userApproved)
            let severityRows = DamageSeverity.allCases.map { severity in
                "\(severity.displayName): \(approvedFindings.filter { $0.severityValue == severity }.count)"
            }
            drawSection("Severity breakdown", body: severityRows, pageRect: pageRect, context: context, y: &y)

            let priorityRows = draft.repairPriorities.map { "\($0.severity.displayName): \($0.title) - \($0.action)" }
            drawSection("Suggested repair priority", body: priorityRows, pageRect: pageRect, context: context, y: &y)

            drawFindings(approvedFindings, pageRect: pageRect, context: context, y: &y)
            drawPhotoLog(photos, pageRect: pageRect, context: context, y: &y)

            drawSection("Insurance disclaimer", body: SafetyCopy.disclaimers, pageRect: pageRect, context: context, y: &y)
            drawSection("Signature placeholder", body: [
                "Inspector/contractor name: ______________________________",
                "Signature: _____________________________________________",
                "Date: _________________________________________________"
            ], pageRect: pageRect, context: context, y: &y)
            drawFooter(pageRect: pageRect)
        }

        return url
    }

    private func safeFilename(for stormCase: StormCase) -> String {
        let base = stormCase.propertyAddress
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "StormClaim-\(base.isEmpty ? "Report" : base)-\(stormCase.id.uuidString.prefix(8)).pdf"
    }

    private func drawCover(stormCase: StormCase, draft: StormReportDraft, includeLogo: Bool, pageRect: CGRect) {
        UIColor.stormNavy.setFill()
        UIBezierPath(rect: pageRect).fill()

        let accentRect = CGRect(x: 0, y: pageRect.height - 180, width: pageRect.width, height: 180)
        UIColor.stormOrange.setFill()
        UIBezierPath(rect: accentRect).fill()

        if includeLogo {
            drawLogoPlaceholder(in: CGRect(x: 64, y: 72, width: 108, height: 108))
        }

        drawString(
            "StormClaim AI",
            in: CGRect(x: 64, y: 212, width: pageRect.width - 128, height: 54),
            font: .boldSystemFont(ofSize: 34),
            color: .white
        )
        drawString(
            draft.title,
            in: CGRect(x: 64, y: 276, width: pageRect.width - 128, height: 40),
            font: .systemFont(ofSize: 20, weight: .semibold),
            color: .white
        )
        drawString(
            stormCase.propertyAddress,
            in: CGRect(x: 64, y: 348, width: pageRect.width - 128, height: 64),
            font: .systemFont(ofSize: 22, weight: .medium),
            color: .white
        )
        drawString(
            "Prepared for \(stormCase.clientName)",
            in: CGRect(x: 64, y: 424, width: pageRect.width - 128, height: 28),
            font: .systemFont(ofSize: 16),
            color: .white
        )
        drawString(
            "Documentation support only. Not insurance, legal, structural, engineering, or certified inspection advice.",
            in: CGRect(x: 64, y: pageRect.height - 122, width: pageRect.width - 128, height: 60),
            font: .systemFont(ofSize: 15, weight: .semibold),
            color: .white
        )
    }

    private func drawHeader(title: String, includeLogo: Bool, pageRect: CGRect, y: inout CGFloat) {
        if includeLogo {
            drawLogoPlaceholder(in: CGRect(x: 48, y: y, width: 48, height: 48))
        }

        drawString(
            "StormClaim AI",
            in: CGRect(x: includeLogo ? 112 : 48, y: y, width: pageRect.width - 96, height: 24),
            font: .boldSystemFont(ofSize: 20),
            color: .stormNavy
        )
        drawString(
            title,
            in: CGRect(x: includeLogo ? 112 : 48, y: y + 28, width: pageRect.width - 96, height: 24),
            font: .systemFont(ofSize: 14, weight: .semibold),
            color: .darkGray
        )
        y += 78
    }

    private func drawSection(
        _ title: String,
        body: [String],
        pageRect: CGRect,
        context: UIGraphicsPDFRendererContext,
        y: inout CGFloat
    ) {
        startNewPageIfNeeded(context: context, pageRect: pageRect, y: &y, requiredHeight: 96)
        drawString(title, in: CGRect(x: 48, y: y, width: pageRect.width - 96, height: 24), font: .boldSystemFont(ofSize: 15), color: .stormNavy)
        y += 28

        for line in body {
            let height = measuredHeight(for: line, width: pageRect.width - 96, font: .systemFont(ofSize: 11))
            startNewPageIfNeeded(context: context, pageRect: pageRect, y: &y, requiredHeight: height + 12)
            drawString(line, in: CGRect(x: 48, y: y, width: pageRect.width - 96, height: height), font: .systemFont(ofSize: 11), color: .black)
            y += height + 8
        }

        y += 12
    }

    private func drawFindings(
        _ findings: [DamageFinding],
        pageRect: CGRect,
        context: UIGraphicsPDFRendererContext,
        y: inout CGFloat
    ) {
        let rows = findings.isEmpty
            ? ["No user-approved AI-assisted findings are included in this report."]
            : findings.map { "\($0.severityValue.displayName) - \($0.title): \($0.description) Suggested action: \($0.suggestedAction)" }
        drawSection("Damage evidence", body: rows, pageRect: pageRect, context: context, y: &y)
    }

    private func drawPhotoLog(
        _ photos: [StormPhoto],
        pageRect: CGRect,
        context: UIGraphicsPDFRendererContext,
        y: inout CGFloat
    ) {
        startNewPageIfNeeded(context: context, pageRect: pageRect, y: &y, requiredHeight: 96)
        drawString("Photo log", in: CGRect(x: 48, y: y, width: pageRect.width - 96, height: 24), font: .boldSystemFont(ofSize: 15), color: .stormNavy)
        y += 32

        if photos.isEmpty {
            drawString("No photos attached.", in: CGRect(x: 48, y: y, width: pageRect.width - 96, height: 20), font: .systemFont(ofSize: 11), color: .black)
            y += 28
            return
        }

        for photo in photos {
            startNewPageIfNeeded(context: context, pageRect: pageRect, y: &y, requiredHeight: 124)

            if let imageData = photo.imageData, let image = UIImage(data: imageData) {
                image.draw(in: CGRect(x: 48, y: y, width: 92, height: 92))
            } else {
                UIColor.systemGray5.setFill()
                UIBezierPath(rect: CGRect(x: 48, y: y, width: 92, height: 92)).fill()
            }

            let text = """
            \(photo.labelValue.displayName)
            \(photo.caption.isEmpty ? "No caption" : photo.caption)
            Captured: \(StormDateFormatter.medium.string(from: photo.timestamp))
            Evidence status: \(photo.evidenceStatusValue.displayName)
            """
            drawString(text, in: CGRect(x: 156, y: y, width: pageRect.width - 204, height: 96), font: .systemFont(ofSize: 11), color: .black)
            y += 112
        }

        y += 8
    }

    private func startNewPageIfNeeded(
        context: UIGraphicsPDFRendererContext,
        pageRect: CGRect,
        y: inout CGFloat,
        requiredHeight: CGFloat
    ) {
        if y + requiredHeight > pageRect.height - 72 {
            drawFooter(pageRect: pageRect)
            context.beginPage()
            y = 56
        }
    }

    private func drawLogoPlaceholder(in rect: CGRect) {
        UIColor.white.withAlphaComponent(0.18).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        drawString("LOGO", in: rect.insetBy(dx: 10, dy: rect.height / 2 - 8), font: .boldSystemFont(ofSize: 13), color: .white)
    }

    private func drawFooter(pageRect: CGRect) {
        drawString(
            "StormClaim AI footer - documentation support only, not a claim approval tool.",
            in: CGRect(x: 48, y: pageRect.height - 42, width: pageRect.width - 96, height: 20),
            font: .systemFont(ofSize: 9),
            color: .darkGray
        )
    }

    private func measuredHeight(for text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }

    private func drawString(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) {
        NSString(string: text).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .foregroundColor: color
            ],
            context: nil
        )
    }
}

private extension UIColor {
    static let stormNavy = UIColor(red: 0.04, green: 0.12, blue: 0.24, alpha: 1)
    static let stormOrange = UIColor(red: 0.91, green: 0.36, blue: 0.13, alpha: 1)
}
