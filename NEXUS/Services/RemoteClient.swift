import CoreMotion
import Foundation
import Network

@MainActor
final class RemoteClient: ObservableObject {
    @Published var isMotionActive = false
    @Published var status = "未连接"

    private let motion = CMMotionManager()
    private var udpConnection: NWConnection?

    func test(host: String, token: String) async {
        do {
            try await sendAction(host: host, token: token, action: "ping", value: nil)
            status = "电脑在线"
        } catch {
            status = "连接失败"
        }
    }

    func sendAction(host: String, token: String, action: String, value: String?) async throws {
        guard let url = URL(string: "http://\(host):8766/action") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RemoteAction(token: token, action: action, value: value))
        let (_, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw URLError(.cannotConnectToHost)
        }
    }

    func startMotion(host: String, token: String) {
        guard !host.isEmpty, !token.isEmpty, motion.isDeviceMotionAvailable else {
            status = "请先填写电脑地址和配对码"
            return
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: 8767, using: .udp)
        connection.start(queue: .global(qos: .userInteractive))
        udpConnection = connection
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let self, let sample else { return }
            let payload: [String: Any] = [
                "token": token,
                "dx": sample.rotationRate.y * 10,
                "dy": sample.rotationRate.x * 10
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
            connection.send(content: data, completion: .contentProcessed { _ in })
        }
        isMotionActive = true
        status = "体感遥控运行中"
    }

    func stopMotion() {
        motion.stopDeviceMotionUpdates()
        udpConnection?.cancel()
        udpConnection = nil
        isMotionActive = false
        status = "已停止"
    }

    func sendPointerDelta(host: String, token: String, dx: Double, dy: Double) {
        let connection = udpConnection ?? NWConnection(host: NWEndpoint.Host(host), port: 8767, using: .udp)
        if udpConnection == nil {
            connection.start(queue: .global(qos: .userInteractive))
            udpConnection = connection
        }
        let payload: [String: Any] = ["token": token, "dx": dx, "dy": dy]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }
}
