// AKFilter.swift
// ArchiveKit - libarchive Swift 封装
//
// 过滤器类型定义

/// 归档过滤器类型
/// 对应 libarchive 的 ARCHIVE_FILTER_* 常量
public enum AKFilter: Int32, CaseIterable, CustomStringConvertible, Sendable {
    
    /// 无压缩
    case none       = 0  // ARCHIVE_FILTER_NONE
    
    /// gzip 压缩
    case gzip       = 1  // ARCHIVE_FILTER_GZIP
    
    /// bzip2 压缩
    case bzip2      = 2  // ARCHIVE_FILTER_BZIP2
    
    /// compress 压缩
    case compress   = 3  // ARCHIVE_FILTER_COMPRESS
    
    /// 外部程序
    case program    = 4  // ARCHIVE_FILTER_PROGRAM
    
    /// lzma 压缩
    case lzma       = 5  // ARCHIVE_FILTER_LZMA
    
    /// xz 压缩
    case xz         = 6  // ARCHIVE_FILTER_XZ
    
    /// uu 编码
    case uu         = 7  // ARCHIVE_FILTER_UU
    
    /// rpm 格式
    case rpm        = 8  // ARCHIVE_FILTER_RPM
    
    /// lzip 压缩
    case lzip       = 9  // ARCHIVE_FILTER_LZIP
    
    /// lrzip 压缩
    case lrzip      = 10 // ARCHIVE_FILTER_LRZIP
    
    /// lzop 压缩
    case lzop       = 11 // ARCHIVE_FILTER_LZOP
    
    /// grzip 压缩
    case grzip      = 12 // ARCHIVE_FILTER_GRZIP
    
    /// lz4 压缩
    case lz4        = 13 // ARCHIVE_FILTER_LZ4
    
    /// zstd 压缩
    case zstd       = 14 // ARCHIVE_FILTER_ZSTD
    
    public var description: String {
        switch self {
        case .none:     return "none"
        case .gzip:     return "gzip"
        case .bzip2:    return "bzip2"
        case .compress: return "compress"
        case .program:  return "program"
        case .lzma:     return "lzma"
        case .xz:       return "xz"
        case .uu:       return "uu"
        case .rpm:      return "rpm"
        case .lzip:     return "lzip"
        case .lrzip:    return "lrzip"
        case .lzop:     return "lzop"
        case .grzip:    return "grzip"
        case .lz4:      return "lz4"
        case .zstd:     return "zstd"
        }
    }
    
    /// 从 libarchive 过滤器代码创建
    public init?(filterCode: Int32) {
        self.init(rawValue: filterCode)
    }
}
