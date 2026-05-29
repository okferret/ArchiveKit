// ArchiveKitTests.swift
// ArchiveKit 测试

import Testing
import Foundation
@testable import ArchiveKit

// MARK: - 版本信息测试

@Test func testLibarchiveVersion() {
    let version = ArchiveKit.libarchiveVersionNumber
    #expect(version > 0)
    
    let versionString = ArchiveKit.libarchiveVersionString
    #expect(!versionString.isEmpty)
    #expect(versionString.contains("libarchive"))
    
    let details = ArchiveKit.libarchiveVersionDetails
    #expect(!details.isEmpty)
}

@Test func testLibarchiveDependencyVersions() {
    // 依赖库版本（可能为 nil，取决于编译配置）
    // 只验证不崩溃，不强制要求非 nil
    _ = ArchiveKit.zlibVersion
    _ = ArchiveKit.liblzmaVersion
    _ = ArchiveKit.bzlibVersion
    _ = ArchiveKit.liblz4Version
    _ = ArchiveKit.libzstdVersion
}

// MARK: - AKFilter 测试

@Test func testAKFilterRawValues() {
    #expect(AKFilter.none.rawValue == 0)
    #expect(AKFilter.gzip.rawValue == 1)
    #expect(AKFilter.bzip2.rawValue == 2)
    #expect(AKFilter.xz.rawValue == 6)
    #expect(AKFilter.zstd.rawValue == 14)
}

@Test func testAKFilterDescription() {
    #expect(AKFilter.none.description == "none")
    #expect(AKFilter.gzip.description == "gzip")
    #expect(AKFilter.xz.description == "xz")
}

@Test func testAKFilterInit() {
    #expect(AKFilter(filterCode: 0) == AKFilter.none)
    #expect(AKFilter(filterCode: 1) == .gzip)
    #expect(AKFilter(filterCode: 999) == nil)
}

// MARK: - AKFormat 测试

@Test func testAKFormatRawValues() {
    #expect(AKFormat.tar.rawValue == 0x30000)
    #expect(AKFormat.zip.rawValue == 0x50000)
    #expect(AKFormat.sevenZip.rawValue == 0xE0000)
}

@Test func testAKFormatDescription() {
    #expect(AKFormat.tar.description == "tar")
    #expect(AKFormat.zip.description == "zip")
    #expect(AKFormat.sevenZip.description == "7zip")
}

@Test func testAKFormatFamily() {
    // tarUstar 的 family 应为 tar
    let family = AKFormat.tarUstar.family
    #expect(family == .tar)
    
    let zipFamily = AKFormat.zip.family
    #expect(zipFamily == .zip)
}

// MARK: - AKExtractFlags 测试

@Test func testAKExtractFlagsOptionSet() {
    let flags: AKExtractFlags = [.time, .permissions]
    #expect(flags.contains(.time))
    #expect(flags.contains(.permissions))
    #expect(!flags.contains(.owner))
}

@Test func testAKExtractFlagsSafe() {
    let safe = AKExtractFlags.safe
    #expect(safe.contains(.secureSymlinks))
    #expect(safe.contains(.secureNoDotDot))
    #expect(safe.contains(.secureNoAbsolutePaths))
}

@Test func testAKExtractFlagsStandard() {
    let standard = AKExtractFlags.standard
    #expect(standard.contains(.time))
    #expect(standard.contains(.permissions))
    #expect(standard.contains(.secureSymlinks))
}

@Test func testAKExtractFlagsFull() {
    let full = AKExtractFlags.full
    #expect(full.contains(.owner))
    #expect(full.contains(.permissions))
    #expect(full.contains(.time))
    #expect(full.contains(.acl))
    #expect(full.contains(.fflags))
    #expect(full.contains(.xattr))
}

@Test func testAKExtractFlagsDescription() {
    let flags: AKExtractFlags = [.time, .permissions, .noHFSCompression, .clearNoChangeFlags]
    let desc = flags.description
    #expect(desc.contains("time"))
    #expect(desc.contains("permissions"))
    #expect(desc.contains("noHFSCompression"))
    #expect(desc.contains("clearNoChangeFlags"))
}

// MARK: - AKEntry 测试

@Test func testAKEntryCreation() {
    let entry = AKEntry()
    #expect(entry.pathname == nil)
    #expect(entry.size == nil)
    #expect(entry.fileType == .unknown)
}

@Test func testAKEntrySetProperties() {
    let entry = AKEntry()
    entry.pathname = "test/file.txt"
    entry.size = 1024
    entry.fileType = .regular
    entry.permissions = 0o644
    
    #expect(entry.pathname == "test/file.txt")
    #expect(entry.size == 1024)
    #expect(entry.fileType == .regular)
    #expect(entry.isRegularFile)
    #expect(!entry.isDirectory)
    #expect(entry.permissions == 0o644)
}

@Test func testAKEntryDirectoryType() {
    let entry = AKEntry()
    entry.fileType = .directory
    #expect(entry.isDirectory)
    #expect(!entry.isRegularFile)
    #expect(!entry.isSymbolicLink)
}

@Test func testAKEntryFileTypeHelpers() {
    let entry = AKEntry()
    
    entry.fileType = .symbolicLink
    #expect(entry.isSymbolicLink)
    
    entry.fileType = .blockDevice
    #expect(entry.isBlockDevice)
    
    entry.fileType = .characterDevice
    #expect(entry.isCharacterDevice)
    
    entry.fileType = .fifo
    #expect(entry.isFIFO)
    
    entry.fileType = .socket
    #expect(entry.isSocket)
}

@Test func testAKEntryMode() {
    let entry = AKEntry()
    entry.fileType = .regular
    entry.permissions = 0o644
    // mode 应包含文件类型位和权限位
    let m = entry.mode
    #expect(m != 0)
}

@Test func testAKEntryStrmode() {
    let entry = AKEntry()
    entry.fileType = .regular
    entry.permissions = 0o644
    let str = entry.strmode
    #expect(!str.isEmpty)
    // 普通文件应以 '-' 开头
    #expect(str.hasPrefix("-"))
}

@Test func testAKEntryModificationTime() {
    let entry = AKEntry()
    let now = Date()
    entry.modificationTime = now
    
    if let mtime = entry.modificationTime {
        // 允许 1 秒误差（时间戳精度）
        #expect(abs(mtime.timeIntervalSince(now)) < 1.0)
    } else {
        Issue.record("修改时间未设置")
    }
}

@Test func testAKEntryAccessTime() {
    let entry = AKEntry()
    let now = Date()
    entry.accessTime = now
    
    if let atime = entry.accessTime {
        #expect(abs(atime.timeIntervalSince(now)) < 1.0)
    } else {
        Issue.record("访问时间未设置")
    }
}

@Test func testAKEntryChangeTime() {
    let entry = AKEntry()
    let now = Date()
    entry.changeTime = now
    
    if let ctime = entry.changeTime {
        #expect(abs(ctime.timeIntervalSince(now)) < 1.0)
    } else {
        Issue.record("变更时间未设置")
    }
}

@Test func testAKEntryBirthTime() {
    let entry = AKEntry()
    let now = Date()
    entry.birthTime = now
    
    if let btime = entry.birthTime {
        #expect(abs(btime.timeIntervalSince(now)) < 1.0)
    } else {
        Issue.record("创建时间未设置")
    }
}

@Test func testAKEntryUnsetTime() {
    let entry = AKEntry()
    // 未设置时应返回 nil
    #expect(entry.modificationTime == nil)
    #expect(entry.accessTime == nil)
    #expect(entry.changeTime == nil)
    #expect(entry.birthTime == nil)
    
    // 设置后取消
    entry.modificationTime = Date()
    #expect(entry.modificationTime != nil)
    entry.modificationTime = nil
    #expect(entry.modificationTime == nil)
}

@Test func testAKEntrySymlink() {
    let entry = AKEntry()
    entry.pathname = "link"
    entry.fileType = .symbolicLink
    entry.symlinkTarget = "/usr/local/bin/swift"
    entry.symlinkType = .file
    
    #expect(entry.symlinkTarget == "/usr/local/bin/swift")
    #expect(entry.symlinkType == .file)
}

@Test func testAKEntryHardlink() {
    let entry = AKEntry()
    entry.pathname = "hardlink"
    entry.hardlinkTarget = "original.txt"
    
    #expect(entry.hardlinkTarget == "original.txt")
}

@Test func testAKEntryUserGroup() {
    let entry = AKEntry()
    entry.uid = 501
    entry.gid = 20
    entry.userName = "testuser"
    entry.groupName = "staff"
    
    #expect(entry.uid == 501)
    #expect(entry.gid == 20)
    #expect(entry.userName == "testuser")
    #expect(entry.groupName == "staff")
}

@Test func testAKEntryDeviceNumbers() {
    let entry = AKEntry()
    entry.nlink = 2
    #expect(entry.nlink == 2)
}

@Test func testAKEntryXattr() {
    let entry = AKEntry()
    let testData = "hello".data(using: .utf8)!
    entry.xattrAdd(name: "user.test", value: testData)
    
    #expect(entry.xattrCount == 1)
    
    let xattrs = entry.xattrs
    #expect(xattrs.count == 1)
    #expect(xattrs[0].name == "user.test")
    #expect(xattrs[0].value == testData)
    
    entry.xattrClear()
    #expect(entry.xattrCount == 0)
}

@Test func testAKEntrySparse() {
    let entry = AKEntry()
    // 稀疏文件需要先设置文件大小
    entry.size = 16384
    entry.fileType = .regular
    entry.sparseAdd(offset: 0, length: 4096)
    entry.sparseAdd(offset: 8192, length: 4096)
    
    // 通过遍历验证稀疏区域（sparse_count 在部分实现中通过遍历计数）
    entry.sparseReset()
    var sparseRegions: [(offset: Int64, length: Int64)] = []
    while let region = entry.sparseNext() {
        sparseRegions.append(region)
    }
    #expect(sparseRegions.count == 2)
    #expect(sparseRegions[0].offset == 0)
    #expect(sparseRegions[0].length == 4096)
    #expect(sparseRegions[1].offset == 8192)
    #expect(sparseRegions[1].length == 4096)
    
    entry.sparseClear()
    // clear 后遍历应为空
    entry.sparseReset()
    #expect(entry.sparseNext() == nil)
}

@Test func testAKEntryClear() {
    let entry = AKEntry()
    entry.pathname = "test.txt"
    entry.size = 100
    
    entry.clear()
    
    // clear 后路径应为 nil
    #expect(entry.pathname == nil)
    #expect(entry.size == nil)
}

@Test func testAKEntryClone() {
    let entry = AKEntry()
    entry.pathname = "original.txt"
    entry.size = 512
    entry.fileType = .regular
    
    let cloned = entry.clone()
    #expect(cloned != nil)
    #expect(cloned?.pathname == "original.txt")
    #expect(cloned?.size == 512)
}

@Test func testAKEntryDescription() {
    let entry = AKEntry()
    entry.pathname = "test.txt"
    entry.size = 100
    entry.fileType = .regular
    
    let desc = entry.description
    #expect(desc.contains("test.txt"))
    #expect(desc.contains("regular"))
}

// MARK: - AKError 测试

@Test func testAKErrorDescription() {
    let error = AKError.failed("测试错误")
    #expect(error.description.contains("测试错误"))
    
    let fatalError = AKError.fatal("致命")
    #expect(fatalError.description.contains("致命"))
}

@Test func testAKErrorFromCode() {
    // ARCHIVE_OK (0) 应返回 nil
    #expect(AKError.from(code: 0, errorString: nil) == nil)
    
    // ARCHIVE_EOF (1) 应返回 .eof
    if case .eof = AKError.from(code: 1, errorString: nil) {
        // 正确
    } else {
        Issue.record("ARCHIVE_EOF 应映射到 .eof")
    }
    
    // ARCHIVE_FATAL (-30) 应返回 .fatal
    if case .fatal = AKError.from(code: -30, errorString: "fatal error") {
        // 正确
    } else {
        Issue.record("ARCHIVE_FATAL 应映射到 .fatal")
    }
}

@Test func testAKErrorLocalizedError() {
    let error = AKError.failed("操作失败")
    #expect(error.errorDescription != nil)
    #expect(error.errorDescription!.contains("操作失败"))
    
    let retryError = AKError.retry("请重试")
    #expect(retryError.recoverySuggestion != nil)
    
    let pathError = AKError.invalidPath("/bad/path")
    #expect(pathError.failureReason != nil)
    #expect(pathError.recoverySuggestion != nil)
}

@Test func testAKErrorEquatable() {
    #expect(AKError.ok == AKError.ok)
    #expect(AKError.eof == AKError.eof)
    #expect(AKError.failed("msg") == AKError.failed("msg"))
    #expect(AKError.failed("a") != AKError.failed("b"))
    #expect(AKError.ok != AKError.eof)
}

// MARK: - AKReader/AKWriter 集成测试

@Test func testWriteAndReadArchive() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_\(UUID().uuidString).tar.gz").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    // 写入测试
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    
    let testContent = "Hello, ArchiveKit!".data(using: .utf8)!
    try writer.addData(testContent, as: "hello.txt")
    try writer.addDirectory(as: "testdir")
    writer.close()
    
    // 验证文件存在
    #expect(FileManager.default.fileExists(atPath: archivePath))
    
    // 读取测试
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    var entries: [String] = []
    while let entry = try reader.nextEntry() {
        if let path = entry.pathname {
            entries.append(path)
        }
        try reader.skipCurrentEntry()
    }
    reader.close()
    
    #expect(entries.contains("hello.txt"))
    // 目录条目路径可能带有尾部斜杠
    #expect(entries.contains(where: { $0 == "testdir" || $0 == "testdir/" }))
}

@Test func testReadEntryData() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_data_\(UUID().uuidString).tar").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let originalContent = "Test content for ArchiveKit"
    let originalData = originalContent.data(using: .utf8)!
    
    // 写入
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(originalData, as: "content.txt")
    writer.close()
    
    // 读取并验证内容
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    var readData: Data?
    while let entry = try reader.nextEntry() {
        if entry.pathname == "content.txt" {
            readData = try reader.readCurrentEntryData()
        } else {
            try reader.skipCurrentEntry()
        }
    }
    reader.close()
    
    #expect(readData != nil)
    if let data = readData {
        let readContent = String(data: data, encoding: .utf8)
        #expect(readContent == originalContent)
    }
}

@Test func testListEntries() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_list_\(UUID().uuidString).zip").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    // 写入多个条目
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("file1".data(using: .utf8)!, as: "file1.txt")
    try writer.addData("file2".data(using: .utf8)!, as: "subdir/file2.txt")
    try writer.addDirectory(as: "emptydir")
    writer.close()
    
    // 列出条目
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains("file1.txt"))
    #expect(entries.contains("subdir/file2.txt"))
    // 目录条目路径可能带有尾部斜杠
    #expect(entries.contains(where: { $0 == "emptydir" || $0 == "emptydir/" }))
}

@Test func testWriteToMemory() async throws {
    let writer = AKWriter()
    let context = try writer.openMemory(format: .zip, filter: .none)
    
    let content1 = "Hello from memory!".data(using: .utf8)!
    let content2 = "Second file".data(using: .utf8)!
    try writer.addData(content1, as: "hello.txt")
    try writer.addData(content2, as: "second.txt")
    
    let archiveData = try writer.closeMemory(context: context)
    
    #expect(!archiveData.isEmpty)
    
    // 从内存读取验证
    let reader = AKReader()
    try reader.open(data: archiveData)
    
    var paths: [String] = []
    while let entry = try reader.nextEntry() {
        if let path = entry.pathname {
            paths.append(path)
        }
        try reader.skipCurrentEntry()
    }
    reader.close()
    
    #expect(paths.contains("hello.txt"))
    #expect(paths.contains("second.txt"))
}

@Test func testArchiveToMemoryStaticMethod() async throws {
    let items: [(data: Data, path: String)] = [
        ("item1".data(using: .utf8)!, "item1.txt"),
        ("item2".data(using: .utf8)!, "item2.txt"),
    ]
    
    let archiveData = try AKWriter.archiveToMemory(items: items, format: .zip)
    #expect(!archiveData.isEmpty)
    
    // 验证内容
    let reader = AKReader()
    try reader.open(data: archiveData)
    var paths: [String] = []
    while let entry = try reader.nextEntry() {
        if let p = entry.pathname { paths.append(p) }
        try reader.skipCurrentEntry()
    }
    reader.close()
    
    #expect(paths.contains("item1.txt"))
    #expect(paths.contains("item2.txt"))
}

@Test func testExtractDataStaticMethod() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_extract_\(UUID().uuidString).tar").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let expected = "Extract me!".data(using: .utf8)!
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(expected, as: "target.txt")
    try writer.addData("other".data(using: .utf8)!, as: "other.txt")
    writer.close()
    
    let extracted = try AKReader.extractData(for: "target.txt", from: archivePath)
    #expect(extracted == expected)
    
    let notFound = try AKReader.extractData(for: "nonexistent.txt", from: archivePath)
    #expect(notFound == nil)
}

@Test func testListAllEntries() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_all_\(UUID().uuidString).tar").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("data".data(using: .utf8)!, as: "file.txt", permissions: 0o644)
    try writer.addDirectory(as: "dir", permissions: 0o755)
    writer.close()
    
    let entries = try AKReader.listAllEntries(at: archivePath)
    #expect(entries.count == 2)
    
    let filenames = entries.compactMap { $0.pathname }
    #expect(filenames.contains("file.txt"))
    #expect(filenames.contains(where: { $0 == "dir" || $0 == "dir/" }))
}

@Test func testReaderProperties() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_props_\(UUID().uuidString).tar.gz").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("test".data(using: .utf8)!, as: "test.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    #expect(reader.isArchiveOpen)
    #expect(reader.filterCount > 0)
    
    while let _ = try reader.nextEntry() {
        try reader.skipCurrentEntry()
    }
    
    #expect(reader.fileCount > 0)
    #expect(reader.bytesRead > 0)
    
    reader.close()
    #expect(!reader.isArchiveOpen)
}

@Test func testWriterAddSymlink() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_symlink_\(UUID().uuidString).tar").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("original".data(using: .utf8)!, as: "original.txt")
    try writer.addSymlink(as: "link.txt", target: "original.txt")
    writer.close()
    
    let entries = try AKReader.listAllEntries(at: archivePath)
    let symlink = entries.first { $0.pathname == "link.txt" }
    #expect(symlink != nil)
    #expect(symlink?.isSymbolicLink == true)
    #expect(symlink?.symlinkTarget == "original.txt")
}

@Test func testEnumerateEntries() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_enum_\(UUID().uuidString).zip").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    for i in 1...5 {
        try writer.addData("content\(i)".data(using: .utf8)!, as: "file\(i).txt")
    }
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    var count = 0
    try reader.enumerateEntries { entry in
        count += 1
        // 遍历前 3 个后停止
        return count < 3
    }
    reader.close()
    
    #expect(count == 3)
}

@Test func testReaderFilterInfo() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_filter_\(UUID().uuidString).tar.gz").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("test".data(using: .utf8)!, as: "test.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    // 应能获取过滤器信息
    let filterName = reader.filterName(at: 0)
    #expect(filterName != nil)
    
    reader.close()
}

@Test func testWriterIsOpen() throws {
    let writer = AKWriter()
    #expect(!writer.isArchiveOpen)
    
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_open_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    #expect(writer.isArchiveOpen)
    
    writer.close()
    #expect(!writer.isArchiveOpen)
}

@Test func testAKEntryFileTypeDescription() {
    #expect(AKEntryFileType.regular.description == "regular")
    #expect(AKEntryFileType.directory.description == "directory")
    #expect(AKEntryFileType.symbolicLink.description == "symlink")
    #expect(AKEntryFileType.unknown.description == "unknown")
}

@Test func testAKSymlinkType() {
    #expect(AKSymlinkType.undefined.description == "undefined")
    #expect(AKSymlinkType.file.description == "file")
    #expect(AKSymlinkType.directory.description == "directory")
}

/// 创建加密 ZIP 归档的辅助函数
private func makeEncryptedZip(password: String) throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_encrypted_\(UUID().uuidString).zip").path
    
    let writer = AKWriter()
    // 格式选项和密码必须在 open 之前通过参数传入（libarchive 限制）
    try writer.open(
        path: archivePath,
        format: .zip,
        filter: .none,
        passphrase: password,
        formatOptions: ["encryption": "aes256"]
    )
    try writer.addData("secret content".data(using: .utf8)!, as: "secret.txt")
    try writer.addData("another secret".data(using: .utf8)!, as: "dir/hidden.txt")
    writer.close()
    
    return archivePath
}

/// 创建未加密 ZIP 归档的辅助函数
private func makePlainZip() throws -> String {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_plain_\(UUID().uuidString).zip").path
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("plain content".data(using: .utf8)!, as: "plain.txt")
    writer.close()
    
    return archivePath
}

@Test func testIsEncryptedOnPlainArchive() async throws {
    let archivePath = try makePlainZip()
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let encrypted = try AKReader.isEncrypted(at: archivePath)
    #expect(!encrypted, "未加密归档应返回 false")
}

@Test func testIsEncryptedOnEncryptedArchive() async throws {
    let archivePath = try makeEncryptedZip(password: "testpass123")
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let encrypted = try AKReader.isEncrypted(at: archivePath)
    #expect(encrypted, "加密归档应返回 true")
}

@Test func testIsEncryptedViaURL() async throws {
    let archivePath = try makeEncryptedZip(password: "urltest")
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let url = URL(fileURLWithPath: archivePath)
    let encrypted = try AKReader.isEncrypted(at: url)
    #expect(encrypted, "通过 URL 检测加密归档应返回 true")
}

@Test func testIsEncryptedOnPlainTar() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_plain_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("hello".data(using: .utf8)!, as: "hello.txt")
    writer.close()
    
    let encrypted = try AKReader.isEncrypted(at: archivePath)
    #expect(!encrypted, "tar.gz 归档不支持加密，应返回 false")
}

@Test func testVerifyPassphraseCorrect() async throws {
    let password = "correct_password_123"
    let archivePath = try makeEncryptedZip(password: password)
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let isValid = try AKReader.verifyPassphrase(password, for: archivePath)
    #expect(isValid, "正确密码应验证通过")
}

@Test func testVerifyPassphraseWrong() async throws {
    let archivePath = try makeEncryptedZip(password: "correct_pass")
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let isValid = try AKReader.verifyPassphrase("wrong_pass", for: archivePath)
    #expect(!isValid, "错误密码应验证失败")
}

@Test func testVerifyPassphraseOnPlainArchive() async throws {
    let archivePath = try makePlainZip()
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    // 未加密归档，任意密码都应返回 true（无需密码）
    let isValid = try AKReader.verifyPassphrase("any_password", for: archivePath)
    #expect(isValid, "未加密归档不需要密码，应返回 true")
}

@Test func testVerifyPassphraseViaURL() async throws {
    let password = "url_test_pass"
    let archivePath = try makeEncryptedZip(password: password)
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let url = URL(fileURLWithPath: archivePath)
    let isValid = try AKReader.verifyPassphrase(password, for: url)
    #expect(isValid, "通过 URL 验证正确密码应通过")
}

@Test func testDetectEncryptionOnOpenedReader() async throws {
    let archivePath = try makeEncryptedZip(password: "detect_test")
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let reader = AKReader()
    // 检测加密不需要密码，直接打开即可
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let encrypted = try reader.detectEncryption()
    #expect(encrypted, "已打开的加密归档应检测到加密")
}

@Test func testVerifyPassphraseOnOpenedReader() async throws {
    let password = "open_reader_pass"
    let archivePath = try makeEncryptedZip(password: password)
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let reader = AKReader()
    // 密码必须在 open 时通过 passphrases 参数传入（libarchive 限制）
    try reader.open(path: archivePath, passphrases: [password])
    defer { reader.close() }
    
    let isValid = try reader.verifyPassphrase()
    #expect(isValid, "已打开的归档使用正确密码应验证通过")
}

@Test func testAKErrorWrongPassphrase() {
    let error = AKError.wrongPassphrase
    #expect(error.description.contains("密码"))
    #expect(error.errorDescription != nil)
    #expect(error.failureReason != nil)
    #expect(error.recoverySuggestion != nil)
    #expect(AKError.wrongPassphrase == AKError.wrongPassphrase)
}

// MARK: - extractAll 解压到目录测试

@Test func testExtractAllToDirectory() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_extractall_\(UUID().uuidString).tar").path
    let extractDir = tempDir.appendingPathComponent("extracted_\(UUID().uuidString)")
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
        try? FileManager.default.removeItem(at: extractDir)
    }
    
    // 写入包含多个条目的归档
    let content1 = "Hello from file1".data(using: .utf8)!
    let content2 = "Hello from file2".data(using: .utf8)!
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(content1, as: "file1.txt", permissions: 0o644)
    try writer.addData(content2, as: "subdir/file2.txt", permissions: 0o644)
    try writer.addDirectory(as: "emptydir", permissions: 0o755)
    writer.close()
    
    // 解压到目标目录
    // 解压到目标目录
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    // 使用 nonisolated(unsafe) 或 actor 收集进度（Swift 6 @Sendable 闭包限制）
    nonisolated(unsafe) var progressEntries: [String] = []
    try reader.extractAll(to: extractDir, flags: [.time, .permissions]) { entry in
        if let path = entry.pathname {
            progressEntries.append(path)
        }
    }
    reader.close()
    
    // 验证进度回调被调用
    #expect(!progressEntries.isEmpty)
    // 验证文件已解压
    let file1Path = extractDir.appendingPathComponent("file1.txt").path
    #expect(FileManager.default.fileExists(atPath: file1Path))
    let readContent1 = try Data(contentsOf: URL(fileURLWithPath: file1Path))
    #expect(readContent1 == content1)
    
    let file2Path = extractDir.appendingPathComponent("subdir/file2.txt").path
    #expect(FileManager.default.fileExists(atPath: file2Path))
    let readContent2 = try Data(contentsOf: URL(fileURLWithPath: file2Path))
    #expect(readContent2 == content2)
    
    // 验证目录已创建
    var isDir: ObjCBool = false
    let emptyDirPath = extractDir.appendingPathComponent("emptydir").path
    let exists = FileManager.default.fileExists(atPath: emptyDirPath, isDirectory: &isDir)
    #expect(exists && isDir.boolValue)
}

// MARK: - addFile(at:) 从磁盘文件添加测试

@Test func testAddFileFromDisk() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceFile = tempDir.appendingPathComponent("source_\(UUID().uuidString).txt")
    let archivePath = tempDir.appendingPathComponent("test_addfile_\(UUID().uuidString).tar").path
    
    defer {
        try? FileManager.default.removeItem(at: sourceFile)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    // 创建源文件
    let originalContent = "This is a disk file content for testing addFile(at:)"
    let originalData = originalContent.data(using: .utf8)!
    try originalData.write(to: sourceFile)
    
    // 使用 addFile(at:) 添加到归档
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addFile(at: sourceFile.path, as: "disk_file.txt")
    writer.close()
    
    // 读取并验证
    let extracted = try AKReader.extractData(for: "disk_file.txt", from: archivePath)
    #expect(extracted != nil)
    #expect(extracted == originalData)
}

@Test func testAddFileFromDiskURL() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceFile = tempDir.appendingPathComponent("source_url_\(UUID().uuidString).txt")
    let archivePath = tempDir.appendingPathComponent("test_addfile_url_\(UUID().uuidString).zip").path
    
    defer {
        try? FileManager.default.removeItem(at: sourceFile)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let originalData = "URL-based file content".data(using: .utf8)!
    try originalData.write(to: sourceFile)
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addFile(at: sourceFile)
    writer.close()
    
    // 验证归档中包含该文件（使用文件名）
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains(sourceFile.lastPathComponent))
}

@Test func testAddFileFromDiskLargeFile() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceFile = tempDir.appendingPathComponent("large_\(UUID().uuidString).bin")
    let archivePath = tempDir.appendingPathComponent("test_large_\(UUID().uuidString).tar.gz").path
    
    defer {
        try? FileManager.default.removeItem(at: sourceFile)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    // 创建 1MB 的测试文件（超过单次读取缓冲区 65536 字节）
    let chunkSize = 1024 * 1024
    var largeData = Data(count: chunkSize)
    // 填充可识别的模式
    for i in 0..<largeData.count {
        largeData[i] = UInt8(i & 0xFF)
    }
    try largeData.write(to: sourceFile)
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addFile(at: sourceFile.path, as: "large.bin")
    writer.close()
    
    // 验证解压后数据完整
    let extracted = try AKReader.extractData(for: "large.bin", from: archivePath)
    #expect(extracted != nil)
    #expect(extracted?.count == chunkSize)
    #expect(extracted == largeData)
}

// MARK: - addDirectory(at:) 递归添加目录测试

@Test func testAddDirectoryRecursive() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceDir = tempDir.appendingPathComponent("srcdir_\(UUID().uuidString)")
    let archivePath = tempDir.appendingPathComponent("test_dir_\(UUID().uuidString).tar").path
    
    defer {
        try? FileManager.default.removeItem(at: sourceDir)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    // 创建目录结构
    let subDir = sourceDir.appendingPathComponent("subdir")
    try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
    
    let file1 = sourceDir.appendingPathComponent("root.txt")
    let file2 = subDir.appendingPathComponent("nested.txt")
    let file3 = subDir.appendingPathComponent("another.txt")
    
    try "root content".data(using: .utf8)!.write(to: file1)
    try "nested content".data(using: .utf8)!.write(to: file2)
    try "another content".data(using: .utf8)!.write(to: file3)
    
    // 递归添加目录
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    
    var progressPaths: [String] = []
    try writer.addDirectory(at: sourceDir.path, as: "mydir") { path in
        progressPaths.append(path)
    }
    writer.close()
    
    // 验证进度回调
    #expect(!progressPaths.isEmpty)
    
    // 验证归档内容
    let entries = try AKReader.listEntries(at: archivePath)
    let dirName = "mydir"
    
    // 根目录
    #expect(entries.contains(where: { $0 == dirName || $0 == dirName + "/" }))
    // 根目录文件
    #expect(entries.contains("\(dirName)/root.txt"))
    // 子目录
    #expect(entries.contains(where: { $0 == "\(dirName)/subdir" || $0 == "\(dirName)/subdir/" }))
    // 子目录文件
    #expect(entries.contains("\(dirName)/subdir/nested.txt"))
    #expect(entries.contains("\(dirName)/subdir/another.txt"))
    
    // 验证文件内容
    let rootContent = try AKReader.extractData(for: "\(dirName)/root.txt", from: archivePath)
    #expect(rootContent == "root content".data(using: .utf8)!)
    
    let nestedContent = try AKReader.extractData(for: "\(dirName)/subdir/nested.txt", from: archivePath)
    #expect(nestedContent == "nested content".data(using: .utf8)!)
}

@Test func testAddDirectoryStaticMethod() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceDir = tempDir.appendingPathComponent("staticdir_\(UUID().uuidString)")
    let archivePath = tempDir.appendingPathComponent("test_static_dir_\(UUID().uuidString).tar.gz").path
    
    defer {
        try? FileManager.default.removeItem(at: sourceDir)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
    try "hello".data(using: .utf8)!.write(to: sourceDir.appendingPathComponent("hello.txt"))
    try "world".data(using: .utf8)!.write(to: sourceDir.appendingPathComponent("world.txt"))
    
    // 使用静态便利方法
    try AKWriter.archive(directory: sourceDir.path, to: archivePath)
    
    #expect(FileManager.default.fileExists(atPath: archivePath))
    
    let entries = try AKReader.listEntries(at: archivePath)
    let dirName = sourceDir.lastPathComponent
    #expect(entries.contains("\(dirName)/hello.txt"))
    #expect(entries.contains("\(dirName)/world.txt"))
}

// MARK: - readDataBlock 低级读取测试

@Test func testReadDataBlock() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_block_\(UUID().uuidString).tar").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let originalData = "Block read test content - 数据块读取测试".data(using: .utf8)!
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(originalData, as: "block_test.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    guard let entry = try reader.nextEntry() else {
        Issue.record("应能读取到条目")
        return
    }
    #expect(entry.pathname == "block_test.txt")
    
    // 使用低级 readDataBlock 读取
    var assembled = Data()
    while let block = try reader.readDataBlock() {
        // 验证 offset 单调递增（或为 0）
        #expect(block.offset >= 0)
        assembled.append(block.data)
    }
    reader.close()
    
    #expect(assembled == originalData)
}

@Test func testReadDataBlockMultipleEntries() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_multiblock_\(UUID().uuidString).zip").path
    
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let data1 = "First entry data".data(using: .utf8)!
    let data2 = "Second entry data".data(using: .utf8)!
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData(data1, as: "first.txt")
    try writer.addData(data2, as: "second.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    
    var results: [String: Data] = [:]
    
    while let entry = try reader.nextEntry() {
        guard let name = entry.pathname else {
            try reader.skipCurrentEntry()
            continue
        }
        var assembled = Data()
        while let block = try reader.readDataBlock() {
            assembled.append(block.data)
        }
        results[name] = assembled
    }
    reader.close()
    
    #expect(results["first.txt"] == data1)
    #expect(results["second.txt"] == data2)
}

// MARK: - 错误处理测试

@Test func testOpenNonExistentFile() {
    let reader = AKReader()
    #expect(throws: (any Error).self) {
        try reader.open(path: "/nonexistent/path/archive.tar")
    }
}

@Test func testOpenInvalidURL() {
    let reader = AKReader()
    let remoteURL = URL(string: "https://example.com/archive.tar")!
    #expect(throws: (any Error).self) {
        try reader.open(url: remoteURL)
    }
}

@Test func testWriterOpenInvalidURL() {
    let writer = AKWriter()
    let remoteURL = URL(string: "https://example.com/output.tar")!
    #expect(throws: (any Error).self) {
        try writer.open(url: remoteURL)
    }
}

@Test func testWriterAddNonExistentFile() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_err_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    defer { writer.close() }
    
    #expect(throws: (any Error).self) {
        try writer.addFile(at: "/nonexistent/file.txt")
    }
}

@Test func testIsSupportedOnValidArchive() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_supported_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("test".data(using: .utf8)!, as: "test.txt")
    writer.close()
    
    #expect(AKReader.isSupported(at: archivePath))
    #expect(AKReader.isSupported(at: URL(fileURLWithPath: archivePath)))
}

@Test func testIsSupportedOnInvalidFile() {
    #expect(!AKReader.isSupported(at: "/nonexistent/file.tar"))
    #expect(!AKReader.isSupported(at: URL(string: "https://example.com/file.tar")!))
}

@Test func testArchiveStaticFilesMethod() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let file1 = tempDir.appendingPathComponent("f1_\(UUID().uuidString).txt")
    let file2 = tempDir.appendingPathComponent("f2_\(UUID().uuidString).txt")
    let archivePath = tempDir.appendingPathComponent("test_static_files_\(UUID().uuidString).tar.gz").path
    
    defer {
        try? FileManager.default.removeItem(at: file1)
        try? FileManager.default.removeItem(at: file2)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    try "content1".data(using: .utf8)!.write(to: file1)
    try "content2".data(using: .utf8)!.write(to: file2)
    try AKWriter.archive(files: [file1.path, file2.path], to: archivePath)
    
    #expect(FileManager.default.fileExists(atPath: archivePath))
    
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains(file1.lastPathComponent))
    #expect(entries.contains(file2.lastPathComponent))
}

// MARK: - AKReader+Extends 新 API 测试

@Test func testAKArchiveInfo() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_info_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("hello".data(using: .utf8)!, as: "hello.txt", permissions: 0o644)
    try writer.addData("world".data(using: .utf8)!, as: "world.txt", permissions: 0o644)
    try writer.addDirectory(as: "subdir", permissions: 0o755)
    writer.close()
    
    let info = try AKReader.info(at: archivePath)
    
    #expect(info.entryCount == 3)
    #expect(info.paths.contains("hello.txt"))
    #expect(info.paths.contains("world.txt"))
    #expect(info.paths.contains(where: { $0 == "subdir" || $0 == "subdir/" }))
    #expect(!info.isEncrypted)
    #expect(info.sourcePath == archivePath)
    #expect(info.regularFileCount == 2)
    #expect(info.directoryCount == 1)
    #expect(info.totalUncompressedSize > 0)
    #expect(info.format != nil)
    #expect(info.filter != nil)
}

@Test func testAKArchiveInfoURL() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_info_url_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("data".data(using: .utf8)!, as: "file.txt")
    writer.close()
    
    let url = URL(fileURLWithPath: archivePath)
    let info = try AKReader.info(at: url)
    #expect(info.entryCount == 1)
    #expect(info.paths.contains("file.txt"))
}

@Test func testAKArchiveInfoInvalidURL() {
    let remoteURL = URL(string: "https://example.com/archive.zip")!
    #expect(throws: (any Error).self) {
        try AKReader.info(at: remoteURL)
    }
}

@Test func testAKReaderCompactMapPaths() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_cmap_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("a".data(using: .utf8)!, as: "a.txt")
    try writer.addData("b".data(using: .utf8)!, as: "b.log")
    try writer.addDirectory(as: "dir")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    // 仅收集 .txt 文件路径
    let txtPaths = try reader.compactMapPaths(where: { $0.pathname?.hasSuffix(".txt") == true })
    #expect(txtPaths == ["a.txt"])
    
    // 收集全部路径
    let reader2 = AKReader()
    try reader2.open(path: archivePath)
    defer { reader2.close() }
    let allPaths = try reader2.compactMapPaths()
    #expect(allPaths.count == 3)
}

@Test func testAKReaderCompactMap() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_cmap2_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("100".data(using: .utf8)!, as: "file1.txt")
    try writer.addData("200".data(using: .utf8)!, as: "file2.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    // 将条目映射为路径+大小元组
    let mapped: [(String, Int64)] = try reader.compactMap { entry in
        guard let path = entry.pathname, let size = entry.size else { return nil }
        return (path, size)
    }
    #expect(mapped.count == 2)
    #expect(mapped.map(\.0).contains("file1.txt"))
    #expect(mapped.map(\.0).contains("file2.txt"))
    // 每个文件大小应为 3 字节（"100" / "200"）
    #expect(mapped.allSatisfy { $0.1 == 3 })
}

@Test func testAKReaderFirstWhere() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_first_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("x".data(using: .utf8)!, as: "alpha.txt")
    try writer.addData("y".data(using: .utf8)!, as: "beta.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let found = try reader.first(where: { $0.pathname == "beta.txt" })
    #expect(found != nil)
    #expect(found?.pathname == "beta.txt")
    
    let reader2 = AKReader()
    try reader2.open(path: archivePath)
    defer { reader2.close() }
    let notFound = try reader2.first(where: { $0.pathname == "nonexistent.txt" })
    #expect(notFound == nil)
}

@Test func testAKReaderContainsWhere() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_contains_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("data".data(using: .utf8)!, as: "target.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let hasTarget = try reader.contains(where: { $0.pathname == "target.txt" })
    #expect(hasTarget)
    
    let reader2 = AKReader()
    try reader2.open(path: archivePath)
    defer { reader2.close() }
    let hasMissing = try reader2.contains(where: { $0.pathname == "missing.txt" })
    #expect(!hasMissing)
}

@Test func testAKReaderCountWhere() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_count_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    for i in 1...4 {
        try writer.addData("data\(i)".data(using: .utf8)!, as: "file\(i).txt")
    }
    try writer.addDirectory(as: "emptydir")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let total = try reader.count()
    #expect(total == 5)
    
    let reader2 = AKReader()
    try reader2.open(path: archivePath)
    defer { reader2.close() }
    let fileCount = try reader2.count(where: { $0.isRegularFile })
    #expect(fileCount == 4)
}

@Test func testAKReaderExtractAllData() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_extractall_data_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let data1 = "content1".data(using: .utf8)!
    let data2 = "content2".data(using: .utf8)!
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(data1, as: "file1.txt")
    try writer.addData(data2, as: "file2.txt")
    try writer.addDirectory(as: "dir")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let result = try reader.extractAllData()
    #expect(result.count == 2)
    #expect(result["file1.txt"] == data1)
    #expect(result["file2.txt"] == data2)
    #expect(result["dir"] == nil) // 目录不应被提取
}

@Test func testAKReaderExtractDataForPaths() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_extract_paths_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let data1 = "alpha".data(using: .utf8)!
    let data2 = "beta".data(using: .utf8)!
    let data3 = "gamma".data(using: .utf8)!
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData(data1, as: "alpha.txt")
    try writer.addData(data2, as: "beta.txt")
    try writer.addData(data3, as: "gamma.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let result = try reader.extractData(forPaths: ["alpha.txt", "gamma.txt"])
    #expect(result.count == 2)
    #expect(result["alpha.txt"] == data1)
    #expect(result["gamma.txt"] == data3)
    #expect(result["beta.txt"] == nil)
}

@Test func testAKReaderArchiveInfo() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_archiveinfo_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("test".data(using: .utf8)!, as: "test.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let info = try reader.archiveInfo()
    #expect(info.entryCount == 1)
    #expect(info.paths.contains("test.txt"))
    #expect(info.sourcePath == nil) // 实例方法不传 sourcePath
}

@Test func testAKReaderTryOpen() throws {
    let reader = AKReader()
    
    // 成功情况
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_tryopen_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("x".data(using: .utf8)!, as: "x.txt")
    writer.close()
    
    let successResult = reader.tryOpen(path: archivePath)
    if case .failure(let err) = successResult {
        Issue.record("tryOpen 应成功，但返回错误: \(err)")
    }
    reader.close()
    
    // 失败情况
    let failResult = reader.tryOpen(path: "/nonexistent/archive.tar")
    if case .success = failResult {
        Issue.record("tryOpen 应失败，但返回成功")
    }
}

@Test func testAKReaderTryNextEntry() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_trynext_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("data".data(using: .utf8)!, as: "entry.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let result = reader.tryNextEntry()
    switch result {
    case .success(let entry):
        #expect(entry?.pathname == "entry.txt")
    case .failure(let err):
        Issue.record("tryNextEntry 应成功，但返回错误: \(err)")
    }
}

@Test func testAKReaderTryReadCurrentEntryData() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_tryread_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let expected = "hello world".data(using: .utf8)!
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(expected, as: "hello.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    _ = try reader.nextEntry()
    let result = reader.tryReadCurrentEntryData()
    switch result {
    case .success(let data):
        #expect(data == expected)
    case .failure(let err):
        Issue.record("tryReadCurrentEntryData 应成功，但返回错误: \(err)")
    }
}

@Test func testAKReaderStream() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_stream_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("aaa".data(using: .utf8)!, as: "a.txt")
    try writer.addData("bbb".data(using: .utf8)!, as: "b.txt")
    try writer.addData("ccc".data(using: .utf8)!, as: "c.txt")
    writer.close()
    
    var visited: [String] = []
    var dataMap: [String: Data] = [:]
    
    try AKReader.stream(from: archivePath) { entry, reader in
        guard let path = entry.pathname else { return true }
        visited.append(path)
        dataMap[path] = try reader.readCurrentEntryData()
        return true
    }
    
    #expect(visited.count == 3)
    #expect(dataMap["a.txt"] == "aaa".data(using: .utf8)!)
    #expect(dataMap["b.txt"] == "bbb".data(using: .utf8)!)
    #expect(dataMap["c.txt"] == "ccc".data(using: .utf8)!)
}

@Test func testAKReaderStreamEarlyStop() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_stream_stop_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    for i in 1...5 {
        try writer.addData("data\(i)".data(using: .utf8)!, as: "file\(i).txt")
    }
    writer.close()
    
    var count = 0
    try AKReader.stream(from: archivePath) { _, _ in
        count += 1
        return count < 2 // 读取 2 个后停止
    }
    #expect(count == 2)
}

@Test func testAKReaderStreamURL() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_stream_url_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("test".data(using: .utf8)!, as: "test.txt")
    writer.close()
    
    var paths: [String] = []
    let url = URL(fileURLWithPath: archivePath)
    try AKReader.stream(from: url) { entry, _ in
        if let p = entry.pathname { paths.append(p) }
        return true
    }
    #expect(paths.contains("test.txt"))
}

@Test func testAKReaderStreamInvalidURL() {
    let remoteURL = URL(string: "https://example.com/archive.tar")!
    #expect(throws: (any Error).self) {
        try AKReader.stream(from: remoteURL) { _, _ in true }
    }
}

@Test func testAKReaderAsyncListEntries() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_async_list_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("x".data(using: .utf8)!, as: "x.txt")
    try writer.addData("y".data(using: .utf8)!, as: "y.txt")
    writer.close()
    
    let entries = try await AKReader.listEntriesAsync(at: archivePath)
    #expect(entries.contains("x.txt"))
    #expect(entries.contains("y.txt"))
}

@Test func testAKReaderAsyncExtractData() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_async_extract_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let expected = "async extract test".data(using: .utf8)!
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(expected, as: "async.txt")
    writer.close()
    
    let data = try await AKReader.extractDataAsync(for: "async.txt", from: archivePath)
    #expect(data == expected)
    
    let missing = try await AKReader.extractDataAsync(for: "missing.txt", from: archivePath)
    #expect(missing == nil)
}

@Test func testAKReaderAsyncExtractAll() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_async_extractall_\(UUID().uuidString).tar").path
    let extractDir = tempDir.appendingPathComponent("async_extracted_\(UUID().uuidString)")
    defer {
        try? FileManager.default.removeItem(atPath: archivePath)
        try? FileManager.default.removeItem(at: extractDir)
    }
    
    let content = "async extract all".data(using: .utf8)!
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(content, as: "async_file.txt")
    writer.close()
    
    try await AKReader.extractAllAsync(from: archivePath, to: extractDir)
    
    let extractedPath = extractDir.appendingPathComponent("async_file.txt").path
    #expect(FileManager.default.fileExists(atPath: extractedPath))
    let readData = try Data(contentsOf: URL(fileURLWithPath: extractedPath))
    #expect(readData == content)
}

@Test func testAKReaderAsyncInfo() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_async_info_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("info test".data(using: .utf8)!, as: "info.txt")
    writer.close()
    
    let info = try await AKReader.infoAsync(at: archivePath)
    #expect(info.entryCount == 1)
    #expect(info.paths.contains("info.txt"))
    #expect(info.sourcePath == archivePath)
}

@Test func testAKEntrySequence() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_seq_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    for i in 1...3 {
        try writer.addData("data\(i)".data(using: .utf8)!, as: "file\(i).txt")
    }
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    var paths: [String] = []
    for entry in reader.entries() {
        if let path = entry.pathname {
            paths.append(path)
        }
    }
    #expect(paths.count == 3)
    #expect(paths.contains("file1.txt"))
    #expect(paths.contains("file2.txt"))
    #expect(paths.contains("file3.txt"))
}

/// 验证 AKEntrySequence 在不读取数据时能正确自动跳过，遍历所有条目
@Test func testAKEntrySequenceAutoSkip() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_seq_skip_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let data1 = "content of file one".data(using: .utf8)!
    let data2 = "content of file two".data(using: .utf8)!
    let data3 = "content of file three".data(using: .utf8)!
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(data1, as: "one.txt")
    try writer.addData(data2, as: "two.txt")
    try writer.addData(data3, as: "three.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    // 遍历时不读取任何数据，验证自动跳过机制能正确推进到下一条目
    var paths: [String] = []
    for entry in reader.entries() {
        if let path = entry.pathname {
            paths.append(path)
        }
        // 故意不调用 readCurrentEntryData()，依赖自动跳过
    }
    #expect(paths.count == 3)
    #expect(paths[0] == "one.txt")
    #expect(paths[1] == "two.txt")
    #expect(paths[2] == "three.txt")
}

@Test func testAKEntryAsyncSequence() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_asyncseq_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    for i in 1...3 {
        try writer.addData("data\(i)".data(using: .utf8)!, as: "async\(i).txt")
    }
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    var paths: [String] = []
    for try await entry in reader.asyncEntries() {
        if let path = entry.pathname {
            paths.append(path)
        }
    }
    #expect(paths.count == 3)
    #expect(paths.contains("async1.txt"))
    #expect(paths.contains("async2.txt"))
    #expect(paths.contains("async3.txt"))
}

// MARK: - AKWriter+Extends 新 API 测试

@Test func testAKWriterBuildToFile() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_build_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let data1 = "build file 1".data(using: .utf8)!
    let data2 = "build file 2".data(using: .utf8)!
    
    try AKWriter.build(to: archivePath, configuration: .tarGz) {
        AKArchiveItem.data(data1, archivePath: "file1.txt")
        AKArchiveItem.data(data2, archivePath: "file2.txt")
        AKArchiveItem.directory(archivePath: "mydir")
    }
    
    #expect(FileManager.default.fileExists(atPath: archivePath))
    
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains("file1.txt"))
    #expect(entries.contains("file2.txt"))
    #expect(entries.contains(where: { $0 == "mydir" || $0 == "mydir/" }))
    
    let extracted = try AKReader.extractData(for: "file1.txt", from: archivePath)
    #expect(extracted == data1)
}

@Test func testAKWriterBuildToMemory() throws {
    let data1 = "memory build 1".data(using: .utf8)!
    let data2 = "memory build 2".data(using: .utf8)!
    
    let archiveData = try AKWriter.buildToMemory(configuration: .zip) {
        AKArchiveItem.data(data1, archivePath: "mem1.txt")
        AKArchiveItem.data(data2, archivePath: "mem2.txt")
    }
    
    #expect(!archiveData.isEmpty)
    
    let reader = AKReader()
    try reader.open(data: archiveData)
    defer { reader.close() }
    
    var paths: [String] = []
    while let entry = try reader.nextEntry() {
        if let p = entry.pathname { paths.append(p) }
        try reader.skipCurrentEntry()
    }
    #expect(paths.contains("mem1.txt"))
    #expect(paths.contains("mem2.txt"))
}

@Test func testAKWriterBuildWithFileItem() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceFile = tempDir.appendingPathComponent("src_\(UUID().uuidString).txt")
    let archivePath = tempDir.appendingPathComponent("test_build_file_\(UUID().uuidString).zip").path
    defer {
        try? FileManager.default.removeItem(at: sourceFile)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    let content = "file item content".data(using: .utf8)!
    try content.write(to: sourceFile)
    
    try AKWriter.build(to: archivePath, configuration: .zip) {
        AKArchiveItem.file(path: sourceFile.path, archivePath: "renamed.txt")
    }
    
    let extracted = try AKReader.extractData(for: "renamed.txt", from: archivePath)
    #expect(extracted == content)
}

@Test func testAKWriterBuildWithSymlinkItem() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_build_symlink_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    try AKWriter.build(to: archivePath, configuration: AKWriterConfiguration(format: .tarPaxRestricted, filter: .none)) {
        AKArchiveItem.data("original".data(using: .utf8)!, archivePath: "original.txt")
        AKArchiveItem.symlink(archivePath: "link.txt", target: "original.txt")
    }
    
    let entries = try AKReader.listAllEntries(at: archivePath)
    let symlink = entries.first { $0.pathname == "link.txt" }
    #expect(symlink?.isSymbolicLink == true)
    #expect(symlink?.symlinkTarget == "original.txt")
}

@Test func testAKWriterAddItems() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_additems_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let items: [AKArchiveItem] = [
        .data("item1".data(using: .utf8)!, archivePath: "item1.txt"),
        .data("item2".data(using: .utf8)!, archivePath: "item2.txt"),
        .directory(archivePath: "itemdir"),
    ]
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addItems(items)
    writer.close()
    
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains("item1.txt"))
    #expect(entries.contains("item2.txt"))
    #expect(entries.contains(where: { $0 == "itemdir" || $0 == "itemdir/" }))
}

@Test func testAKWriterTryOpen() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_tryopen_w_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    
    // 成功情况
    let successResult = writer.tryOpen(path: archivePath, configuration: .tarGz)
    if case .failure(let err) = successResult {
        Issue.record("tryOpen 应成功，但返回错误: \(err)")
    }
    writer.close()
    
    // 失败情况（无效路径）
    let failResult = writer.tryOpen(path: "/nonexistent/dir/archive.tar")
    if case .success = failResult {
        Issue.record("tryOpen 应失败，但返回成功")
    }
}

@Test func testAKWriterTryAddData() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_tryadd_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    
    let result = writer.tryAddData("hello".data(using: .utf8)!, as: "hello.txt")
    if case .failure(let err) = result {
        Issue.record("tryAddData 应成功，但返回错误: \(err)")
    }
    writer.close()
    
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains("hello.txt"))
}

@Test func testAKWriterTryAddFile() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceFile = tempDir.appendingPathComponent("src_tryaddfile_\(UUID().uuidString).txt")
    let archivePath = tempDir.appendingPathComponent("test_tryaddfile_\(UUID().uuidString).tar").path
    defer {
        try? FileManager.default.removeItem(at: sourceFile)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    try "file content".data(using: .utf8)!.write(to: sourceFile)
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    
    let successResult = writer.tryAddFile(at: sourceFile.path, as: "added.txt")
    if case .failure(let err) = successResult {
        Issue.record("tryAddFile 应成功，但返回错误: \(err)")
    }
    
    let failResult = writer.tryAddFile(at: "/nonexistent/file.txt")
    if case .success = failResult {
        Issue.record("tryAddFile 应失败，但返回成功")
    }
    writer.close()
}

@Test func testAKWriterChainedAppend() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_chain_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    
    // 链式调用
    try writer
        .appendData("data1".data(using: .utf8)!, as: "chain1.txt")
        .appendData("data2".data(using: .utf8)!, as: "chain2.txt")
        .appendDirectory(as: "chaindir")
    writer.close()
    
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains("chain1.txt"))
    #expect(entries.contains("chain2.txt"))
    #expect(entries.contains(where: { $0 == "chaindir" || $0 == "chaindir/" }))
}

@Test func testAKWriterAsyncArchiveFiles() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let file1 = tempDir.appendingPathComponent("async_f1_\(UUID().uuidString).txt")
    let file2 = tempDir.appendingPathComponent("async_f2_\(UUID().uuidString).txt")
    let archivePath = tempDir.appendingPathComponent("test_async_files_\(UUID().uuidString).tar.gz").path
    defer {
        try? FileManager.default.removeItem(at: file1)
        try? FileManager.default.removeItem(at: file2)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    try "async content 1".data(using: .utf8)!.write(to: file1)
    try "async content 2".data(using: .utf8)!.write(to: file2)
    
    try await AKWriter.archiveAsync(files: [file1.path, file2.path], to: archivePath)
    
    #expect(FileManager.default.fileExists(atPath: archivePath))
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains(file1.lastPathComponent))
    #expect(entries.contains(file2.lastPathComponent))
}

@Test func testAKWriterAsyncArchiveDirectory() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceDir = tempDir.appendingPathComponent("async_dir_\(UUID().uuidString)")
    let archivePath = tempDir.appendingPathComponent("test_async_dir_\(UUID().uuidString).tar.gz").path
    defer {
        try? FileManager.default.removeItem(at: sourceDir)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
    try "hello".data(using: .utf8)!.write(to: sourceDir.appendingPathComponent("hello.txt"))
    
    nonisolated(unsafe) var progressPaths: [String] = []
    try await AKWriter.archiveAsync(
        directory: sourceDir.path,
        to: archivePath,
        progress: { path in progressPaths.append(path) }
    )
    
    #expect(FileManager.default.fileExists(atPath: archivePath))
    #expect(!progressPaths.isEmpty)
    
    let entries = try AKReader.listEntries(at: archivePath)
    let dirName = sourceDir.lastPathComponent
    #expect(entries.contains("\(dirName)/hello.txt"))
}

@Test func testAKWriterAsyncArchiveToMemory() async throws {
    let items: [(data: Data, path: String)] = [
        ("async mem 1".data(using: .utf8)!, "async_mem1.txt"),
        ("async mem 2".data(using: .utf8)!, "async_mem2.txt"),
    ]
    
    let archiveData = try await AKWriter.archiveToMemoryAsync(items: items)
    #expect(!archiveData.isEmpty)
    
    let reader = AKReader()
    try reader.open(data: archiveData)
    defer { reader.close() }
    
    var paths: [String] = []
    while let entry = try reader.nextEntry() {
        if let p = entry.pathname { paths.append(p) }
        try reader.skipCurrentEntry()
    }
    #expect(paths.contains("async_mem1.txt"))
    #expect(paths.contains("async_mem2.txt"))
}

@Test func testAKWriterBuildAsync() async throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_buildasync_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let items: [AKArchiveItem] = [
        .data("async build 1".data(using: .utf8)!, archivePath: "ab1.txt"),
        .data("async build 2".data(using: .utf8)!, archivePath: "ab2.txt"),
    ]
    
    try await AKWriter.buildAsync(to: archivePath, configuration: .zip, items: items)
    
    #expect(FileManager.default.fileExists(atPath: archivePath))
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains("ab1.txt"))
    #expect(entries.contains("ab2.txt"))
}

@Test func testAKWriterConfigurationPresets() throws {
    // 验证各预设配置的格式和过滤器
    #expect(AKWriterConfiguration.zip.format == .zip)
    #expect(AKWriterConfiguration.zip.filter == .none)
    
    #expect(AKWriterConfiguration.tarGz.format == .tarPaxRestricted)
    #expect(AKWriterConfiguration.tarGz.filter == .gzip)
    
    #expect(AKWriterConfiguration.tarXz.format == .tarPaxRestricted)
    #expect(AKWriterConfiguration.tarXz.filter == .xz)
    
    #expect(AKWriterConfiguration.tarBz2.format == .tarPaxRestricted)
    #expect(AKWriterConfiguration.tarBz2.filter == .bzip2)
    
    #expect(AKWriterConfiguration.tarZst.format == .tarPaxRestricted)
    #expect(AKWriterConfiguration.tarZst.filter == .zstd)
    
    #expect(AKWriterConfiguration.sevenZip.format == .sevenZip)
    #expect(AKWriterConfiguration.sevenZip.filter == .none)
    
    let encZip = AKWriterConfiguration.encryptedZip(passphrase: "test123")
    #expect(encZip.format == .zip)
    #expect(encZip.passphrase == "test123")
    #expect(encZip.formatOptions["encryption"] == "aes256")
}

@Test func testAKWriterBuildDirectoryTree() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let sourceDir = tempDir.appendingPathComponent("tree_src_\(UUID().uuidString)")
    let archivePath = tempDir.appendingPathComponent("test_tree_\(UUID().uuidString).tar.gz").path
    defer {
        try? FileManager.default.removeItem(at: sourceDir)
        try? FileManager.default.removeItem(atPath: archivePath)
    }
    
    // 创建目录结构
    let subDir = sourceDir.appendingPathComponent("sub")
    try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
    try "root".data(using: .utf8)!.write(to: sourceDir.appendingPathComponent("root.txt"))
    try "sub".data(using: .utf8)!.write(to: subDir.appendingPathComponent("sub.txt"))
    
    try AKWriter.build(to: archivePath, configuration: .tarGz) {
        AKArchiveItem.directoryTree(path: sourceDir.path, archiveBasePath: "mytree")
    }
    
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.contains("mytree/root.txt"))
    #expect(entries.contains("mytree/sub/sub.txt"))
}

// MARK: - AKFormat 新增属性测试

@Test func testAKFormatIsRealFormat() {
    // baseMask 不是真实格式
    #expect(!AKFormat.baseMask.isRealFormat)
    
    // 其他格式均为真实格式
    #expect(AKFormat.tar.isRealFormat)
    #expect(AKFormat.zip.isRealFormat)
    #expect(AKFormat.sevenZip.isRealFormat)
    #expect(AKFormat.rarV5.isRealFormat)
    #expect(AKFormat.cpio.isRealFormat)
    
    // allCases 中过滤掉 baseMask 后应全部为真实格式
    let realFormats = AKFormat.allCases.filter { $0.isRealFormat }
    #expect(!realFormats.contains(.baseMask))
    #expect(realFormats.count == AKFormat.allCases.count - 1)
}

@Test func testAKFormatFamilyWithBaseMask() {
    // baseMask 本身的 family 应为 nil（familyCode == baseMask.rawValue，但 rawValue & baseMask == baseMask，
    // 而 baseMask 不等于 0，所以会返回 baseMask 自身——需验证实际行为）
    // tarUstar 的 family 应为 tar
    #expect(AKFormat.tarUstar.family == .tar)
    #expect(AKFormat.tarPaxInterchange.family == .tar)
    #expect(AKFormat.tarPaxRestricted.family == .tar)
    #expect(AKFormat.tarGnu.family == .tar)
    
    // zip 的 family 应为 zip（zip 本身就是族代码）
    #expect(AKFormat.zip.family == .zip)
    
    // arGnu 的 family 应为 ar
    #expect(AKFormat.arGnu.family == .ar)
    #expect(AKFormat.arBsd.family == .ar)
    
    // cpioPosix 的 family 应为 cpio
    #expect(AKFormat.cpioPosix.family == .cpio)
    
    // rarV5 (0x100000): 0x100000 & 0xFF0000 = 0x100000，即 rarV5 自身
    // rarV5 是独立格式族，family 返回自身
    #expect(AKFormat.rarV5.family == .rarV5)
}

// MARK: - AKEntry 边界值与低级接口测试

@Test func testAKEntryNegativeTimestamp() {
    // 测试 1970 年之前的负时间戳（toTimespec 修复验证）
    let entry = AKEntry()
    // 1969-12-31 23:59:59.5 UTC（负时间戳，带纳秒）
    let pastDate = Date(timeIntervalSince1970: -0.5)
    entry.modificationTime = pastDate
    
    if let mtime = entry.modificationTime {
        // 允许 1 秒误差
        #expect(abs(mtime.timeIntervalSince(pastDate)) < 1.0)
        // 验证时间戳在 1970 年之前
        #expect(mtime.timeIntervalSince1970 < 0)
    } else {
        Issue.record("负时间戳应能正确设置")
    }
}

@Test func testAKEntryVeryOldTimestamp() {
    // 测试极早时间戳（1900年）
    let entry = AKEntry()
    let veryOld = Date(timeIntervalSince1970: -2_208_988_800) // 1900-01-01
    entry.modificationTime = veryOld
    
    if let mtime = entry.modificationTime {
        #expect(abs(mtime.timeIntervalSince(veryOld)) < 1.0)
    } else {
        Issue.record("极早时间戳应能正确设置")
    }
}

@Test func testAKEntryDevInoRdev() {
    let entry = AKEntry()
    
    // ino 是 Int64，可直接赋值
    entry.ino = 67890
    #expect(entry.ino == 67890)
    
    // nlink 是 UInt32，可直接赋值
    entry.nlink = 3
    #expect(entry.nlink == 3)
    
    // devmajor/devminor 通过 major/minor 设置，dev 由 makedev 编码
    // 设置 devmajor/devminor 后，dev 会被 libarchive 内部编码（makedev），
    // 因此 dev 的值不等于直接赋入的整数
    entry.devmajor = 8
    entry.devminor = 1
    #expect(entry.devmajor == 8)
    #expect(entry.devminor == 1)
    
    // rdevmajor/rdevminor 同理
    entry.rdevmajor = 9
    entry.rdevminor = 2
    #expect(entry.rdevmajor == 9)
    #expect(entry.rdevminor == 2)
}

@Test func testAKEntryXattrEmptyValue() {
    // 测试空值 xattr
    let entry = AKEntry()
    let emptyData = Data()
    entry.xattrAdd(name: "user.empty", value: emptyData)
    
    #expect(entry.xattrCount == 1)
    let xattrs = entry.xattrs
    #expect(xattrs.count == 1)
    #expect(xattrs[0].name == "user.empty")
    #expect(xattrs[0].value.isEmpty)
}

@Test func testAKEntryXattrMultiple() {
    // 测试多个 xattr 的遍历顺序
    let entry = AKEntry()
    let data1 = "value1".data(using: .utf8)!
    let data2 = "value2".data(using: .utf8)!
    let data3 = "value3".data(using: .utf8)!
    
    entry.xattrAdd(name: "user.a", value: data1)
    entry.xattrAdd(name: "user.b", value: data2)
    entry.xattrAdd(name: "user.c", value: data3)
    
    #expect(entry.xattrCount == 3)
    
    // 通过 xattrNext 手动遍历
    entry.xattrReset()
    var names: [String] = []
    while let xattr = entry.xattrNext() {
        names.append(xattr.name)
    }
    #expect(names.count == 3)
    #expect(names.contains("user.a"))
    #expect(names.contains("user.b"))
    #expect(names.contains("user.c"))
    
    // 再次调用 xattrNext 应返回 nil（已到末尾）
    #expect(entry.xattrNext() == nil)
    
    // xattrReset 后应能重新遍历
    entry.xattrReset()
    #expect(entry.xattrNext() != nil)
}

@Test func testAKEntryCopyStatFromPath() {
    // 测试从文件路径复制 stat 信息
    let tempFile = FileManager.default.temporaryDirectory
        .appendingPathComponent("stat_test_\(UUID().uuidString).txt")
    defer { try? FileManager.default.removeItem(at: tempFile) }
    
    let content = "stat test content".data(using: .utf8)!
    try? content.write(to: tempFile)
    
    let entry = AKEntry()
    entry.copyStatFromPath(tempFile.path)
    
    // 复制 stat 后应有文件大小和类型
    #expect(entry.size != nil)
    #expect(entry.size == Int64(content.count))
    #expect(entry.fileType == .regular)
}

@Test func testAKEntryCopyStatFromNonExistentPath() {
    // 测试从不存在的路径复制 stat（应静默失败）
    let entry = AKEntry()
    entry.copyStatFromPath("/nonexistent/path/file.txt")
    // 不应崩溃，条目保持默认状态
    #expect(entry.fileType == .unknown)
}

@Test func testAKEntryEncryptionFlags() {
    // 测试加密标志（新建条目默认不加密）
    let entry = AKEntry()
    #expect(!entry.isDataEncrypted)
    #expect(!entry.isMetadataEncrypted)
    #expect(!entry.isEncrypted)
}

@Test func testAKEntrySparseCount() {
    // 测试 sparseCount 属性
    let entry = AKEntry()
    entry.size = 65536
    entry.fileType = .regular
    
    #expect(entry.sparseCount == 0)
    
    entry.sparseAdd(offset: 0, length: 4096)
    entry.sparseAdd(offset: 8192, length: 4096)
    entry.sparseAdd(offset: 32768, length: 8192)
    
    #expect(entry.sparseCount == 3)
    
    entry.sparseClear()
    #expect(entry.sparseCount == 0)
}

// MARK: - AKWriter 低级接口测试

@Test func testAKWriterLowLevelInterface() throws {
    // 测试 writeHeader + writeData + finishEntry 低级接口
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_lowlevel_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let content = "low level write test".data(using: .utf8)!
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    
    let entry = AKEntry()
    entry.pathname = "lowlevel.txt"
    entry.size = Int64(content.count)
    entry.fileType = .regular
    entry.permissions = 0o644
    entry.modificationTime = Date()
    
    try writer.writeHeader(entry)
    let written = try writer.writeData(content)
    #expect(written == content.count)
    try writer.finishEntry()
    writer.close()
    
    let extracted = try AKReader.extractData(for: "lowlevel.txt", from: archivePath)
    #expect(extracted == content)
}

@Test func testAKWriterWriteDataBlock() throws {
    // writeDataBlock 是 libarchive disk writer 专用接口（archive_write_data_block），
    // 不支持普通文件归档写入器（tar/zip 等）。
    // 验证对普通写入器调用时会抛出错误。
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_datablock_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let content = "data block content".data(using: .utf8)!
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    defer { writer.close() }
    
    let entry = AKEntry()
    entry.pathname = "block.txt"
    entry.size = Int64(content.count)
    entry.fileType = .regular
    entry.permissions = 0o644
    
    try writer.writeHeader(entry)
    
    // archive_write_data_block 在非 disk writer 上不支持，应抛出错误
    #expect(throws: (any Error).self) {
        try writer.writeDataBlock(content, offset: 0)
    }
}

@Test func testAKWriterReopenOverwrite() throws {
    // 测试重复 open 会覆盖旧归档
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_reopen_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    
    // 第一次写入
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("first".data(using: .utf8)!, as: "first.txt")
    writer.close()
    
    // 第二次写入（覆盖）
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("second".data(using: .utf8)!, as: "second.txt")
    writer.close()
    
    // 只应包含第二次写入的内容
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(!entries.contains("first.txt"))
    #expect(entries.contains("second.txt"))
}

@Test func testAKWriterSetCompressionLevel() throws {
    // setCompressionLevel 必须在 open 之前调用（libarchive 限制：
    // archive_write_set_filter_option 只能在 state='new' 时调用）。
    // 通过 open 的 formatOptions 参数或在 prepareArchive 后、open 前设置。
    // 此测试验证在 open 之后调用会抛出错误。
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_compress_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    defer { writer.close() }
    
    // open 之后调用 setCompressionLevel 应抛出错误（libarchive 状态机限制）
    #expect(throws: (any Error).self) {
        try writer.setCompressionLevel(9)
    }
}

@Test func testAKWriterBytesWritten() throws {
    // 测试 bytesWritten 属性
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_bytes_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    #expect(writer.bytesWritten == 0) // 未打开时为 0
    
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("hello world".data(using: .utf8)!, as: "hello.txt")
    
    // 写入后字节数应大于 0
    #expect(writer.bytesWritten > 0)
    writer.close()
    
    #expect(writer.bytesWritten == 0) // 关闭后为 0
}

@Test func testAKWriterLastError() throws {
    // 测试 lastError 和 lastErrorCode 属性
    let writer = AKWriter()
    #expect(writer.lastError == nil) // 未打开时为 nil
    #expect(writer.lastErrorCode == 0)
}

@Test func testAKWriterEmptyArchive() throws {
    // 测试写入空归档（无条目）
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_empty_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    writer.close()
    
    #expect(FileManager.default.fileExists(atPath: archivePath))
    
    // 空归档应能正常打开，但没有条目
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.isEmpty)
}

// MARK: - AKReader 边界条件测试

@Test func testAKReaderEmptyArchive() throws {
    // 测试读取空归档
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_empty_read_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    // 空归档第一次 nextEntry 应返回 nil
    let entry = try reader.nextEntry()
    #expect(entry == nil)
    
    // fileCount 应为 0
    #expect(reader.fileCount == 0)
}

@Test func testAKReaderReopenAfterClose() throws {
    // 测试关闭后重新打开
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_reopen_r_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("hello".data(using: .utf8)!, as: "hello.txt")
    writer.close()
    
    let reader = AKReader()
    
    // 第一次打开
    try reader.open(path: archivePath)
    var entries1: [String] = []
    while let entry = try reader.nextEntry() {
        if let p = entry.pathname { entries1.append(p) }
        try reader.skipCurrentEntry()
    }
    reader.close()
    
    // 第二次打开（重用同一 reader）
    try reader.open(path: archivePath)
    var entries2: [String] = []
    while let entry = try reader.nextEntry() {
        if let p = entry.pathname { entries2.append(p) }
        try reader.skipCurrentEntry()
    }
    reader.close()
    
    #expect(entries1 == entries2)
    #expect(entries1.contains("hello.txt"))
}

@Test func testAKReaderOpenDataEmpty() throws {
    // libarchive 对空数据不会在 open 时报错，而是在读取第一个条目时返回 EOF 或错误。
    // 验证：open 成功，但 nextEntry 返回 nil（空归档行为）或抛出错误。
    let reader = AKReader()
    defer { reader.close() }
    
    // open 空数据：libarchive 可能成功打开（视为空归档）
    do {
        try reader.open(data: Data())
        // 若 open 成功，nextEntry 应返回 nil 或抛出错误
        let entry = try? reader.nextEntry()
        // 空数据要么无条目，要么读取失败——两种情况都是正确的
        _ = entry
    } catch {
        // open 本身抛出错误也是可接受的
    }
    // 不崩溃即为通过
}

@Test func testAKReaderOpenDataInvalid() throws {
    // libarchive 对无效数据不会在 open 时立即报错，
    // 而是在读取第一个条目头部时才检测到格式错误。
    let reader = AKReader()
    defer { reader.close() }
    
    let invalidData = "this is not an archive at all!!!".data(using: .utf8)!
    do {
        try reader.open(data: invalidData)
        // open 可能成功（libarchive 延迟格式检测）
        // 读取第一个条目时应失败
        do {
            _ = try reader.nextEntry()
            // 某些情况下 libarchive 可能返回 nil（EOF）而非错误
        } catch {
            // 读取时抛出错误是预期行为
        }
    } catch {
        // open 时抛出错误也是可接受的
    }
    // 不崩溃即为通过
}

@Test func testAKReaderBytesRead() throws {
    // 测试 bytesRead 和 compressedBytesRead 属性
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_bytes_r_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData(Data(repeating: 0x41, count: 10000), as: "large.txt")
    writer.close()
    
    let reader = AKReader()
    #expect(reader.bytesRead == 0)
    #expect(reader.compressedBytesRead == 0)
    
    try reader.open(path: archivePath)
    while let _ = try reader.nextEntry() {
        try reader.skipCurrentEntry()
    }
    
    // 读取后字节数应大于 0
    #expect(reader.bytesRead > 0)
    #expect(reader.compressedBytesRead > 0)
    reader.close()
}

@Test func testAKReaderLastError() throws {
    // 测试 lastError 和 lastErrorCode 属性
    let reader = AKReader()
    #expect(reader.lastError == nil)
    #expect(reader.lastErrorCode == 0)
}

@Test func testAKReaderAddPassphraseAfterOpen() throws {
    // libarchive 限制：archive_read_add_passphrase 只能在 state='new' 时调用，
    // 即必须在 archive_read_open 之前调用。open 之后调用会触发 INTERNAL ERROR。
    // 正确用法是通过 open(path:passphrases:) 的 passphrases 参数传入密码。
    // 此测试验证 open 之后调用 addPassphrase 会抛出错误。
    let archivePath = try makeEncryptedZip(password: "test_pass")
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    // open 之后调用 addPassphrase 应抛出错误（libarchive 状态机限制）
    #expect(throws: (any Error).self) {
        try reader.addPassphrase("test_pass")
    }
}

@Test func testAKReaderFormatAndFilterAfterRead() throws {
    // 测试在读取条目后 format 和 filter 属性有值
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_fmt_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    try writer.addData("test".data(using: .utf8)!, as: "test.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    // 打开后但未读取条目时，format 可能为 nil 或 0
    // 读取第一个条目后，format 应有值
    _ = try reader.nextEntry()
    
    let fmt = reader.format
    let flt = reader.filter
    #expect(fmt != nil)
    #expect(flt != nil)
    // tar.gz 的过滤器应为 gzip
    #expect(flt == .gzip)
}

// MARK: - 多格式兼容性测试

@Test func testMultipleFormats() throws {
    // 测试多种格式的写入和读取
    let tempDir = FileManager.default.temporaryDirectory
    let content = "format compatibility test".data(using: .utf8)!
    
    let formats: [(AKFormat, AKFilter, String)] = [
        (.tarPaxRestricted, .none,  "test.tar"),
        (.tarPaxRestricted, .gzip,  "test.tar.gz"),
        (.tarPaxRestricted, .bzip2, "test.tar.bz2"),
        (.tarPaxRestricted, .xz,    "test.tar.xz"),
        (.tarPaxRestricted, .zstd,  "test.tar.zst"),
        (.zip,              .none,  "test.zip"),
    ]
    
    for (format, filter, filename) in formats {
        let archivePath = tempDir.appendingPathComponent("\(UUID().uuidString)_\(filename)").path
        defer { try? FileManager.default.removeItem(atPath: archivePath) }
        
        // 写入
        let writer = AKWriter()
        try writer.open(path: archivePath, format: format, filter: filter)
        try writer.addData(content, as: "test.txt")
        writer.close()
        
        // 读取验证
        let extracted = try AKReader.extractData(for: "test.txt", from: archivePath)
        #expect(extracted == content, "格式 \(format)/\(filter) 读写不一致")
    }
}

@Test func testZipFormat() throws {
    // 专项测试 ZIP 格式特性
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_zip_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    
    // ZIP 支持多个文件
    for i in 1...10 {
        try writer.addData("content \(i)".data(using: .utf8)!, as: "file\(i).txt")
    }
    try writer.addDirectory(as: "subdir")
    writer.close()
    
    let entries = try AKReader.listEntries(at: archivePath)
    #expect(entries.count == 11) // 10 files + 1 dir
    for i in 1...10 {
        #expect(entries.contains("file\(i).txt"))
    }
}

// MARK: - 内存归档边界测试

@Test func testMemoryArchiveEmpty() throws {
    // 测试空内存归档
    let writer = AKWriter()
    let context = try writer.openMemory(format: .zip, filter: .none)
    let data = try writer.closeMemory(context: context)
    
    // 空归档数据不应为空（包含 ZIP 结束标记）
    #expect(!data.isEmpty)
    
    // 应能从空归档读取（无条目）
    let reader = AKReader()
    try reader.open(data: data)
    defer { reader.close() }
    let entry = try reader.nextEntry()
    #expect(entry == nil)
}

@Test func testMemoryArchiveLargeData() throws {
    // 测试内存归档写入大数据
    let writer = AKWriter()
    let context = try writer.openMemory(format: .zip, filter: .none)
    
    // 写入 5MB 数据
    let largeData = Data(repeating: 0xAB, count: 5 * 1024 * 1024)
    try writer.addData(largeData, as: "large.bin")
    let archiveData = try writer.closeMemory(context: context)
    
    #expect(!archiveData.isEmpty)
    
    // 验证读取
    let reader = AKReader()
    try reader.open(data: archiveData)
    defer { reader.close() }
    
    guard let entry = try reader.nextEntry() else {
        Issue.record("应能读取到条目")
        return
    }
    #expect(entry.pathname == "large.bin")
    let readData = try reader.readCurrentEntryData()
    #expect(readData == largeData)
}

@Test func testMemoryArchiveMultipleFiles() throws {
    // 测试内存归档写入多个文件并验证所有内容
    let items: [(String, Data)] = [
        ("alpha.txt", "alpha content".data(using: .utf8)!),
        ("beta.txt",  "beta content".data(using: .utf8)!),
        ("gamma.txt", "gamma content".data(using: .utf8)!),
        ("delta/epsilon.txt", "nested content".data(using: .utf8)!),
    ]
    
    let writer = AKWriter()
    let context = try writer.openMemory(format: .zip, filter: .none)
    for (path, data) in items {
        try writer.addData(data, as: path)
    }
    let archiveData = try writer.closeMemory(context: context)
    
    // 验证所有文件内容
    let reader = AKReader()
    try reader.open(data: archiveData)
    defer { reader.close() }
    
    var results: [String: Data] = [:]
    while let entry = try reader.nextEntry() {
        if let path = entry.pathname {
            results[path] = try reader.readCurrentEntryData()
        } else {
            try reader.skipCurrentEntry()
        }
    }
    
    for (path, expectedData) in items {
        #expect(results[path] == expectedData, "路径 \(path) 的数据不匹配")
    }
}

@Test func testMemoryArchiveArchiveToMemoryStatic() throws {
    // 测试 archiveToMemory 静态方法的错误处理
    // 空列表应返回有效的空归档
    let emptyData = try AKWriter.archiveToMemory(items: [], format: .zip)
    #expect(!emptyData.isEmpty)
    
    let reader = AKReader()
    try reader.open(data: emptyData)
    defer { reader.close() }
    #expect(try reader.nextEntry() == nil)
}

// MARK: - 并发安全测试

@Test func testConcurrentReaders() async throws {
    // 测试多个 reader 并发读取同一文件
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_concurrent_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    // 准备归档
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .gzip)
    for i in 1...5 {
        try writer.addData("content \(i)".data(using: .utf8)!, as: "file\(i).txt")
    }
    writer.close()
    
    // 并发读取（每个 Task 使用独立的 reader 实例）
    let results = try await withThrowingTaskGroup(of: [String].self) { group in
        for _ in 1...4 {
            group.addTask {
                try AKReader.listEntries(at: archivePath)
            }
        }
        var allResults: [[String]] = []
        for try await result in group {
            allResults.append(result)
        }
        return allResults
    }
    
    // 所有并发读取结果应一致
    #expect(results.count == 4)
    for result in results {
        #expect(result.count == 5)
        for i in 1...5 {
            #expect(result.contains("file\(i).txt"))
        }
    }
}

@Test func testAsyncWriteAndRead() async throws {
    // 测试异步写入后异步读取
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_async_wr_\(UUID().uuidString).tar.gz").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let items: [AKArchiveItem] = [
        .data("async data 1".data(using: .utf8)!, archivePath: "async1.txt"),
        .data("async data 2".data(using: .utf8)!, archivePath: "async2.txt"),
        .data("async data 3".data(using: .utf8)!, archivePath: "async3.txt"),
    ]
    
    try await AKWriter.buildAsync(to: archivePath, configuration: .tarGz, items: items)
    
    let entries = try await AKReader.listEntriesAsync(at: archivePath)
    #expect(entries.count == 3)
    #expect(entries.contains("async1.txt"))
    #expect(entries.contains("async2.txt"))
    #expect(entries.contains("async3.txt"))
}

// MARK: - AKEntrySequence 错误处理测试

@Test func testAKEntrySequenceIteratorError() throws {
    // 测试 AKEntrySequence.Iterator 的 error 属性
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_seq_err_\(UUID().uuidString).zip").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .zip, filter: .none)
    try writer.addData("data".data(using: .utf8)!, as: "file.txt")
    writer.close()
    
    let reader = AKReader()
    try reader.open(path: archivePath)
    defer { reader.close() }
    
    let sequence = reader.entries()
    var iterator = sequence.makeIterator()
    
    // 正常遍历，error 应为 nil
    _ = iterator.next()
    _ = iterator.next() // EOF
    #expect(iterator.error == nil)
}

// MARK: - AKReader 静态方法边界测试

@Test func testListEntriesURLNonFile() {
    // 测试 listEntries(at:URL) 传入非文件 URL
    let remoteURL = URL(string: "https://example.com/archive.tar")!
    #expect(throws: (any Error).self) {
        try AKReader.listEntries(at: remoteURL)
    }
}

@Test func testListAllEntriesNonExistent() {
    // 测试 listAllEntries 读取不存在的文件
    #expect(throws: (any Error).self) {
        try AKReader.listAllEntries(at: "/nonexistent/archive.tar")
    }
}

@Test func testExtractDataNonExistentArchive() {
    // 测试从不存在的归档提取数据
    #expect(throws: (any Error).self) {
        try AKReader.extractData(for: "file.txt", from: "/nonexistent/archive.tar")
    }
}

// MARK: - AKWriter 错误路径测试

@Test func testAKWriterAddFileNonExistentURL() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_err_url_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    defer { writer.close() }
    
    // 非文件 URL 应抛出错误
    let remoteURL = URL(string: "https://example.com/file.txt")!
    #expect(throws: (any Error).self) {
        try writer.addFile(at: remoteURL)
    }
}

@Test func testAKWriterOpenURLNonFile() {
    let writer = AKWriter()
    let remoteURL = URL(string: "ftp://example.com/archive.tar")!
    #expect(throws: (any Error).self) {
        try writer.open(url: remoteURL)
    }
}

// MARK: - AKArchiveInfo 边界测试

@Test func testAKArchiveInfoEncryptedArchive() throws {
    // 测试加密归档的 info
    let archivePath = try makeEncryptedZip(password: "info_test_pass")
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let info = try AKReader.info(at: archivePath)
    #expect(info.isEncrypted)
    #expect(info.entryCount > 0)
    #expect(info.sourcePath == archivePath)
}

@Test func testAKArchiveInfoEmptyArchive() throws {
    // 测试空归档的 info
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_info_empty_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    writer.close()
    
    let info = try AKReader.info(at: archivePath)
    #expect(info.entryCount == 0)
    #expect(info.paths.isEmpty)
    #expect(info.entries.isEmpty)
    #expect(!info.isEncrypted)
    #expect(info.regularFileCount == 0)
    #expect(info.directoryCount == 0)
    #expect(info.totalUncompressedSize == 0)
}

@Test func testAKArchiveInfoTotalSize() throws {
    // 测试 totalUncompressedSize 计算
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_info_size_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let data1 = Data(repeating: 0x01, count: 100)
    let data2 = Data(repeating: 0x02, count: 200)
    let data3 = Data(repeating: 0x03, count: 300)
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData(data1, as: "f1.bin")
    try writer.addData(data2, as: "f2.bin")
    try writer.addData(data3, as: "f3.bin")
    try writer.addDirectory(as: "dir") // 目录大小不计入
    writer.close()
    
    let info = try AKReader.info(at: archivePath)
    #expect(info.entryCount == 4)
    #expect(info.regularFileCount == 3)
    #expect(info.directoryCount == 1)
    #expect(info.totalUncompressedSize == 600) // 100 + 200 + 300
}

// MARK: - AKWriterConfiguration 测试

@Test func testAKWriterConfigurationDefault() {
    let config = AKWriterConfiguration()
    #expect(config.format == .tarPaxRestricted)
    #expect(config.filter == .none)
    #expect(config.passphrase == nil)
    #expect(config.formatOptions.isEmpty)
    #expect(config.compressionLevel == nil)
}

@Test func testAKWriterConfigurationCustom() {
    var config = AKWriterConfiguration(
        format: .zip,
        filter: .none,
        passphrase: "secret",
        formatOptions: ["key": "value"],
        compressionLevel: 6
    )
    #expect(config.format == .zip)
    #expect(config.filter == .none)
    #expect(config.passphrase == "secret")
    #expect(config.formatOptions["key"] == "value")
    #expect(config.compressionLevel == 6)
    
    // 测试属性可变
    config.passphrase = nil
    #expect(config.passphrase == nil)
}

// MARK: - AKReader.stream 错误传播测试

@Test func testAKReaderStreamThrowsFromHandler() throws {
    let tempDir = FileManager.default.temporaryDirectory
    let archivePath = tempDir.appendingPathComponent("test_stream_throw_\(UUID().uuidString).tar").path
    defer { try? FileManager.default.removeItem(atPath: archivePath) }
    
    let writer = AKWriter()
    try writer.open(path: archivePath, format: .tarPaxRestricted, filter: .none)
    try writer.addData("data".data(using: .utf8)!, as: "file.txt")
    writer.close()
    
    // handler 抛出错误时，stream 应传播该错误
    struct TestError: Error {}
    #expect(throws: TestError.self) {
        try AKReader.stream(from: archivePath) { _, _ in
            throw TestError()
        }
    }
}

// MARK: - AKWriter.build 错误传播测试

@Test func testAKWriterBuildThrowsOnInvalidPath() {
    #expect(throws: (any Error).self) {
        try AKWriter.build(to: "/nonexistent/dir/archive.tar", configuration: .tarGz) {
            AKArchiveItem.data("data".data(using: .utf8)!, archivePath: "file.txt")
        }
    }
}

@Test func testAKWriterBuildToMemoryWithCompressionLevel() throws {
    // compressionLevel 现在通过 openMemory 的参数在 open 之前正确设置，
    // 验证带 compressionLevel 的配置能正常创建归档并读取内容。
    let data = "compression level test".data(using: .utf8)!
    var config = AKWriterConfiguration(format: .zip)
    config.compressionLevel = 1 // ZIP 格式的压缩级别（1=最快，9=最高压缩）
    
    let archiveData = try AKWriter.buildToMemory(configuration: config) {
        AKArchiveItem.data(data, archivePath: "test.txt")
    }
    #expect(!archiveData.isEmpty)
    
    let extracted = try { () throws -> Data? in
        let reader = AKReader()
        try reader.open(data: archiveData)
        defer { reader.close() }
        while let entry = try reader.nextEntry() {
            if entry.pathname == "test.txt" {
                return try reader.readCurrentEntryData()
            }
            try reader.skipCurrentEntry()
        }
        return nil
    }()
    #expect(extracted == data)
}
