// ArchiveKit.swift
// ArchiveKit - libarchive Swift 封装
//
// 主入口文件，重新导出所有公开类型

internal import libarchive

// MARK: - 版本信息

/// ArchiveKit 版本信息
public enum ArchiveKit {
    
    /// libarchive 版本号（整数形式，如 3008007 表示 3.8.7）
    public static var libarchiveVersionNumber: Int {
        Int(archive_version_number())
    }
    
    /// libarchive 版本字符串（如 "libarchive 3.8.7"）
    public static var libarchiveVersionString: String {
        String(cString: archive_version_string())
    }
    
    /// libarchive 详细版本信息（包含依赖库版本）
    public static var libarchiveVersionDetails: String {
        String(cString: archive_version_details())
    }
    
    /// zlib 版本字符串（如 "1.2.11"），不可用时返回 nil
    public static var zlibVersion: String? {
        guard let cStr = archive_zlib_version() else { return nil }
        return String(cString: cStr)
    }
    
    /// liblzma 版本字符串，不可用时返回 nil
    public static var liblzmaVersion: String? {
        guard let cStr = archive_liblzma_version() else { return nil }
        return String(cString: cStr)
    }
    
    /// bzlib 版本字符串，不可用时返回 nil
    public static var bzlibVersion: String? {
        guard let cStr = archive_bzlib_version() else { return nil }
        return String(cString: cStr)
    }
    
    /// liblz4 版本字符串，不可用时返回 nil
    public static var liblz4Version: String? {
        guard let cStr = archive_liblz4_version() else { return nil }
        return String(cString: cStr)
    }
    
    /// libzstd 版本字符串，不可用时返回 nil
    public static var libzstdVersion: String? {
        guard let cStr = archive_libzstd_version() else { return nil }
        return String(cString: cStr)
    }
}
