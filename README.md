# ArchiveKit

ArchiveKit 是基于 [libarchive](https://libarchive.org) 的 Swift 封装库，提供简洁、类型安全的归档读写 API，支持 ZIP、TAR、7-Zip、RAR 等主流格式，以及 gzip、bzip2、xz、zstd 等压缩算法。

## 特性

- 📦 **多格式支持**：ZIP、TAR（ustar/pax/gnu）、7-Zip、RAR/RAR5、CPIO、XAR、LHA、CAB 等
- 🗜️ **多压缩算法**：gzip、bzip2、xz、lzma、lz4、zstd 等
- 🔐 **加密支持**：ZIP AES-256 加密/解密
- 🚀 **现代 Swift API**：async/await、AsyncSequence、Result Builder、链式调用
- 🛡️ **类型安全**：完整的错误类型、OptionSet 标志位
- 💾 **内存归档**：支持直接在内存中创建和读取归档
- 🍎 **多平台**：macOS 10.15+、iOS 13+、tvOS 13+、watchOS 6+

## 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/okferret/ArchiveKit.git", branch: "main"),
]
```

然后在目标中添加：

```swift
.target(
    name: "YourTarget",
    dependencies: ["ArchiveKit"]
)
```

---

## 快速开始

### 解压归档

```swift
import ArchiveKit

// 一行代码解压到目录
let reader = AKReader()
try reader.open(path: "/path/to/archive.zip")
defer { reader.close() }
try reader.extractAll(to: URL(fileURLWithPath: "/output/dir"))
```

### 创建归档

```swift
import ArchiveKit

// 创建 tar.gz 归档
let writer = AKWriter()
try writer.open(path: "/output/archive.tar.gz", format: .tarPaxRestricted, filter: .gzip)
defer { writer.close() }
try writer.addFile(at: "/path/to/file.txt")
try writer.addDirectory(at: "/path/to/dir")
```

---

## 详细使用文档

### 目录

- [AKReader — 归档读取器](#akreader--归档读取器)
- [AKWriter — 归档写入器](#akwriter--归档写入器)
- [AKEntry — 归档条目](#akentry--归档条目)
- [AKFormat — 归档格式](#akformat--归档格式)
- [AKFilter — 压缩过滤器](#akfilter--压缩过滤器)
- [AKExtractFlags — 解压标志](#akextractflags--解压标志)
- [AKError — 错误类型](#akerror--错误类型)
- [现代化 API 扩展](#现代化-api-扩展)
- [版本信息](#版本信息)

---

## AKReader — 归档读取器

`AKReader` 用于打开、遍历和解压归档文件。

### 打开归档

```swift
let reader = AKReader()

// 从文件路径打开
try reader.open(path: "/path/to/archive.zip")

// 从 URL 打开
try reader.open(url: URL(fileURLWithPath: "/path/to/archive.tar.gz"))

// 从内存数据打开
let data: Data = ...
try reader.open(data: data)

// 打开加密归档（密码必须在 open 之前传入）
try reader.open(path: "/path/to/encrypted.zip", passphrases: ["mypassword"])
```

> **注意**：密码必须通过 `passphrases` 参数在 `open` 时传入，不能在 `open` 之后调用 `addPassphrase(_:)`（libarchive 状态机限制）。

### 遍历条目

```swift
// 方式一：手动遍历
while let entry = try reader.nextEntry() {
    print(entry.pathname ?? "")
    // 读取数据（可选）
    let data = try reader.readCurrentEntryData()
    // 或跳过
    try reader.skipCurrentEntry()
}

// 方式二：enumerateEntries（自动跳过未读数据）
try reader.enumerateEntries { entry in
    print(entry.pathname ?? "")
    return true  // 返回 false 停止遍历
}

// 方式三：for-in 序列语法
for entry in reader.entries() {
    print(entry.pathname ?? "")
    // 若需要读取数据，在此处调用 reader.readCurrentEntryData()
}

// 方式四：async/await 异步序列
for try await entry in reader.asyncEntries() {
    print(entry.pathname ?? "")
}
```

### 解压到磁盘

```swift
// 解压全部条目到指定目录
try reader.extractAll(
    to: URL(fileURLWithPath: "/output/dir"),
    flags: [.time, .permissions],
    progress: { entry in
        print("正在解压: \(entry.pathname ?? "")")
    }
)

// 解压当前条目（需先切换工作目录）
try reader.extractCurrentEntry(entry, flags: .standard)
```

**解压标志预设**：

| 预设 | 说明 |
|------|------|
| `.safe` | 防路径穿越攻击（secureSymlinks + secureNoDotDot + secureNoAbsolutePaths） |
| `.standard` | 恢复时间、权限 + 安全模式 |
| `.full` | 完整恢复（owner、permissions、time、acl、fflags、xattr + 安全模式） |

### 读取条目数据

```swift
// 读取当前条目的全部数据
let data = try reader.readCurrentEntryData()

// 低级块读取（支持稀疏文件）
while let (blockData, offset) = try reader.readDataBlock() {
    // 处理数据块
}
```

### 格式检测与加密检测

```swift
// 检测文件是否为受支持的归档格式
let supported = AKReader.isSupported(at: "/path/to/file")

// 检测归档是否加密
let encrypted = try AKReader.isEncrypted(at: "/path/to/archive.zip")

// 验证密码是否正确
let valid = try AKReader.verifyPassphrase("mypassword", for: "/path/to/encrypted.zip")
```

### 便利静态方法

```swift
// 列出所有条目路径
let paths = try AKReader.listEntries(at: "/path/to/archive.zip")

// 列出所有条目（含完整元数据）
let entries = try AKReader.listAllEntries(at: "/path/to/archive.zip")

// 提取指定路径的文件数据
let data = try AKReader.extractData(for: "folder/file.txt", from: "/path/to/archive.zip")
```

### 归档属性

```swift
reader.format        // AKFormat? — 归档格式
reader.formatName    // String?  — 格式名称（如 "POSIX pax interchange format"）
reader.filter        // AKFilter? — 最外层过滤器
reader.filterCount   // Int      — 过滤器数量
reader.fileCount     // Int      — 已处理文件数
reader.bytesRead     // Int64    — 解压后总字节数
reader.compressedBytesRead  // Int64 — 实际读取的压缩字节数
reader.isArchiveOpen // Bool     — 归档是否已打开
reader.lastError     // String?  — 最后一次错误信息
```

---

## AKWriter — 归档写入器

`AKWriter` 用于创建归档文件，支持写入文件、目录、内存数据和符号链接。

### 创建归档文件

```swift
let writer = AKWriter()

// 创建 ZIP 归档
try writer.open(path: "/output/archive.zip", format: .zip, filter: .none)

// 创建 tar.gz 归档
try writer.open(path: "/output/archive.tar.gz", format: .tarPaxRestricted, filter: .gzip)

// 创建加密 ZIP（AES-256）
try writer.open(
    path: "/output/encrypted.zip",
    format: .zip,
    filter: .none,
    passphrase: "mypassword",
    formatOptions: ["encryption": "aes256"]
)

// 指定压缩级别（0-9，0 为默认，9 为最高压缩）
try writer.open(
    path: "/output/archive.tar.gz",
    format: .tarPaxRestricted,
    filter: .gzip,
    compressionLevel: 9
)

defer { writer.close() }
```

### 添加文件

```swift
// 从磁盘路径添加文件
try writer.addFile(at: "/path/to/file.txt")

// 指定在归档中的路径
try writer.addFile(at: "/path/to/file.txt", as: "docs/readme.txt")

// 从 URL 添加
try writer.addFile(at: URL(fileURLWithPath: "/path/to/file.txt"), as: "readme.txt")

// 从内存数据添加
let data = "Hello, World!".data(using: .utf8)!
try writer.addData(data, as: "hello.txt")
try writer.addData(data, as: "hello.txt", modificationDate: Date(), permissions: 0o644)
```

### 添加目录

```swift
// 添加空目录条目
try writer.addDirectory(as: "logs", permissions: 0o755)

// 递归添加磁盘目录（包含所有子文件）
try writer.addDirectory(at: "/path/to/dir")

// 指定归档中的基础路径
try writer.addDirectory(at: "/path/to/dir", as: "mydir")

// 包含隐藏文件，带进度回调
try writer.addDirectory(
    at: "/path/to/dir",
    as: "mydir",
    includeHiddenFiles: true,
    progress: { filePath in
        print("添加: \(filePath)")
    }
)
```

### 添加符号链接

```swift
try writer.addSymlink(as: "link.txt", target: "../original.txt")
```

### 内存归档

```swift
let writer = AKWriter()
let context = try writer.openMemory(format: .zip)
try writer.addData("content".data(using: .utf8)!, as: "file.txt")
let archiveData = try writer.closeMemory(context: context)
// archiveData 即为完整的 ZIP 归档数据
```

### 低级写入接口

```swift
// 手动写入条目（适合自定义元数据场景）
let entry = AKEntry()
entry.pathname = "custom.txt"
entry.size = Int64(data.count)
entry.fileType = .regular
entry.permissions = 0o644
entry.modificationTime = Date()

try writer.writeHeader(entry)
try writer.writeData(data)
try writer.finishEntry()
```

### 便利静态方法

```swift
// 将文件列表打包为 tar.gz
try AKWriter.archive(
    files: ["/path/file1.txt", "/path/file2.txt"],
    to: "/output/archive.tar.gz"
)

// 将目录打包为 tar.gz
try AKWriter.archive(
    directory: "/path/to/dir",
    to: "/output/archive.tar.gz"
)

// 将数据打包为内存 ZIP
let zipData = try AKWriter.archiveToMemory(
    items: [
        (data: data1, path: "file1.txt"),
        (data: data2, path: "file2.txt"),
    ]
)
```

---

## AKEntry — 归档条目

`AKEntry` 封装了归档中单个条目的元数据，支持读取和写入。

### 基本属性

```swift
entry.pathname          // String?  — 条目路径（UTF-8）
entry.size              // Int64?   — 文件大小（字节），未设置时为 nil
entry.fileType          // AKEntryFileType — 文件类型
entry.permissions       // UInt16   — Unix 权限位（如 0o644）
entry.mode              // mode_t   — 完整 stat 模式（类型 + 权限）
entry.strmode           // String   — 模式字符串（如 "-rwxr-xr-x"）
```

### 文件类型判断

```swift
entry.isRegularFile     // Bool — 是否为普通文件
entry.isDirectory       // Bool — 是否为目录
entry.isSymbolicLink    // Bool — 是否为符号链接
entry.isBlockDevice     // Bool — 是否为块设备
entry.isCharacterDevice // Bool — 是否为字符设备
entry.isFIFO            // Bool — 是否为 FIFO
entry.isSocket          // Bool — 是否为 Socket
```

### 时间戳

```swift
entry.modificationTime  // Date? — 修改时间（mtime）
entry.accessTime        // Date? — 访问时间（atime）
entry.changeTime        // Date? — 状态变更时间（ctime）
entry.birthTime         // Date? — 创建时间（birthtime，部分格式支持）
```

### 链接

```swift
entry.symlinkTarget     // String? — 符号链接目标路径
entry.symlinkType       // AKSymlinkType — 符号链接类型（file/directory/undefined）
entry.hardlinkTarget    // String? — 硬链接目标路径
```

### 用户/组

```swift
entry.uid               // Int64  — 用户 ID
entry.gid               // Int64  — 组 ID
entry.userName          // String? — 用户名
entry.groupName         // String? — 组名
```

### 加密状态

```swift
entry.isEncrypted           // Bool — 是否加密（数据或元数据）
entry.isDataEncrypted       // Bool — 数据是否加密
entry.isMetadataEncrypted   // Bool — 元数据是否加密
```

### 扩展属性（xattr）

```swift
// 获取所有扩展属性
let xattrs = entry.xattrs  // [(name: String, value: Data)]

// 逐个遍历
entry.xattrReset()
while let (name, value) = entry.xattrNext() {
    print("\(name): \(value.count) bytes")
}

// 添加扩展属性
entry.xattrAdd(name: "com.example.key", value: someData)

// 清空扩展属性
entry.xattrClear()
```

### 克隆与清空

```swift
// 深拷贝条目（归档关闭后仍可使用）
let cloned = entry.clone()

// 清空条目内容（重置所有字段）
entry.clear()
```

### 文件类型枚举

```swift
public enum AKEntryFileType {
    case regular        // 普通文件
    case symbolicLink   // 符号链接
    case socket         // Socket 文件
    case characterDevice // 字符设备
    case blockDevice    // 块设备
    case directory      // 目录
    case fifo           // FIFO 管道
    case unknown        // 未知类型
}
```

---

## AKFormat — 归档格式

`AKFormat` 枚举定义了所有支持的归档格式。

### 常用格式

| 枚举值 | 说明 |
|--------|------|
| `.zip` | ZIP 格式（支持加密） |
| `.tarPaxRestricted` | TAR PAX restricted（推荐，默认） |
| `.tarPaxInterchange` | TAR PAX interchange |
| `.tarUstar` | TAR USTAR 格式 |
| `.tarGnu` | GNU TAR 格式 |
| `.sevenZip` | 7-Zip 格式 |
| `.rar` | RAR 格式（仅读取） |
| `.rarV5` | RAR v5 格式（仅读取） |
| `.cpio` | CPIO 格式 |
| `.xar` | XAR 格式 |
| `.lha` | LHA 格式 |
| `.cab` | CAB 格式 |
| `.iso9660` | ISO 9660 格式 |

### 格式族

```swift
// 获取格式族（如 tarUstar 的格式族是 tar）
let family = AKFormat.tarUstar.family  // .tar

// 判断是否为真实格式（排除 baseMask）
let isReal = AKFormat.zip.isRealFormat  // true
```

---

## AKFilter — 压缩过滤器

`AKFilter` 枚举定义了所有支持的压缩过滤器。

| 枚举值 | 说明 |
|--------|------|
| `.none` | 无压缩 |
| `.gzip` | gzip 压缩（.tar.gz / .tgz） |
| `.bzip2` | bzip2 压缩（.tar.bz2） |
| `.xz` | xz 压缩（.tar.xz） |
| `.lzma` | lzma 压缩 |
| `.lz4` | lz4 压缩 |
| `.zstd` | zstd 压缩（.tar.zst） |
| `.compress` | compress 压缩（.tar.Z） |
| `.lzip` | lzip 压缩 |
| `.lzop` | lzop 压缩 |
| `.grzip` | grzip 压缩 |
| `.lrzip` | lrzip 压缩 |
| `.uu` | UU 编码 |
| `.rpm` | RPM 格式 |

---

## AKExtractFlags — 解压标志

`AKExtractFlags` 是 `OptionSet`，控制解压行为。

### 单个标志

| 标志 | 说明 |
|------|------|
| `.owner` | 恢复文件所有者/组 |
| `.permissions` | 恢复文件权限（遵守 umask） |
| `.time` | 恢复修改时间和访问时间 |
| `.noOverwrite` | 不覆盖已存在的文件 |
| `.unlink` | 解压前先删除已存在的文件 |
| `.acl` | 恢复 ACL |
| `.fflags` | 恢复文件标志（fflags） |
| `.xattr` | 恢复扩展属性（xattrs） |
| `.secureSymlinks` | 防止符号链接重定向攻击 |
| `.secureNoDotDot` | 拒绝包含 `..` 的路径 |
| `.secureNoAbsolutePaths` | 拒绝绝对路径 |
| `.noAutoDir` | 不自动创建父目录 |
| `.noOverwriteNewer` | 不覆盖比归档中更新的文件 |
| `.sparse` | 检测全零块并写入稀疏文件 |
| `.macMetadata` | 恢复 Mac 扩展元数据（仅 macOS） |
| `.safeWrites` | 使用原子写入（rename） |

### 预设组合

```swift
// 安全解压（防路径穿越攻击）
try reader.extractAll(to: destURL, flags: .safe)

// 标准解压（恢复时间、权限 + 安全模式）
try reader.extractAll(to: destURL, flags: .standard)

// 完整恢复（尽可能恢复所有元数据）
try reader.extractAll(to: destURL, flags: .full)

// 自定义组合
try reader.extractAll(to: destURL, flags: [.time, .permissions, .secureSymlinks])
```

---

## AKError — 错误类型

`AKError` 是 ArchiveKit 的统一错误类型，遵循 `Error`、`LocalizedError`、`Equatable`。

```swift
public enum AKError: Error {
    case ok                          // 操作成功
    case eof                         // 到达归档末尾
    case retry(String)               // 可重试的错误
    case warn(String)                // 部分成功（警告）
    case failed(String)              // 当前操作无法完成
    case fatal(String)               // 致命错误，归档对象不可再用
    case invalidPath(String)         // 无效的归档文件路径
    case cannotOpenFile(String)      // 无法打开文件
    case cannotCreateArchive(String) // 无法创建归档
    case wrongPassphrase             // 密码错误或需要密码
    case unknown(Int32, String)      // 未知错误
}
```

### 错误处理示例

```swift
do {
    let reader = AKReader()
    try reader.open(path: "/path/to/archive.zip")
    defer { reader.close() }
    try reader.extractAll(to: URL(fileURLWithPath: "/output"))
} catch AKError.cannotOpenFile(let path) {
    print("无法打开文件: \(path)")
} catch AKError.wrongPassphrase {
    print("密码错误，请重新输入")
} catch AKError.fatal(let msg) {
    print("致命错误: \(msg)")
} catch {
    print("其他错误: \(error.localizedDescription)")
}
```

---

## 现代化 API 扩展

### AKWriterConfiguration — 写入器配置

`AKWriterConfiguration` 提供预设配置，简化写入器初始化：

```swift
// 使用预设配置
try AKWriter.build(to: "/output/archive.tar.gz", configuration: .tarGz) {
    AKArchiveItem.file(path: "/path/to/file.txt")
    AKArchiveItem.data(jsonData, archivePath: "config.json")
}

// 内置预设
AKWriterConfiguration.zip          // ZIP 格式（无压缩）
AKWriterConfiguration.tarGz        // tar.gz 格式
AKWriterConfiguration.tarXz        // tar.xz 格式
AKWriterConfiguration.tarBz2       // tar.bz2 格式
AKWriterConfiguration.tarZst       // tar.zst 格式
AKWriterConfiguration.sevenZip     // 7-Zip 格式

// 加密 ZIP
let config = AKWriterConfiguration.encryptedZip(passphrase: "mypassword")

// 自定义配置
let config = AKWriterConfiguration(
    format: .zip,
    filter: .none,
    passphrase: "secret",
    formatOptions: ["encryption": "aes256"],
    compressionLevel: 6
)
```

### Result Builder — 声明式归档构建

```swift
// 使用 Result Builder 语法声明式构建归档
try AKWriter.build(to: "/output/archive.zip", configuration: .zip) {
    AKArchiveItem.file(path: "/path/to/file1.txt")
    AKArchiveItem.file(path: "/path/to/file2.txt", archivePath: "renamed.txt")
    AKArchiveItem.data(jsonData, archivePath: "config.json")
    AKArchiveItem.directory(archivePath: "logs")
    AKArchiveItem.symlink(archivePath: "link.txt", target: "../original.txt")
    AKArchiveItem.directoryTree(path: "/path/to/dir", archiveBasePath: "mydir")
}

// 支持条件语句
let includeExtra = true
try AKWriter.build(to: "/output/archive.zip", configuration: .zip) {
    AKArchiveItem.file(path: "/path/to/main.txt")
    if includeExtra {
        AKArchiveItem.file(path: "/path/to/extra.txt")
    }
}

// 构建到内存
let zipData = try AKWriter.buildToMemory(configuration: .zip) {
    AKArchiveItem.data("Hello".data(using: .utf8)!, archivePath: "hello.txt")
    AKArchiveItem.data("World".data(using: .utf8)!, archivePath: "world.txt")
}
```

### 链式调用

```swift
let writer = AKWriter()
try writer.open(path: "/output/archive.zip", format: .zip)
defer { writer.close() }

try writer
    .appendData(data1, as: "file1.txt")
    .appendData(data2, as: "file2.txt")
    .appendFile(at: "/path/to/file3.txt")
    .appendDirectory(as: "logs")
```

### async/await 异步 API

```swift
// 异步解压
try await AKReader.extractAllAsync(
    from: "/path/to/archive.zip",
    to: URL(fileURLWithPath: "/output"),
    flags: .standard,
    progress: { entry in
        print("解压: \(entry.pathname ?? "")")
    }
)

// 异步列出条目
let paths = try await AKReader.listEntriesAsync(at: "/path/to/archive.zip")

// 异步提取文件数据
let data = try await AKReader.extractDataAsync(
    for: "folder/file.txt",
    from: "/path/to/archive.zip"
)

// 异步获取归档摘要
let info = try await AKReader.infoAsync(at: "/path/to/archive.zip")

// 异步打包文件
try await AKWriter.archiveAsync(
    files: ["/path/file1.txt", "/path/file2.txt"],
    to: "/output/archive.tar.gz",
    configuration: .tarGz
)

// 异步打包目录
try await AKWriter.archiveAsync(
    directory: "/path/to/dir",
    to: "/output/archive.tar.gz",
    configuration: .tarGz,
    progress: { filePath in
        print("添加: \(filePath)")
    }
)
```

### Result-based 非抛出 API

```swift
// 不抛出异常，返回 Result
let reader = AKReader()
switch reader.tryOpen(path: "/path/to/archive.zip") {
case .success:
    print("打开成功")
case .failure(let error):
    print("打开失败: \(error)")
}

switch reader.tryNextEntry() {
case .success(let entry):
    print("条目: \(entry?.pathname ?? "EOF")")
case .failure(let error):
    print("读取失败: \(error)")
}

// Writer 的 Result API
let writer = AKWriter()
switch writer.tryOpen(path: "/output/archive.zip", configuration: .zip) {
case .success:
    break
case .failure(let error):
    print("创建失败: \(error)")
}
```

### 流式读取

```swift
// 流式读取，每个条目调用一次回调
try AKReader.stream(from: "/path/to/archive.zip") { entry, reader in
    print("条目: \(entry.pathname ?? "")")
    if entry.pathname == "target.txt" {
        let data = try reader.readCurrentEntryData()
        // 处理数据
        return false  // 找到目标，停止遍历
    }
    return true  // 继续遍历
}
```

### 归档摘要信息

```swift
// 获取归档完整摘要
let info = try AKReader.info(at: "/path/to/archive.zip")

print("格式: \(info.formatName ?? "未知")")
print("过滤器: \(info.filterName ?? "无")")
print("条目总数: \(info.entryCount)")
print("普通文件数: \(info.regularFileCount)")
print("目录数: \(info.directoryCount)")
print("符号链接数: \(info.symlinkCount)")
print("未压缩总大小: \(info.totalUncompressedSize) 字节")
print("是否加密: \(info.isEncrypted)")
print("所有路径: \(info.paths)")
```

### 函数式 API

```swift
let reader = AKReader()
try reader.open(path: "/path/to/archive.zip")
defer { reader.close() }

// 收集所有满足条件的路径
let txtPaths = try reader.compactMapPaths { entry in
    entry.pathname?.hasSuffix(".txt") == true
}

// 映射转换
let sizes = try reader.compactMap { entry -> Int64? in
    entry.size
}

// 查找第一个满足条件的条目
let firstTxt = try reader.first { entry in
    entry.pathname?.hasSuffix(".txt") == true
}

// 检查是否存在
let hasReadme = try reader.contains { entry in
    entry.pathname == "README.md"
}

// 统计数量
let fileCount = try reader.count { entry in
    entry.isRegularFile
}
```

---

## 版本信息

```swift
// libarchive 版本号（整数，如 3008007 表示 3.8.7）
print(ArchiveKit.libarchiveVersionNumber)

// libarchive 版本字符串（如 "libarchive 3.8.7"）
print(ArchiveKit.libarchiveVersionString)

// 详细版本信息（包含依赖库版本）
print(ArchiveKit.libarchiveVersionDetails)

// 各压缩库版本
print(ArchiveKit.zlibVersion ?? "不可用")
print(ArchiveKit.liblzmaVersion ?? "不可用")
print(ArchiveKit.bzlibVersion ?? "不可用")
print(ArchiveKit.liblz4Version ?? "不可用")
print(ArchiveKit.libzstdVersion ?? "不可用")
```

---

## 完整示例

### 示例一：解压加密 ZIP

```swift
import ArchiveKit

func extractEncryptedZip(at path: String, password: String, to destination: String) throws {
    // 验证密码
    guard try AKReader.verifyPassphrase(password, for: path) else {
        throw AKError.wrongPassphrase
    }

    let reader = AKReader()
    try reader.open(path: path, passphrases: [password])
    defer { reader.close() }

    try reader.extractAll(
        to: URL(fileURLWithPath: destination),
        flags: .standard,
        progress: { entry in
            print("解压: \(entry.pathname ?? "")")
        }
    )
}
```

### 示例二：创建加密 ZIP 归档

```swift
import ArchiveKit

func createEncryptedZip(files: [String], to output: String, password: String) throws {
    try AKWriter.build(
        to: output,
        configuration: .encryptedZip(passphrase: password)
    ) {
        for file in files {
            AKArchiveItem.file(path: file)
        }
    }
}
```

### 示例三：读取归档中的特定文件

```swift
import ArchiveKit

func readFile(_ filename: String, from archivePath: String) throws -> Data? {
    return try AKReader.extractData(for: filename, from: archivePath)
}
```

### 示例四：异步打包目录并显示进度

```swift
import ArchiveKit

func archiveDirectory(_ dirPath: String, to output: String) async throws {
    try await AKWriter.archiveAsync(
        directory: dirPath,
        to: output,
        configuration: .tarGz,
        progress: { filePath in
            // 在后台线程调用，需要切换到主线程更新 UI
            DispatchQueue.main.async {
                print("正在添加: \(filePath)")
            }
        }
    )
}
```

### 示例五：内存归档（适合网络传输）

```swift
import ArchiveKit

func createInMemoryZip(items: [(name: String, content: String)]) throws -> Data {
    return try AKWriter.buildToMemory(configuration: .zip) {
        for item in items {
            let data = item.content.data(using: .utf8)!
            AKArchiveItem.data(data, archivePath: item.name)
        }
    }
}
```

---

## 许可证

本项目基于 MIT 许可证开源，详见 [LICENSE](LICENSE) 文件。

libarchive 基于 BSD 2-Clause 许可证，详见 [libarchive 官网](https://libarchive.org)。
