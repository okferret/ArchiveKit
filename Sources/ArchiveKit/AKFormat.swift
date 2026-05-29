// AKFormat.swift
// ArchiveKit - libarchive Swift 封装
//
// 归档格式定义

/// 归档格式类型
/// 对应 libarchive 的 ARCHIVE_FORMAT_* 常量
///
/// - Note: `baseMask` 是 libarchive 内部使用的掩码常量，不代表真实的归档格式。
///   通过 `AKFormat(rawValue:)` 或 `AKFormat(formatCode:)` 初始化时可能返回该值，
///   但在遍历 `allCases` 时应通过 `isRealFormat` 属性过滤掉它。
public enum AKFormat: Int32, CaseIterable, CustomStringConvertible, Sendable {
    
    /// 基础掩码（非独立格式，仅用于 libarchive 内部格式族判断）
    case baseMask       = 0x00FF0000 // ARCHIVE_FORMAT_BASE_MASK
    
    /// CPIO 格式
    case cpio           = 0x10000    // ARCHIVE_FORMAT_CPIO
    
    /// CPIO POSIX 格式
    case cpioPosix      = 0x10001    // ARCHIVE_FORMAT_CPIO_POSIX
    
    /// CPIO 二进制小端格式
    case cpioBinLE      = 0x10002    // ARCHIVE_FORMAT_CPIO_BIN_LE
    
    /// CPIO 二进制大端格式
    case cpioBinBE      = 0x10003    // ARCHIVE_FORMAT_CPIO_BIN_BE
    
    /// CPIO SVR4 无 CRC 格式
    case cpioSVR4NoCRC  = 0x10004    // ARCHIVE_FORMAT_CPIO_SVR4_NOCRC
    
    /// CPIO SVR4 带 CRC 格式
    case cpioSVR4CRC    = 0x10005    // ARCHIVE_FORMAT_CPIO_SVR4_CRC
    
    /// SHAR 格式
    case shar           = 0x20000    // ARCHIVE_FORMAT_SHAR
    
    /// SHAR 基础格式
    case sharBase       = 0x20001    // ARCHIVE_FORMAT_SHAR_BASE
    
    /// SHAR dump 格式
    case sharDump       = 0x20002    // ARCHIVE_FORMAT_SHAR_DUMP
    
    /// TAR 格式
    case tar            = 0x30000    // ARCHIVE_FORMAT_TAR
    
    /// TAR USTAR 格式
    case tarUstar       = 0x30001    // ARCHIVE_FORMAT_TAR_USTAR
    
    /// TAR PAX interchange 格式
    case tarPaxInterchange  = 0x30002 // ARCHIVE_FORMAT_TAR_PAX_INTERCHANGE
    
    /// TAR PAX restricted 格式
    case tarPaxRestricted   = 0x30003 // ARCHIVE_FORMAT_TAR_PAX_RESTRICTED
    
    /// GNU TAR 格式
    case tarGnu         = 0x30004    // ARCHIVE_FORMAT_TAR_GNUTAR
    
    /// ISO 9660 格式
    case iso9660        = 0x40000    // ARCHIVE_FORMAT_ISO9660
    
    /// ISO 9660 RockRidge 格式
    case iso9660RockRidge = 0x40001  // ARCHIVE_FORMAT_ISO9660_ROCKRIDGE
    
    /// ZIP 格式
    case zip            = 0x50000    // ARCHIVE_FORMAT_ZIP
    
    /// 空归档
    case empty          = 0x60000    // ARCHIVE_FORMAT_EMPTY
    
    /// AR 格式
    case ar             = 0x70000    // ARCHIVE_FORMAT_AR
    
    /// AR GNU 格式
    case arGnu          = 0x70001    // ARCHIVE_FORMAT_AR_GNU
    
    /// AR BSD 格式
    case arBsd          = 0x70002    // ARCHIVE_FORMAT_AR_BSD
    
    /// MTREE 格式
    case mtree          = 0x80000    // ARCHIVE_FORMAT_MTREE
    
    /// RAW 格式
    case raw            = 0x90000    // ARCHIVE_FORMAT_RAW
    
    /// XAR 格式
    case xar            = 0xA0000    // ARCHIVE_FORMAT_XAR
    
    /// LHA 格式
    case lha            = 0xB0000    // ARCHIVE_FORMAT_LHA
    
    /// CAB 格式
    case cab            = 0xC0000    // ARCHIVE_FORMAT_CAB
    
    /// RAR 格式
    case rar            = 0xD0000    // ARCHIVE_FORMAT_RAR
    
    /// 7-Zip 格式
    case sevenZip       = 0xE0000    // ARCHIVE_FORMAT_7ZIP
    
    /// WARC 格式
    case warc           = 0xF0000    // ARCHIVE_FORMAT_WARC
    
    /// RAR v5 格式
    case rarV5          = 0x100000   // ARCHIVE_FORMAT_RAR_V5
    
    public var description: String {
        switch self {
        case .baseMask:             return "base_mask"
        case .cpio:                 return "cpio"
        case .cpioPosix:            return "cpio_posix"
        case .cpioBinLE:            return "cpio_bin_le"
        case .cpioBinBE:            return "cpio_bin_be"
        case .cpioSVR4NoCRC:        return "cpio_svr4_nocrc"
        case .cpioSVR4CRC:          return "cpio_svr4_crc"
        case .shar:                 return "shar"
        case .sharBase:             return "shar_base"
        case .sharDump:             return "shar_dump"
        case .tar:                  return "tar"
        case .tarUstar:             return "tar_ustar"
        case .tarPaxInterchange:    return "tar_pax_interchange"
        case .tarPaxRestricted:     return "tar_pax_restricted"
        case .tarGnu:               return "tar_gnu"
        case .iso9660:              return "iso9660"
        case .iso9660RockRidge:     return "iso9660_rockridge"
        case .zip:                  return "zip"
        case .empty:                return "empty"
        case .ar:                   return "ar"
        case .arGnu:                return "ar_gnu"
        case .arBsd:                return "ar_bsd"
        case .mtree:                return "mtree"
        case .raw:                  return "raw"
        case .xar:                  return "xar"
        case .lha:                  return "lha"
        case .cab:                  return "cab"
        case .rar:                  return "rar"
        case .sevenZip:             return "7zip"
        case .warc:                 return "warc"
        case .rarV5:                return "rar_v5"
        }
    }
    
    /// 从 libarchive 格式代码创建
    public init?(formatCode: Int32) {
        self.init(rawValue: formatCode)
    }
    
    /// 是否为真实的归档格式（排除 `baseMask` 掩码常量）
    public var isRealFormat: Bool {
        self != .baseMask
    }
    
    /// 获取格式族（取高位格式族代码，对应 libarchive 的 ARCHIVE_FORMAT_BASE_MASK 掩码）
    ///
    /// 例如：`.tarUstar.family == .tar`，`.arGnu.family == .ar`，`.rarV5.family == .rarV5`
    ///
    /// - Note: 对于 `.rarV5`（rawValue = 0x100000），
    ///   `0x100000 & 0xFF0000 = 0x100000`，即 `rarV5` 自身，因为 `rarV5` 是独立格式族。
    ///   对于 rawValue 为 0 的情况（如未知格式），返回 nil。
    public var family: AKFormat? {
        // 使用与 baseMask 相同的掩码提取格式族代码
        let familyCode = rawValue & AKFormat.baseMask.rawValue
        guard familyCode != 0 else { return nil }
        return AKFormat(rawValue: familyCode)
    }
}
