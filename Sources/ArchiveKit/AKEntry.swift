// AKEntry.swift
// ArchiveKit - libarchive Swift 封装
//
// 归档条目封装

import Foundation
internal import libarchive

/// 归档条目文件类型
public enum AKEntryFileType: UInt32, CustomStringConvertible {
    /// 普通文件
    case regular        = 0o100000  // AE_IFREG
    /// 符号链接
    case symbolicLink   = 0o120000  // AE_IFLNK
    /// Socket 文件
    case socket         = 0o140000  // AE_IFSOCK
    /// 字符设备
    case characterDevice = 0o020000 // AE_IFCHR
    /// 块设备
    case blockDevice    = 0o060000  // AE_IFBLK
    /// 目录
    case directory      = 0o040000  // AE_IFDIR
    /// FIFO 管道
    case fifo           = 0o010000  // AE_IFIFO
    /// 未知类型
    case unknown        = 0
    
    public var description: String {
        switch self {
        case .regular:          return "regular"
        case .symbolicLink:     return "symlink"
        case .socket:           return "socket"
        case .characterDevice:  return "char_device"
        case .blockDevice:      return "block_device"
        case .directory:        return "directory"
        case .fifo:             return "fifo"
        case .unknown:          return "unknown"
        }
    }
}

/// 符号链接类型（archive_entry_symlink_type）
public enum AKSymlinkType: Int32, CustomStringConvertible {
    /// 未定义
    case undefined  = 0  // AE_SYMLINK_TYPE_UNDEFINED
    /// 文件符号链接
    case file       = 1  // AE_SYMLINK_TYPE_FILE
    /// 目录符号链接
    case directory  = 2  // AE_SYMLINK_TYPE_DIRECTORY
    
    public var description: String {
        switch self {
        case .undefined:    return "undefined"
        case .file:         return "file"
        case .directory:    return "directory"
        }
    }
}

/// 归档条目摘要类型
public enum AKEntryDigestType: Int32 {
    case md5    = 0  // ARCHIVE_ENTRY_DIGEST_MD5
    case rmd160 = 1  // ARCHIVE_ENTRY_DIGEST_RMD160
    case sha1   = 2  // ARCHIVE_ENTRY_DIGEST_SHA1
    case sha256 = 3  // ARCHIVE_ENTRY_DIGEST_SHA256
    case sha384 = 4  // ARCHIVE_ENTRY_DIGEST_SHA384
    case sha512 = 5  // ARCHIVE_ENTRY_DIGEST_SHA512
}

/// 归档条目，封装 libarchive 的 archive_entry
///
/// - Note: `@unchecked Sendable` — libarchive 的 archive_entry 指针本身不是线程安全的，
///   调用方需确保不在多个线程中并发访问同一个 AKEntry 实例。
public final class AKEntry: @unchecked Sendable {
    
    // MARK: - 内部属性
    
    internal let pointer: OpaquePointer
    private let owned: Bool
    
    // MARK: - 初始化
    
    /// 创建新的空条目
    /// - Note: `archive_entry_new()` 在内存不足时理论上可能返回 nil，
    ///   此处做防御性检查，失败时触发 fatalError（与 Swift 标准库对 OOM 的处理一致）。
    public init() {
        guard let ptr = archive_entry_new() else {
            fatalError("archive_entry_new() 返回 nil：内存不足")
        }
        self.pointer = ptr
        self.owned = true
    }
    
    /// 从已有的 archive_entry 指针创建（不拥有所有权）
    internal init(borrowing pointer: OpaquePointer) {
        self.pointer = pointer
        self.owned = false
    }
    
    /// 从已有的 archive_entry 指针创建（拥有所有权）
    internal init(owning pointer: OpaquePointer) {
        self.pointer = pointer
        self.owned = true
    }
    
    deinit {
        if owned {
            archive_entry_free(pointer)
        }
    }
    
    // MARK: - 路径名
    
    /// 条目路径名（UTF-8）
    public var pathname: String? {
        get {
            guard let cStr = archive_entry_pathname_utf8(pointer) else {
                // 回退到非 UTF-8 版本
                guard let cStr2 = archive_entry_pathname(pointer) else { return nil }
                return String(cString: cStr2)
            }
            return String(cString: cStr)
        }
        set {
            if let value = newValue {
                archive_entry_set_pathname_utf8(pointer, value)
            } else {
                archive_entry_set_pathname(pointer, nil)
            }
        }
    }
    
    /// 源路径（用于磁盘读取时的实际路径）
    public var sourcepath: String? {
        guard let cStr = archive_entry_sourcepath(pointer) else { return nil }
        return String(cString: cStr)
    }
    
    // MARK: - 文件大小
    
    /// 条目大小（字节），未设置时为 nil
    public var size: Int64? {
        get {
            guard archive_entry_size_is_set(pointer) != 0 else { return nil }
            return archive_entry_size(pointer)
        }
        set {
            if let value = newValue {
                archive_entry_set_size(pointer, value)
            } else {
                archive_entry_unset_size(pointer)
            }
        }
    }
    
    // MARK: - 文件类型与模式
    
    /// 文件类型
    public var fileType: AKEntryFileType {
        get {
            let mode = archive_entry_filetype(pointer)
            return AKEntryFileType(rawValue: UInt32(mode)) ?? .unknown
        }
        set {
            archive_entry_set_filetype(pointer, newValue.rawValue)
        }
    }
    
    /// 完整的 stat 模式（文件类型 + 权限位）
    public var mode: mode_t {
        get { archive_entry_mode(pointer) }
        set { archive_entry_set_mode(pointer, newValue) }
    }
    
    /// 模式的字符串表示（如 "-rwxr-xr-x"）
    public var strmode: String {
        guard let cStr = archive_entry_strmode(pointer) else { return "----------" }
        return String(cString: cStr)
    }
    
    /// 是否为普通文件
    public var isRegularFile: Bool { fileType == .regular }
    
    /// 是否为目录
    public var isDirectory: Bool { fileType == .directory }
    
    /// 是否为符号链接
    public var isSymbolicLink: Bool { fileType == .symbolicLink }
    
    /// 是否为块设备
    public var isBlockDevice: Bool { fileType == .blockDevice }
    
    /// 是否为字符设备
    public var isCharacterDevice: Bool { fileType == .characterDevice }
    
    /// 是否为 FIFO
    public var isFIFO: Bool { fileType == .fifo }
    
    /// 是否为 Socket
    public var isSocket: Bool { fileType == .socket }
    
    // MARK: - 权限
    
    /// 文件权限（Unix 权限位，不含文件类型位）
    public var permissions: UInt16 {
        get { UInt16(archive_entry_perm(pointer)) }
        set { archive_entry_set_perm(pointer, mode_t(newValue)) }
    }
    
    // MARK: - 时间戳
    
    /// 修改时间（mtime）
    public var modificationTime: Date? {
        get {
            guard archive_entry_mtime_is_set(pointer) != 0 else { return nil }
            let sec = archive_entry_mtime(pointer)
            let nsec = archive_entry_mtime_nsec(pointer)
            return Date(timeIntervalSince1970: TimeInterval(sec) + TimeInterval(nsec) / 1_000_000_000)
        }
        set {
            if let date = newValue {
                let (sec, nsec) = date.toTimespec()
                archive_entry_set_mtime(pointer, sec, nsec)
            } else {
                archive_entry_unset_mtime(pointer)
            }
        }
    }
    
    /// 访问时间（atime）
    public var accessTime: Date? {
        get {
            guard archive_entry_atime_is_set(pointer) != 0 else { return nil }
            let sec = archive_entry_atime(pointer)
            let nsec = archive_entry_atime_nsec(pointer)
            return Date(timeIntervalSince1970: TimeInterval(sec) + TimeInterval(nsec) / 1_000_000_000)
        }
        set {
            if let date = newValue {
                let (sec, nsec) = date.toTimespec()
                archive_entry_set_atime(pointer, sec, nsec)
            } else {
                archive_entry_unset_atime(pointer)
            }
        }
    }
    
    /// 状态变更时间（ctime）
    public var changeTime: Date? {
        get {
            guard archive_entry_ctime_is_set(pointer) != 0 else { return nil }
            let sec = archive_entry_ctime(pointer)
            let nsec = archive_entry_ctime_nsec(pointer)
            return Date(timeIntervalSince1970: TimeInterval(sec) + TimeInterval(nsec) / 1_000_000_000)
        }
        set {
            if let date = newValue {
                let (sec, nsec) = date.toTimespec()
                archive_entry_set_ctime(pointer, sec, nsec)
            } else {
                archive_entry_unset_ctime(pointer)
            }
        }
    }
    
    /// 文件创建时间（birthtime），仅部分平台/格式支持
    public var birthTime: Date? {
        get {
            guard archive_entry_birthtime_is_set(pointer) != 0 else { return nil }
            let sec = archive_entry_birthtime(pointer)
            let nsec = archive_entry_birthtime_nsec(pointer)
            return Date(timeIntervalSince1970: TimeInterval(sec) + TimeInterval(nsec) / 1_000_000_000)
        }
        set {
            if let date = newValue {
                let (sec, nsec) = date.toTimespec()
                archive_entry_set_birthtime(pointer, sec, nsec)
            } else {
                archive_entry_unset_birthtime(pointer)
            }
        }
    }
    
    // MARK: - 链接
    
    /// 符号链接目标路径
    public var symlinkTarget: String? {
        get {
            guard let cStr = archive_entry_symlink_utf8(pointer) else {
                guard let cStr2 = archive_entry_symlink(pointer) else { return nil }
                return String(cString: cStr2)
            }
            return String(cString: cStr)
        }
        set {
            archive_entry_set_symlink_utf8(pointer, newValue)
        }
    }
    
    /// 符号链接类型
    public var symlinkType: AKSymlinkType {
        get {
            let t = archive_entry_symlink_type(pointer)
            return AKSymlinkType(rawValue: t) ?? .undefined
        }
        set {
            archive_entry_set_symlink_type(pointer, newValue.rawValue)
        }
    }
    
    /// 硬链接目标路径
    public var hardlinkTarget: String? {
        get {
            guard let cStr = archive_entry_hardlink_utf8(pointer) else {
                guard let cStr2 = archive_entry_hardlink(pointer) else { return nil }
                return String(cString: cStr2)
            }
            return String(cString: cStr)
        }
        set {
            archive_entry_set_hardlink_utf8(pointer, newValue)
        }
    }
    
    // MARK: - 用户/组
    
    /// 用户 ID
    public var uid: Int64 {
        get { archive_entry_uid(pointer) }
        set { archive_entry_set_uid(pointer, newValue) }
    }
    
    /// 组 ID
    public var gid: Int64 {
        get { archive_entry_gid(pointer) }
        set { archive_entry_set_gid(pointer, newValue) }
    }
    
    /// 用户名
    public var userName: String? {
        get {
            guard let cStr = archive_entry_uname_utf8(pointer) else {
                guard let cStr2 = archive_entry_uname(pointer) else { return nil }
                return String(cString: cStr2)
            }
            return String(cString: cStr)
        }
        set {
            archive_entry_set_uname_utf8(pointer, newValue)
        }
    }
    
    /// 组名
    public var groupName: String? {
        get {
            guard let cStr = archive_entry_gname_utf8(pointer) else {
                guard let cStr2 = archive_entry_gname(pointer) else { return nil }
                return String(cString: cStr2)
            }
            return String(cString: cStr)
        }
        set {
            archive_entry_set_gname_utf8(pointer, newValue)
        }
    }
    
    // MARK: - 设备/Inode
    
    /// 设备号（dev）
    public var dev: dev_t {
        get { archive_entry_dev(pointer) }
        set { archive_entry_set_dev(pointer, newValue) }
    }
    
    /// 主设备号
    public var devmajor: dev_t {
        get { archive_entry_devmajor(pointer) }
        set { archive_entry_set_devmajor(pointer, newValue) }
    }
    
    /// 次设备号
    public var devminor: dev_t {
        get { archive_entry_devminor(pointer) }
        set { archive_entry_set_devminor(pointer, newValue) }
    }
    
    /// Inode 号
    public var ino: Int64 {
        get { archive_entry_ino64(pointer) }
        set { archive_entry_set_ino64(pointer, newValue) }
    }
    
    /// 硬链接数
    public var nlink: UInt32 {
        get { archive_entry_nlink(pointer) }
        set { archive_entry_set_nlink(pointer, newValue) }
    }
    
    /// 特殊设备号（用于字符/块设备）
    public var rdev: dev_t {
        get { archive_entry_rdev(pointer) }
        set { archive_entry_set_rdev(pointer, newValue) }
    }
    
    /// 特殊设备主号
    public var rdevmajor: dev_t {
        get { archive_entry_rdevmajor(pointer) }
        set { archive_entry_set_rdevmajor(pointer, newValue) }
    }
    
    /// 特殊设备次号
    public var rdevminor: dev_t {
        get { archive_entry_rdevminor(pointer) }
        set { archive_entry_set_rdevminor(pointer, newValue) }
    }
    
    // MARK: - 加密
    
    /// 数据是否加密
    public var isDataEncrypted: Bool {
        archive_entry_is_data_encrypted(pointer) != 0
    }
    
    /// 元数据是否加密
    public var isMetadataEncrypted: Bool {
        archive_entry_is_metadata_encrypted(pointer) != 0
    }
    
    /// 是否加密（数据或元数据）
    public var isEncrypted: Bool {
        archive_entry_is_encrypted(pointer) != 0
    }
    
    // MARK: - 扩展属性（xattr）
    
    /// 重置扩展属性遍历游标
    public func xattrReset() {
        archive_entry_xattr_reset(pointer)
    }
    
    /// 获取下一个扩展属性
    /// - Returns: (name, value) 元组，遍历结束时返回 nil
    ///
    /// - Note: 空值 xattr（value 指针为 nil 但 size == 0）是合法的，
    ///   此时返回 (name, Data())，而非 nil。
    public func xattrNext() -> (name: String, value: Data)? {
        var name: UnsafePointer<CChar>? = nil
        var value: UnsafeRawPointer? = nil
        var size: Int = 0
        let result = archive_entry_xattr_next(pointer, &name, &value, &size)
        // result != ARCHIVE_OK 或 name 为 nil 时表示遍历结束
        guard result == AKError.ARCHIVE_OK, let namePtr = name else { return nil }
        let nameStr = String(cString: namePtr)
        // value 可能为 nil（空值 xattr，size == 0），此时返回空 Data
        let data: Data
        if let valuePtr = value, size > 0 {
            data = Data(bytes: valuePtr, count: size)
        } else {
            data = Data()
        }
        return (nameStr, data)
    }
    
    /// 添加扩展属性
    /// - Parameters:
    ///   - name: 属性名
    ///   - value: 属性值
    public func xattrAdd(name: String, value: Data) {
        value.withUnsafeBytes { bytes in
            archive_entry_xattr_add_entry(pointer, name, bytes.baseAddress, bytes.count)
        }
    }
    
    /// 清空所有扩展属性
    public func xattrClear() {
        archive_entry_xattr_clear(pointer)
    }
    
    /// 扩展属性数量
    public var xattrCount: Int {
        Int(archive_entry_xattr_count(pointer))
    }
    
    /// 获取所有扩展属性
    public var xattrs: [(name: String, value: Data)] {
        xattrReset()
        var result: [(name: String, value: Data)] = []
        while let xattr = xattrNext() {
            result.append(xattr)
        }
        return result
    }
    
    // MARK: - 稀疏文件（sparse）
    
    /// 重置稀疏区域遍历游标
    public func sparseReset() {
        archive_entry_sparse_reset(pointer)
    }
    
    /// 获取下一个稀疏区域
    /// - Returns: (offset, length) 元组，遍历结束时返回 nil
    public func sparseNext() -> (offset: Int64, length: Int64)? {
        var offset: Int64 = 0
        var length: Int64 = 0
        let result = archive_entry_sparse_next(pointer, &offset, &length)
        guard result == AKError.ARCHIVE_OK else { return nil }
        return (offset, length)
    }
    
    /// 添加稀疏区域
    /// - Parameters:
    ///   - offset: 起始偏移
    ///   - length: 长度
    public func sparseAdd(offset: Int64, length: Int64) {
        archive_entry_sparse_add_entry(pointer, offset, length)
    }
    
    /// 清空所有稀疏区域
    public func sparseClear() {
        archive_entry_sparse_clear(pointer)
    }
    
    /// 稀疏区域数量
    public var sparseCount: Int {
        Int(archive_entry_sparse_count(pointer))
    }
    
    // MARK: - 克隆与清空
    
    /// 深拷贝当前条目
    public func clone() -> AKEntry? {
        guard let cloned = archive_entry_clone(pointer) else { return nil }
        return AKEntry(owning: cloned)
    }
    
    /// 清空条目内容（保留指针，重置所有字段）
    @discardableResult
    public func clear() -> AKEntry {
        archive_entry_clear(pointer)
        return self
    }
    
    // MARK: - 从 stat 结构复制
    
    /// 从文件路径复制 stat 信息到条目
    /// - Parameter path: 文件路径
    public func copyStatFromPath(_ path: String) {
        var st = stat()
        if lstat(path, &st) == 0 {
            archive_entry_copy_stat(pointer, &st)
        }
    }
}

// MARK: - CustomStringConvertible
extension AKEntry: CustomStringConvertible {
    public var description: String {
        let path = pathname ?? "(unknown)"
        let type = fileType.description
        let sizeStr = size.map { "\($0) bytes" } ?? "unknown size"
        return "AKEntry(\(type): \(path), \(sizeStr))"
    }
}

// MARK: - 内部辅助扩展
private extension Date {
    /// 将 Date 转换为 (seconds, nanoseconds) 元组
    ///
    /// 修复：对于 1970 年之前的负时间戳，直接截断会导致 nsec 为负值，
    /// 而 libarchive 要求 nsec 在 [0, 999_999_999] 范围内。
    /// 使用 floor 向下取整确保 sec 始终 ≤ interval，nsec 始终 ≥ 0。
    func toTimespec() -> (time_t, Int) {
        let interval = timeIntervalSince1970
        let secDouble = floor(interval)
        let sec = time_t(secDouble)
        let nsec = Int((interval - secDouble) * 1_000_000_000)
        // 防御性夹紧，确保 nsec 在合法范围内
        let clampedNsec = max(0, min(nsec, 999_999_999))
        return (sec, clampedNsec)
    }
}
