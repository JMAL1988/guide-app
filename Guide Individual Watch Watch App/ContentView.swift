import SwiftUI
import WatchConnectivity
import UserNotifications
import Combine

// MARK: - Data Models (must match iOS)

struct Routine: Identifiable, Codable {
    let id: UUID
    var name: String
    var timeOfDay: TimeOfDay
    var tasks: [Task]
    var enabled: Bool
    var scheduledHour: Int
    var scheduledMinute: Int

    init(id: UUID = UUID(), name: String, timeOfDay: TimeOfDay, tasks: [Task] = [],
         enabled: Bool = true, scheduledHour: Int? = nil, scheduledMinute: Int = 0) {
        self.id = id
        self.name = name
        self.timeOfDay = timeOfDay
        self.tasks = tasks
        self.enabled = enabled
        self.scheduledMinute = scheduledMinute
        switch timeOfDay {
        case .morning: self.scheduledHour = scheduledHour ?? 7
        case .midday:  self.scheduledHour = scheduledHour ?? 12
        case .evening: self.scheduledHour = scheduledHour ?? 18
        case .night:   self.scheduledHour = scheduledHour ?? 21
        }
    }

    // Backward-compatible decode: old saves lack scheduledHour/scheduledMinute
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,       forKey: .id)
        name      = try c.decode(String.self,     forKey: .name)
        timeOfDay = try c.decode(TimeOfDay.self,  forKey: .timeOfDay)
        tasks     = try c.decode([Task].self,     forKey: .tasks)
        enabled   = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        scheduledMinute = try c.decodeIfPresent(Int.self, forKey: .scheduledMinute) ?? 0
        let defaultHour: Int
        switch timeOfDay {
        case .morning: defaultHour = 7
        case .midday:  defaultHour = 12
        case .evening: defaultHour = 18
        case .night:   defaultHour = 21
        }
        scheduledHour = try c.decodeIfPresent(Int.self, forKey: .scheduledHour) ?? defaultHour
    }

    enum TimeOfDay: String, Codable, CaseIterable {
        case morning = "Morning"
        case midday  = "Midday"
        case evening = "Evening"
        case night   = "Night"
    }
}

struct Task: Identifiable, Codable {
    let id: UUID
    var name: String
    var durationMinutes: Int
    var warningMinutes: Int

    init(id: UUID = UUID(), name: String, durationMinutes: Int = 5, warningMinutes: Int = 1) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.warningMinutes = warningMinutes
    }
}

// MARK: - Watch Store + Session Delegate (unified)

class WatchRoutineStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var routines: [Routine] = []
    @Published var sessionStateLabel: String = "not started"
    @Published var contextKeys: String = "—"
    @Published var isReachable: Bool = false
    @Published var lastError: String = "—"

    private let saveKey = "SavedRoutines"
    private let sharedDefaults = UserDefaults(suiteName: "group.com.joostlaarakker.guide")

    override init() {
        super.init()
        loadFromDisk()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            DispatchQueue.main.async {
                self.sessionStateLabel = "activating…"
            }
        } else {
            DispatchQueue.main.async {
                self.sessionStateLabel = "NOT SUPPORTED"
            }
        }
    }

    func requestFromPhone() {
        let session = WCSession.default
        guard session.activationState == .activated else {
            lastError = "session not activated"
            return
        }
        guard session.isReachable else {
            lastError = "phone not reachable"
            // Try transferUserInfo as fallback
            session.transferUserInfo(["request": "routines"])
            return
        }
        session.sendMessage(["request": "routines"], replyHandler: { [weak self] reply in
            guard let data = reply["routines"] as? Data else {
                DispatchQueue.main.async { self?.lastError = "no data in reply" }
                return
            }
            self?.apply(data)
        }, errorHandler: { [weak self] err in
            DispatchQueue.main.async { self?.lastError = err.localizedDescription }
        })
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:   self.sessionStateLabel = "activated ✓"
            case .inactive:    self.sessionStateLabel = "inactive"
            case .notActivated: self.sessionStateLabel = "NOT ACTIVATED"
            @unknown default:  self.sessionStateLabel = "unknown(\(activationState.rawValue))"
            }
            self.isReachable = session.isReachable
            self.contextKeys = session.receivedApplicationContext.keys.joined(separator: ",")
            if let err = error { self.lastError = err.localizedDescription }
        }

        guard activationState == .activated else { return }

        // Read system-cached context first — no live connection needed
        if let data = session.receivedApplicationContext["routines"] as? Data {
            apply(data)
        }

        // Also request fresh data from iPhone if it's reachable
        if session.isReachable {
            session.sendMessage(["request": "routines"], replyHandler: { [weak self] reply in
                guard let data = reply["routines"] as? Data else { return }
                self?.apply(data)
            }, errorHandler: { _ in })
        }
    }

    // iPhone updated applicationContext while Watch app is running
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["routines"] as? Data else { return }
        apply(data)
    }

    // iPhone pushed via sendMessage (Watch is open and reachable)
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["routines"] as? Data else { return }
        apply(data)
    }

    // iPhone pushed via transferUserInfo (queued background delivery)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["routines"] as? Data else { return }
        apply(data)
    }

    // MARK: Private

    private func apply(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode([Routine].self, from: data) else {
            DispatchQueue.main.async { self.lastError = "decode failed" }
            return
        }
        DispatchQueue.main.async {
            self.routines = decoded
            self.saveToDisk(decoded)
            self.scheduleNotifications(for: decoded)
        }
    }

    private func loadFromDisk() {
        // Try shared App Group first — written by iPhone app
        let data = sharedDefaults?.data(forKey: saveKey)
            ?? UserDefaults.standard.data(forKey: saveKey)
        guard let data,
              let decoded = try? JSONDecoder().decode([Routine].self, from: data) else { return }
        routines = decoded
    }

    private func saveToDisk(_ routines: [Routine]) {
        if let encoded = try? JSONEncoder().encode(routines) {
            sharedDefaults?.set(encoded, forKey: saveKey)
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func scheduleNotifications(for routines: [Routine]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for routine in routines where routine.enabled {
            let content = UNMutableNotificationContent()
            content.title = routine.name
            content.body = "Time for your \(routine.timeOfDay.rawValue.lowercased()) routine"
            content.sound = .default
            var components = DateComponents()
            components.hour   = routine.scheduledHour
            components.minute = routine.scheduledMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: routine.id.uuidString, content: content, trigger: trigger)
            )
        }
    }
}

// MARK: - Watch Content View (Now + All)

struct ContentView: View {
    @StateObject private var store = WatchRoutineStore()
    @State private var now = Date()
    private let clockTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var featuredRoutine: Routine? {
        let cal = Calendar.current
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let enabled = store.routines.filter { $0.enabled }

        // Active: within 2-hour window after scheduled time
        if let active = enabled.first(where: {
            let s = $0.scheduledHour * 60 + $0.scheduledMinute
            return mins >= s && mins < s + 120
        }) { return active }

        // Next: soonest upcoming today
        return enabled
            .filter { $0.scheduledHour * 60 + $0.scheduledMinute > mins }
            .min { $0.scheduledHour * 60 + $0.scheduledMinute < $1.scheduledHour * 60 + $1.scheduledMinute }
    }

    private func timeLabel(for routine: Routine) -> String {
        let cal = Calendar.current
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let s = routine.scheduledHour * 60 + routine.scheduledMinute
        if mins >= s && mins < s + 120 { return "Active now" }
        return String(format: "Next · %d:%02d", routine.scheduledHour, routine.scheduledMinute)
    }

    var body: some View {
        NavigationView {
            List {
                // NOW card — current or next routine
                if let featured = featuredRoutine {
                    Section {
                        NavigationLink(destination: RoutineRunView(routine: featured)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(timeLabel(for: featured))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .textCase(.uppercase)
                                Text(featured.name)
                                    .font(.headline)
                                Text("\(featured.tasks.count) tasks · \(featured.tasks.reduce(0) { $0 + $1.durationMinutes }) min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Full list
                Section("All") {
                    if store.routines.isEmpty {
                        Text("Set up on iPhone")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // Debug info (reactive — updates when store publishes)
                        Group {
                            Text("Session: \(store.sessionStateLabel)")
                            Text("Ctx: \(store.contextKeys.isEmpty ? "empty" : store.contextKeys)")
                            Text("Reachable: \(store.isReachable ? "yes" : "no")")
                            Text("Err: \(store.lastError)")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.orange)

                        Button("Ask iPhone") {
                            store.requestFromPhone()
                        }
                        .font(.caption2)
                    } else {
                        ForEach(store.routines.filter { $0.enabled }) { routine in
                            NavigationLink(destination: RoutineRunView(routine: routine)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name).font(.caption)
                                    Text(String(format: "%d:%02d", routine.scheduledHour, routine.scheduledMinute))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Guide")
            .onReceive(clockTick) { now = $0 }
        }
    }
}

// MARK: - Routine Runner

struct RoutineRunView: View {
    let routine: Routine
    @State private var currentTaskIndex = 0
    @State private var timeRemaining = 0
    @State private var timer: Timer?

    var currentTask: Task? {
        guard currentTaskIndex < routine.tasks.count else { return nil }
        return routine.tasks[currentTaskIndex]
    }

    var body: some View {
        VStack(spacing: 8) {
            if let task = currentTask {
                // Progress indicator
                Text("\(currentTaskIndex + 1) / \(routine.tasks.count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Task name
                Text(task.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                // Countdown
                Text("\(timeRemaining / 60):\(String(format: "%02d", timeRemaining % 60))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(timeRemaining <= 30 ? .orange : .primary)

                // Next button — always visible, one tap to advance
                Button(action: advance) {
                    Label(
                        currentTaskIndex < routine.tasks.count - 1 ? "Next" : "Done",
                        systemImage: currentTaskIndex < routine.tasks.count - 1 ? "arrow.right" : "checkmark"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(currentTaskIndex < routine.tasks.count - 1 ? .blue : .green)

            } else {
                // All tasks complete
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
                    Text("Routine\ncomplete")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startTask() }
        .onDisappear { stopTimer() }
    }

    private func startTask() {
        guard let task = currentTask else { return }
        stopTimer()
        timeRemaining = task.durationMinutes * 60
        WKInterfaceDevice.current().play(.start)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                guard timeRemaining > 0 else { return }
                timeRemaining -= 1
                if timeRemaining == task.warningMinutes * 60 {
                    WKInterfaceDevice.current().play(.notification)
                }
                if timeRemaining == 0 {
                    WKInterfaceDevice.current().play(.success)
                    advance()
                }
            }
        }
    }

    private func advance() {
        WKInterfaceDevice.current().play(.click)
        stopTimer()
        currentTaskIndex += 1
        if currentTaskIndex < routine.tasks.count { startTask() }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview { ContentView() }
