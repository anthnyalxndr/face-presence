// face-presence: is someone in front of this Mac's camera?
//
// Samples the built-in camera, counts faces with Apple's on-device Vision
// framework, and prints one JSON object per sample to stdout:
//
//   {"timestamp":"2026-10-12T21:39:29Z","present":true,"faces":1,"luminance":0.41,"dark":false}
//
// `luminance` is the frame's mean brightness (0 to 1). Below `--dark-threshold`
// the detector has nothing to work with, so the sample reports `present` as
// null and `dark` as true: unknown, not absent. Consumers that merge identical
// samples should keep `luminance` out of the merge key; it changes every frame.
//
// The frame lives only in memory and is released as soon as the detector
// returns; nothing is written to disk and nothing leaves the machine. The
// camera is opened and closed around each sample, so the indicator light is
// on for well under a second per sample.
//
// Usage: face-presence [--once] [--interval SECONDS] [--timeout SECONDS]
//   --once       take one sample, print it, exit
//   --interval   seconds between samples in loop mode (default 60)
//   --timeout    seconds to wait for a usable frame (default 4)
//   --dark-threshold  mean luminance below which a sample is unknown (default 0.08)
// Exit codes: 0 ok, 2 camera permission denied, 3 no camera, 64 bad usage.

import AVFoundation
import CoreImage
import Foundation
import Vision

// MARK: - Arguments

struct Options {
    var once = false
    var interval: Double = 60
    var timeout: Double = 4
    /// Mean luminance (0...1) below which the detector is considered blind.
    var darkThreshold: Double = 0.08
}

func usage() -> Never {
    FileHandle.standardError.write(
        "usage: face-presence [--once] [--interval SECONDS] [--timeout SECONDS] [--dark-threshold 0..1]\n".data(using: .utf8)!)
    exit(64)
}

func parse(_ argv: [String]) -> Options {
    var o = Options()
    var args = argv
    while !args.isEmpty {
        let a = args.removeFirst()
        switch a {
        case "--once": o.once = true
        case "--interval":
            guard !args.isEmpty, let v = Double(args.removeFirst()), v > 0 else { usage() }
            o.interval = v
        case "--timeout":
            guard !args.isEmpty, let v = Double(args.removeFirst()), v > 0 else { usage() }
            o.timeout = v
        case "--dark-threshold":
            guard !args.isEmpty, let v = Double(args.removeFirst()), v >= 0, v <= 1 else { usage() }
            o.darkThreshold = v
        case "-h", "--help": usage()
        default: usage()
        }
    }
    return o
}

let options = parse(Array(CommandLine.arguments.dropFirst()))

func log(_ s: String) {
    FileHandle.standardError.write("face-presence: \(s)\n".data(using: .utf8)!)
}

// MARK: - One-frame capture

// One grabber, and so one capture session, serves every sample for the life of
// the process; the session is started and stopped around each sample. Once a
// session has run, AVFoundation keeps it alive even after it stops, loses its
// input and output, and is released. With a session per sample, every earlier
// input stayed registered as an observer of the camera device, so each start
// notified all of them on the main thread and left garbage that is never
// drained: memory and CPU grew with the square of the sample count (74 GB
// after 12 days at one sample a minute).
final class FrameGrabber: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "face-presence.capture")
    private var configured = false
    // frames, generation and done are touched only on `queue`.
    private var frames = 0
    private var generation = 0
    private var done: ((CVPixelBuffer?) -> Void)?
    // Skip the first few frames so auto-exposure has settled.
    private let warmupFrames = 6

    private func configure() -> Bool {
        if configured { return true }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        if session.canAddInput(input) { session.addInput(input) }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        configured = true
        return true
    }

    func grab(timeout: Double, completion: @escaping (CVPixelBuffer?) -> Void) {
        guard configure() else { completion(nil); return }
        let current: Int = queue.sync {
            frames = 0
            generation += 1
            var finished = false
            done = { [weak self] buf in
                guard !finished else { return }
                finished = true
                self?.session.stopRunning()
                completion(buf)
            }
            return generation
        }
        session.startRunning()
        // A timeout left over from an earlier sample must not end this one.
        queue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self, self.generation == current else { return }
            self.done?(nil)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        frames += 1
        guard frames > warmupFrames, let buf = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        done?(buf)
    }
}

// MARK: - Face count

func countFaces(in buffer: CVPixelBuffer) -> Int? {
    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
    do {
        try handler.perform([request])
        return request.results?.count ?? 0
    } catch {
        log("vision error: \(error)")
        return nil
    }
}

// MARK: - Brightness

/// Mean luminance of the frame, 0 (black) to 1 (white), from a Core Image
/// area average over the whole frame. One number; the frame itself is not kept.
func meanLuminance(of buffer: CVPixelBuffer) -> Double? {
    let image = CIImage(cvPixelBuffer: buffer)
    guard let filter = CIFilter(name: "CIAreaAverage") else { return nil }
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)
    guard let out = filter.outputImage else { return nil }
    var px = [UInt8](repeating: 0, count: 4)
    let ctx = CIContext(options: [.workingColorSpace: NSNull()])
    ctx.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
               format: .RGBA8, colorSpace: nil)
    let r = Double(px[0]) / 255, g = Double(px[1]) / 255, b = Double(px[2]) / 255
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

// MARK: - Output

let iso = ISO8601DateFormatter()
let stdout = FileHandle.standardOutput

func emit(faces: Int, luminance: Double?) {
    let lum = luminance ?? 1  // unknown brightness is treated as lit, so detection still counts
    let dark = lum < options.darkThreshold
    let present = dark ? "null" : "\(faces > 0)"
    let lumText = String(format: "%.3f", lum)
    let line = "{\"timestamp\":\"\(iso.string(from: Date()))\",\"present\":\(present),\"faces\":\(faces),\"luminance\":\(lumText),\"dark\":\(dark)}\n"
    stdout.write(line.data(using: .utf8)!)
}

// MARK: - Main

func requestCamera() -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized: return true
    case .notDetermined:
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        AVCaptureDevice.requestAccess(for: .video) { ok = $0; sem.signal() }
        sem.wait()
        return ok
    default: return false
    }
}

guard requestCamera() else {
    log("camera permission denied; grant it in System Settings > Privacy & Security > Camera")
    exit(2)
}
guard AVCaptureDevice.default(for: .video) != nil else {
    log("no camera available")
    exit(3)
}

let grabber = FrameGrabber()

func sample() {
    let sem = DispatchSemaphore(value: 0)
    grabber.grab(timeout: options.timeout) { buf in
        if let buf = buf, let faces = countFaces(in: buf) {
            emit(faces: faces, luminance: meanLuminance(of: buf))
        } else {
            log("no usable frame this sample")
        }
        sem.signal()
    }
    sem.wait()
}

if options.once {
    sample()
    exit(0)
}
while true {
    sample()
    Thread.sleep(forTimeInterval: options.interval)
}
