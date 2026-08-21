/// The highlighter's language, guessed from the file's extension.
///
/// A hint and nothing more: the client passes it to a highlighter that will fall back on its own if
/// it does not recognise the name, and nothing in the product's behaviour depends on it being
/// right. Absent rather than guessed when the extension says nothing, because a wrong language
/// colours a file worse than no language does.
public enum LanguageHint {

    public static func forPath(_ path: String) -> String? {
        guard let dot = path.lastIndex(of: "."), dot != path.startIndex else { return nil }
        let fileExtension = path[path.index(after: dot)...].lowercased()
        // The separator check keeps `src/v1.2/README` from claiming an extension of `2/readme`.
        guard fileExtension.contains("/") == false else { return nil }
        return byExtension[fileExtension]
    }

    private static let byExtension: [String: String] = [
        "swift": "swift",
        "kt": "kotlin", "kts": "kotlin",
        "java": "java",
        "m": "objectivec", "mm": "objectivec", "h": "objectivec",
        "c": "c", "cc": "cpp", "cpp": "cpp", "hpp": "cpp",
        "js": "javascript", "jsx": "javascript", "mjs": "javascript",
        "ts": "typescript", "tsx": "typescript",
        "py": "python",
        "rb": "ruby",
        "go": "go",
        "rs": "rust",
        "php": "php",
        "cs": "csharp",
        "scala": "scala",
        "dart": "dart",
        "sh": "bash", "bash": "bash", "zsh": "bash",
        "sql": "sql",
        "json": "json",
        "yml": "yaml", "yaml": "yaml",
        "toml": "ini", "ini": "ini",
        "xml": "xml", "plist": "xml", "html": "xml", "storyboard": "xml", "xib": "xml",
        "css": "css", "scss": "scss",
        "md": "markdown", "markdown": "markdown",
        "gradle": "gradle",
        "txt": "plaintext"
    ]
}
