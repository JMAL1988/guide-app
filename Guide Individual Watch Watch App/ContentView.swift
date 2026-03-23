import SwiftUI
import WatchConnectivity
import UserNotifications
import WatchKit
import Combine
import AVFoundation

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
            DispatchQueue.main.async { self.sessionStateLabel = "activating…" }
        } else {
            DispatchQueue.main.async { self.sessionStateLabel = "NOT SUPPORTED" }
        }
    }

    /// Returns the first enabled routine of the day (earliest scheduledHour/scheduledMinute)
    var firstRoutineOfDay: Routine? {
        routines
            .filter { $0.enabled }
            .min { ($0.scheduledHour * 60 + $0.scheduledMinute) < ($1.scheduledHour * 60 + $1.scheduledMinute) }
    }

    func requestFromPhone() {
        let session = WCSession.default
        guard session.activationState == .activated else { lastError = "session not activated"; return }
        guard session.isReachable else {
            lastError = "phone not reachable"
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

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            switch activationState {
            case .activated:    self.sessionStateLabel = "activated"
            case .inactive:     self.sessionStateLabel = "inactive"
            case .notActivated: self.sessionStateLabel = "NOT ACTIVATED"
            @unknown default:   self.sessionStateLabel = "unknown(\(activationState.rawValue))"
            }
            self.isReachable = session.isReachable
            self.contextKeys = session.receivedApplicationContext.keys.joined(separator: ",")
            if let err = error { self.lastError = err.localizedDescription }
        }
        guard activationState == .activated else { return }
        if let data = session.receivedApplicationContext["routines"] as? Data { apply(data) }
        if session.isReachable {
            session.sendMessage(["request": "routines"], replyHandler: { [weak self] reply in
                guard let data = reply["routines"] as? Data else { return }
                self?.apply(data)
            }, errorHandler: { _ in })
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["routines"] as? Data else { return }
        apply(data)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["routines"] as? Data else { return }
        apply(data)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["routines"] as? Data else { return }
        apply(data)
    }

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
        let data = sharedDefaults?.data(forKey: saveKey)
            ?? UserDefaults.standard.data(forKey: saveKey)
        guard let data, let decoded = try? JSONDecoder().decode([Routine].self, from: data) else { return }
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
            // Standard routine notification
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

        // Wake-up notification: 10 minutes before first routine of the day
        if let first = routines.filter({ $0.enabled })
            .min(by: { ($0.scheduledHour * 60 + $0.scheduledMinute) < ($1.scheduledHour * 60 + $1.scheduledMinute) }) {

            let totalMinutes = first.scheduledHour * 60 + first.scheduledMinute - 10
            if totalMinutes >= 0 {
                let wakeContent = UNMutableNotificationContent()
                wakeContent.title = "Wake Up"
                wakeContent.body = "\(first.name) starts in 10 minutes"
                wakeContent.sound = UNNotificationSound.defaultCritical
                var wakeComponents = DateComponents()
                wakeComponents.hour   = totalMinutes / 60
                wakeComponents.minute = totalMinutes % 60
                let wakeTrigger = UNCalendarNotificationTrigger(dateMatching: wakeComponents, repeats: true)
                UNUserNotificationCenter.current().add(
                    UNNotificationRequest(identifier: "wakeup-\(first.id.uuidString)", content: wakeContent, trigger: wakeTrigger)
                )
            }
        }
    }
}

// MARK: - Watch Content View

struct ContentView: View {
    @StateObject private var store = WatchRoutineStore()
    @State private var now = Date()
    private let clockTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var featuredRoutine: Routine? {
        let cal = Calendar.current
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let enabled = store.routines.filter { $0.enabled }
        if let active = enabled.first(where: {
            let s = $0.scheduledHour * 60 + $0.scheduledMinute
            return mins >= s && mins < s + 120
        }) { return active }
        return enabled
            .filter { $0.scheduledHour * 60 + $0.scheduledMinute > mins }
            .min { $0.scheduledHour * 60 + $0.scheduledMinute < $1.scheduledHour * 60 + $1.scheduledMinute }
    }

    private func timeLabel(for routine: Routine) -> String {
        let cal = Calendar.current
        let mins = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let s = routine.scheduledHour * 60 + routine.scheduledMinute
        if mins >= s && mins < s + 120 { return "Active now" }
        return String(format: "Next at %d:%02d", routine.scheduledHour, routine.scheduledMinute)
    }

    var body: some View {
        NavigationView {
            List {
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

                Section("All") {
                    if store.routines.isEmpty {
                        Text("Set up on iPhone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Ask iPhone") { store.requestFromPhone() }
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

// MARK: - Haptic Engine

/// Intense haptic pattern system:
/// - Every 1 second: single tap
/// - Every 10 seconds: double tap
/// - Every 30 seconds: burst of 5 taps
/// - Last 60 seconds: 3 bursts of 5 taps (at 60s, 30s, 10s remaining)
struct HapticEngine {
    static func playForTick(secondsElapsed: Int, timeRemaining: Int, totalDuration: Int) {
        let device = WKInterfaceDevice.current()
        let isLastMinute = timeRemaining <= 60

        if isLastMinute {
            // Last minute: 3 bursts of 5 at specific remaining-time marks
            if timeRemaining == 60 || timeRemaining == 30 || timeRemaining == 10 {
                playBurst(count: 5, device: device)
                return
            }
        }

        // Every 30 seconds: burst of 5 taps
        if secondsElapsed > 0 && secondsElapsed % 30 == 0 {
            playBurst(count: 5, device: device)
            return
        }

        // Every 10 seconds: double tap
        if secondsElapsed > 0 && secondsElapsed % 10 == 0 {
            device.play(.click)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                device.play(.click)
            }
            return
        }

        // Every second: single tap
        device.play(.click)
    }

    /// Burst of N taps with short intervals
    static func playBurst(count: Int, device: WKInterfaceDevice) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.12) {
                device.play(.directionUp)
            }
        }
    }

    /// Strong completion haptic
    static func playTaskComplete() {
        let device = WKInterfaceDevice.current()
        device.play(.success)
    }

    /// Routine start haptic
    static func playRoutineStart() {
        let device = WKInterfaceDevice.current()
        device.play(.start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            device.play(.start)
        }
    }

    /// Routine finished celebration
    static func playRoutineComplete() {
        let device = WKInterfaceDevice.current()
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.25) {
                device.play(.success)
            }
        }
    }
}

// MARK: - Routine Runner

class RoutineRunManager: ObservableObject {
    @Published var currentTaskIndex = 0
    @Published var timeRemaining = 0
    @Published var showingCompletion = false

    private var routine: Routine
    private var timer: Timer?
    private var extendedSession: WKExtendedRuntimeSession?
    private var tickCounter = 0

    init(routine: Routine) {
        self.routine = routine
    }

    var currentTask: Task? {
        guard currentTaskIndex < routine.tasks.count else { return nil }
        return routine.tasks[currentTaskIndex]
    }

    var taskCount: Int { routine.tasks.count }
    var isFinished: Bool { currentTaskIndex >= routine.tasks.count }
    var canGoBack: Bool { currentTaskIndex > 0 }

    var totalDurationForCurrentTask: Int {
        guard let task = currentTask else { return 0 }
        return task.durationMinutes * 60
    }

    func start() {
        startExtendedSession()
        HapticEngine.playRoutineStart()
        startTask()
    }

    func stop() {
        stopTimer()
        extendedSession?.invalidate()
        extendedSession = nil
    }

    func advance() {
        WKInterfaceDevice.current().play(.click)
        stopTimer()
        currentTaskIndex += 1
        if currentTaskIndex < routine.tasks.count {
            startTask()
        } else {
            // Routine finished — show completion screen
            showingCompletion = true
            HapticEngine.playRoutineComplete()
        }
    }

    func goBack() {
        guard canGoBack else { return }
        WKInterfaceDevice.current().play(.click)
        stopTimer()
        currentTaskIndex -= 1
        startTask()
    }

    private func startTask() {
        guard let task = currentTask else { return }
        stopTimer()
        tickCounter = 0
        timeRemaining = task.durationMinutes * 60

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.timeRemaining > 0 else { return }
                self.timeRemaining -= 1
                self.tickCounter += 1

                // Play haptic pattern
                HapticEngine.playForTick(
                    secondsElapsed: self.tickCounter,
                    timeRemaining: self.timeRemaining,
                    totalDuration: self.totalDurationForCurrentTask
                )

                // Warning haptic (extra strong at warning threshold)
                if let task = self.currentTask, self.timeRemaining == task.warningMinutes * 60 {
                    WKInterfaceDevice.current().play(.notification)
                }

                // Task done
                if self.timeRemaining == 0 {
                    HapticEngine.playTaskComplete()
                    self.advance()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startExtendedSession() {
        extendedSession?.invalidate()
        let session = WKExtendedRuntimeSession()
        extendedSession = session
        session.start()
    }
}

// MARK: - Logo Placeholder (animated)

struct AnimatedLogo: View {
    @State private var pulse = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .cyan, .blue]),
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            // Inner icon
            Image(systemName: "figure.run")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.blue)
                .scaleEffect(pulse ? 1.15 : 1.0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                        pulse = true
                    }
                }
        }
    }
}

/// Animated checkmark for routine completion
struct CompletionAnimation: View {
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0
    @State private var ringProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // Animated ring
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))

            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                ringProgress = 1.0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Progress Ring

struct TaskProgressRing: View {
    let progress: Double
    let isLastMinute: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isLastMinute ? Color.orange : Color.blue,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}

// MARK: - Routine Run View

struct RoutineRunView: View {
    let routine: Routine
    @StateObject private var manager: RoutineRunManager
    @Environment(\.dismiss) private var dismiss

    init(routine: Routine) {
        self.routine = routine
        _manager = StateObject(wrappedValue: RoutineRunManager(routine: routine))
    }

    private var progress: Double {
        guard manager.totalDurationForCurrentTask > 0 else { return 0 }
        return 1.0 - (Double(manager.timeRemaining) / Double(manager.totalDurationForCurrentTask))
    }

    var body: some View {
        VStack(spacing: 8) {
            if manager.showingCompletion {
                // Completion screen — tap anywhere to go back to main menu
                VStack(spacing: 12) {
                    CompletionAnimation()

                    Text("Done!")
                        .font(.headline)

                    Text("Tap to go back")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    manager.stop()
                    dismiss()
                }

            } else if let task = manager.currentTask {
                Text("\(manager.currentTaskIndex + 1) / \(manager.taskCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(task.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)

                ZStack {
                    TaskProgressRing(
                        progress: progress,
                        isLastMinute: manager.timeRemaining <= 60
                    )
                    .frame(width: 80, height: 80)

                    Text("\(manager.timeRemaining / 60):\(String(format: "%02d", manager.timeRemaining % 60))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(manager.timeRemaining <= 30 ? .orange : .primary)
                }

                HStack(spacing: 12) {
                    if manager.canGoBack {
                        Button(action: { manager.goBack() }) {
                            Image(systemName: "arrow.left")
                        }
                        .buttonStyle(.bordered)
                        .tint(.gray)
                    }

                    Button(action: { manager.advance() }) {
                        Label(
                            manager.currentTaskIndex < manager.taskCount - 1 ? "Next" : "Done",
                            systemImage: manager.currentTaskIndex < manager.taskCount - 1 ? "arrow.right" : "checkmark"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(manager.currentTaskIndex < manager.taskCount - 1 ? .blue : .green)
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { manager.start() }
        .onDisappear { manager.stop() }
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width > 50 {
                        manager.goBack()
                    } else if value.translation.width < -50 {
                        manager.advance()
                    }
                }
        )
    }
}

#Preview { ContentView() }
