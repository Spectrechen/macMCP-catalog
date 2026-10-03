// Validates catalog.json for CI (no macMCP checkout needed; Foundation only).
// The macMCP binary enforces the same rules again when it loads a catalog
// (MacMCPCore/Catalog/Catalog.swift); keep both in sync.
//   swift scripts/validate.swift catalog.json
import Foundation

var errors: [String] = []
func fail(_ s: String) { errors.append(s) }
func matches(_ s: String, _ pattern: String) -> Bool { s.range(of: pattern, options: .regularExpression) != nil }

let path = CommandLine.arguments.dropFirst().first ?? "catalog.json"
guard let data = FileManager.default.contents(atPath: path),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    print("error: \(path) is not a JSON object"); exit(1)
}

let reservedHeaders: Set<String> = ["authorization", "host", "cookie", "proxy-authorization", "content-length"]
let methods: Set<String> = ["GET", "POST", "PUT", "PATCH", "DELETE"]
let statuses: Set<String> = ["supported", "experimental", "planned"]
let authTypes: Set<String> = ["bearer", "basic", "header", "oauth2ClientCredentials"]

func checkPath(_ p: String, _ ctx: String) {
    if !p.hasPrefix("/") || p.hasPrefix("//") || p.contains("://") || p.contains("..") || p.contains("?") || p.contains("#") || p.contains("\\") {
        fail("\(ctx): path '\(p)' must be relative to the base URL")
    }
}

func placeholders(_ v: Any?) -> Set<String> {
    switch v {
    case let s as String:
        let re = try! NSRegularExpression(pattern: #"\{([A-Za-z_][A-Za-z0-9_]*)\}"#)
        return Set(re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range(at: 1), in: s)!]) })
    case let a as [Any]: return a.reduce(into: Set<String>()) { $0.formUnion(placeholders($1)) }
    case let d as [String: Any]: return d.values.reduce(into: Set<String>()) { $0.formUnion(placeholders($1)) }
    default: return []
    }
}

if root["schemaVersion"] as? Int != 1 { fail("schemaVersion must be 1") }
if let v = root["catalogVersion"] as? String, !matches(v, #"^\d{4}\.\d{2}\.\d{2}\.\d+$"#) { fail("catalogVersion must be YYYY.MM.DD.N") }

var connectorIDs = Set<String>()
for c in root["connectors"] as? [[String: Any]] ?? [] {
    let id = c["id"] as? String ?? "?"
    if !matches(id, #"^[a-z0-9][a-z0-9-]{0,31}$"#) { fail("connector id '\(id)' invalid") }
    if !connectorIDs.insert(id).inserted { fail("duplicate connector \(id)") }
    for key in ["displayName", "vendor", "lastReviewed"] where (c[key] as? String ?? "").isEmpty { fail("\(id): \(key) missing") }
    if !statuses.contains(c["status"] as? String ?? "") { fail("\(id): status must be supported/experimental/planned") }
    if (c["documentation"] as? [String] ?? []).isEmpty { fail("\(id): documentation links required") }

    let auth = c["auth"] as? [[String: Any]] ?? []
    if auth.isEmpty { fail("\(id): needs at least one auth method") }
    for a in auth {
        let type = a["type"] as? String ?? ""
        if !authTypes.contains(type) { fail("\(id): auth type '\(type)' unknown") }
        if a["perUser"] as? Bool == nil { fail("\(id)/\(a["id"] ?? "?"): perUser must be set") }
        if type == "oauth2ClientCredentials" { checkPath(a["tokenPath"] as? String ?? "", "\(id)/tokenPath") }
        if type == "header", reservedHeaders.contains((a["headerName"] as? String ?? "").lowercased()) { fail("\(id): reserved headerName") }
    }
    if let check = c["connectionCheck"] as? [String: Any] { checkPath(check["path"] as? String ?? "", "\(id)/connectionCheck") }

    var toolNames = Set<String>()
    for t in c["tools"] as? [[String: Any]] ?? [] {
        let name = t["name"] as? String ?? "?"
        let ctx = "\(id)/\(name)"
        if !matches(name, #"^[a-z][a-z0-9_]{0,39}$"#) { fail("\(ctx): tool name must be snake_case ≤ 40") }
        if !toolNames.insert(name).inserted { fail("\(ctx): duplicate") }
        if (t["description"] as? String ?? "").isEmpty { fail("\(ctx): description missing") }
        guard let readOnly = t["readOnly"] as? Bool else { fail("\(ctx): readOnly must be set"); continue }
        let schema = t["inputSchema"] as? [String: Any] ?? [:]
        if schema["type"] as? String != "object" { fail("\(ctx): inputSchema.type must be object") }
        let request = t["request"] as? [String: Any] ?? [:]
        let method = request["method"] as? String ?? ""
        if !methods.contains(method) { fail("\(ctx): method '\(method)'") }
        if readOnly && method != "GET" { fail("\(ctx): readOnly tools must use GET (macMCP treats every other method as a write)") }
        checkPath(request["path"] as? String ?? "", ctx)
        for h in (request["headers"] as? [String: Any] ?? [:]).keys where reservedHeaders.contains(h.lowercased()) { fail("\(ctx): header \(h) is reserved") }
        let declared = Set((schema["properties"] as? [String: Any] ?? [:]).keys)
        let used = placeholders(request["path"]).union(placeholders(request["query"])).union(placeholders(request["headers"])).union(placeholders(request["body"]))
        let unknown = used.subtracting(declared)
        if !unknown.isEmpty { fail("\(ctx): undeclared placeholders \(unknown.sorted())") }
        for r in schema["required"] as? [String] ?? [] where !declared.contains(r) { fail("\(ctx): required '\(r)' not a property") }
    }
}

var clientIDs = Set<String>()
for client in root["clients"] as? [[String: Any]] ?? [] {
    let id = client["id"] as? String ?? "?"
    if !clientIDs.insert(id).inserted { fail("duplicate client \(id)") }
    if !["stdio", "http"].contains(client["transport"] as? String ?? "") { fail("client \(id): transport must be stdio or http") }
    if client["entry"] as? [String: Any] == nil { fail("client \(id): entry must be an object") }
}

if errors.isEmpty {
    print("OK: \(connectorIDs.count) connectors, \(clientIDs.count) clients")
} else {
    errors.forEach { print("error: \($0)") }
    exit(1)
}
