public protocol CaptureSourceValidating: Sendable {
    func metadata(for source: CaptureSource) throws -> CaptureSourceMetadata
}

public struct DefaultRecordingConfigurationResolver: RecordingConfigurationResolving {
    private let sourceValidator: any CaptureSourceValidating

    public init(sourceValidator: any CaptureSourceValidating) {
        self.sourceValidator = sourceValidator
    }

    public func resolve(
        source: CaptureSource,
        settings: RecordingSettings
    ) throws -> ResolvedRecordingConfiguration {
        let metadata = try sourceValidator.metadata(for: source)
        return try ConfigurationResolver.resolve(
            source: source,
            metadata: metadata,
            settings: settings
        )
    }
}
