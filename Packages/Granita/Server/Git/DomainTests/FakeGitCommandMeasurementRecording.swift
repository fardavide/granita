import ServerGitDomain

actor FakeGitCommandMeasurementRecording {
    private(set) var measurements: [GitCommandMeasurement]

    init(measurements: [GitCommandMeasurement] = []) {
        self.measurements = measurements
    }

    func record(_ measurement: GitCommandMeasurement) {
        measurements.append(measurement)
    }
}
