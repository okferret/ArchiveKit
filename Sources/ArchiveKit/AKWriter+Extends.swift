// AKWriter+Extends.swift
// ArchiveKit - libarchive Swift 封装
//
// AKWriter 现代化 API 扩展
// 提供 Builder 模式、async/await、Result-based 等现代 Swift 风格接口

import Foundation

// MARK: - AKArchiveItem（归档条目描述符）

/// 归档条目描述符，用于 Builder 模式批量构建归档
public enum AKArchiveItem: Sendable {
    /// 普通文件（来自磁盘）
    case file(path: String, archivePath: String? = nil)
    /// 普通文件（来自内存数据）
    case data(_ data: Data, archivePath: String, modificationDate: Date = Date(), permissions: UInt16 = 0o644)
    /// 目录
    case directory(archivePath: String, permissions: UInt16 = 0o755, modificationDate: Date = Date())
    /// 符号链接
    case symlink(archivePath: String, target: String, permissions: UInt16 = 0o777)
    /// 递归目录（来自磁盘，递归添加所有内容）
    case directoryTree(path: String, archiveBasePath: String? = nil, includeHidden: Bool = false)
}

// MARK: - AKWriterConfiguration（写入器配置）

/// 归档写入器配置，用于 Builder 模式
public struct AKWriterConfiguration: Sendable {
    /// 归档格式，默认 tarPaxRestricted
    public var format: AKFormat
    /// 压缩过滤器，默认无压缩
    public var filter: AKFilter
    /// 加密密码（仅支持加密格式，如 ZIP AES），nil 表示不加密
    public var passphrase: String?
    /// 格式选项字典
    public var formatOptions: [String: String]
    /// 压缩级别（0-9，0 为默认），nil 表示不设置
    public var compressionLevel: Int?
    
    public init(
        format: AKFormat = .tarPaxRestricted,
        filter: AKFilter = .none,
        passphrase: String? = nil,
        formatOptions: [String: String] = [:],
        compressionLevel: Int? = nil
    ) {
        self.format = format
        self.filter = filter
        self.passphrase = passphrase
        self.formatOptions = formatOptions
        self.compressionLevel = compressionLevel
    }
    
    /// ZIP 格式（无压缩）
    public static let zip = AKWriterConfiguration(format: .zip, filter: .none)
    
    /// ZIP 格式（AES-256 加密）
    public static func encryptedZip(passphrase: String) -> AKWriterConfiguration {
        AKWriterConfiguration(
            format: .zip,
            filter: .none,
            passphrase: passphrase,
            formatOptions: ["encryption": "aes256"]
        )
    }
    
    /// tar.gz 格式
    public static let tarGz = AKWriterConfiguration(format: .tarPaxRestricted, filter: .gzip)
    
    /// tar.xz 格式
    public static let tarXz = AKWriterConfiguration(format: .tarPaxRestricted, filter: .xz)
    
    /// tar.bz2 格式
    public static let tarBz2 = AKWriterConfiguration(format: .tarPaxRestricted, filter: .bzip2)
    
    /// tar.zst 格式
    public static let tarZst = AKWriterConfiguration(format: .tarPaxRestricted, filter: .zstd)
    
    /// 7-Zip 格式
    public static let sevenZip = AKWriterConfiguration(format: .sevenZip, filter: .none)
}

// MARK: - AKWriter 现代化扩展

extension AKWriter {
    
    // MARK: - Builder 模式批量写入
    
    /// 使用 Builder 模式批量写入条目到文件
    ///
    /// 使用示例：
    /// ```swift
    /// try AKWriter.build(to: outputPath, configuration: .tarGz) {
    ///     .file(path: "/path/to/file.txt")
    ///     .data(jsonData, archivePath: "config.json")
    ///     .directory(archivePath: "logs")
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - outputPath: 输出文件路径
    ///   - configuration: 写入器配置
    ///   - items: 条目列表（使用 result builder 语法）
    /// - Throws: AKError
    public static func build(
        to outputPath: String,
        configuration: AKWriterConfiguration = AKWriterConfiguration(),
        @AKArchiveItemBuilder items: () -> [AKArchiveItem]
    ) throws {
        let writer = AKWriter()
        // compressionLevel 必须在 open 之前设置（libarchive 状态机限制），
        // 通过 open 的 compressionLevel 参数在 prepareArchive 之后、archive_write_open 之前设置。
        try writer.open(
            path: outputPath,
            format: configuration.format,
            filter: configuration.filter,
            passphrase: configuration.passphrase,
            formatOptions: configuration.formatOptions,
            compressionLevel: configuration.compressionLevel
        )
        defer { writer.close() }
        try writer.addItems(items())
    }
    
    /// 使用 Builder 模式批量写入条目到内存
    ///
    /// - Parameters:
    ///   - configuration: 写入器配置
    ///   - items: 条目列表
    /// - Returns: 归档数据
    /// - Throws: AKError
    public static func buildToMemory(
        configuration: AKWriterConfiguration = AKWriterConfiguration(format: .zip),
        @AKArchiveItemBuilder items: () -> [AKArchiveItem]
    ) throws -> Data {
        let writer = AKWriter()
        // compressionLevel 必须在 open 之前设置（libarchive 状态机限制），
        // 通过 openMemory 的 compressionLevel 参数在 prepareArchive 之后、open 之前设置。
        let context = try writer.openMemory(
            format: configuration.format,
            filter: configuration.filter,
            compressionLevel: configuration.compressionLevel
        )
        do {
            try writer.addItems(items())
            return try writer.closeMemory(context: context)
        } catch {
            writer.close()
            throw error
        }
    }
    
    // MARK: - 批量条目写入
    
    /// 批量写入条目列表
    ///
    /// - Parameter items: 条目描述符列表
    /// - Throws: AKError
    public func addItems(_ items: [AKArchiveItem]) throws {
        for item in items {
            try addItem(item)
        }
    }
    
    /// 写入单个条目描述符
    ///
    /// - Parameter item: 条目描述符
    /// - Throws: AKError
    public func addItem(_ item: AKArchiveItem) throws {
        switch item {
        case .file(let path, let archivePath):
            try addFile(at: path, as: archivePath)
            
        case .data(let data, let archivePath, let modDate, let permissions):
            try addData(data, as: archivePath, modificationDate: modDate, permissions: permissions)
            
        case .directory(let archivePath, let permissions, let modDate):
            try addDirectory(as: archivePath, permissions: permissions, modificationDate: modDate)
            
        case .symlink(let archivePath, let target, let permissions):
            try addSymlink(as: archivePath, target: target, permissions: permissions)
            
        case .directoryTree(let path, let archiveBasePath, let includeHidden):
            try addDirectory(at: path, as: archiveBasePath, includeHiddenFiles: includeHidden)
        }
    }
    
    // MARK: - Result-based 非抛出 API
    
    /// 以 Result 形式打开归档文件（不抛出异常）
    ///
    /// - Parameters:
    ///   - path: 输出文件路径
    ///   - configuration: 写入器配置
    /// - Returns: `.success(())` 或 `.failure(AKError)`
    @discardableResult
    public func tryOpen(
        path: String,
        configuration: AKWriterConfiguration = AKWriterConfiguration()
    ) -> Result<Void, AKError> {
        do {
            try open(
                path: path,
                format: configuration.format,
                filter: configuration.filter,
                passphrase: configuration.passphrase,
                formatOptions: configuration.formatOptions,
                compressionLevel: configuration.compressionLevel
            )
            return .success(())
        } catch let error as AKError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
    
    /// 以 Result 形式写入数据条目（不抛出异常）
    ///
    /// - Parameters:
    ///   - data: 文件数据
    ///   - archivePath: 在归档中的路径
    /// - Returns: `.success(())` 或 `.failure(AKError)`
    @discardableResult
    public func tryAddData(_ data: Data, as archivePath: String) -> Result<Void, AKError> {
        do {
            try addData(data, as: archivePath)
            return .success(())
        } catch let error as AKError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
    
    /// 以 Result 形式写入磁盘文件（不抛出异常）
    ///
    /// - Parameters:
    ///   - filePath: 源文件路径
    ///   - archivePath: 在归档中的路径
    /// - Returns: `.success(())` 或 `.failure(AKError)`
    @discardableResult
    public func tryAddFile(at filePath: String, as archivePath: String? = nil) -> Result<Void, AKError> {
        do {
            try addFile(at: filePath, as: archivePath)
            return .success(())
        } catch let error as AKError {
            return .failure(error)
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }
    
    // MARK: - async/await 静态方法
    
    /// 异步将文件列表打包为归档
    ///
    /// - Parameters:
    ///   - filePaths: 源文件路径列表
    ///   - outputPath: 输出归档路径
    ///   - configuration: 写入器配置
    /// - Throws: AKError
    public static func archiveAsync(
        files filePaths: [String],
        to outputPath: String,
        configuration: AKWriterConfiguration = AKWriterConfiguration(filter: .gzip)
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let writer = AKWriter()
            try writer.open(
                path: outputPath,
                format: configuration.format,
                filter: configuration.filter,
                passphrase: configuration.passphrase,
                formatOptions: configuration.formatOptions
            )
            defer { writer.close() }
            for path in filePaths {
                try writer.addFile(at: path)
            }
        }.value
    }
    
    /// 异步将目录打包为归档
    ///
    /// - Parameters:
    ///   - directoryPath: 源目录路径
    ///   - outputPath: 输出归档路径
    ///   - configuration: 写入器配置
    ///   - progress: 进度回调（在后台线程调用）
    /// - Throws: AKError
    public static func archiveAsync(
        directory directoryPath: String,
        to outputPath: String,
        configuration: AKWriterConfiguration = AKWriterConfiguration(filter: .gzip),
        progress: (@Sendable (String) -> Void)? = nil
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let writer = AKWriter()
            try writer.open(
                path: outputPath,
                format: configuration.format,
                filter: configuration.filter,
                passphrase: configuration.passphrase,
                formatOptions: configuration.formatOptions
            )
            defer { writer.close() }
            try writer.addDirectory(at: directoryPath, progress: progress)
        }.value
    }
    
    /// 异步将数据打包为内存归档
    ///
    /// - Parameters:
    ///   - items: `[(数据, 归档路径)]` 列表
    ///   - configuration: 写入器配置
    /// - Returns: 归档数据
    /// - Throws: AKError
    public static func archiveToMemoryAsync(
        items: [(data: Data, path: String)],
        configuration: AKWriterConfiguration = AKWriterConfiguration(format: .zip)
    ) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let writer = AKWriter()
            let context = try writer.openMemory(
                format: configuration.format,
                filter: configuration.filter,
                compressionLevel: configuration.compressionLevel
            )
            do {
                for item in items {
                    try writer.addData(item.data, as: item.path)
                }
                return try writer.closeMemory(context: context)
            } catch {
                writer.close()
                throw error
            }
        }.value
    }
    
    /// 异步批量写入条目列表到文件
    ///
    /// 与同步 `build(to:configuration:items:)` 配合使用：
    /// 先用 `AKArchiveItemBuilder` 构建条目列表，再异步写入。
    ///
    /// - Parameters:
    ///   - outputPath: 输出文件路径
    ///   - configuration: 写入器配置
    ///   - items: 预先构建好的条目列表
    /// - Throws: AKError
    public static func buildAsync(
        to outputPath: String,
        configuration: AKWriterConfiguration = AKWriterConfiguration(),
        items: [AKArchiveItem]
    ) async throws {
        let capturedOutput = outputPath
        let capturedConfig = configuration
        let capturedItems = items
        try await Task.detached(priority: .userInitiated) {
            let writer = AKWriter()
            // compressionLevel 必须在 open 之前设置（libarchive 状态机限制）
            try writer.open(
                path: capturedOutput,
                format: capturedConfig.format,
                filter: capturedConfig.filter,
                passphrase: capturedConfig.passphrase,
                formatOptions: capturedConfig.formatOptions,
                compressionLevel: capturedConfig.compressionLevel
            )
            defer { writer.close() }
            try writer.addItems(capturedItems)
        }.value
    }
    
    // MARK: - 便利写入（链式调用支持）
    
    /// 写入数据条目并返回 self（支持链式调用）
    ///
    /// - Parameters:
    ///   - data: 文件数据
    ///   - archivePath: 在归档中的路径
    ///   - modificationDate: 修改时间
    ///   - permissions: 文件权限
    /// - Returns: self（用于链式调用）
    /// - Throws: AKError
    @discardableResult
    public func appendData(
        _ data: Data,
        as archivePath: String,
        modificationDate: Date = Date(),
        permissions: UInt16 = 0o644
    ) throws -> AKWriter {
        try addData(data, as: archivePath, modificationDate: modificationDate, permissions: permissions)
        return self
    }
    
    /// 写入磁盘文件并返回 self（支持链式调用）
    ///
    /// - Parameters:
    ///   - filePath: 源文件路径
    ///   - archivePath: 在归档中的路径
    /// - Returns: self（用于链式调用）
    /// - Throws: AKError
    @discardableResult
    public func appendFile(at filePath: String, as archivePath: String? = nil) throws -> AKWriter {
        try addFile(at: filePath, as: archivePath)
        return self
    }
    
    /// 写入目录条目并返回 self（支持链式调用）
    ///
    /// - Parameters:
    ///   - archivePath: 在归档中的目录路径
    ///   - permissions: 目录权限
    /// - Returns: self（用于链式调用）
    /// - Throws: AKError
    @discardableResult
    public func appendDirectory(
        as archivePath: String,
        permissions: UInt16 = 0o755
    ) throws -> AKWriter {
        try addDirectory(as: archivePath, permissions: permissions)
        return self
    }
}

// MARK: - AKArchiveItemBuilder（Result Builder）

/// 归档条目 Result Builder，支持声明式语法构建条目列表
///
/// 使用示例：
/// ```swift
/// try AKWriter.build(to: outputPath, configuration: .tarGz) {
///     AKArchiveItem.data(data1, archivePath: "file1.txt")
///     AKArchiveItem.data(data2, archivePath: "file2.txt")
///     if includeDir {
///         AKArchiveItem.directory(archivePath: "logs")
///     }
/// }
/// ```
@resultBuilder
public struct AKArchiveItemBuilder {
    
    /// 将多个 `[AKArchiveItem]` 组件合并为一个列表
    ///
    /// - Note: Result Builder 中每个表达式经 `buildExpression` 转换为 `[AKArchiveItem]`，
    ///   再由 `buildBlock` 合并。此处只保留接受 `[AKArchiveItem]...` 的版本，
    ///   避免与 `buildExpression` 产生歧义。
    public static func buildBlock(_ components: [AKArchiveItem]...) -> [AKArchiveItem] {
        components.flatMap { $0 }
    }
    
    public static func buildArray(_ components: [[AKArchiveItem]]) -> [AKArchiveItem] {
        components.flatMap { $0 }
    }
    
    public static func buildOptional(_ component: [AKArchiveItem]?) -> [AKArchiveItem] {
        component ?? []
    }
    
    public static func buildEither(first component: [AKArchiveItem]) -> [AKArchiveItem] {
        component
    }
    
    public static func buildEither(second component: [AKArchiveItem]) -> [AKArchiveItem] {
        component
    }
    
    /// 将单个 `AKArchiveItem` 表达式包装为列表
    public static func buildExpression(_ expression: AKArchiveItem) -> [AKArchiveItem] {
        [expression]
    }
    
    /// 将 `[AKArchiveItem]` 表达式直接透传
    public static func buildExpression(_ expression: [AKArchiveItem]) -> [AKArchiveItem] {
        expression
    }
    
    public static func buildFinalResult(_ component: [AKArchiveItem]) -> [AKArchiveItem] {
        component
    }
}
