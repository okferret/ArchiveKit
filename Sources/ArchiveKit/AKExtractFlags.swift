// AKExtractFlags.swift
// ArchiveKit - libarchive Swift 封装
//
// 解压标志定义

/// 解压操作标志
/// 对应 libarchive 的 ARCHIVE_EXTRACT_* 常量
public struct AKExtractFlags: OptionSet, CustomStringConvertible, Sendable {
    public let rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    /// 恢复文件所有者/组
    public static let owner               = AKExtractFlags(rawValue: 0x0001)
    
    /// 恢复文件权限（遵守 umask）
    public static let permissions         = AKExtractFlags(rawValue: 0x0002)
    
    /// 恢复修改时间和访问时间
    public static let time                = AKExtractFlags(rawValue: 0x0004)
    
    /// 不覆盖已存在的文件
    public static let noOverwrite         = AKExtractFlags(rawValue: 0x0008)
    
    /// 解压前先删除已存在的文件
    public static let unlink              = AKExtractFlags(rawValue: 0x0010)
    
    /// 恢复 ACL
    public static let acl                 = AKExtractFlags(rawValue: 0x0020)
    
    /// 恢复文件标志（fflags）
    public static let fflags              = AKExtractFlags(rawValue: 0x0040)
    
    /// 恢复扩展属性（xattrs）
    public static let xattr               = AKExtractFlags(rawValue: 0x0080)
    
    /// 防止符号链接重定向攻击
    public static let secureSymlinks      = AKExtractFlags(rawValue: 0x0100)
    
    /// 拒绝包含 '..' 的路径
    public static let secureNoDotDot      = AKExtractFlags(rawValue: 0x0200)
    
    /// 不自动创建父目录
    public static let noAutoDir           = AKExtractFlags(rawValue: 0x0400)
    
    /// 不覆盖比归档中更新的文件
    public static let noOverwriteNewer    = AKExtractFlags(rawValue: 0x0800)
    
    /// 检测全零块并写入稀疏文件
    public static let sparse              = AKExtractFlags(rawValue: 0x1000)
    
    /// 恢复 Mac 扩展元数据（仅 macOS）
    public static let macMetadata         = AKExtractFlags(rawValue: 0x2000)
    
    /// 不使用 HFS+ 压缩（仅 macOS 10.6+）
    public static let noHFSCompression    = AKExtractFlags(rawValue: 0x4000)
    
    /// 强制使用 HFS+ 压缩（仅 macOS 10.6+）
    public static let hfsCompressionForced = AKExtractFlags(rawValue: 0x8000)
    
    /// 拒绝绝对路径
    public static let secureNoAbsolutePaths = AKExtractFlags(rawValue: 0x10000)
    
    /// 解除 no-change 标志后再删除
    public static let clearNoChangeFlags  = AKExtractFlags(rawValue: 0x20000)
    
    /// 使用原子写入（rename）
    public static let safeWrites          = AKExtractFlags(rawValue: 0x40000)
    
    // MARK: - 预设组合
    
    /// 常用安全解压组合（防止路径穿越攻击）
    public static let safe: AKExtractFlags = [.secureSymlinks, .secureNoDotDot, .secureNoAbsolutePaths]
    
    /// 标准解压组合（恢复时间、权限，安全模式）
    public static let standard: AKExtractFlags = [.time, .permissions, .safe]
    
    /// 完整恢复组合（尽可能恢复所有元数据）
    public static let full: AKExtractFlags = [.owner, .permissions, .time, .acl, .fflags, .xattr, .safe]
    
    public var description: String {
        var parts: [String] = []
        if contains(.owner)                  { parts.append("owner") }
        if contains(.permissions)            { parts.append("permissions") }
        if contains(.time)                   { parts.append("time") }
        if contains(.noOverwrite)            { parts.append("noOverwrite") }
        if contains(.unlink)                 { parts.append("unlink") }
        if contains(.acl)                    { parts.append("acl") }
        if contains(.fflags)                 { parts.append("fflags") }
        if contains(.xattr)                  { parts.append("xattr") }
        if contains(.secureSymlinks)         { parts.append("secureSymlinks") }
        if contains(.secureNoDotDot)         { parts.append("secureNoDotDot") }
        if contains(.noAutoDir)              { parts.append("noAutoDir") }
        if contains(.noOverwriteNewer)       { parts.append("noOverwriteNewer") }
        if contains(.sparse)                 { parts.append("sparse") }
        if contains(.macMetadata)            { parts.append("macMetadata") }
        if contains(.noHFSCompression)       { parts.append("noHFSCompression") }
        if contains(.hfsCompressionForced)   { parts.append("hfsCompressionForced") }
        if contains(.secureNoAbsolutePaths)  { parts.append("secureNoAbsolutePaths") }
        if contains(.clearNoChangeFlags)     { parts.append("clearNoChangeFlags") }
        if contains(.safeWrites)             { parts.append("safeWrites") }
        return "AKExtractFlags([\(parts.joined(separator: ", "))])"
    }
}
