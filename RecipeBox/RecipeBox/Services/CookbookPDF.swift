import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Renders recipes as formatted cookbook pages (US Letter), with photo, details, ingredients and numbered steps.
enum CookbookPDF {
    private static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    private static let margin: CGFloat = 54

    static func render(_ recipes: [Recipe], title: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: {
            let f = UIGraphicsPDFRendererFormat()
            f.documentInfo = [kCGPDFContextTitle as String: title, kCGPDFContextCreator as String: "Recipe Box"]
            return f
        }())
        return renderer.pdfData { ctx in
            if recipes.count > 1 { cover(ctx, title: title, count: recipes.count) }
            for r in recipes { draw(r, ctx) }
        }
    }

    static func print(_ recipes: [Recipe], title: String) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = title
        controller.printInfo = info
        controller.printingItem = render(recipes, title: title)
        controller.present(animated: true)
    }

    // MARK: Drawing

    private static let accent = UIColor(red: 0.82, green: 0.38, blue: 0.16, alpha: 1)

    private static func font(_ size: CGFloat, _ weight: UIFont.Weight = .regular, serif: Bool = false) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if serif, let d = base.fontDescriptor.withDesign(.serif) { return UIFont(descriptor: d, size: size) }
        return base
    }

    private static func cover(_ ctx: UIGraphicsPDFRendererContext, title: String, count: Int) {
        ctx.beginPage()
        let t = NSAttributedString(string: title, attributes: [.font: font(40, .bold, serif: true), .foregroundColor: UIColor.black])
        t.draw(in: CGRect(x: margin, y: 280, width: page.width - margin * 2, height: 120))
        let sub = NSAttributedString(string: "\(count) recipes · \(Date().formatted(date: .long, time: .omitted))",
                                     attributes: [.font: font(14), .foregroundColor: UIColor.darkGray])
        sub.draw(at: CGPoint(x: margin, y: 400))
        accent.setFill()
        UIRectFill(CGRect(x: margin, y: 270, width: 80, height: 4))
    }

    /// Draws text, starting new pages as needed. Returns the new y.
    @discardableResult
    private static func text(_ s: NSAttributedString, x: CGFloat, y: CGFloat, width: CGFloat,
                             ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var yy = y
        let h = ceil(s.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
        if yy + h > page.height - margin {
            ctx.beginPage()
            yy = margin
        }
        s.draw(with: CGRect(x: x, y: yy, width: width, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return yy + h
    }

    private static func draw(_ r: Recipe, _ ctx: UIGraphicsPDFRendererContext) {
        ctx.beginPage()
        let width = page.width - margin * 2
        var y = margin

        if let d = r.photoData, let img = UIImage(data: d) {
            let h: CGFloat = 230
            let rect = CGRect(x: margin, y: y, width: width, height: h)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
            ctx.cgContext.saveGState()
            path.addClip()
            let scale = max(rect.width / img.size.width, rect.height / img.size.height)
            let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
            img.draw(in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height))
            ctx.cgContext.restoreGState()
            y += h + 18
        }

        let meta = [r.category, r.cuisine, r.difficulty].filter { !$0.isEmpty }.joined(separator: " · ").uppercased()
        y = text(NSAttributedString(string: meta, attributes: [.font: font(10, .bold), .foregroundColor: accent, .kern: 1.2]),
                 x: margin, y: y, width: width, ctx: ctx) + 4
        y = text(NSAttributedString(string: r.title, attributes: [.font: font(28, .bold, serif: true)]),
                 x: margin, y: y, width: width, ctx: ctx) + 6
        if !r.summary.isEmpty {
            y = text(NSAttributedString(string: r.summary, attributes: [.font: font(12), .foregroundColor: UIColor.darkGray]),
                     x: margin, y: y, width: width, ctx: ctx) + 8
        }
        var facts = ["Serves \(r.servings)"]
        if r.prepMinutes > 0 { facts.append("Prep \(Recipe.format(minutes: r.prepMinutes))") }
        if r.cookMinutes > 0 { facts.append("Cook \(Recipe.format(minutes: r.cookMinutes))") }
        if !r.temperature.isEmpty { facts.append(r.temperature) }
        y = text(NSAttributedString(string: facts.joined(separator: "   •   "), attributes: [.font: font(11, .semibold)]),
                 x: margin, y: y, width: width, ctx: ctx) + 14
        UIColor(white: 0.85, alpha: 1).setFill()
        UIRectFill(CGRect(x: margin, y: y, width: width, height: 0.75))
        y += 14

        y = text(NSAttributedString(string: "Ingredients", attributes: [.font: font(16, .bold, serif: true), .foregroundColor: accent]),
                 x: margin, y: y, width: width, ctx: ctx) + 6
        for ing in r.ingredients {
            y = text(NSAttributedString(string: "•  " + ing, attributes: [.font: font(11.5)]), x: margin + 4, y: y, width: width - 4, ctx: ctx) + 3
        }
        y += 14
        y = text(NSAttributedString(string: "Method", attributes: [.font: font(16, .bold, serif: true), .foregroundColor: accent]),
                 x: margin, y: y, width: width, ctx: ctx) + 6
        for (i, step) in r.steps.enumerated() {
            let para = NSMutableParagraphStyle()
            para.headIndent = 22
            let s = NSMutableAttributedString(string: "\(i + 1).  ", attributes: [.font: font(11.5, .bold), .foregroundColor: accent])
            s.append(NSAttributedString(string: step, attributes: [.font: font(11.5)]))
            s.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: s.length))
            y = text(s, x: margin, y: y, width: width, ctx: ctx) + 7
        }
        let personal = (r.cookNotes ?? []).map(\.text)
        let allNotes = ([r.notes] + personal).filter { !$0.isEmpty }
        if !allNotes.isEmpty {
            y += 10
            y = text(NSAttributedString(string: "Notes", attributes: [.font: font(16, .bold, serif: true), .foregroundColor: accent]),
                     x: margin, y: y, width: width, ctx: ctx) + 6
            for n in allNotes {
                y = text(NSAttributedString(string: n, attributes: [.font: font(11), .foregroundColor: UIColor.darkGray]),
                         x: margin, y: y, width: width, ctx: ctx) + 4
            }
        }
        if !r.sourceURL.isEmpty {
            y += 10
            text(NSAttributedString(string: "Source: \(r.sourceURL)", attributes: [.font: font(9), .foregroundColor: UIColor.gray]),
                 x: margin, y: y, width: width, ctx: ctx)
        }
        if r.sourceKind == "ai" {
            NSAttributedString(string: "AI-generated recipe", attributes: [.font: font(9, .semibold), .foregroundColor: UIColor.purple])
                .draw(at: CGPoint(x: margin, y: page.height - margin + 16))
        }
    }
}

struct PDFDocumentFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
