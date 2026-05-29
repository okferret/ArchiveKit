// AKReader.swift
// ArchiveKit - libarchive Swift 封装
//
// 归档读取器

import Foundation
internal import libarchive

/// 归档读取器，用于读取和解压归档文件
public final class AKReader {
    
    // MARK: - 内部属性
    
    private var archive: OpaquePointer?
    private var isOpen: Bool = false
    /// 持有内存归档的 Data，防止 libarchive 持有指针期间被 ARC 释放（悬垂指针防护）
    private var memoryData: Data?
    
    // MARK: - 公开属性
    
    /// 当前归档格式
    public var format: AKFormat? {
        guard let archive else { return nil }
        let code = libarchive.archive_format(archive)
        return AKFormat(rawValue: code)
    }
    
    /// 当前归档格式名称
    public var formatName: String? {
        guard let archive else { return nil }
        guard let cStr = libarchive.archive_format_name(archive) else { return nil }
        return String(cString: cStr)
    }
    
    /// 过滤器数量
    public var filterCount: Int {
        guard let archive else { return 0 }
        return Int(libarchive.archive_filter_count(archive))
    }
    
    /// 已处理的文件数量
    public var fileCount: Int {
        guard let archive else { return 0 }
        return Int(libarchive.archive_file_count(archive))
    }
    
    /// 最后一次错误信息
    public var lastError: String? {
        guard let archive else { return nil }
        guard let cStr = libarchive.archive_error_string(archive) else { return nil }
        return String(cString: cStr)
    }
    
    /// 最后一次错误码
    public var lastErrorCode: Int32 {
        guard let archive else { return 0 }
        return libarchive.archive_errno(archive)
    }
    
    /// 已处理的总字节数（经过所有过滤器处理后的输出字节数，即解压后的原始数据量）
    ///
    /// - Note: `archive_filter_bytes(archive, -1)` 返回所有过滤器链的总输出字节数。
    ///   对于压缩归档，这是解压后的数据量；对于未压缩归档，等于磁盘读取量。
    public var bytesRead: Int64 {
        guard let archive else { return 0 }
        return libarchive.archive_filter_bytes(archive, -1)
    }
    
    /// 实际从磁盘/内存读取的压缩字节数（第一个过滤器的输入字节数）
    ///
    /// - Note: `archive_filter_bytes(archive, 0)` 返回索引 0 过滤器的输入字节数，
    ///   即从数据源（文件/内存）实际读取的原始压缩字节数。
    public var compressedBytesRead: Int64 {
        guard let archive else { return 0 }
        return libarchive.archive_filter_bytes(archive, 0)
    }
    
    /// 归档是否已打开
    public var isArchiveOpen: Bool { isOpen }
    
    // MARK: - 初始化
    
    public init() {}
    
    deinit {
        close()
    }
    
    // MARK: - 打开归档
    
    /// 打开文件路径的归档（自动检测格式和过滤器）
    /// - Parameters:
    ///   - path: 归档文件路径
    ///   - blockSize: 读取块大小，默认 10240 字节
    ///   - passphrases: 预设密码列表（在打开前注册，用于加密归档），默认为空
    /// - Throws: AKError
    public func open(path: String, blockSize: Int = 10240, passphrases: [String] = []) throws {
        try prepareArchive()
        // 密码必须在 archive_read_open 之前注册
        for passphrase in passphrases {
            libarchive.archive_read_add_passphrase(archive, passphrase)
        }
        let result = libarchive.archive_read_open_filename(archive, path, blockSize)
        if result != AKError.ARCHIVE_OK {
            let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
            libarchive.archive_read_free(archive)
            archive = nil
            throw AKError.cannotOpenFile(errStr ?? path)
        }
        isOpen = true
    }
    
    /// 打开 URL 指向的归档文件（仅支持本地文件 URL）
    /// - Parameters:
    ///   - url: 本地文件 URL
    ///   - blockSize: 读取块大小，默认 10240 字节
    ///   - passphrases: 预设密码列表（在打开前注册，用于加密归档），默认为空
    /// - Throws: AKError
    public func open(url: URL, blockSize: Int = 10240, passphrases: [String] = []) throws {
        guard url.isFileURL else {
            throw AKError.invalidPath(url.absoluteString)
        }
        try open(path: url.path, blockSize: blockSize, passphrases: passphrases)
    }
    
    /// 从内存数据打开归档
    /// - Parameter data: 归档数据
    /// - Throws: AKError
    public func open(data: Data) throws {
        try prepareArchive()
        // 将 data 存储为成员变量，确保在归档关闭前 Data 不会被 ARC 释放。
        // libarchive 的 archive_read_open_memory 不会拷贝数据，仅持有指针，
        // 若 Data 提前释放则产生悬垂指针。
        memoryData = data
        let result = data.withUnsafeBytes { bytes in
            libarchive.archive_read_open_memory(archive, bytes.baseAddress, bytes.count)
        }
        if result != AKError.ARCHIVE_OK {
            let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
            libarchive.archive_read_free(archive)
            archive = nil
            memoryData = nil
            throw AKError.cannotOpenFile(errStr ?? "无法从内存打开归档")
        }
        isOpen = true
    }
    
    // MARK: - 密码支持
    
    /// 添加解密密码（用于加密归档，如加密 ZIP）
    ///
    /// - Important: libarchive 限制：`archive_read_add_passphrase` 只能在归档处于
    ///   `new` 状态时调用，即必须在 `open(path:...)` / `open(data:)` **之前**调用。
    ///   在 open 之后调用会触发 `ARCHIVE_FAILED` 错误（INTERNAL ERROR: wrong state）。
    ///   推荐做法：通过 `open(path:passphrases:)` 的 `passphrases` 参数在打开时传入密码。
    ///
    /// - Parameter passphrase: 密码字符串
    /// - Throws: `AKError.failed` — 若在 open 之后调用（libarchive 状态机限制）
    public func addPassphrase(_ passphrase: String) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未初始化")
        }
        let result = libarchive.archive_read_add_passphrase(archive, passphrase)
        try checkResult(result)
    }
    
    // MARK: - 格式支持检测
    
    /// 检测文件路径是否支持解压（libarchive 能否识别该归档格式）
    ///
    /// 通过尝试打开归档并读取第一个条目头部来判断文件是否为受支持的归档格式。
    /// 此方法不会解压任何数据，仅做格式探测。
    ///
    /// - Parameter path: 文件路径
    /// - Returns: `true` 表示文件受支持可解压，`false` 表示格式不受支持
    public static func isSupported(at path: String) -> Bool {
        let reader = AKReader()
        do {
            try reader.open(path: path)
            defer { reader.close() }
            // 尝试读取第一个条目头部，成功则说明格式受支持
            _ = try reader.nextEntry()
            return true
        } catch {
            return false
        }
    }
    
    /// 检测 URL 指向的文件是否支持解压（仅支持本地文件 URL）
    ///
    /// 通过尝试打开归档并读取第一个条目头部来判断文件是否为受支持的归档格式。
    /// 此方法不会解压任何数据，仅做格式探测。
    ///
    /// - Parameter url: 本地文件 URL
    /// - Returns: `true` 表示文件受支持可解压，`false` 表示格式不受支持或非本地文件 URL
    public static func isSupported(at url: URL) -> Bool {
        guard url.isFileURL else { return false }
        return isSupported(at: url.path)
    }
    
    // MARK: - 加密检测
    
    /// 检测归档文件是否有密码保护（静态方法，不影响已打开的归档）
    ///
    /// 通过打开归档并遍历条目头部，检查是否存在加密条目。
    /// 此方法仅读取条目元数据，不解压任何数据。
    ///
    /// - Parameter path: 归档文件路径
    /// - Returns: `true` 表示归档包含加密条目，`false` 表示未加密
    /// - Throws: AKError（无法打开文件等错误）
    public static func isEncrypted(at path: String) throws -> Bool {
        let reader = AKReader()
        try reader.open(path: path)
        defer { reader.close() }
        return try reader._detectEncryption()
    }
    
    /// 检测归档文件是否有密码保护（URL 版本）
    ///
    /// - Parameter url: 归档文件 URL（仅支持本地文件）
    /// - Returns: `true` 表示归档包含加密条目，`false` 表示未加密
    /// - Throws: AKError
    public static func isEncrypted(at url: URL) throws -> Bool {
        guard url.isFileURL else {
            throw AKError.invalidPath(url.absoluteString)
        }
        return try isEncrypted(at: url.path)
    }
    
    /// 检测当前已打开的归档是否包含加密条目
    ///
    /// - Returns: `true` 表示归档包含加密条目，`false` 表示未加密
    /// - Throws: AKError
    public func detectEncryption() throws -> Bool {
        guard isOpen else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        return try _detectEncryption()
    }
    
    /// 验证密码是否正确（静态方法）
    ///
    /// 通过尝试用给定密码解压第一个加密条目的数据来验证密码正确性。
    /// 若归档未加密，则直接返回 `true`。
    ///
    /// - Parameters:
    ///   - passphrase: 待验证的密码
    ///   - path: 归档文件路径
    /// - Returns: `true` 表示密码正确（或归档未加密），`false` 表示密码错误
    /// - Throws: AKError（无法打开文件等错误，密码错误时返回 `false` 而非抛出）
    public static func verifyPassphrase(_ passphrase: String, for path: String) throws -> Bool {
        let reader = AKReader()
        // 密码必须在 open 之前通过 passphrases 参数传入
        try reader.open(path: path, passphrases: [passphrase])
        defer { reader.close() }
        return try reader._verifyPassphrase()
    }
    
    /// 验证密码是否正确（URL 版本）
    ///
    /// - Parameters:
    ///   - passphrase: 待验证的密码
    ///   - url: 归档文件 URL（仅支持本地文件）
    /// - Returns: `true` 表示密码正确（或归档未加密），`false` 表示密码错误
    /// - Throws: AKError
    public static func verifyPassphrase(_ passphrase: String, for url: URL) throws -> Bool {
        guard url.isFileURL else {
            throw AKError.invalidPath(url.absoluteString)
        }
        return try verifyPassphrase(passphrase, for: url.path)
    }
    
    /// 对当前已打开的归档验证密码
    ///
    /// 注意：密码必须在调用 `open(path:passphrases:)` 时通过 `passphrases` 参数传入，
    /// 而不能在 open 之后通过 `addPassphrase(_:)` 添加（libarchive 限制）。
    /// 此方法会尝试读取第一个加密条目的少量数据以验证密码。
    ///
    /// - Returns: `true` 表示密码正确（或归档未加密），`false` 表示密码错误
    /// - Throws: AKError（非密码错误的其他错误）
    public func verifyPassphrase() throws -> Bool {
        guard isOpen else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        return try _verifyPassphrase()
    }
    
    // MARK: - 遍历条目
    
    /// 读取下一个条目头部
    /// - Returns: 下一个 AKEntry，若到达末尾则返回 nil
    /// - Throws: AKError（非 EOF 错误）
    public func nextEntry() throws -> AKEntry? {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        var entryPtr: OpaquePointer?
        let result = libarchive.archive_read_next_header(archive, &entryPtr)
        
        if result == AKError.ARCHIVE_EOF {
            return nil
        }
        // ARCHIVE_WARN 视为成功（有警告但可继续）
        if result != AKError.ARCHIVE_OK && result != AKError.ARCHIVE_WARN {
            let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
            if let error = AKError.from(code: result, errorString: errStr) {
                throw error
            }
        }
        guard let ptr = entryPtr else { return nil }
        return AKEntry(borrowing: ptr)
    }
    
    /// 跳过当前条目的数据
    /// - Throws: AKError
    public func skipCurrentEntry() throws {
        guard let archive else { return }
        let result = libarchive.archive_read_data_skip(archive)
        try checkResult(result)
    }
    
    /// 读取当前条目的全部数据
    /// - Returns: 条目数据
    /// - Throws: AKError
    public func readCurrentEntryData() throws -> Data {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        var result = Data()
        let bufferSize = 65536
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        
        while true {
            let bytesRead = libarchive.archive_read_data(archive, &buffer, bufferSize)
            if bytesRead == 0 { break }
            if bytesRead < 0 {
                let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
                throw AKError.failed(errStr ?? "读取数据失败")
            }
            result.append(contentsOf: buffer.prefix(Int(bytesRead)))
        }
        return result
    }
    
    /// 低级数据块读取（对应 archive_read_data_block）
    /// - Returns: (data, offset) 元组，到达末尾时返回 nil
    /// - Throws: AKError
    public func readDataBlock() throws -> (data: Data, offset: Int64)? {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        var buff: UnsafeRawPointer? = nil
        var size: Int = 0
        var offset: Int64 = 0
        let result = libarchive.archive_read_data_block(archive, &buff, &size, &offset)
        if result == AKError.ARCHIVE_EOF { return nil }
        if result != AKError.ARCHIVE_OK {
            let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
            throw AKError.failed(errStr ?? "读取数据块失败")
        }
        guard let ptr = buff else { return nil }
        let data = Data(bytes: ptr, count: size)
        return (data, offset)
    }
    
    // MARK: - 解压到磁盘
    
    /// 将当前条目解压到磁盘（使用当前工作目录）
    /// - Parameters:
    ///   - entry: 要解压的条目
    ///   - flags: 解压标志，默认为空
    /// - Throws: AKError
    public func extractCurrentEntry(_ entry: AKEntry, flags: AKExtractFlags = []) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        let result = libarchive.archive_read_extract(archive, entry.pointer, flags.rawValue)
        try checkResult(result)
    }
    
    /// 将归档中所有条目解压到指定目录
    /// - Parameters:
    ///   - destinationURL: 目标目录 URL
    ///   - flags: 解压标志，默认恢复时间和权限
    ///   - progress: 进度回调，参数为当前条目
    /// - Throws: AKError
    ///
    /// - Note: 此方法内部需要切换进程工作目录（`chdir`），这是 libarchive
    ///   `archive_read_extract` 的要求。切换工作目录是进程级操作，在多线程环境下
    ///   可能影响其他线程。如需在多线程环境中使用，请在调用方自行加锁，或改用
    ///   `archive_read_extract2` 配合 disk writer 的方式。
    public func extractAll(
        to destinationURL: URL,
        flags: AKExtractFlags = [.time, .permissions],
        progress: (@Sendable (AKEntry) -> Void)? = nil
    ) throws {
        guard destinationURL.isFileURL else {
            throw AKError.invalidPath(destinationURL.absoluteString)
        }
        // 确保目标目录存在
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        // 使用 POSIX chdir 切换工作目录（进程级操作，非线程安全）
        let destPath = destinationURL.path
        let originalPath = FileManager.default.currentDirectoryPath
        guard FileManager.default.changeCurrentDirectoryPath(destPath) else {
            throw AKError.cannotOpenFile("无法切换到目标目录: \(destPath)")
        }
        // 使用 defer 确保即使抛出异常也能恢复工作目录
        defer {
            _ = FileManager.default.changeCurrentDirectoryPath(originalPath)
        }
        
        while let entry = try nextEntry() {
            progress?(entry)
            try extractCurrentEntry(entry, flags: flags)
        }
    }
    
    // MARK: - 遍历所有条目（不解压）
    
    /// 遍历归档中所有条目
    ///
    /// - Note: `handler` 执行期间可以调用 `readCurrentEntryData()` 读取数据，
    ///   遍历器会在 `handler` 返回后自动跳过未读取的剩余数据（`archive_read_data_skip`
    ///   在数据已被完全读取时是安全的，直接返回 `ARCHIVE_OK`）。
    ///   若需要更精细的控制，请直接使用 `nextEntry()` + `readCurrentEntryData()` 组合。
    ///
    /// - Parameter handler: 处理每个条目的闭包，返回 `true` 继续遍历，返回 `false` 停止
    /// - Throws: AKError
    public func enumerateEntries(_ handler: (AKEntry) throws -> Bool) throws {
        while let entry = try nextEntry() {
            let shouldContinue = try handler(entry)
            // 无论 handler 是否读取了数据，都跳过剩余数据以推进到下一条目。
            // archive_read_data_skip 在数据已被完全读取时是安全的（返回 ARCHIVE_OK）。
            // 即使 shouldContinue == false 也需要跳过，确保归档状态一致。
            try skipCurrentEntry()
            if !shouldContinue { break }
        }
    }
    
    // MARK: - 过滤器信息
    
    /// 获取指定索引的过滤器代码
    /// - Parameter index: 过滤器索引（-1 表示最外层）
    /// - Returns: AKFilter，未知时返回 nil
    public func filter(at index: Int) -> AKFilter? {
        guard let archive else { return nil }
        let code = libarchive.archive_filter_code(archive, Int32(index))
        return AKFilter(rawValue: code)
    }
    
    /// 获取指定索引的过滤器名称
    /// - Parameter index: 过滤器索引
    /// - Returns: 过滤器名称字符串
    public func filterName(at index: Int) -> String? {
        guard let archive else { return nil }
        guard let cStr = libarchive.archive_filter_name(archive, Int32(index)) else { return nil }
        return String(cString: cStr)
    }
    
    /// 最外层（第一个）过滤器
    public var filter: AKFilter? { filter(at: 0) }
    
    // MARK: - 关闭
    
    /// 关闭归档并释放资源
    public func close() {
        if let archive {
            libarchive.archive_read_free(archive)
            self.archive = nil
        }
        // 归档释放后才能安全释放内存数据
        memoryData = nil
        isOpen = false
    }
    
    // MARK: - 私有方法
    
    private func prepareArchive() throws {
        // 如果已有归档，先关闭
        if archive != nil {
            close()
        }
        guard let newArchive = libarchive.archive_read_new() else {
            throw AKError.cannotCreateArchive("无法创建读取器")
        }
        archive = newArchive
        // 启用所有格式和过滤器支持
        libarchive.archive_read_support_filter_all(archive)
        libarchive.archive_read_support_format_all(archive)
        // 启用原始格式支持（用于读取单文件压缩）
        libarchive.archive_read_support_format_raw(archive)
    }
    
    private func checkResult(_ result: Int32) throws {
        guard result != AKError.ARCHIVE_OK && result != AKError.ARCHIVE_WARN else { return }
        let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
        if let error = AKError.from(code: result, errorString: errStr) {
            throw error
        }
    }
    
    /// 内部实现：遍历条目头部，检测是否存在加密条目
    ///
    /// libarchive 在读取加密条目头部时会设置 `archive_entry_is_encrypted`，
    /// 即使没有提供密码也能检测到加密标志（ZIP AES 等格式在头部即标记加密）。
    private func _detectEncryption() throws -> Bool {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        var entryPtr: OpaquePointer?
        while true {
            let result = libarchive.archive_read_next_header(archive, &entryPtr)
            if result == AKError.ARCHIVE_EOF { break }
            // 忽略密码相关错误（ARCHIVE_FAILED），继续检测头部标志
            if result == AKError.ARCHIVE_FATAL {
                let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
                throw AKError.fatal(errStr ?? "读取归档头部失败")
            }
            guard let ptr = entryPtr else { continue }
            // 检查条目是否加密（数据或元数据）
            if libarchive.archive_entry_is_encrypted(ptr) != 0 {
                return true
            }
            // 跳过当前条目数据，继续检查下一个
            libarchive.archive_read_data_skip(archive)
        }
        return false
    }
    
    /// 内部实现：尝试读取第一个加密条目的少量数据以验证密码
    ///
    /// 策略：
    /// 1. 遍历条目，找到第一个加密条目
    /// 2. 尝试读取该条目的数据（哪怕只读 1 字节）
    /// 3. 若读取成功，密码正确；若返回错误（通常含 "passphrase" 或 "password"），密码错误
    /// 4. 若归档无加密条目，直接返回 true
    private func _verifyPassphrase() throws -> Bool {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        var entryPtr: OpaquePointer?
        while true {
            let result = libarchive.archive_read_next_header(archive, &entryPtr)
            if result == AKError.ARCHIVE_EOF {
                // 没有找到加密条目，归档未加密，视为"正确"
                return true
            }
            if result == AKError.ARCHIVE_FATAL {
                let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
                throw AKError.fatal(errStr ?? "读取归档头部失败")
            }
            guard let ptr = entryPtr else { continue }
            
            // 仅对加密条目进行验证
            guard libarchive.archive_entry_is_encrypted(ptr) != 0 else {
                libarchive.archive_read_data_skip(archive)
                continue
            }
            
            // 尝试读取少量数据来验证密码
            var buffer = [UInt8](repeating: 0, count: 1)
            let bytesRead = libarchive.archive_read_data(archive, &buffer, 1)
            
            if bytesRead >= 0 {
                // 读取成功（包括空文件返回 0），密码正确
                return true
            }
            
            // 读取失败，检查错误信息判断是否为密码错误
            // 注意：先获取原始字符串用于中文匹配，再转小写用于英文关键字匹配
            let rawErrStr = libarchive.archive_error_string(archive).map { String(cString: $0) } ?? ""
            let errStr = rawErrStr.lowercased()
            let isPassphraseError = errStr.contains("passphrase") ||
                                    errStr.contains("password") ||
                                    errStr.contains("incorrect") ||
                                    errStr.contains("wrong") ||
                                    errStr.contains("bad") ||
                                    rawErrStr.contains("密码")
            if isPassphraseError {
                return false
            }
            // 其他读取错误，抛出
            let errCode = libarchive.archive_errno(archive)
            if let error = AKError.from(code: errCode, errorString: rawErrStr.isEmpty ? nil : rawErrStr) {
                throw error
            }
            return false
        }
    }
}

// MARK: - 便利方法

extension AKReader {
    
    /// 列出归档中所有条目的路径
    /// - Parameter path: 归档文件路径
    /// - Returns: 路径列表
    /// - Throws: AKError
    public static func listEntries(at path: String) throws -> [String] {
        let reader = AKReader()
        try reader.open(path: path)
        defer { reader.close() }
        
        var paths: [String] = []
        while let entry = try reader.nextEntry() {
            if let pathname = entry.pathname {
                paths.append(pathname)
            }
            try reader.skipCurrentEntry()
        }
        return paths
    }
    
    /// 列出归档中所有条目的路径
    /// - Parameter url: 归档文件 URL（仅支持本地文件）
    /// - Returns: 路径列表
    /// - Throws: AKError
    public static func listEntries(at url: URL) throws -> [String] {
        guard url.isFileURL else {
            throw AKError.invalidPath(url.absoluteString)
        }
        return try listEntries(at: url.path)
    }
    
    /// 列出归档中所有条目（包含完整元数据）
    /// - Parameter path: 归档文件路径
    /// - Returns: 条目克隆列表（拥有所有权，可在关闭归档后使用）
    /// - Throws: AKError
    public static func listAllEntries(at path: String) throws -> [AKEntry] {
        let reader = AKReader()
        try reader.open(path: path)
        defer { reader.close() }
        
        var entries: [AKEntry] = []
        while let entry = try reader.nextEntry() {
            // 克隆条目以便在归档关闭后仍可访问
            if let cloned = entry.clone() {
                entries.append(cloned)
            }
            try reader.skipCurrentEntry()
        }
        return entries
    }
    
    /// 从归档中提取指定路径的文件数据
    /// - Parameters:
    ///   - entryPath: 条目路径
    ///   - archivePath: 归档文件路径
    /// - Returns: 文件数据，未找到时返回 nil
    /// - Throws: AKError
    public static func extractData(
        for entryPath: String,
        from archivePath: String
    ) throws -> Data? {
        let reader = AKReader()
        try reader.open(path: archivePath)
        defer { reader.close() }
        
        while let entry = try reader.nextEntry() {
            if entry.pathname == entryPath {
                return try reader.readCurrentEntryData()
            }
            try reader.skipCurrentEntry()
        }
        return nil
    }
}
