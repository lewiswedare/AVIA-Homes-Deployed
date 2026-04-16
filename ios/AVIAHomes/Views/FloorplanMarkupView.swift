import SwiftUI
import PencilKit

struct FloorplanMarkupView: View {
    @Binding var drawing: PKDrawing
    let floorplanURL: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var selectedTool: MarkupTool = .pen
    @State private var selectedColor: Color = .red
    @State private var hasDrawn: Bool = false

    enum MarkupTool: String, CaseIterable {
        case pen = "Pen"
        case marker = "Marker"
        case eraser = "Eraser"

        var icon: String {
            switch self {
            case .pen: "pencil.tip"
            case .marker: "highlighter"
            case .eraser: "eraser.fill"
            }
        }
    }

    private let markupColors: [Color] = [.red, .blue, .green, .orange, .purple, .black]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AVIATheme.timelessBrown
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    instructionBanner
                    markupCanvas
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    toolBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AVIATheme.timelessBrown, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Markup Plans")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            canvasView.drawing = PKDrawing()
                            drawing = PKDrawing()
                            hasDrawn = false
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Button {
                            drawing = canvasView.drawing
                            onSubmit()
                            dismiss()
                        } label: {
                            Text("Submit")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(hasDrawn ? AVIATheme.primaryGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                                .clipShape(Capsule())
                        }
                        .disabled(!hasDrawn)
                    }
                }
            }
        }
    }

    private var instructionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.draw.fill")
                .font(.neueCorp(12))
                .foregroundStyle(AVIATheme.timelessBrown)
            Text("Draw on the floor plan to indicate changes you'd like made")
                .font(.neueCaption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
    }

    private var markupCanvas: some View {
        ZStack {
            AsyncImage(url: URL(string: floorplanURL)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                } else if phase.error != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.split.2x2")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("Unable to load floorplan")
                            .font(.neueSubheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                }
            }
            .allowsHitTesting(false)

            CanvasRepresentable(
                canvasView: $canvasView,
                drawing: $drawing,
                selectedTool: selectedTool,
                selectedColor: selectedColor,
                onDrawingChanged: { hasDrawn = true }
            )
        }
    }

    private var toolBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                ForEach(MarkupTool.allCases, id: \.self) { tool in
                    Button {
                        selectedTool = tool
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tool.icon)
                                .font(.neueCorpMedium(16))
                                .foregroundStyle(selectedTool == tool ? .white : .white.opacity(0.4))
                                .frame(width: 44, height: 44)
                                .background(selectedTool == tool ? Color.white.opacity(0.15) : Color.clear)
                                .clipShape(Circle())
                            Text(tool.rawValue)
                                .font(.neueCaption2)
                                .foregroundStyle(selectedTool == tool ? .white : .white.opacity(0.4))
                        }
                    }
                }

                Spacer()

                if selectedTool != .eraser {
                    HStack(spacing: 8) {
                        ForEach(markupColors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        if selectedColor == color {
                                            Circle()
                                                .stroke(.white, lineWidth: 2.5)
                                                .frame(width: 30, height: 30)
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.5))
    }
}

struct CanvasRepresentable: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var drawing: PKDrawing
    let selectedTool: FloorplanMarkupView.MarkupTool
    let selectedColor: Color
    let onDrawingChanged: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        updateTool(canvasView)
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        updateTool(uiView)
    }

    private func updateTool(_ canvas: PKCanvasView) {
        let uiColor = UIColor(selectedColor)
        switch selectedTool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: uiColor, width: 3)
        case .marker:
            canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.4), width: 15)
        case .eraser:
            canvas.tool = PKEraserTool(.bitmap)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing, onDrawingChanged: onDrawingChanged)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        let onDrawingChanged: () -> Void

        init(drawing: Binding<PKDrawing>, onDrawingChanged: @escaping () -> Void) {
            _drawing = drawing
            self.onDrawingChanged = onDrawingChanged
        }

        nonisolated func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            Task { @MainActor in
                drawing = canvasView.drawing
                onDrawingChanged()
            }
        }
    }
}
