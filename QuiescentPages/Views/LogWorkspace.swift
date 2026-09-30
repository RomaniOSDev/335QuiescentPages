import PhotosUI
import SwiftUI
import UIKit

struct PageCaptureView: View {
    var onRecognized: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var isWorking = false
    @State private var errorText = ""
    @State private var preview: UIImage?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(Color("AppAccent"))
                    Spacer()
                    Text("Page Scan")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(Color("AppPrimary"))
                    Spacer()
                    Color.clear.frame(width: 48, height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    InkPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Capture a printed page. Recognition runs on-device — nothing leaves the phone.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundColor(Color.primary.opacity(0.75))

                            if let preview {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }

                            AmberCTA(title: "Take Photo") {
                                showCamera = true
                            }

                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Text("Choose from Photos")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundColor(Color("AppPrimary"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color("AppPrimary").opacity(0.5), lineWidth: 1)
                                    )
                            }

                            if isWorking {
                                ProgressView("Reading page…")
                                    .tint(Color("AppPrimary"))
                            }

                            FieldHint(text: errorText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .clearScrollBackground()
            }
            .libraryBackdrop()
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await process(image) }
            }
        }
        .onChange(of: pickerItem) { _ in
            guard let newItem = pickerItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await process(image)
                } else {
                    errorText = "Could not load that photo."
                }
            }
        }
    }

    @MainActor
    private func process(_ image: UIImage) async {
        preview = image
        isWorking = true
        errorText = ""
        defer { isWorking = false }
        do {
            let text = try await PageOCRService.recognizeText(in: image)
            onRecognized(text)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }
    }
}
