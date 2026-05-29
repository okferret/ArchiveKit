// AKReader+Extends.swift
// ArchiveKit - libarchive Swift 封装
//
// AKReader 现代化 API 扩展
// 提供 AsyncSequence、函数式、Result-based 等现代 Swift 风格接口

import Foundation

// MARK: - AKArchiveInfo（归档摘要信息）

/// 归档文件的摘要信息
///
/// - Note: `@unchecked Sendable` — `entries` 中的 `AKEntry` 实例均为克隆副本，
///   在归档关闭后不再被 libarchive 修改，调用方需确保不并发访问同一实例。
public struct AKArchiveInfo: @unchecked Sendable {
    /// 归档格式名称（如 "POSIX pax interchange format"）
    public let formatName: String?
    /// 归档格式枚举值
    public let format: AKFormat?
    /// 最外层过滤器
    public let filter: AKFilter?
    /// 过滤器名称（如 "gzip"）
    public let filterName: String?
    /// 条目总数
    public let entryCount: Int
    /// 所有条目路径列表
    public let paths: [String]
    /// 所有条目（含完整元数据，已克隆，可在归档关闭后使用）
    public let entries: [AKEntry]
    /// 归档是否包含加密条目
    public let isEncrypted: Bool
    /// 归档文件路径（从文件打开时有值）
    public let sourcePath: String?
    
    /// 普通文件条目数量
    public var regularFileCount: Int {
        entries.filter { $0.isRegularFile }.count
    }
    
    /// 目录条目数量
    public var directoryCount: Int {
        entries.filter { $0.isDirectory }.count
    }
    
    /// 符号链接条目数量
    public var symlinkCount: Int {
        entries.filter { $0.isSymbolicLink }.count
    }
    
    /// 所有普通文件的总大小（字节），未设置大小的条目不计入
    public var totalUncompressedSize: Int64 {
        entries.compactMap { $0.size }.reduce(0, +)
    }
}

// MARK: - AKEntrySequence（同步条目序列）

/// 同步条目序列，支持 `for entry in reader.entries()` 语法
///
/// 使用示例：
/// ```swift
/// let reader = AKReader()
/// try reader.open(path: archivePath)
/// for entry in reader.entries() {
///     print(entry.pathname ?? "")
///     // 若需要读取数据，在此处调用 reader.readCurrentEntryData()
///     // 未读取的数据会在进入下一次迭代时自动跳过
/// }
/// ```
///
/// - Note: 每次调用 `next()` 时，会先跳过上一个条目未读取的数据，再读取下一个条目头部。
///   这确保了即使用户不读取数据，遍历也能正确推进。
public struct AKEntrySequence: Sequence {
    
    public struct Iterator: IteratorProtocol {
        private let reader: AKReader
        private var finished = false
        private var lastError: (any Error)?
        /// 是否已读取过至少一个条目（用于判断是否需要跳过上一条目的数据）
        private var hasReadEntry = false
        
        internal init(reader: AKReader) {
            self.reader = reader
        }
        
        /// 读取下一个条目，遇到错误时停止并记录错误
        ///
        /// 在读取下一个条目头部之前，会自动跳过上一个条目未读取的数据。
        public mutating func next() -> AKEntry? {
            guard !finished else { return nil }
            do {
                // 跳过上一个条目未读取的数据（首次调用时无需跳过）
                if hasReadEntry {
                    try reader.skipCurrentEntry()
                }
                guard let entry = try reader.nextEntry() else {
                    finished = true
                    return nil
                }
                hasReadEntry = true
                return entry
            } catch {
                finished = true
                lastError = error
                return nil
            }
        }
        
        /// 迭代过程中发生的最后一个错误
        public var error: (any Error)? { lastError }
    }
    
    private let reader: AKReader
    
    internal init(reader: AKReader) {
        self.reader = reader
    }
    
    public func makeIterator() -> Iterator {
        Iterator(reader: reader)
    }
}

// MARK: - AKEntryAsyncSequence（异步条目序列）

/// 异步条目序列，支持 `for await entry in reader.asyncEntries()` 语法
///
/// 使用示例：
/// ```swift
/// let reader = AKReader()
/// try reader.open(path: archivePath)
/// for try await entry in reader.asyncEntries() {
///     print(entry.pathname ?? "")
/// }
/// ```
public struct AKEntryAsyncSequence: AsyncSequence {
    public typealias Element = AKEntry
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let reader: AKReader
        private var finished = false
        
        internal init(reader: AKReader) {
            self.reader = reader
        }
        
        public mutating func next() async throws -> AKEntry? {
            guard !finished else { return nil }
            // 允许在每次迭代前检查取消
            try Task.checkCancellation()
            guard let entry = try reader.nextEntry() else {
                finished = true
                return nil
            }
            return entry
        }
    }
    
    private let reader: AKReader
    
    internal init(reader: AKReader) {
        self.reader = reader
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(reader: reader)
    }
}

// MARK: - AKReader 现代化扩展

extension AKReader {
    
    // MARK: - 序列访问
    
    /// 返回同步条目序列（支持 for-in 遍历）
    ///
    /// - Note: 遍历时每个条目的数据需在进入下一次迭代前读取，否则将被自动跳过。
    ///   若需要在遍历后访问条目元数据，请使用 `entry.clone()` 克隆条目。
    ///
    /// - Returns: `AKEntrySequence`
    public func entries() -> AKEntrySequence {
        AKEntrySequence(reader: self)
    }
    
    /// 返回异步条目序列（支持 for-await-in 遍历，支持 Task 取消）
    ///
    /// - Returns: `AKEntryAsyncSequence`
    public func asyncEntries() -> AKEntryAsyncSequence {
        AKEntryAsyncSequence(reader: self)
    }
    
    // MARK: - 函数式 API
    
    /// 收集所有满足条件的条目路径
    ///
    /// - Parameter predicate: 过滤条件，返回 `true` 表示保留
    /// - Returns: 满足条件的路径列表
    /// - Throws: AKError
    public func compactMapPaths(where predicate: (AKEntry) -> Bool = { _ in true }) throws -> [String] {
        var result: [String] = []
        try enumerateEntries { entry in
            if predicate(entry), let path = entry.pathname {
                result.append(path)
            }
            return true
        }
        return result
    }
    
    /// 将所有条目映射为指定类型
    ///
    /// - Parameter transform: 转换闭包
    /// - Returns: 转换结果列表（transform 返回 nil 的条目被过滤掉）
    /// - Throws: AKError
    public func compactMap<T>(_ transform: (AKEntry) throws -> T?) throws -> [T] {
        var result: [T] = []
        try enumerateEntries { entry in
            if let value = try transform(entry) {
                result.append(value)
            }
            return true
        }
        return result
    }
    
    /// 查找第一个满足条件的条目（含克隆，可在归档关闭后使用）
    ///
    /// - Parameter predicate: 查找条件
    /// - Returns: 第一个满足条件的条目克隆，未找到返回 nil
    /// - Throws: AKError
    public func first(where predicate: (AKEntry) -> Bool) throws -> AKEntry? {
        var found: AKEntry?
        try enumerateEntries { entry in
            if predicate(entry) {
                found = entry.clone()
                return false // 停止遍历
            }
            return true
        }
        return found
    }
    
    /// 检查是否存在满足条件的条目
    ///
    /// - Parameter predicate: 检查条件
    /// - Returns: 存在返回 `true`，否则返回 `false`
    /// - Throws: AKError
    public func contains(where predicate: (AKEntry) -> Bool) throws -> Bool {
        var found = false
        try enumerateEntries { entry in
            if predicate(entry) {
                found = true
                return false
            }
            return true
        }
        return found
    }
    
    /// 统计满足条件的条目数量
    ///
    /// - Parameter predicate: 统计条件，默认统计全部
    /// - Returns: 满足条件的条目数量
    /// - Throws: AKError
    public func count(where predicate: (AKEntry) -> Bool = { _ in true }) throws -> Int {
        var n = 0
        try enumerateEntries { entry in
            if predicate(entry) { n += 1 }
            return true
        }
        return n
    }
    
    // MARK: - 批量数据提取
    
    /// 提取所有满足条件的文件数据
    ///
    /// - Parameter predicate: 过滤条件（仅对普通文件有效），默认提取全部普通文件
    /// - Returns: `[路径: 数据]` 字典
    /// - Throws: AKError
    public func extractAllData(
        where predicate: (AKEntry) -> Bool = { $0.isRegularFile }
    ) throws -> [String: Data] {
        var result: [String: Data] = [:]
        guard isArchiveOpen else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        while let entry = try nextEntry() {
            if predicate(entry), let path = entry.pathname {
                result[path] = try readCurrentEntryData()
            } else {
                try skipCurrentEntry()
            }
        }
        return result
    }
    
    /// 提取指定路径集合中的文件数据
    ///
    /// - Parameter paths: 要提取的条目路径集合
    /// - Returns: `[路径: 数据]` 字典（未找到的路径不包含在结果中）
    /// - Throws: AKError
    public func extractData(forPaths paths: Set<String>) throws -> [String: Data] {
        var result: [String: Data] = [:]
        var remaining = paths
        guard isArchiveOpen else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        while let entry = try nextEntry() {
            if let path = entry.pathname, remaining.contains(path) {
                result[path] = try readCurrentEntryData()
                remaining.remove(path)
                if remaining.isEmpty { break }
            } else {
                try skipCurrentEntry()
            }
        }
        return result
    }
    
    // MARK: - 归档信息摘要
    
    /// 获取归档的完整摘要信息
    ///
    /// 此方法会遍历归档中所有条目并克隆元数据，适合需要全面了解归档内容的场景。
    /// 对于大型归档，建议使用 `enumerateEntries` 流式处理。
    ///
    /// - Parameter path: 归档文件路径
    /// - Returns: `AKArchiveInfo` 归档摘要
    /// - Throws: AKError
    public static func info(at path: String) throws -> AKArchiveInfo {
        let reader = AKReader()
        try reader.open(path: path)
        defer { reader.close() }
        return try reader._buildInfo(sourcePath: path)
    }
    
    /// 获取归档的完整摘要信息（URL 版本）
    ///
    /// - Parameter url: 归档文件 URL（仅支持本地文件）
    /// - Returns: `AKArchiveInfo` 归档摘要
    /// - Throws: AKError
    public static func info(at url: URL) throws -> AKArchiveInfo {
        guard url.isFileURL else {
            throw AKError.invalidPath(url.absoluteString)
        }
        return try info(at: url.path)
    }
    
    /// 获取当前已打开归档的摘要信息
    ///
    /// - Returns: `AKArchiveInfo` 归档摘要
    /// - Throws: AKError
    public func archiveInfo() throws -> AKArchiveInfo {
        guard isArchiveOpen else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        return try _buildInfo(sourcePath: nil)
    }
    
    // MARK: - Result-based 非抛出 API
    
    /// 以 Result 形式打开归档文件（不抛出异常）
    ///
    /// - Parameters:
    ///   - path: 归档文件路径
    ///   - passphrases: 预设密码列表
    /// - Returns: `.success(())` 或 `.failure(AKError)`
    @discardableResult
    public func tryOpen(path: String, passphrases: [String] = []) -> Result<Void, AKError> {
        do {
            try open(path: path, passphrases: passphrases)
            return .success(())
        } catch let error as AKError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
    
    /// 以 Result 形式读取下一个条目（不抛出异常）
    ///
    /// - Returns: `.success(AKEntry?)` 或 `.failure(AKError)`
    public func tryNextEntry() -> Result<AKEntry?, AKError> {
        do {
            return .success(try nextEntry())
        } catch let error as AKError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
    
    /// 以 Result 形式读取当前条目数据（不抛出异常）
    ///
    /// - Returns: `.success(Data)` 或 `.failure(AKError)`
    public func tryReadCurrentEntryData() -> Result<Data, AKError> {
        do {
            return .success(try readCurrentEntryData())
        } catch let error as AKError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
    
    // MARK: - async/await 静态方法
    
    /// 异步列出归档中所有条目路径
    ///
    /// - Parameter path: 归档文件路径
    /// - Returns: 路径列表
    /// - Throws: AKError
    public static func listEntriesAsync(at path: String) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try AKReader.listEntries(at: path)
        }.value
    }
    
    /// 异步列出归档中所有条目路径（URL 版本）
    ///
    /// - Parameter url: 归档文件 URL
    /// - Returns: 路径列表
    /// - Throws: AKError
    public static func listEntriesAsync(at url: URL) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            try AKReader.listEntries(at: url)
        }.value
    }
    
    /// 异步提取指定路径的文件数据
    ///
    /// - Parameters:
    ///   - entryPath: 条目路径
    ///   - archivePath: 归档文件路径
    /// - Returns: 文件数据，未找到时返回 nil
    /// - Throws: AKError
    public static func extractDataAsync(
        for entryPath: String,
        from archivePath: String
    ) async throws -> Data? {
        try await Task.detached(priority: .userInitiated) {
            try AKReader.extractData(for: entryPath, from: archivePath)
        }.value
    }
    
    /// 异步解压归档到指定目录
    ///
    /// - Parameters:
    ///   - archivePath: 归档文件路径
    ///   - destinationURL: 目标目录 URL
    ///   - flags: 解压标志
    ///   - progress: 进度回调（在后台线程调用）
    /// - Throws: AKError
    public static func extractAllAsync(
        from archivePath: String,
        to destinationURL: URL,
        flags: AKExtractFlags = [.time, .permissions],
        progress: (@Sendable (AKEntry) -> Void)? = nil
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let reader = AKReader()
            try reader.open(path: archivePath)
            defer { reader.close() }
            try reader.extractAll(to: destinationURL, flags: flags, progress: progress)
        }.value
    }
    
    /// 异步获取归档摘要信息
    ///
    /// - Parameter path: 归档文件路径
    /// - Returns: `AKArchiveInfo` 归档摘要
    /// - Throws: AKError
    public static func infoAsync(at path: String) async throws -> AKArchiveInfo {
        try await Task.detached(priority: .userInitiated) {
            try AKReader.info(at: path)
        }.value
    }
    
    // MARK: - 订阅式进度回调（Closure-based streaming）
    
    /// 流式读取归档，每读取一个条目调用一次回调
    ///
    /// 与 `enumerateEntries` 的区别：此方法在回调中提供读取数据的能力，
    /// 回调返回后自动跳过未读取的数据。
    ///
    /// - Parameters:
    ///   - path: 归档文件路径
    ///   - passphrases: 密码列表
    ///   - handler: 条目处理回调
    ///     - entry: 当前条目
    ///     - reader: 当前读取器（可调用 `readCurrentEntryData()` 读取数据）
    ///     - Returns: `true` 继续，`false` 停止
    /// - Throws: AKError
    public static func stream(
        from path: String,
        passphrases: [String] = [],
        handler: (AKEntry, AKReader) throws -> Bool
    ) throws {
        let reader = AKReader()
        try reader.open(path: path, passphrases: passphrases)
        defer { reader.close() }
        while let entry = try reader.nextEntry() {
            let shouldContinue = try handler(entry, reader)
            try reader.skipCurrentEntry()
            if !shouldContinue { break }
        }
    }
    
    /// 流式读取归档（URL 版本）
    ///
    /// - Parameters:
    ///   - url: 归档文件 URL（仅支持本地文件）
    ///   - passphrases: 密码列表
    ///   - handler: 条目处理回调
    /// - Throws: AKError
    public static func stream(
        from url: URL,
        passphrases: [String] = [],
        handler: (AKEntry, AKReader) throws -> Bool
    ) throws {
        guard url.isFileURL else {
            throw AKError.invalidPath(url.absoluteString)
        }
        try stream(from: url.path, passphrases: passphrases, handler: handler)
    }
    
    // MARK: - 私有辅助
    
    /// 构建归档摘要信息（内部实现）
    ///
    /// - Note: libarchive 的 `archive_format()` 在读取第一个条目头部后才能确定格式，
    ///   因此格式/过滤器信息必须在遍历条目**之后**读取。
    private func _buildInfo(sourcePath: String?) throws -> AKArchiveInfo {
        var entries: [AKEntry] = []
        var paths: [String] = []
        var encrypted = false
        
        while let entry = try nextEntry() {
            if entry.isEncrypted { encrypted = true }
            if let path = entry.pathname { paths.append(path) }
            if let cloned = entry.clone() { entries.append(cloned) }
            try skipCurrentEntry()
        }
        
        // 遍历完成后读取格式/过滤器信息（libarchive 在读取第一个条目后才确定格式）
        let fmtName = formatName
        let fmt = format
        let flt = filter
        let fltName = filterName(at: 0)
        
        return AKArchiveInfo(
            formatName: fmtName,
            format: fmt,
            filter: flt,
            filterName: fltName,
            entryCount: entries.count,
            paths: paths,
            entries: entries,
            isEncrypted: encrypted,
            sourcePath: sourcePath
        )
    }
}
