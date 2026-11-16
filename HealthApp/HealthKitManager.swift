import Foundation
import HealthKit
import Combine

final class HealthKitManager: ObservableObject {
    @Published var isSyncing = false
    @Published var status: String = "尚未同步"
    @Published var lastSync: Date?

    private let healthStore = HKHealthStore()
    private let collectQueue = DispatchQueue(label: "health.records.collect")

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .appleExerciseTime,
            .heartRate,
            .bodyMass,
            .bodyFatPercentage,
            .bloodPressureSystolic,
            .bloodPressureDiastolic
        ]
        for id in quantityIDs {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        return types
    }

    func sync(into store: Store) {
        guard !isSyncing else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "这台设备不支持健康数据"
            return
        }

        isSyncing = true
        status = "正在请求健康权限…"

        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.isSyncing = false
                    self.status = "授权失败：" + error.localizedDescription
                }
                return
            }
            DispatchQueue.main.async {
                self.status = "正在读取最近 30 天数据…"
            }
            self.fetchAll(into: store)
        }
    }

    private func fetchAll(into store: Store) {
        let cal = Calendar.current
        let end = Date()
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -29, to: end) ?? end)

        let group = DispatchGroup()
        var collected: [Record] = []

        func append(_ records: [Record]) {
            collectQueue.sync { collected.append(contentsOf: records) }
        }

        group.enter()
        dailySums(.stepCount, unit: .count(), metric: .steps, start: start, end: end) {
            append($0); group.leave()
        }

        group.enter()
        dailySums(.appleExerciseTime, unit: .minute(), metric: .exercise, start: start, end: end) {
            append($0); group.leave()
        }

        group.enter()
        dailyAverages(.heartRate, unit: HKUnit.count().unitDivided(by: HKUnit.minute()), metric: .hr, start: start, end: end) {
            append($0); group.leave()
        }

        group.enter()
        fetchBodyComposition(start: start, end: end) {
            append($0); group.leave()
        }

        group.enter()
        fetchBloodPressure(start: start, end: end) {
            append($0); group.leave()
        }

        group.enter()
        fetchSleep(start: start, end: end) {
            append($0); group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            let inserted = store.insertIfMissing(collected)
            self.isSyncing = false
            self.lastSync = Date()
            self.status = inserted > 0 ? "已导入 \(inserted) 条记录" : "没有新的可导入数据"
        }
    }

    // MARK: - 每日累计（步数、运动分钟）

    private func dailySums(_ id: HKQuantityTypeIdentifier,
                           unit: HKUnit,
                           metric: MetricType,
                           start: Date,
                           end: Date,
                           completion: @escaping ([Record]) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else {
            completion([])
            return
        }
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .cumulativeSum,
            anchorDate: Calendar.current.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, results, _ in
            var output: [Record] = []
            results?.enumerateStatistics(from: start, to: end) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    let value = sum.doubleValue(for: unit)
                    if value > 0 {
                        output.append(Record(type: metric,
                                             day: statistics.startDate,
                                             createdAt: statistics.endDate,
                                             v1: value,
                                             note: "Apple 健康"))
                    }
                }
            }
            completion(output)
        }
        healthStore.execute(query)
    }

    // MARK: - 每日平均（心率）

    private func dailyAverages(_ id: HKQuantityTypeIdentifier,
                               unit: HKUnit,
                               metric: MetricType,
                               start: Date,
                               end: Date,
                               completion: @escaping ([Record]) -> Void) {
        dailyAverageMap(id, unit: unit, start: start, end: end) { map in
            let records = map.map { day, value in
                Record(type: metric, day: day, createdAt: day, v1: value, note: "Apple 健康")
            }
            completion(records)
        }
    }

    private func dailyAverageMap(_ id: HKQuantityTypeIdentifier,
                                 unit: HKUnit,
                                 start: Date,
                                 end: Date,
                                 completion: @escaping ([Date: Double]) -> Void) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else {
            completion([:])
            return
        }
        let cal = Calendar.current
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: .discreteAverage,
            anchorDate: cal.startOfDay(for: start),
            intervalComponents: DateComponents(day: 1)
        )
        query.initialResultsHandler = { _, results, _ in
            var map: [Date: Double] = [:]
            results?.enumerateStatistics(from: start, to: end) { statistics, _ in
                if let average = statistics.averageQuantity() {
                    map[cal.startOfDay(for: statistics.startDate)] = average.doubleValue(for: unit)
                }
            }
            completion(map)
        }
        healthStore.execute(query)
    }

    // MARK: - 体重 + 体脂

    private func fetchBodyComposition(start: Date, end: Date, completion: @escaping ([Record]) -> Void) {
        let group = DispatchGroup()
        var massByDay: [Date: Double] = [:]
        var fatByDay: [Date: Double] = [:]
        let cal = Calendar.current

        group.enter()
        dailyAverageMap(.bodyMass, unit: HKUnit.gramUnit(with: .kilo), start: start, end: end) {
            massByDay = $0
            group.leave()
        }

        group.enter()
        dailyAverageMap(.bodyFatPercentage, unit: HKUnit.percent(), start: start, end: end) {
            fatByDay = $0
            group.leave()
        }

        group.notify(queue: .global()) {
            var output: [Record] = []
            let days = Set(massByDay.keys).union(fatByDay.keys)
            for day in days {
                let mass = massByDay[day]
                let fat = fatByDay[day].map { $0 * 100 }
                guard mass != nil || fat != nil else { continue }
                let createdAt = cal.date(byAdding: .hour, value: 12, to: day) ?? day
                output.append(Record(type: .weight,
                                     day: day,
                                     createdAt: createdAt,
                                     v1: mass,
                                     v2: fat,
                                     note: "Apple 健康"))
            }
            completion(output)
        }
    }

    // MARK: - 血压

    private func fetchBloodPressure(start: Date, end: Date, completion: @escaping ([Record]) -> Void) {
        let group = DispatchGroup()
        var systolic: [Date: Double] = [:]
        var diastolic: [Date: Double] = [:]

        group.enter()
        dailyAverageMap(.bloodPressureSystolic, unit: HKUnit.millimeterOfMercury(), start: start, end: end) {
            systolic = $0
            group.leave()
        }

        group.enter()
        dailyAverageMap(.bloodPressureDiastolic, unit: HKUnit.millimeterOfMercury(), start: start, end: end) {
            diastolic = $0
            group.leave()
        }

        group.notify(queue: .global()) {
            var output: [Record] = []
            for (day, upper) in systolic {
                guard let lower = diastolic[day] else { continue }
                output.append(Record(type: .bp,
                                     day: day,
                                     createdAt: day,
                                     v1: upper,
                                     v2: lower,
                                     note: "Apple 健康"))
            }
            completion(output)
        }
    }

    // MARK: - 睡眠

    private func fetchSleep(start: Date, end: Date, completion: @escaping ([Record]) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let query = HKSampleQuery(sampleType: sleepType,
                                  predicate: predicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: sort) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                completion([])
                return
            }
            let cal = Calendar.current
            var hoursByDay: [Date: Double] = [:]
            for sample in samples {
                guard sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                    || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue else {
                    continue
                }
                let day = cal.startOfDay(for: sample.endDate)
                let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
                hoursByDay[day, default: 0] += hours
            }
            var output: [Record] = []
            for (day, hours) in hoursByDay where hours > 0.25 {
                output.append(Record(type: .sleep,
                                     day: day,
                                     createdAt: day,
                                     v1: (hours * 10).rounded() / 10,
                                     note: "Apple 健康"))
            }
            completion(output)
        }
        healthStore.execute(query)
    }
}
