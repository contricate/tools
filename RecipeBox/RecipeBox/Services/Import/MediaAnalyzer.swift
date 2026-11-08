import Foundation
import Vision
import AVFoundation
import Speech
import UIKit

/// On-device text recognition (Vision) for thumbnails, frames and screenshots.
enum TextRecognizer {
    static func lines(in imageData: Data) async -> [String] {
        guard let cg = UIImage(data: imageData)?.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                let lines = obs.compactMap { $0.topCandidates(1).first }
                    .filter { $0.confidence > 0.35 }
                    .map { $0.string.trimmingCharacters(in: .whitespaces) }
                    .filter { $0.count >= 2 }
                cont.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do { try handler.perform([request]) } catch { cont.resume(returning: []) }
            }
        }
    }

    static func text(in images: [Data]) async -> String {
        var seen = Set<String>()
        var out: [String] = []
        for img in images {
            for line in await lines(in: img) where seen.insert(line.lowercased()).inserted {
                out.append(line)
            }
        }
        return out.joined(separator: "\n")
    }
}

/// Analyses a video file the user chose from their own library (e.g. a saved or screen-recorded clip):
/// samples frames for on-screen text and transcribes the audio on device.
enum MediaAnalyzer {
    struct Analysis {
        var frames: [Data] = []
        var onScreenText = ""
        var transcript = ""
        var notes: [String] = []
    }

    static func analyze(videoURL: URL, progress: @escaping (String) -> Void) async -> Analysis {
        var result = Analysis()
        let asset = AVURLAsset(url: videoURL)
        let duration = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0

        progress("Sampling video frames")
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        let count = duration > 0 ? min(16, max(4, Int(duration / 3))) : 0
        for i in 0..<count {
            let t = CMTime(seconds: duration * (Double(i) + 0.5) / Double(count), preferredTimescale: 600)
            if let (cg, _) = try? await generator.image(at: t),
               let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.7) {
                result.frames.append(jpeg)
            }
        }
        progress("Reading on-screen text")
        result.onScreenText = await TextRecognizer.text(in: result.frames)

        progress("Transcribing spoken instructions")
        switch await transcribe(asset: asset) {
        case .success(let t): result.transcript = t
        case .failure(let e): result.notes.append(e.localizedDescription)
        }
        return result
    }

    enum SpeechError: LocalizedError {
        case denied, unavailable, noAudio, failed(String)
        var errorDescription: String? {
            switch self {
            case .denied: return "Speech recognition permission was denied, so audio wasn't transcribed."
            case .unavailable: return "Speech recognition isn't available on this device right now."
            case .noAudio: return "The video has no audio track."
            case .failed(let m): return "Audio couldn't be transcribed: \(m)"
            }
        }
    }

    private static func transcribe(asset: AVURLAsset) async -> Swift.Result<String, SpeechError> {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized else { return .failure(.denied) }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) ?? SFSpeechRecognizer(),
              recognizer.isAvailable else { return .failure(.unavailable) }
        let tracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []
        guard !tracks.isEmpty else { return .failure(.noAudio) }

        // Export the audio track to an m4a file the recognizer can read.
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return .failure(.failed("export unavailable"))
        }
        export.outputURL = out
        export.outputFileType = .m4a
        await export.export()
        guard export.status == .completed else { return .failure(.failed(export.error?.localizedDescription ?? "export failed")) }
        defer { try? FileManager.default.removeItem(at: out) }

        let request = SFSpeechURLRecognitionRequest(url: out)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        return await withCheckedContinuation { c in
            var finished = false
            recognizer.recognitionTask(with: request) { res, err in
                guard !finished else { return }
                if let res, res.isFinal {
                    finished = true
                    c.resume(returning: .success(res.bestTranscription.formattedString))
                } else if let err {
                    finished = true
                    c.resume(returning: .failure(.failed(err.localizedDescription)))
                }
            }
        }
    }
}
