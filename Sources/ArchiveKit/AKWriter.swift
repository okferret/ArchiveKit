// AKWriter.swift
// ArchiveKit - libarchive Swift 封装
//
// 归档写入器

import Foundation
internal import libarchive

/// 归档写入器，用于创建归档文件
public final class AKWriter {
    
    // MARK: - 内部属性
    
    private var archive: OpaquePointer?
    private var isOpen: Bool = false
    
    // MARK: - 公开属性
    
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
    
    /// 已写入的压缩后字节数（实际写入磁盘/内存的总字节数，经过所有过滤器处理后）
    ///
    /// - Note: `archive_filter_bytes(archive, -1)` 返回所有过滤器处理后的总输出字节数，
    ///   即最终写入目标（文件/内存）的压缩后字节数。
    public var bytesWritten: Int64 {
        guard let archive else { return 0 }
        return libarchive.archive_filter_bytes(archive, -1)
    }
    
    /// 归档是否已打开
    public var isArchiveOpen: Bool { isOpen }
    
    // MARK: - 初始化
    
    public init() {}
    
    deinit {
        close()
    }
    
    // MARK: - 打开归档
    
    /// 创建归档文件
    /// - Parameters:
    ///   - path: 输出文件路径
    ///   - format: 归档格式，默认 tarPaxRestricted
    ///   - filter: 压缩过滤器，默认无压缩
    ///   - passphrase: 加密密码（仅支持加密格式，如 ZIP AES），nil 表示不加密
    ///   - formatOptions: 格式选项字典，键为选项名，值为选项值（在打开前设置）
    ///   - compressionLevel: 压缩级别（0-9），nil 表示使用默认级别。
    public func open(
        path: String,
        format: AKFormat = .tarPaxRestricted,
        filter: AKFilter = .none,
        passphrase: String? = nil,
        formatOptions: [String: String] = [:],
        compressionLevel: Int? = nil
    ) throws {
        try prepareArchive(format: format, filter: filter)
        // 压缩级别必须在 archive_write_open 之前设置（libarchive 状态机限制）
        // 先尝试过滤器选项（gzip/xz/zstd 等），再尝试格式选项（zip 等）
        // ARCHIVE_WARN/ARCHIVE_FAILED 表示不支持（忽略），ARCHIVE_FATAL 表示严重错误（抛出）
        if let level = compressionLevel {
            let filterResult = libarchive.archive_write_set_filter_option(archive, nil, "compression-level", "\(level)")
            if filterResult == AKError.ARCHIVE_FATAL {
                let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
                libarchive.archive_write_free(archive)
                archive = nil
                throw AKError.failed(errStr ?? "设置压缩级别失败")
            }
            // 若过滤器不支持，尝试格式选项（如 ZIP 格式）
            if filterResult != AKError.ARCHIVE_OK {
                let formatResult = libarchive.archive_write_set_format_option(archive, nil, "compression-level", "\(level)")
                // 格式选项也不支持时静默忽略（使用默认压缩级别）
                if formatResult == AKError.ARCHIVE_FATAL {
                    let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
                    libarchive.archive_write_free(archive)
                    archive = nil
                    throw AKError.failed(errStr ?? "设置压缩级别失败")
                }
            }
        }
        // 格式选项必须在 archive_write_open 之前设置
        for (key, value) in formatOptions {
            libarchive.archive_write_set_format_option(archive, nil, key, value)
        }
        // 密码也必须在 archive_write_open 之前设置
        if let passphrase {
            let result = libarchive.archive_write_set_passphrase(archive, passphrase)
            if result != AKError.ARCHIVE_OK {
                let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
                libarchive.archive_write_free(archive)
                archive = nil
                throw AKError.cannotCreateArchive(errStr ?? "设置密码失败")
            }
        }
        let result = libarchive.archive_write_open_filename(archive, path)
        if result != AKError.ARCHIVE_OK {
            let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
            libarchive.archive_write_free(archive)
            archive = nil
            throw AKError.cannotOpenFile(errStr ?? path)
        }
        isOpen = true
    }
    
    /// 创建归档文件（URL 版本）
    /// - Parameters:
    ///   - url: 输出文件 URL（仅支持本地文件）
    ///   - format: 归档格式，默认 tarPaxRestricted
    ///   - filter: 压缩过滤器，默认无压缩
    ///   - passphrase: 加密密码（仅支持加密格式，如 ZIP AES），nil 表示不加密
    ///   - formatOptions: 格式选项字典，键为选项名，值为选项值（在打开前设置）
    /// - Throws: AKError
    public func open(
        url: URL,
        format: AKFormat = .tarPaxRestricted,
        filter: AKFilter = .none,
        passphrase: String? = nil,
        formatOptions: [String: String] = [:]
    ) throws {
        guard url.isFileURL else {
            throw AKError.invalidPath(url.absoluteString)
        }
        try open(path: url.path, format: format, filter: filter, passphrase: passphrase, formatOptions: formatOptions)
    }
    
    /// 创建归档到内存，返回写入完成后的数据
    ///
    /// 使用方式：
    /// ```swift
    /// let writer = AKWriter()
    /// let context = try writer.openMemory(format: .zip)
    /// try writer.addData(data, as: "file.txt")
    /// let archiveData = try writer.closeMemory(context: context)
    /// ```
    ///
    /// - Parameters:
    ///   - format: 归档格式
    ///   - filter: 压缩过滤器
    ///   - compressionLevel: 压缩级别（0-9），nil 表示使用默认级别。
    ///     必须在 open 之前设置（libarchive 状态机限制），因此通过此参数传入而非
    ///     在 open 之后调用 `setCompressionLevel`。
    /// - Returns: 内存写入上下文（用于 closeMemory 获取最终数据）
    /// - Throws: AKError
    @discardableResult
    public func openMemory(
        format: AKFormat = .zip,
        filter: AKFilter = .none,
        compressionLevel: Int? = nil
    ) throws -> AKMemoryWriteContext {
        try prepareArchive(format: format, filter: filter)
        // 压缩级别必须在 archive_write_open 之前设置（libarchive 状态机限制）
        // 先尝试过滤器选项（gzip/xz/zstd 等），再尝试格式选项（zip 等）
        // ARCHIVE_WARN/ARCHIVE_FAILED 表示不支持（忽略），ARCHIVE_FATAL 表示严重错误（抛出）
        if let level = compressionLevel {
            let filterResult = libarchive.archive_write_set_filter_option(archive, nil, "compression-level", "\(level)")
            if filterResult == AKError.ARCHIVE_FATAL {
                let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
                libarchive.archive_write_free(archive)
                archive = nil
                throw AKError.failed(errStr ?? "设置压缩级别失败")
            }
            // 若过滤器不支持，尝试格式选项（如 ZIP 格式）
            if filterResult != AKError.ARCHIVE_OK {
                let formatResult = libarchive.archive_write_set_format_option(archive, nil, "compression-level", "\(level)")
                if formatResult == AKError.ARCHIVE_FATAL {
                    let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
                    libarchive.archive_write_free(archive)
                    archive = nil
                    throw AKError.failed(errStr ?? "设置压缩级别失败")
                }
            }
        }
        let context = AKMemoryWriteContext()
        let result = context.open(archive: archive!)
        if result != AKError.ARCHIVE_OK {
            let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
            libarchive.archive_write_free(archive)
            archive = nil
            throw AKError.cannotCreateArchive(errStr ?? "无法创建内存归档")
        }
        isOpen = true
        return context
    }
    
    /// 关闭内存归档并返回最终数据
    /// - Parameter context: openMemory 返回的上下文
    /// - Returns: 归档数据
    /// - Throws: AKError
    ///
    /// 修复：原实现只调用 archive_write_close 而未调用 archive_write_free，
    /// 导致归档对象内存泄漏。现在先 close（写入结束标记并触发 flush），
    /// 再获取数据，最后 free 释放所有资源。
    public func closeMemory(context: AKMemoryWriteContext) throws -> Data {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        // 1. 写入归档结束标记（end-of-archive blocks）
        let closeResult = libarchive.archive_write_close(archive)
        // 2. close 完成后所有数据已写入 context.chunks，此时获取最终数据
        let data = context.finalData
        // 3. 释放归档对象（必须调用，否则内存泄漏）
        libarchive.archive_write_free(archive)
        self.archive = nil
        isOpen = false
        // 4. 检查 close 结果（在 free 之后，避免访问已释放的 archive）
        try checkResultWithoutArchive(closeResult)
        return data
    }
    
    // MARK: - 压缩选项
    
    /// 设置压缩级别（0-9，0 为默认，9 为最高压缩）
    ///
    /// - Important: libarchive 限制：`archive_write_set_filter_option` 只能在归档处于
    ///   `new` 状态时调用，即必须在 `open(path:...)` / `openMemory(...)` **之前**调用。
    ///   在 open 之后调用会触发 `ARCHIVE_FAILED` 错误（INTERNAL ERROR: wrong state）。
    ///
    /// - Parameter level: 压缩级别（0-9）
    /// - Throws: `AKError.failed` — 若在 open 之后调用，或过滤器不支持此选项
    public func setCompressionLevel(_ level: Int) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未初始化")
        }
        let result = libarchive.archive_write_set_filter_option(archive, nil, "compression-level", "\(level)")
        // ARCHIVE_WARN：过滤器不支持此选项（忽略）
        // ARCHIVE_FAILED：状态错误（open 之后调用）或其他错误（抛出）
        if result == AKError.ARCHIVE_FAILED || result == AKError.ARCHIVE_FATAL {
            let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
            throw AKError.failed(errStr ?? "设置压缩级别失败")
        }
    }
    
    /// 设置过滤器选项
    /// - Parameters:
    ///   - option: 选项名
    ///   - value: 选项值
    ///   - module: 模块名（nil 表示所有模块）
    /// - Throws: AKError
    public func setFilterOption(_ option: String, value: String, module: String? = nil) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未初始化")
        }
        let result = libarchive.archive_write_set_filter_option(archive, module, option, value)
        try checkResult(result)
    }
    
    /// 设置格式选项
    /// - Parameters:
    ///   - option: 选项名
    ///   - value: 选项值
    ///   - module: 模块名（nil 表示所有模块）
    /// - Throws: AKError
    public func setFormatOption(_ option: String, value: String, module: String? = nil) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未初始化")
        }
        let result = libarchive.archive_write_set_format_option(archive, module, option, value)
        try checkResult(result)
    }
    
    // MARK: - 密码支持
    
    /// 设置加密密码（用于支持加密的格式，如 ZIP AES）
    /// - Parameter passphrase: 密码字符串
    /// - Throws: AKError
    public func setPassphrase(_ passphrase: String) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未初始化")
        }
        let result = libarchive.archive_write_set_passphrase(archive, passphrase)
        try checkResult(result)
    }
    
    // MARK: - 写入条目
    
    /// 写入条目头部
    /// - Parameter entry: 要写入的条目
    /// - Throws: AKError
    public func writeHeader(_ entry: AKEntry) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        let result = libarchive.archive_write_header(archive, entry.pointer)
        try checkResult(result)
    }
    
    /// 写入数据块
    /// - Parameter data: 要写入的数据
    /// - Returns: 实际写入的字节数
    /// - Throws: AKError
    @discardableResult
    public func writeData(_ data: Data) throws -> Int {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        let written = data.withUnsafeBytes { bytes in
            libarchive.archive_write_data(archive, bytes.baseAddress, bytes.count)
        }
        if written < 0 {
            let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
            throw AKError.failed(errStr ?? "写入数据失败")
        }
        return Int(written)
    }
    
    /// 写入数据块（低级接口，支持稀疏文件偏移）
    /// - Parameters:
    ///   - data: 要写入的数据
    ///   - offset: 数据在文件中的偏移量
    /// - Throws: AKError
    public func writeDataBlock(_ data: Data, offset: Int64) throws {
        guard let archive else {
            throw AKError.cannotCreateArchive("归档未打开")
        }
        // archive_write_data_block 返回 la_ssize_t（Int），
        // 正常成功返回 ARCHIVE_OK(0)，错误返回负值（与 Int32 错误码兼容）。
        // 使用 Int32(clamping:) 安全截断，避免溢出。
        let rawResult = data.withUnsafeBytes { bytes in
            libarchive.archive_write_data_block(archive, bytes.baseAddress, bytes.count, offset)
        }
        let result = Int32(clamping: rawResult)
        try checkResult(result)
    }
    
    /// 完成当前条目的写入
    /// - Throws: AKError
    public func finishEntry() throws {
        guard let archive else { return }
        let result = libarchive.archive_write_finish_entry(archive)
        try checkResult(result)
    }
    
    // MARK: - 便利写入方法
    
    /// 从文件路径添加文件到归档
    /// - Parameters:
    ///   - filePath: 源文件路径
    ///   - archivePath: 在归档中的路径，默认使用文件名
    /// - Throws: AKError
    public func addFile(at filePath: String, as archivePath: String? = nil) throws {
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw AKError.cannotOpenFile(filePath)
        }
        
        let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
        
        let entry = AKEntry()
        entry.pathname = archivePath ?? fileURL.lastPathComponent
        
        // 优先使用 Int64，兼容大文件
        if let fileSize = attrs[.size] as? Int64 {
            entry.size = fileSize
        } else if let fileSize = attrs[.size] as? Int {
            entry.size = Int64(fileSize)
        } else if let fileSize = attrs[.size] as? NSNumber {
            entry.size = fileSize.int64Value
        }
        
        entry.fileType = .regular
        
        if let modDate = attrs[.modificationDate] as? Date {
            entry.modificationTime = modDate
        }
        
        if let posixPerms = attrs[.posixPermissions] as? Int {
            entry.permissions = UInt16(posixPerms & 0o7777)
        }
        
        try writeHeader(entry)
        
        // 使用流式读取避免大文件内存问题
        // 使用 FileHandle(forReadingFrom:) 替代旧的 FileHandle(forReadingAtPath:)，
        // 前者在失败时抛出错误，后者返回 nil 且无错误信息。
        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forReadingFrom: URL(fileURLWithPath: filePath))
        } catch {
            throw AKError.cannotOpenFile(filePath)
        }
        defer { try? fileHandle.close() }
        
        let chunkSize = 65536
        while true {
            let chunk: Data
            if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
                // 使用新 API，读取失败时抛出错误
                // read(upToCount:) 在此 SDK 版本中返回 Data?，空数据或 nil 均表示 EOF
                chunk = (try fileHandle.read(upToCount: chunkSize)) ?? Data()
            } else {
                // 旧 API 回退（不抛出错误，空数据表示 EOF）
                chunk = fileHandle.readData(ofLength: chunkSize)
            }
            if chunk.isEmpty { break }
            try writeData(chunk)
        }
        try finishEntry()
    }
    
    /// 从文件 URL 添加文件到归档
    /// - Parameters:
    ///   - fileURL: 源文件 URL
    ///   - archivePath: 在归档中的路径，默认使用文件名
    /// - Throws: AKError
    public func addFile(at fileURL: URL, as archivePath: String? = nil) throws {
        guard fileURL.isFileURL else {
            throw AKError.invalidPath(fileURL.absoluteString)
        }
        try addFile(at: fileURL.path, as: archivePath)
    }
    
    /// 添加内存数据作为文件条目
    /// - Parameters:
    ///   - data: 文件数据
    ///   - archivePath: 在归档中的路径
    ///   - modificationDate: 修改时间，默认为当前时间
    ///   - permissions: 文件权限，默认 0o644
    /// - Throws: AKError
    public func addData(
        _ data: Data,
        as archivePath: String,
        modificationDate: Date = Date(),
        permissions: UInt16 = 0o644
    ) throws {
        let entry = AKEntry()
        entry.pathname = archivePath
        entry.size = Int64(data.count)
        entry.fileType = .regular
        entry.modificationTime = modificationDate
        entry.permissions = permissions
        
        try writeHeader(entry)
        try writeData(data)
        try finishEntry()
    }
    
    /// 添加目录条目
    /// - Parameters:
    ///   - archivePath: 在归档中的目录路径
    ///   - permissions: 目录权限，默认 0o755
    ///   - modificationDate: 修改时间，默认为当前时间
    /// - Throws: AKError
    public func addDirectory(
        as archivePath: String,
        permissions: UInt16 = 0o755,
        modificationDate: Date = Date()
    ) throws {
        let entry = AKEntry()
        entry.pathname = archivePath
        entry.fileType = .directory
        entry.permissions = permissions
        entry.modificationTime = modificationDate
        
        try writeHeader(entry)
        try finishEntry()
    }
    
    /// 添加符号链接条目
    /// - Parameters:
    ///   - archivePath: 在归档中的路径
    ///   - target: 符号链接目标路径
    ///   - permissions: 权限，默认 0o777
    /// - Throws: AKError
    public func addSymlink(
        as archivePath: String,
        target: String,
        permissions: UInt16 = 0o777
    ) throws {
        let entry = AKEntry()
        entry.pathname = archivePath
        entry.fileType = .symbolicLink
        entry.symlinkTarget = target
        entry.permissions = permissions
        entry.modificationTime = Date()
        
        try writeHeader(entry)
        try finishEntry()
    }
    
    /// 递归添加目录中的所有文件
    /// - Parameters:
    ///   - directoryPath: 源目录路径
    ///   - archiveBasePath: 在归档中的基础路径，默认为目录名
    ///   - includeHiddenFiles: 是否包含隐藏文件，默认 false
    ///   - progress: 进度回调，参数为当前处理的文件路径
    /// - Throws: AKError
    public func addDirectory(
        at directoryPath: String,
        as archiveBasePath: String? = nil,
        includeHiddenFiles: Bool = false,
        progress: ((String) -> Void)? = nil
    ) throws {
        let dirURL = URL(fileURLWithPath: directoryPath)
        
        guard FileManager.default.fileExists(atPath: directoryPath) else {
            throw AKError.cannotOpenFile(directoryPath)
        }
        
        let basePath = archiveBasePath ?? dirURL.lastPathComponent
        
        var options: FileManager.DirectoryEnumerationOptions = []
        if !includeHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }
        
        let enumerator = FileManager.default.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey],
            options: options
        )
        
        guard let enumerator else {
            throw AKError.cannotOpenFile(directoryPath)
        }
        
        // 先添加根目录
        let rootAttrs = try FileManager.default.attributesOfItem(atPath: directoryPath)
        let rootPerms = (rootAttrs[.posixPermissions] as? Int).map { UInt16($0 & 0o7777) } ?? 0o755
        let rootMod = rootAttrs[.modificationDate] as? Date ?? Date()
        try addDirectory(as: basePath, permissions: rootPerms, modificationDate: rootMod)
        
        // 使用标准化的绝对路径作为前缀，避免符号链接或路径格式差异导致 hasPrefix 失败
        let canonicalDirPath: String
        if let resolved = try? URL(fileURLWithPath: directoryPath).resourceValues(forKeys: [.canonicalPathKey]).canonicalPath {
            canonicalDirPath = resolved
        } else {
            canonicalDirPath = (directoryPath as NSString).standardizingPath
        }
        let dirPrefix = canonicalDirPath.hasSuffix("/") ? canonicalDirPath : canonicalDirPath + "/"
        
        for case let fileURL as URL in enumerator {
            let filePath = fileURL.path
            // 使用标准化路径计算相对路径，确保与 dirPrefix 格式一致
            let canonicalFilePath = (filePath as NSString).standardizingPath
            let relativePath: String
            if canonicalFilePath.hasPrefix(dirPrefix) {
                relativePath = String(canonicalFilePath.dropFirst(dirPrefix.count))
            } else if filePath.hasPrefix(dirPrefix) {
                relativePath = String(filePath.dropFirst(dirPrefix.count))
            } else {
                relativePath = fileURL.lastPathComponent
            }
            let archivePath = basePath + "/" + relativePath
            
            progress?(filePath)
            
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            
            if resourceValues.isSymbolicLink == true {
                // 处理符号链接
                let target = try FileManager.default.destinationOfSymbolicLink(atPath: filePath)
                try addSymlink(as: archivePath, target: target)
            } else if resourceValues.isDirectory == true {
                let attrs = try FileManager.default.attributesOfItem(atPath: filePath)
                let perms = (attrs[.posixPermissions] as? Int).map { UInt16($0 & 0o7777) } ?? 0o755
                let modDate = attrs[.modificationDate] as? Date ?? Date()
                try addDirectory(as: archivePath, permissions: perms, modificationDate: modDate)
            } else {
                try addFile(at: filePath, as: archivePath)
            }
        }
    }
    
    // MARK: - 关闭
    
    /// 关闭归档并释放资源
    ///
    /// - Note: 此方法直接调用 `archive_write_free`，该函数内部会先执行 close 操作
    ///   （写入归档结束标记），再释放所有资源。因此无需单独调用 `archive_write_close`。
    ///   若需要获取 close 的错误码（如内存归档），请使用 `closeMemory(context:)` 方法。
    public func close() {
        if let archive {
            // archive_write_free 内部会先调用 archive_write_close（写入结束标记），
            // 再释放所有资源。此处忽略返回值（deinit 场景无法抛出错误）。
            libarchive.archive_write_free(archive)
            self.archive = nil
        }
        isOpen = false
    }
    
    // MARK: - 私有方法
    
    private func prepareArchive(format: AKFormat, filter: AKFilter) throws {
        if archive != nil {
            close()
        }
        guard let newArchive = libarchive.archive_write_new() else {
            throw AKError.cannotCreateArchive("无法创建写入器")
        }
        archive = newArchive
        
        // 设置格式
        let formatResult = setFormat(format)
        if formatResult != AKError.ARCHIVE_OK {
            let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
            libarchive.archive_write_free(archive)
            archive = nil
            throw AKError.cannotCreateArchive(errStr ?? "不支持的格式: \(format)")
        }
        
        // 设置过滤器
        let filterResult = addFilter(filter)
        if filterResult != AKError.ARCHIVE_OK && filterResult != AKError.ARCHIVE_WARN {
            let errStr = libarchive.archive_error_string(archive).map { String(cString: $0) }
            libarchive.archive_write_free(archive)
            archive = nil
            throw AKError.cannotCreateArchive(errStr ?? "不支持的过滤器: \(filter)")
        }
    }
    
    /// 设置归档格式（使用 archive_write_set_format 通用接口）
    private func setFormat(_ format: AKFormat) -> Int32 {
        return libarchive.archive_write_set_format(archive, format.rawValue)
    }
    
    /// 添加过滤器
    private func addFilter(_ filter: AKFilter) -> Int32 {
        switch filter {
        case .none:     return libarchive.archive_write_add_filter_none(archive)
        case .gzip:     return libarchive.archive_write_add_filter_gzip(archive)
        case .bzip2:    return libarchive.archive_write_add_filter_bzip2(archive)
        case .xz:       return libarchive.archive_write_add_filter_xz(archive)
        case .lzma:     return libarchive.archive_write_add_filter_lzma(archive)
        case .lz4:      return libarchive.archive_write_add_filter_lz4(archive)
        case .zstd:     return libarchive.archive_write_add_filter_zstd(archive)
        case .compress: return libarchive.archive_write_add_filter_compress(archive)
        case .lzip:     return libarchive.archive_write_add_filter_lzip(archive)
        case .lzop:     return libarchive.archive_write_add_filter_lzop(archive)
        case .grzip:    return libarchive.archive_write_add_filter_grzip(archive)
        case .lrzip:    return libarchive.archive_write_add_filter_lrzip(archive)
        case .uu:       return libarchive.archive_write_add_filter_uuencode(archive)
        case .rpm:      return libarchive.archive_write_add_filter_program(archive, "rpm2cpio")
        case .program:  return libarchive.archive_write_add_filter_program(archive, "cat")
        }
    }
    
    private func checkResult(_ result: Int32) throws {
        guard result != AKError.ARCHIVE_OK && result != AKError.ARCHIVE_WARN else { return }
        let errStr = archive.flatMap { libarchive.archive_error_string($0) }.map { String(cString: $0) }
        if let error = AKError.from(code: result, errorString: errStr) {
            throw error
        }
    }
    
    /// 在 archive 已被 free 后检查结果（不访问 archive 指针）
    private func checkResultWithoutArchive(_ result: Int32) throws {
        guard result != AKError.ARCHIVE_OK && result != AKError.ARCHIVE_WARN else { return }
        if let error = AKError.from(code: result, errorString: nil) {
            throw error
        }
    }
}

// MARK: - 内存写入上下文

/// 内存归档写入上下文，用于收集写入的数据
public final class AKMemoryWriteContext {
    
    private var chunks: [Data] = []
    
    internal init() {}
    
    /// 打开内存写入（使用自定义回调）
    ///
    /// 使用 `passUnretained` 而非 `passRetained`，由调用方（AKWriter）通过强引用
    /// 持有 context 的生命周期，避免 close callback 未被调用时的引用计数泄漏。
    /// 调用方必须确保在 archive_write_free 调用前 context 对象保持存活。
    internal func open(archive: OpaquePointer) -> Int32 {
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        return libarchive.archive_write_open2(
            archive,
            selfPtr,
            nil, // open callback
            { _, clientData, buffer, length -> la_ssize_t in
                // write callback：将数据块追加到 chunks
                guard let clientData, let buffer else { return -1 }
                let ctx = Unmanaged<AKMemoryWriteContext>.fromOpaque(clientData).takeUnretainedValue()
                let data = Data(bytes: buffer, count: length)
                ctx.chunks.append(data)
                return la_ssize_t(length)
            },
            { _, _ -> Int32 in
                // close callback：使用 unretained，无需手动 release
                return AKError.ARCHIVE_OK
            },
            nil // free callback
        )
    }
    
    /// 获取最终合并的数据
    public var finalData: Data {
        // 预先计算总大小，一次性分配内存，避免多次 realloc
        let totalSize = chunks.reduce(0) { $0 + $1.count }
        var result = Data(capacity: totalSize)
        for chunk in chunks {
            result.append(chunk)
        }
        return result
    }
}

// MARK: - 便利静态方法

extension AKWriter {
    
    /// 将文件列表打包为归档
    /// - Parameters:
    ///   - filePaths: 源文件路径列表
    ///   - outputPath: 输出归档路径
    ///   - format: 归档格式，默认 tarPaxRestricted
    ///   - filter: 压缩过滤器，默认 gzip
    /// - Throws: AKError
    public static func archive(
        files filePaths: [String],
        to outputPath: String,
        format: AKFormat = .tarPaxRestricted,
        filter: AKFilter = .gzip
    ) throws {
        let writer = AKWriter()
        try writer.open(path: outputPath, format: format, filter: filter)
        defer { writer.close() }
        
        for path in filePaths {
            try writer.addFile(at: path)
        }
    }
    
    /// 将目录打包为归档
    /// - Parameters:
    ///   - directoryPath: 源目录路径
    ///   - outputPath: 输出归档路径
    ///   - format: 归档格式，默认 tarPaxRestricted
    ///   - filter: 压缩过滤器，默认 gzip
    /// - Throws: AKError
    public static func archive(
        directory directoryPath: String,
        to outputPath: String,
        format: AKFormat = .tarPaxRestricted,
        filter: AKFilter = .gzip
    ) throws {
        let writer = AKWriter()
        try writer.open(path: outputPath, format: format, filter: filter)
        defer { writer.close() }
        
        try writer.addDirectory(at: directoryPath)
    }
    
    /// 将数据打包为内存归档
    /// - Parameters:
    ///   - items: [(数据, 归档路径)] 列表
    ///   - format: 归档格式，默认 zip
    ///   - filter: 压缩过滤器，默认无
    /// - Returns: 归档数据
    /// - Throws: AKError
    public static func archiveToMemory(
        items: [(data: Data, path: String)],
        format: AKFormat = .zip,
        filter: AKFilter = .none
    ) throws -> Data {
        let writer = AKWriter()
        let context = try writer.openMemory(format: format, filter: filter)
        // 确保异常时也能正确关闭并释放资源（writer.close() 调用 archive_write_free）
        do {
            for item in items {
                try writer.addData(item.data, as: item.path)
            }
            return try writer.closeMemory(context: context)
        } catch {
            writer.close()
            throw error
        }
    }
}
