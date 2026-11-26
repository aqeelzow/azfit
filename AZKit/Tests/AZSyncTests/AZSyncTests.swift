import AZModel
import Foundation
import ImageIO
import Network
import Testing
import UniformTypeIdentifiers

@testable import AZSync

@Suite struct PairingCodeTests {
    @Test func roundTripsThroughText() throws {
        let code = PairingCode(bridgeID: UUID(), bridgeName: "Aqeel's MacBook", hosts: ["mac.tailnet.ts.net"])
        #expect(code.text.hasPrefix("azfit-pair:"))
        #expect(!code.text.contains("+") && !code.text.contains("/") && !code.text.contains("="))
        #expect(try PairingCode(text: "  \(code.text)\n") == code)
    }

    @Test func rejectsOtherText() {
        #expect(throws: PairingCode.Failure.notAPairingCode) { try PairingCode(text: "hello") }
        #expect(throws: PairingCode.Failure.unreadable) { try PairingCode(text: "azfit-pair:!!!") }
        var short = PairingCode(bridgeID: UUID(), bridgeName: "Mac")
        short.key = Data([1, 2, 3])
        #expect(throws: PairingCode.Failure.badKey) { try PairingCode(text: short.text) }
    }
}

@Suite struct MessageTests {
    @Test func messagesRoundTrip() throws {
        let messages: [Message] = [
            .hello(Hello(phoneName: "iPhone")),
            .status(BridgeStatus(bridgeName: "Mac", claude: .signedOut)),
            .request(Request(job: .chat(ChatRequest(message: "Why?", history: [ChatMessage(role: .div, text: "Hi")])))),
            .response(
                Response(
                    id: UUID(),
                    outcome: .chat(
                        ChatReply(
                            reply: "Done.",
                            changes: [Checked(item: Proposal(.swapExercise(from: "A", to: "B", weeks: 2), reason: "r"), verdict: .apply)],
                            model: "opus")))),
            .response(Response(id: UUID(), outcome: .failed("Claude is signed out."))),
            .request(Request(job: .sessionReview(SessionReviewRequest(workoutID: UUID())), person: UUID())),
            .response(Response(id: UUID(), outcome: .sessionReviewed(SessionReviewReply(note: "Good.", applied: 1, proposed: 0)))),
            .request(
                Request(job: .estimateMeal(MealPhotoRequest(photo: Data([0xFF, 0xD8, 0xFF]), mediaType: .jpeg, note: "half the rice")))),
            .request(Request(job: .reviseMeal(MealRevisionRequest(previous: Self.estimate, question: "Dressing?", answer: "A little")))),
            .response(
                Response(
                    id: UUID(),
                    outcome: .mealEstimated(
                        MealEstimateReply(
                            estimate: Self.estimate, totals: MealTotals(kcal: 270, proteinG: 30, carbsG: 0, fatG: 16, grams: 130),
                            warnings: ["Check the rice."])))),
        ]
        for message in messages {
            #expect(try DivJSON.decode(Message.self, from: DivJSON.encode(message)) == message)
        }
        #expect(try DivJSON.string(Message.hello(Hello(phoneName: "iPhone")), pretty: false).contains(#""type":"hello""#))
        let review = try DivJSON.string(Job.sessionReview(SessionReviewRequest(workoutID: UUID())), pretty: false)
        #expect(review.contains(#""kind":"session_review""#) && review.contains(#""session_review":{"#))
        let photo = try DivJSON.string(Job.estimateMeal(MealPhotoRequest(photo: Data(), mediaType: .jpeg)), pretty: false)
        #expect(photo.contains(#""kind":"estimate_meal""#) && photo.contains(#""estimate_meal":{"#))
        let estimated = try DivJSON.string(
            Outcome.mealEstimated(MealEstimateReply(estimate: Self.estimate, totals: MealTotals(kcal: 1, proteinG: 0, carbsG: 0, fatG: 0, grams: 0))),
            pretty: false)
        #expect(estimated.contains(#""kind":"meal_estimated""#) && estimated.contains(#""meal_estimated":{"#))
    }

    static let estimate = MealEstimate(
        mealName: "Salmon bowl",
        items: [MealItem(name: "Salmon", portion: "130 g", grams: 130, kcal: 270, proteinG: 30, carbsG: 0, fatG: 16)], kcalLow: 520,
        kcalHigh: 760, followUpQuestion: "Was there dressing?")

    @Test func framesSplitAndJoin() throws {
        let one = try Framing.frame(.hello(Hello(phoneName: "A")))
        let two = try Framing.frame(.status(BridgeStatus(bridgeName: "B", claude: .ready)))
        var buffer = FrameBuffer()
        let all = one + two
        buffer.append(all.prefix(3))
        #expect(try buffer.next() == nil)
        buffer.append(all.dropFirst(3))
        let first = try #require(try buffer.next())
        let second = try #require(try buffer.next())
        #expect(try buffer.next() == nil)
        #expect(try DivJSON.decode(Message.self, from: first) == .hello(Hello(phoneName: "A")))
        #expect(try DivJSON.decode(Message.self, from: second) == .status(BridgeStatus(bridgeName: "B", claude: .ready)))
    }

    @Test func oversizedFramesAreRejected() {
        var buffer = FrameBuffer()
        buffer.append(Data([0xFF, 0xFF, 0xFF, 0xFF]))
        #expect(throws: Framing.Failure.self) { try buffer.next() }
    }
}

/// A real TLS connection over loopback, with the pre-shared keys from pairing codes.
@Suite(.serialized) struct ChannelTests {
    let phone = ChannelSecurity.Key(PairingCode(bridgeID: UUID(), bridgeName: "Mac"))
    let otherPhone = ChannelSecurity.Key(PairingCode(bridgeID: UUID(), bridgeName: "Mac"))

    /// Starts a listener that answers every hello with a status, and returns its port.
    func echoBridge(keys: [ChannelSecurity.Key]) async throws -> (NWListener, UInt16) {
        let listener = try NWListener(using: ChannelSecurity.parameters(keys: keys), on: .any)
        let (ports, port) = AsyncStream<UInt16>.makeStream()
        listener.stateUpdateHandler = { state in
            if case .ready = state, let value = listener.port?.rawValue { port.yield(value) }
        }
        listener.newConnectionHandler = { connection in
            let channel = Channel(connection)
            Task {
                do {
                    try await channel.start()
                    for try await message in channel.messages {
                        if case .hello(let hello) = message {
                            try await channel.send(.status(BridgeStatus(bridgeName: "Bridge for \(hello.phoneName)", claude: .ready)))
                        }
                    }
                } catch {}
            }
        }
        listener.start(queue: .global())
        var iterator = ports.makeAsyncIterator()
        return (listener, try #require(await iterator.next()))
    }

    func connect(port: UInt16, key: ChannelSecurity.Key) -> Channel {
        Channel(NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: ChannelSecurity.parameters(keys: [key])))
    }

    @Test func pairedPhonesConnectAndTalk() async throws {
        let (listener, port) = try await echoBridge(keys: [otherPhone, phone])
        defer { listener.cancel() }
        for key in [phone, otherPhone] {
            let channel = connect(port: port, key: key)
            try await channel.start()
            try await channel.send(.hello(Hello(phoneName: "iPhone")))
            var iterator = channel.messages.makeAsyncIterator()
            #expect(try await iterator.next() == .status(BridgeStatus(bridgeName: "Bridge for iPhone", claude: .ready)))
            channel.close()
        }
    }

    @Test func anUnpairedKeyIsRefused() async throws {
        let (listener, port) = try await echoBridge(keys: [phone])
        defer { listener.cancel() }
        let stranger = ChannelSecurity.Key(identity: phone.identity, secret: PairingCode.newKey())
        let channel = connect(port: port, key: stranger)
        await #expect(throws: Channel.Failure.self) { try await channel.start() }
    }
}

@MainActor @Suite(.serialized) struct BridgeConnectionTests {
    @Test func pairsConnectsAndForgets() async throws {
        let code = PairingCode(bridgeID: UUID(), bridgeName: "Mac", hosts: ["127.0.0.1"])
        let (listener, port) = try await ChannelTests().echoBridge(keys: [ChannelSecurity.Key(code)])
        defer { listener.cancel() }
        var reachable = code
        reachable.port = port

        let storage = MemoryPairingStorage()
        let connection = BridgeConnection(storage: storage, phoneName: "iPhone", retryDelays: [.milliseconds(50)])
        #expect(connection.state == .unpaired)
        #expect(throws: PairingCode.Failure.notAPairingCode) { try connection.pair(text: "nope") }

        try connection.pair(text: reachable.text)
        #expect(storage.load() == reachable)
        for _ in 0..<100 {
            if case .connected = connection.state { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(connection.state == .connected(BridgeStatus(bridgeName: "Bridge for iPhone", claude: .ready)))
        #expect(connection.isReady)

        connection.forget()
        #expect(connection.state == .unpaired)
        #expect(storage.load() == nil)
    }

    @Test func staysOfflineAndRetriesWhenTheMacIsAway() async throws {
        let code = PairingCode(bridgeID: UUID(), bridgeName: "Mac", hosts: ["127.0.0.1"], port: 9)
        let connection = BridgeConnection(storage: MemoryPairingStorage(code), phoneName: "iPhone", retryDelays: [.seconds(60)])
        connection.connect()
        for _ in 0..<100 {
            if case .offline = connection.state { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(connection.offlineReason != nil)
        await #expect(throws: BridgeLink.Failure.self) { try await connection.ask(.chat(ChatRequest(message: "hi"))) }
        connection.stop()
    }
}

@Suite struct PhotoPrepTests {
    /// A 3000 by 2000 PNG, like a big photo from the library.
    private func bigPNG() throws -> Data {
        let context = try #require(
            CGContext(
                data: nil, width: 3000, height: 2000, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        let image = try #require(context.makeImage())
        let out = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return out as Data
    }

    @Test func shrinksAnyPhotoToAJPEGClaudeReadsWhole() throws {
        let jpeg = try #require(PhotoPrep.jpeg(from: try bigPNG()))
        #expect(jpeg.prefix(2) == Data([0xFF, 0xD8]))
        let image = try #require(PhotoPrep.image(from: jpeg))
        #expect(max(image.width, image.height) == PhotoPrep.maxPixels)
        #expect(image.width > image.height)
    }

    @Test func refusesWhatIsntAnImage() {
        #expect(PhotoPrep.jpeg(from: Data("not a photo".utf8)) == nil)
    }
}
