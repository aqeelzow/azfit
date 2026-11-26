import AZModel
import Foundation

/// Food search and barcode lookup in Open Food Facts, a free, open food database. Only the search words or the
/// barcode leave the phone, nothing about the person.
public struct FoodDatabase: Sendable {
    public enum Problem: Error, Equatable {
        case offline
        /// Open Food Facts limits how often one phone may ask. It clears within a minute.
        case busy
        case server(Int)
    }

    /// A search match: enough for a row. Its full nutrition comes from `product(barcode:)` when it's picked.
    public struct Hit: Sendable, Hashable, Identifiable {
        public var code: String
        public var name: String
        public var brand: String?
        public var kcalPer100g: Double?
        public var serving: String?

        public var id: String { code }

        public init(code: String, name: String, brand: String? = nil, kcalPer100g: Double? = nil, serving: String? = nil) {
            self.code = code
            self.name = name
            self.brand = brand
            self.kcalPer100g = kcalPer100g
            self.serving = serving
        }
    }

    /// English-speaking markets, searched first so names and serving sizes read the way the person shops.
    static let markets = ["en:canada", "en:united-states", "en:united-kingdom", "en:australia", "en:ireland", "en:new-zealand"]

    private let session: URLSession
    private let cache = ProductCache()
    private let base = URL(string: "https://world.openfoodfacts.org")!
    private let searchBase = URL(string: "https://search.openfoodfacts.org")!
    private static let fields =
        "code,lang,product_name,product_name_en,generic_name,generic_name_en,brands,serving_size,serving_quantity,nutriments"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Foods matching the words, with English names, from English-speaking markets first. One request: the
    /// rows' calories come from the search itself, and a food's full label is read only when it's picked.
    public func search(_ query: String, limit: Int = 25) async throws -> [Hit] {
        let words = query.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
        guard !words.isEmpty else { return [] }
        let markets = Self.markets.map { "\"\($0)\"" }.joined(separator: " OR ")
        let local = Self.hits(fromSearch: try await get(searchURL("\(words) countries:(\(markets))", limit: limit)))
        guard local.count < 5 else { return local }
        // Few sold nearby: the rest of the world, still English names only.
        let seen = Set(local.map(\.code))
        let world = Self.hits(fromSearch: try await get(searchURL(words, limit: limit)))
        return local + world.filter { !seen.contains($0.code) }
    }

    private func searchURL(_ q: String, limit: Int) -> URL {
        var url = searchBase.appending(path: "search")
        url.append(queryItems: [
            .init(name: "q", value: q), .init(name: "langs", value: "en"), .init(name: "page_size", value: "\(limit)"),
            .init(name: "fields", value: "code,lang,product_name,product_name_en,brands,serving_size,nutriscore_data"),
        ])
        return url
    }

    /// The product with this barcode, or nil when the database doesn't have it (or has no calories for it).
    public func product(barcode: String) async throws -> Food? {
        if let cached = await cache.foods[barcode] { return cached }
        var url = base.appending(path: "api/v2/product/\(barcode).json")
        url.append(queryItems: [.init(name: "fields", value: Self.fields)])
        let food = Self.food(fromProduct: try await get(url))
        await cache.keep(food, for: barcode)
        return food
    }

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        // Open Food Facts asks apps to name themselves.
        request.setValue("AZfit/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Problem.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        // A barcode the database doesn't know comes back as 404 with a JSON body.
        if status == 429 { throw Problem.busy }
        guard status < 500 else { throw Problem.server(status) }
        return data
    }

    // MARK: Parsing

    /// The search's matches that have an English name, in order.
    static func hits(fromSearch data: Data) -> [Hit] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let hits = json["hits"] as? [[String: Any]]
        else { return [] }
        return hits.compactMap { h in
            guard let code = h["code"] as? String, !code.isEmpty, code.allSatisfy(\.isNumber), let name = englishName(h) else {
                return nil
            }
            // Nutri-Score keeps energy per 100 g in kJ.
            let components = ((h["nutriscore_data"] as? [String: Any])?["components"] as? [String: Any])?["negative"] as? [[String: Any]]
            let kJ = components?.first { $0["id"] as? String == "energy" }.flatMap { number($0["value"]) }
            let serving = (h["serving_size"] as? String)?.trimmingCharacters(in: .whitespaces)
            return Hit(
                code: code, name: name, brand: brand(h["brands"]), kcalPer100g: kJ.map { ($0 / 4.184).rounded() },
                serving: serving?.isEmpty == false ? serving : nil)
        }
    }

    /// The product's English name: its own name when it was entered in English, else its English translation.
    /// Nil when it has neither, so a search never shows a name the person can't read.
    static func englishName(_ p: [String: Any]) -> String? {
        func text(_ key: String) -> String? {
            (p[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        let english = (p["lang"] as? String).map { $0 == "en" } ?? true
        return text("product_name_en") ?? (english ? text("product_name") : nil) ?? text("generic_name_en")
            ?? (english ? text("generic_name") : nil)
    }

    /// "Fage, Other" from the product API, ["xx:Chobani"] from search.
    static func brand(_ any: Any?) -> String? {
        let brands = any as? [String] ?? (any as? String).map { $0.split(separator: ",").map(String.init) } ?? []
        return brands.first.map { b in
            let b = b.trimmingCharacters(in: .whitespaces)
            let name = b.count > 3 && b.dropFirst(2).hasPrefix(":") ? String(b.dropFirst(3)) : b
            // Some are entered all lowercase ("chobani").
            return name == name.lowercased() ? name.capitalized : name
        }
    }

    static func food(fromProduct data: Data) -> Food? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let product = json["product"] as? [String: Any]
        else { return nil }
        return food(product)
    }

    /// One product, when it has a name and calories per 100 g or per serving.
    static func food(_ p: [String: Any]) -> Food? {
        let name = englishName(p) ?? (p["product_name"] as? String)?.trimmingCharacters(in: .whitespaces).nilIfEmpty
        guard let name, let code = p["code"] as? String ?? (p["code"] as? NSNumber)?.stringValue else { return nil }
        let n = p["nutriments"] as? [String: Any] ?? [:]
        func value(_ key: String) -> Double? { number(n[key]) }
        func nutrients(_ suffix: String) -> Nutrients? {
            let kcal = value("energy-kcal_\(suffix)") ?? value("energy_\(suffix)").map { $0 / 4.184 }
            guard let kcal, kcal >= 0 else { return nil }
            var micros: [String: Double] = [:]
            for micro in Micronutrient.allCases {
                if let grams = value("\(micro.foodFactsKey)_\(suffix)"), grams >= 0 { micros[micro.rawValue] = grams * micro.perGram }
            }
            return Nutrients(
                kcal: kcal, proteinG: value("proteins_\(suffix)") ?? 0, carbsG: value("carbohydrates_\(suffix)") ?? 0,
                fatG: value("fat_\(suffix)") ?? 0, micros: micros)
        }
        let per100g = nutrients("100g")
        let label = (p["serving_size"] as? String)?.trimmingCharacters(in: .whitespaces)
        let grams = number(p["serving_quantity"]).flatMap { $0 > 0 ? $0 : nil }
        var serving: Food.Serving?
        if let label, !label.isEmpty {
            serving = .init(label: label, grams: grams, nutrients: per100g == nil || grams == nil ? nutrients("serving") : nil)
            if serving?.grams == nil && serving?.nutrients == nil { serving = nil }
        }
        guard per100g != nil || serving?.nutrients != nil else { return nil }
        let brand = brand(p["brands"])
        return Food(
            id: "off:\(code)", name: name, brand: brand, barcode: code, per100g: per100g,
            // A serving label that just repeats the grams adds nothing: grams are always offered.
            serving: serving.flatMap { s in s.label.filter { $0 != " " }.lowercased() == "\(Food.trim(s.grams ?? -1))g" ? nil : s },
            origin: .database)
    }

    private static func number(_ any: Any?) -> Double? {
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}

/// Products already read this session, so going back and forth costs no requests (the database limits them).
private actor ProductCache {
    var foods: [String: Food?] = [:]
    func keep(_ food: Food?, for code: String) { foods[code] = food }
}

extension String {
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
