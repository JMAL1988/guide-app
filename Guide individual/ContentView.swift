import UserNotifications
import SwiftUI
import WatchConnectivity
import Combine

// MARK: - Data Models

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
        id       = try c.decode(UUID.self,      forKey: .id)
        name     = try c.decode(String.self,    forKey: .name)
        timeOfDay = try c.decode(TimeOfDay.self, forKey: .timeOfDay)
        tasks    = try c.decode([Task].self,    forKey: .tasks)
        enabled  = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
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

struct Task: Identifiable, Codable, Equatable {
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

// MARK: - Store

class RoutineStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var routines: [Routine] = []
    @Published var wcStatus: String = "…"
    private let saveKey = "SavedRoutines"
    private let sharedDefaults = UserDefaults(suiteName: "group.com.joostlaarakker.guide")

    override init() {
        super.init()
        load()

        // Request notification permissions for wake-up alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .criticalAlert]) { _, _ in }

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        if routines.isEmpty {
            routines = [
                Routine(
                    name: "Morning Routine", timeOfDay: .morning,
                    tasks: [
                        Task(name: "Wake up & get out of bed", durationMinutes: 2),
                        Task(name: "Shower",      durationMinutes: 10),
                        Task(name: "Get dressed", durationMinutes: 5),
                        Task(name: "Breakfast",   durationMinutes: 15),
                        Task(name: "Prep to leave", durationMinutes: 5)
                    ]
                ),
                Routine(
                    name: "Work Start", timeOfDay: .midday,
                    tasks: [
                        Task(name: "Review calendar",   durationMinutes: 3),
                        Task(name: "Prioritize tasks",  durationMinutes: 5),
                        Task(name: "Start first task",  durationMinutes: 25)
                    ]
                ),
                Routine(
                    name: "Evening Wind Down", timeOfDay: .evening,
                    tasks: [
                        Task(name: "Prepare tomorrow's clothes", durationMinutes: 5),
                        Task(name: "Pack bag",         durationMinutes: 5),
                        Task(name: "Review tomorrow",  durationMinutes: 5),
                        Task(name: "Bedtime routine",  durationMinutes: 15)
                    ]
                )
            ]
            save()
        }
    }

    func updateRoutine(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        }
    }

    func save() {
        if let encoded = try? JSONEncoder().encode(routines) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
            sharedDefaults?.set(encoded, forKey: saveKey)
            syncToWatch()
            scheduleWakeUpNotification()
        }
    }

    /// Schedule a wake-up notification 10 minutes before the first routine of the day
    private func scheduleWakeUpNotification() {
        // Remove any existing wake-up notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["guide-wakeup"])

        guard let first = routines.filter({ $0.enabled })
            .min(by: { ($0.scheduledHour * 60 + $0.scheduledMinute) < ($1.scheduledHour * 60 + $1.scheduledMinute) }) else { return }

        let totalMinutes = first.scheduledHour * 60 + first.scheduledMinute - 10
        guard totalMinutes >= 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Wake Up"
        content.body = "\(first.name) starts in 10 minutes"
        content.sound = UNNotificationSound.defaultCritical

        var components = DateComponents()
        components.hour   = totalMinutes / 60
        components.minute = totalMinutes % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "guide-wakeup", content: content, trigger: trigger)
        )
    }

    func load() {
        // Try shared group first, fall back to standard
        let data = sharedDefaults?.data(forKey: saveKey)
            ?? UserDefaults.standard.data(forKey: saveKey)
        guard let data,
              let decoded = try? JSONDecoder().decode([Routine].self, from: data) else { return }
        routines = decoded
    }

    func syncToWatch() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let encoded = try? JSONEncoder().encode(routines) else { return }
        let payload: [String: Any] = ["routines": encoded]

        // updateApplicationContext: system-cached, Watch reads it even without a live connection
        try? session.updateApplicationContext(payload)

        // transferUserInfo: queued, delivered when Watch app next opens
        session.transferUserInfo(payload)

        // sendMessage: immediate push if Watch is open right now
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    // MARK: WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            let s = WCSession.default
            self.wcStatus = "state:\(activationState.rawValue) paired:\(s.isPaired ? "✓" : "✗") installed:\(s.isWatchAppInstalled ? "✓" : "✗") reachable:\(s.isReachable ? "✓" : "✗")"
        }
        if activationState == .activated { syncToWatch() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    // Watch requesting routines directly
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        let encoded = try? JSONEncoder().encode(routines)
        DispatchQueue.main.async {
            self.wcStatus = "got msg from watch! routines:\(self.routines.count)"
        }
        guard let data = encoded else { replyHandler([:]); return }
        replyHandler(["routines": data])
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var store = RoutineStore()
    @State private var showingAddRoutine = false

    var body: some View {
        NavigationView {
            List {
                ForEach(Routine.TimeOfDay.allCases, id: \.self) { timeOfDay in
                    Section(header: Text(timeOfDay.rawValue.uppercased())) {
                        ForEach(store.routines.filter { $0.timeOfDay == timeOfDay }) { routine in
                            NavigationLink(destination: RoutineDetailView(routine: routine, store: store)) {
                                RoutineRow(routine: routine)
                            }
                        }
                        .onDelete { indexSet in
                            let filtered = store.routines.filter { $0.timeOfDay == timeOfDay }
                            let ids = indexSet.map { filtered[$0].id }
                            store.routines.removeAll { ids.contains($0.id) }
                            store.save()
                        }
                    }
                }
            }
            .navigationTitle("ROUTINES")
            .safeAreaInset(edge: .bottom) {
                Text(store.wcStatus)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(4)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.7))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { store.syncToWatch() }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRoutine = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoutine) {
                AddRoutineView(store: store)
            }
        }
    }
}

// MARK: - Routine Row

struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name).font(.headline)
            HStack {
                Label("\(routine.tasks.count)", systemImage: "list.bullet")
                Label("\(routine.tasks.reduce(0) { $0 + $1.durationMinutes }) min", systemImage: "clock")
                Spacer()
                Text(String(format: "%d:%02d", routine.scheduledHour, routine.scheduledMinute))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Routine Detail View

struct RoutineDetailView: View {
    let routine: Routine
    @ObservedObject var store: RoutineStore
    @State private var name: String
    @State private var timeOfDay: Routine.TimeOfDay
    @State private var scheduledDate: Date
    @State private var tasks: [Task]
    @State private var showingAddTask = false

    init(routine: Routine, store: RoutineStore) {
        self.routine = routine
        self.store = store
        _name      = State(initialValue: routine.name)
        _timeOfDay = State(initialValue: routine.timeOfDay)
        _tasks     = State(initialValue: routine.tasks)
        var comps  = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = routine.scheduledHour
        comps.minute = routine.scheduledMinute
        _scheduledDate = State(initialValue: Calendar.current.date(from: comps) ?? Date())
    }

    private func persist() {
        let cal = Calendar.current
        var updated         = routine
        updated.name        = name
        updated.timeOfDay   = timeOfDay
        updated.scheduledHour   = cal.component(.hour,   from: scheduledDate)
        updated.scheduledMinute = cal.component(.minute, from: scheduledDate)
        updated.tasks       = tasks
        store.updateRoutine(updated)
        store.save()
    }

    var body: some View {
        List {
            Section("Routine") {
                TextField("Name", text: $name)
                    .onChange(of: name) { _ in persist() }
                Picker("Category", selection: $timeOfDay) {
                    ForEach(Routine.TimeOfDay.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .onChange(of: timeOfDay) { _ in persist() }
                DatePicker("Notification time",
                           selection: $scheduledDate,
                           displayedComponents: .hourAndMinute)
                    .onChange(of: scheduledDate) { _ in persist() }
            }

            Section("Tasks") {
                ForEach(tasks) { task in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.name).font(.headline)
                        Text("\(task.durationMinutes) min · warn \(task.warningMinutes) min before")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { tasks.remove(atOffsets: $0); persist() }
                .onMove   { tasks.move(fromOffsets: $0, toOffset: $1); persist() }

                Button(action: { showingAddTask = true }) {
                    Label("Add Task", systemImage: "plus")
                }
            }
        }
        .navigationTitle(name.isEmpty ? "Routine" : name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { EditButton() }
        .onChange(of: tasks) { _ in persist() }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(tasks: $tasks)
        }
    }
}

// MARK: - Add Routine View

struct AddRoutineView: View {
    @ObservedObject var store: RoutineStore
    @Environment(\.presentationMode) var presentationMode
    @State private var routineName = ""
    @State private var selectedTimeOfDay: Routine.TimeOfDay = .morning
    @State private var tasks: [Task] = []
    @State private var showingAddTask = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Routine Details")) {
                    TextField("Routine Name", text: $routineName)
                    Picker("Time of Day", selection: $selectedTimeOfDay) {
                        ForEach(Routine.TimeOfDay.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }
                Section(header: Text("Tasks")) {
                    ForEach(tasks) { task in
                        VStack(alignment: .leading) {
                            Text(task.name)
                            Text("\(task.durationMinutes) min").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .onDelete { tasks.remove(atOffsets: $0) }
                    .onMove  { tasks.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add Task") { showingAddTask = true }
                }
            }
            .navigationTitle("New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.routines.append(Routine(name: routineName, timeOfDay: selectedTimeOfDay, tasks: tasks))
                        store.save()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(routineName.isEmpty || tasks.isEmpty)
                }
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(tasks: $tasks)
            }
        }
    }
}

// MARK: - Add Task Sheet

struct AddTaskView: View {
    @Binding var tasks: [Task]
    @Environment(\.presentationMode) var presentationMode
    @State private var taskName = ""
    @State private var duration = 5
    @State private var warning = 1

    var body: some View {
        NavigationView {
            Form {
                TextField("Task Name", text: $taskName)
                Stepper("Duration: \(duration) min", value: $duration, in: 1...120)
                Stepper("Warning: \(warning) min before", value: $warning, in: 0...30)
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        tasks.append(Task(name: taskName, durationMinutes: duration, warningMinutes: warning))
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(taskName.isEmpty)
                }
            }
        }
    }
}

class WatchSessionDelegate: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSessionDelegate()
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

#Preview { ContentView() }
