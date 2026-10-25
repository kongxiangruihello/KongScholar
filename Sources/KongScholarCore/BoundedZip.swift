import Foundation
import zlib

/// Reads ZIP members in memory. No archive path is ever extracted to the filesystem.
public struct BoundedZip {
    public struct Member { public let name: String; public let method: Int; public let size: Int; let packed: Int; let offset: Int; let checksum: UInt32 }
    private let bytes: Data
    public let members: [Member]
    public init(_ input: Data, limit: Int = ScholarStore.limit) throws {
        guard input.count >= 22, input.count <= limit else { throw ScholarStoreError.tooLarge }
        bytes = input
        func n(_ p: Int, _ count: Int) throws -> Int { guard p >= 0, p + count <= input.count else { throw ScholarStoreError.invalidData }; return (0..<count).reduce(0) { $0 | Int(input[p + $1]) << ($1 * 8) } }
        var end: Int?
        for p in stride(from: input.count - 22, through: max(0, input.count - 65557), by: -1) {
            if try n(p,4) == 0x06054b50, p + 22 + (try n(p+20,2)) == input.count { end = p; break }
        }
        guard let e = end, try n(e+4,2) == 0, try n(e+6,2) == 0 else { throw ScholarStoreError.invalidData }
        let count = try n(e+10,2), centralSize = try n(e+12,4), central = try n(e+16,4)
        guard count <= 10000, try n(e+8,2) == count, central + centralSize == e else { throw ScholarStoreError.invalidData }
        var rows = [Member](), seen = Set<String>(), p = central, total = 0
        for _ in 0..<count {
            guard try n(p,4) == 0x02014b50 else { throw ScholarStoreError.invalidData }
            let flags = try n(p+8,2), method = try n(p+10,2), packed = try n(p+20,4), size = try n(p+24,4), nameLength = try n(p+28,2), extra = try n(p+30,2), comment = try n(p+32,2), offset = try n(p+42,4), attr = try n(p+38,4)
            guard flags & 1 == 0, [0,8].contains(method), p + 46 + nameLength + extra + comment <= e, size <= limit - total,
                  (attr >> 16) & 0xf000 != 0xa000, try n(p+34,2) == 0,
                  let name = String(data: input.subdata(in: p+46..<p+46+nameLength), encoding: .utf8), Self.safeName(name), seen.insert(name).inserted,
                  offset < central, try n(offset,4) == 0x04034b50, try n(offset+8,2) == method else { throw ScholarStoreError.invalidData }
            let localNameLength = try n(offset+26,2), localExtra = try n(offset+28,2), start = offset + 30 + localNameLength + localExtra
            guard start <= central, packed <= central - start, let localName = String(data:input.subdata(in:offset+30..<offset+30+localNameLength),encoding:.utf8), localName == name else { throw ScholarStoreError.invalidData }
            rows.append(Member(name:name,method:method,size:size,packed:packed,offset:start,checksum:UInt32(try n(p+16,4))));total += size;p += 46 + nameLength + extra + comment
        }
        guard p == e else { throw ScholarStoreError.invalidData }; members = rows
    }
    public static func safeName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix("/") && !name.contains("\\") && !name.contains(":") && !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) && !name.split(separator:"/",omittingEmptySubsequences:false).contains(where: { $0 == ".." || $0 == "." })
    }
    public func read(_ name: String, limit: Int = ScholarStore.limit) throws -> Data {
        guard let m = members.first(where: { $0.name == name }), m.size <= limit else { throw ScholarStoreError.invalidData }
        let input = bytes.subdata(in:m.offset..<m.offset+m.packed)
        let result: Data
        if m.method == 0 { guard input.count == m.size else { throw ScholarStoreError.invalidData }; result = input }
        else {
            var output = Data(count:max(1,m.size)), stream = z_stream()
            guard inflateInit2_(&stream,-MAX_WBITS,ZLIB_VERSION,Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw ScholarStoreError.invalidData }
            defer { inflateEnd(&stream) }
            let status = input.withUnsafeBytes { source in output.withUnsafeMutableBytes { target -> Int32 in
                stream.next_in = UnsafeMutablePointer(mutating:source.bindMemory(to:Bytef.self).baseAddress);stream.avail_in = uInt(input.count)
                stream.next_out = target.bindMemory(to:Bytef.self).baseAddress;stream.avail_out = uInt(max(1,m.size));return inflate(&stream,Z_FINISH)
            } }
            guard status == Z_STREAM_END, stream.total_out == m.size, stream.total_in == m.packed else { throw ScholarStoreError.invalidData }; output.count = m.size;result = output
        }
        let checksum = result.withUnsafeBytes { crc32(0,$0.bindMemory(to:Bytef.self).baseAddress,uInt(result.count)) }
        guard UInt32(checksum) == m.checksum else { throw ScholarStoreError.invalidData }; return result
    }
}
