//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@frozen
public struct BufferViewIndex<Element> {
  @usableFromInline
  let _rawValue: UnsafeRawPointer

  @inlinable @inline(__always)
  internal init(rawValue: UnsafeRawPointer) {
    _rawValue = rawValue
  }

  @inlinable @inline(__always)
  var isAligned: Bool {
    (Int(bitPattern: _rawValue) & (MemoryLayout<Element>.alignment-1)) == 0
  }
}

extension BufferViewIndex: Equatable {}

extension BufferViewIndex: Hashable {}

extension BufferViewIndex: Strideable {
  public typealias Stride = Int

  @inlinable @inline(__always)
  public func distance(to other: BufferViewIndex) -> Int {
    let bytes = _rawValue.distance(to: other._rawValue)
    let (q, r) = bytes.quotientAndRemainder(dividingBy: MemoryLayout<Element>.stride)
    precondition(r == 0)
    return q
  }

  @inlinable @inline(__always)
  public func advanced(by n: Int) -> BufferViewIndex {
    .init(rawValue: _rawValue.advanced(by: n &* MemoryLayout<Element>.stride))
  }
}

extension BufferViewIndex: Comparable {
  @inlinable @inline(__always)
  public static func <(lhs: BufferViewIndex, rhs: BufferViewIndex) -> Bool {
    lhs._rawValue < rhs._rawValue
  }
}

@available(*, unavailable)
extension BufferViewIndex: Sendable {}
