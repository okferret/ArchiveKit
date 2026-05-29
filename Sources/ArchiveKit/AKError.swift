// AKError.swift
// ArchiveKit - libarchive Swift 封装
//
// 错误类型定义

import Foundation

/// ArchiveKit 错误类型
///
/// - Note: `.ok` 和 `.eof` 在语义上不是真正的错误，它们对应 libarchive 的
///   `ARCHIVE_OK`（0）和 `ARCHIVE_EOF`（1）状态码，仅用于内部状态映射。
///   在公开 API 中，成功通过返回值表示，EOF 通过 `nextEntry()` 返回 `nil` 表示，
///   这两个 case 不会被 `throw`，仅在 `AKError.from(code:errorString:)` 中用于判断。
public enum AKError: Error, CustomStringConvertible {
    
    /// 操作成功（不作为错误抛出，仅用于内部状态码映射）
    ///
    /// - Important: 此 case 不应被 `throw`。公开 API 通过返回值表示成功。
    case ok
    
    /// 到达归档末尾（不作为错误抛出，仅用于内部状态码映射）
    ///
    /// - Important: 此 case 不应被 `throw`。公开 API 通过 `nextEntry()` 返回 `nil` 表示 EOF。
    case eof
    
    /// 可重试的错误
    case retry(String)
    
    /// 部分成功（警告）
    case warn(String)
    
    /// 当前操作无法完成
    case failed(String)
    
    /// 致命错误，归档对象不可再用
    case fatal(String)
    
    /// 无效的归档文件路径
    case invalidPath(String)
    
    /// 无法打开文件
    case cannotOpenFile(String)
    
    /// 无法创建归档
    case cannotCreateArchive(String)
    
    /// 密码错误或需要密码
    case wrongPassphrase
    
    /// 未知错误
    case unknown(Int32, String)
    
    public var description: String {
        switch self {
        case .ok:
            return "操作成功"
        case .eof:
            return "到达归档末尾"
        case .retry(let msg):
            return "可重试错误: \(msg)"
        case .warn(let msg):
            return "警告: \(msg)"
        case .failed(let msg):
            return "操作失败: \(msg)"
        case .fatal(let msg):
            return "致命错误: \(msg)"
        case .invalidPath(let path):
            return "无效路径: \(path)"
        case .cannotOpenFile(let path):
            return "无法打开文件: \(path)"
        case .cannotCreateArchive(let msg):
            return "无法创建归档: \(msg)"
        case .wrongPassphrase:
            return "密码错误或归档需要密码"
        case .unknown(let code, let msg):
            return "未知错误 (\(code)): \(msg)"
        }
    }
    
    // libarchive 返回码常量（内部使用）
    internal static let ARCHIVE_EOF:    Int32 =  1
    internal static let ARCHIVE_OK:     Int32 =  0
    internal static let ARCHIVE_RETRY:  Int32 = -10
    internal static let ARCHIVE_WARN:   Int32 = -20
    internal static let ARCHIVE_FAILED: Int32 = -25
    internal static let ARCHIVE_FATAL:  Int32 = -30
    
    /// 从 libarchive 返回码和错误字符串创建错误
    internal static func from(code: Int32, errorString: String?) -> AKError? {
        let msg = errorString ?? "未知错误"
        switch code {
        case ARCHIVE_OK:
            return nil
        case ARCHIVE_EOF:
            return .eof
        case ARCHIVE_RETRY:
            return .retry(msg)
        case ARCHIVE_WARN:
            return .warn(msg)
        case ARCHIVE_FAILED:
            return .failed(msg)
        case ARCHIVE_FATAL:
            return .fatal(msg)
        default:
            return .unknown(code, msg)
        }
    }
}

// MARK: - LocalizedError
extension AKError: LocalizedError {
    public var errorDescription: String? { description }
    
    public var failureReason: String? {
        switch self {
        case .retry(let msg), .warn(let msg), .failed(let msg), .fatal(let msg):
            return msg
        case .invalidPath(let path):
            return "路径无效: \(path)"
        case .cannotOpenFile(let path):
            return "无法打开: \(path)"
        case .cannotCreateArchive(let msg):
            return msg
        case .wrongPassphrase:
            return "提供的密码不正确，或归档已加密但未提供密码"
        case .unknown(let code, let msg):
            return "错误码 \(code): \(msg)"
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .retry:
            return "请稍后重试该操作"
        case .invalidPath:
            return "请检查文件路径是否正确"
        case .cannotOpenFile:
            return "请确认文件存在且有读取权限"
        case .cannotCreateArchive:
            return "请确认目标路径有写入权限"
        case .wrongPassphrase:
            return "请提供正确的密码后重试"
        default:
            return nil
        }
    }
}

// MARK: - Equatable
extension AKError: Equatable {
    public static func == (lhs: AKError, rhs: AKError) -> Bool {
        switch (lhs, rhs) {
        case (.ok, .ok):                        return true
        case (.eof, .eof):                      return true
        case (.retry(let a), .retry(let b)):    return a == b
        case (.warn(let a), .warn(let b)):      return a == b
        case (.failed(let a), .failed(let b)):  return a == b
        case (.fatal(let a), .fatal(let b)):    return a == b
        case (.invalidPath(let a), .invalidPath(let b)):                return a == b
        case (.cannotOpenFile(let a), .cannotOpenFile(let b)):          return a == b
        case (.cannotCreateArchive(let a), .cannotCreateArchive(let b)): return a == b
        case (.wrongPassphrase, .wrongPassphrase):                       return true
        case (.unknown(let c1, let m1), .unknown(let c2, let m2)):      return c1 == c2 && m1 == m2
        default:                                return false
        }
    }
}
