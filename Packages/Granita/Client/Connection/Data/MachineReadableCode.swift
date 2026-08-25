import CorePairingDomain

/// What one machine-readable code the camera made out amounts to.
///
/// **A file of its own beside the session that produces them, and that is not tidiness.** A capture
/// session cannot be run anywhere a test runs, and this can; kept in there it would be measured as
/// part of something unrunnable and would stop being visible as the one decision the scanner takes.
///
/// It takes the text rather than the object carrying it, which is what makes that possible: an
/// `AVMetadataMachineReadableCodeObject` is only ever made by AVFoundation and a test cannot hand
/// one over. The browse next door reads an endpoint rather than a browse result for the same
/// reason.
enum MachineReadableCode {

    /// `stringValue` is optional on every machine-readable code there is, and one spotted at the
    /// edge of the frame — seen far enough to be reported, not far enough to be decoded — arrives
    /// with none. That is somebody else's code in the only sense that matters here, so it is passed
    /// over in the same silence: design §5 keeps even a foreign QR down to a line under the reticle,
    /// and this is less than that.
    static func scanned(_ stringValue: String?) -> ScannedCode {
        guard let stringValue else { return .somethingElse }
        return PairingLink.scanned(stringValue)
    }
}
