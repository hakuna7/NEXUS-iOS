import Foundation
import Network

final class LoopbackServer {
    private let queue = DispatchQueue(label: "nexus.loopback.server")
    private var listener: NWListener?
    var onText: ((String) -> Void)?

    func start() {
        guard listener == nil else { return }
        do {
            let listener = try NWListener(using: .tcp, on: 8765)
            listener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            listener.stateUpdateHandler = { state in
                if case let .failed(error) = state {
                    print("Loopback listener failed: \(error)")
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            print("Unable to start loopback listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, isComplete, error in
            var next = buffer
            if let data { next.append(data) }

            if let body = self?.httpBodyIfComplete(next),
               let payload = try? JSONDecoder().decode(OCRPayload.self, from: body),
               !payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self?.onText?(payload.text)
                self?.respondOK(connection)
                return
            }

            if isComplete || error != nil {
                connection.cancel()
            } else {
                self?.receive(on: connection, buffer: next)
            }
        }
    }

    private func httpBodyIfComplete(_ data: Data) -> Data? {
        guard let marker = "\r\n\r\n".data(using: .utf8),
              let range = data.range(of: marker) else { return nil }
        let headerData = data[..<range.lowerBound]
        let headers = String(decoding: headerData, as: UTF8.self)
        let contentLength = headers
            .split(separator: "\n")
            .first { $0.lowercased().contains("content-length:") }
            .flatMap { Int($0.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") } ?? 0
        let bodyStart = range.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }
        return data.subdata(in: bodyStart..<(bodyStart + contentLength))
    }

    private func respondOK(_ connection: NWConnection) {
        let response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
