import Foundation
import Network

// ---------------------------------------------------------------------------
// Servidor de controle
//   GET  /idle|working|done|attention[?session=id&project=nome]
//   GET  /quit                          (requer token)
//   GET  /answer/<...>                  (requer token)
//   POST /ask {title, detail, urgent, options?, input?}
//        segura a conexão (long-poll) até a escolha do usuário
//
// Token: endpoints que DECIDEM algo (answer/quit) exigem ?token= ou o header
// X-Craby-Token, para que nenhum processo local injete decisões às cegas.
// ---------------------------------------------------------------------------

struct AskPayload: Codable {
    let title: String
    let detail: String
    let urgent: Bool
    // modo pergunta: rótulos das opções; modo texto: input=true;
    // nenhum dos dois = modo permissão (Permitir/Negar/Terminal)
    let options: [String]?
    let input: Bool?
    // modo permissão: regra de allowlist sugerida (ex. "Bash(git *)") —
    // habilita o botão "Sempre permitir"; quem grava a regra é o ask.sh
    var rule: String? = nil
}

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data
}

final class ControlServer {
    let listener: NWListener
    let authToken: String
    // (comando, query) -> corpo da resposta (nil = "ok")
    let onCommand: (String, [String: String]) -> String?
    let onAsk: (AskPayload, NWConnection) -> Void

    init(port: UInt16,
         authToken: String,
         onCommand: @escaping (String, [String: String]) -> String?,
         onAsk: @escaping (AskPayload, NWConnection) -> Void) throws {
        self.authToken = authToken
        self.onCommand = onCommand
        self.onAsk = onAsk
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            self?.receiveRequest(conn, buffer: Data())
        }
        listener.start(queue: .main)
    }

    private func receiveRequest(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16384) {
            [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = Self.parse(buffer) {
                self.route(request, conn: conn)
            } else if !isComplete && error == nil {
                self.receiveRequest(conn, buffer: buffer) // corpo ainda não chegou inteiro
            } else {
                conn.cancel()
            }
        }
    }

    private func route(_ request: HTTPRequest, conn: NWConnection) {
        if request.method == "POST" && request.path == "/ask" {
            if let payload = try? JSONDecoder().decode(AskPayload.self, from: request.body) {
                onAsk(payload, conn) // conexão fica aberta; respond() é chamado depois
            } else {
                Self.respond(conn, body: "ask")
            }
            return
        }
        let command = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // endpoints com poder de decisão exigem o token
        if command == "quit" || command.hasPrefix("answer/") {
            let provided = request.query["token"] ?? request.headers["x-craby-token"] ?? ""
            guard provided == authToken else {
                Self.respond(conn, body: "forbidden", status: "403 Forbidden")
                return
            }
        }

        let reply = onCommand(command.removingPercentEncoding ?? command, request.query)
        Self.respond(conn, body: reply ?? "ok")
    }

    static func respond(_ conn: NWConnection, body: String, status: String = "200 OK") {
        let data = body.data(using: .utf8)!
        let response = "HTTP/1.1 \(status)\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
        conn.send(content: response.data(using: .utf8)! + data,
                  completion: .contentProcessed { _ in conn.cancel() })
    }

    static func parse(_ buffer: Data) -> HTTPRequest? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: buffer[buffer.startIndex..<headerEnd.lowerBound],
                                encoding: .utf8)
        else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines[0].split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var contentLength = 0
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = kv[0].lowercased()
            let value = kv[1].trimmingCharacters(in: .whitespaces)
            headers[key] = value
            if key == "content-length" { contentLength = Int(value) ?? 0 }
        }
        let bodyAvailable = buffer.distance(from: headerEnd.upperBound, to: buffer.endIndex)
        guard bodyAvailable >= contentLength else { return nil }
        let body = buffer.subdata(
            in: headerEnd.upperBound..<buffer.index(headerEnd.upperBound, offsetBy: contentLength))

        // separa caminho e query string (valores com percent-encoding)
        let rawPath = String(parts[1])
        let pathParts = rawPath.split(separator: "?", maxSplits: 1)
        var query: [String: String] = [:]
        if pathParts.count == 2 {
            for pair in pathParts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let value = String(kv[1])
                    query[String(kv[0])] = value.removingPercentEncoding ?? value
                }
            }
        }
        return HTTPRequest(
            method: String(parts[0]),
            path: String(pathParts[0]),
            query: query,
            headers: headers,
            body: body)
    }
}
