import AVFoundation

/// Plays brown noise generated on the fly — no audio file needed.
///
/// How it works: `AVAudioEngine` is Apple's audio pipeline. We plug in an
/// `AVAudioSourceNode`, which is a little function the system calls many times
/// a second asking "give me the next few hundred samples". We fill them in.
///
/// Brown noise is white noise (pure random values) that has been smoothed by
/// adding each new random value onto the previous sample. That "random walk"
/// removes the hiss and leaves a deep, steady rumble.
final class BrownNoisePlayer {

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    var isPlaying: Bool { engine.isRunning }

    /// Starts playing at `volume` (0...1). If already playing, just sets the volume.
    func start(volume: Float) {
        setVolume(volume)
        guard sourceNode == nil else { return }

        // These two values belong to the noise generator and persist between calls.
        var lastSample: Float = 0
        var randomState: UInt32 = 0x1234_5678

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            // This closure runs on a real-time audio thread, so it must be fast:
            // no allocating memory, no locks. A tiny "xorshift" random number
            // generator keeps it that way.
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                randomState ^= randomState << 13
                randomState ^= randomState >> 17
                randomState ^= randomState << 5
                let white = Float(randomState) / Float(UInt32.max) * 2 - 1   // -1...1

                // The random walk, gently pulled back toward 0 so it never drifts off.
                lastSample = (lastSample + 0.02 * white) / 1.02
                let sample = lastSample * 3.5   // make up for the quietness of smoothing

                // Same sample on every channel (left and right).
                for buffer in buffers {
                    let channel = UnsafeMutableBufferPointer<Float>(buffer)
                    channel[frame] = sample
                }
            }
            return noErr
        }

        // Match the output device's sample rate, two channels of 32-bit floats.
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: outputFormat.sampleRate,
                                         channels: 2) else { return }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node

        do {
            try engine.start()
        } catch {
            print("JouleAI: couldn't start brown noise: \(error)")
            stop()
        }
    }

    /// Changes the volume, live.
    func setVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = max(0, min(1, volume))
    }

    func stop() {
        engine.stop()
        if let sourceNode {
            engine.detach(sourceNode)
        }
        sourceNode = nil
    }
}
