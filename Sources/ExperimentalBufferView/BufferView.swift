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

// A BufferView<Element> represents a span of memory which
// contains initialized `Element` instances.

@frozen
public struct BufferView<Element> /* : ~Escapable */ {
  @usableFromInline let start: BufferViewIndex<Element>
  public let count: Int

  private var baseAddress: UnsafeRawPointer { start._rawValue }

  @inlinable
  public init<Owner>(
    unsafeBaseAddress: UnsafeRawPointer,
    count: Int,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    self.init(
      start: .init(rawValue: unsafeBaseAddress), count: count, dependsOn: owner
    )
  }

  @inlinable
  init<Owner>(
    start index: BufferViewIndex<Element>,
    count: Int,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    precondition(count >= 0, "Count must not be negative")
    if !_isPOD(Element.self) {
      precondition(
        index.isAligned,
        "baseAddress must be properly aligned for \(Element.self)"
      )
    }
    self.start = index
    self.count = count
  }

  public init?<Owner>(
    unsafeBufferPointer buffer: UnsafeBufferPointer<Element>,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    guard let baseAddress = UnsafeRawPointer(buffer.baseAddress) else { return nil }
    self.init(unsafeBaseAddress: baseAddress, count: buffer.count, dependsOn: owner)
  }
}

extension BufferView /*where Element: BitwiseCopyable*/ {

  public init?<Owner>(
    unsafeRawBufferPointer buffer: UnsafeRawBufferPointer,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    guard _isPOD(Element.self) else { fatalError() }
    guard let p = buffer.baseAddress else { return nil }
    let (q, r) = buffer.count.quotientAndRemainder(dividingBy: MemoryLayout<Element>.stride)
    precondition(r == 0)
    self.init(unsafeBaseAddress: p, count: q, dependsOn: owner)
  }
}

//MARK: Sequence

extension BufferView: Sequence {

  public func makeIterator() -> BufferViewIterator<Element> {
    .init(from: startIndex, to: endIndex, dependsOn: self)
  }

  //FIXME: mark closure parameter as non-escaping
  public func withContiguousStorageIfAvailable<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    try baseAddress.withMemoryRebound(to: Element.self, capacity: count) {
      [count = count] in
      try body(UnsafeBufferPointer(start: $0, count: count))
    }
  }
}

@available(*, unavailable)
extension BufferView: Sendable {}

extension BufferView where Element: Equatable {

  public func elementsEqual(_ other: Self) -> Bool {
    guard count == other.count else { return false }
    if count == 0 { return true }
    if startIndex == other.startIndex { return true }

    //FIXME: This could be a shortcut with a layout constraint
    //       where stride equals size, with no unused bits.
    // if Element is BitwiseRepresentable {
    // return _swift_stdlib_memcmp(lhs.baseAddress, rhs.baseAddress, count) == 0
    // }
    for (a,b) in zip(self, other) {
      guard a == b else { return false }
    }
    return true
  }
}

//MARK: Collection, RandomAccessCollection
extension BufferView:
  Collection,
  BidirectionalCollection,
  RandomAccessCollection {

  public typealias Element = Element
  public typealias Index = BufferViewIndex<Element>
  public typealias SubSequence = Self

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public var startIndex: Index { start }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public var endIndex: Index { start.advanced(by: count) }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public var indices: Range<Index> {
    .init(uncheckedBounds: (startIndex, endIndex))
  }

  @inlinable @inline(__always)
  public var isEmpty: Bool { count == 0 }

  @inlinable @inline(__always)
  func _checkBounds(_ position: Index) {
    precondition(
      distance(from: startIndex, to: position) >= 0 &&
      distance(from: position, to: endIndex) > 0,
      "Index out of bounds"
    )
    //FIXME: Use `BitwiseCopyable` layout constraint
    if !_isPOD(Element.self) {
      precondition(
        position.isAligned,
        "Index is unaligned for Element"
      )
    }
  }

  @inlinable @inline(__always)
  func _checkBounds(_ bounds: Range<Index>) {
    //FIXME: Use `BitwiseCopyable` layout constraint
    if _isPOD(Element.self) {
      precondition(
        startIndex._rawValue.distance(to: bounds.lowerBound._rawValue) >= 0 &&
        bounds.lowerBound._rawValue.distance(to: bounds.upperBound._rawValue) >= 0 &&
        bounds.upperBound._rawValue.distance(to: endIndex._rawValue) >= 0,
        "Range of indices out of bounds"
      )
    } else {
      precondition(
        bounds.lowerBound.isAligned && bounds.upperBound.isAligned,
        "Range of indices is unaligned for Element"
      )
      precondition(
        distance(from: startIndex, to: bounds.lowerBound) >= 0 &&
        distance(from: bounds.lowerBound, to: bounds.upperBound) >= 0 &&
        distance(from: bounds.upperBound, to: endIndex) >= 0,
        "Range of indices out of bounds"
      )
    }
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public func index(after i: Index) -> Index {
    i.advanced(by: +1)
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public func index(before i: Index) -> Index {
    i.advanced(by: -1)
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public func formIndex(after i: inout Index) {
    i = index(after: i)
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public func formIndex(before i: inout Index) {
    i = index(before: i)
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    i.advanced(by: distance)
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public func formIndex(_ i: inout Index, offsetBy distance: Int) {
    i = index(i, offsetBy: distance)
  }

  @inlinable @inline(__always)
  public func distance(from start: Index, to end: Index) -> Int {
    start.distance(to: end)
  }

  @inlinable @inline(__always)
  public subscript(position: Index) -> Element {
    get {
      _checkBounds(position)
      return self[unchecked: position]
    }
  }

  @inlinable @inline(__always)
  public subscript(unchecked position: Index) -> Element {
    get {
      if _isPOD(Element.self) {
        return position._rawValue.loadUnaligned(as: Element.self)
      }
      else {
        return position._rawValue.load(as: Element.self)
      }
    }
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public subscript(bounds: Range<Index>) -> Self {
    get {
      _checkBounds(bounds)
      return self[unchecked: bounds]
    }
  }

  //FIXME: lifetime-dependent on self
  @inlinable @inline(__always)
  public subscript(unchecked bounds: Range<Index>) -> Self {
    get {
      BufferView(
        unsafeBaseAddress: UnsafeRawPointer(bounds.lowerBound._rawValue),
        count: bounds.count,
        dependsOn: self
      )
    }
  }

  //FIXME: lifetime-dependent on self
  @_alwaysEmitIntoClient
  public subscript(bounds: some RangeExpression<Index>) -> Self {
  // internal subscript<R: RangeExpression>(bounds: R) -> Self where R.Bound == Index {
    get {
      self[bounds.relative(to: self)]
    }
  }

  //FIXME: lifetime-dependent on self
  @_alwaysEmitIntoClient
  public subscript(unchecked bounds: some RangeExpression<Index>) -> Self {
    get {
      self[unchecked: bounds.relative(to: self)]
    }
  }

  //FIXME: lifetime-dependent on self
  @_alwaysEmitIntoClient
  public subscript(x: UnboundedRange) -> Self {
    get {
      self[unchecked: indices]
    }
  }
}

//MARK: withUnsafeRaw...
extension BufferView /* where Element: BitwiseCopyable */ {

  //FIXME: mark closure parameter as non-escapable
  public func withUnsafeRawPointer<R>(
    _ body: (_ pointer: UnsafeRawPointer, _ count: Int) throws -> R
  ) rethrows -> R {
    try body(baseAddress, count*MemoryLayout<Element>.stride)
  }

  //FIXME: mark closure parameter as non-escapable
  public func withUnsafeBytes<R>(
    _ body: (_ buffer: UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    try body(.init(start: baseAddress, count: count))
  }
}

//MARK: withUnsafePointer, etc.
extension BufferView {

  //FIXME: mark closure parameter as non-escapable
  public func withUnsafePointer<R>(
    _ body: (
      _ pointer: UnsafePointer<Element>,
      _ capacity: Int
    ) throws -> R
  ) rethrows -> R {
    try baseAddress.withMemoryRebound(to: Element.self, capacity: count) {
      try body($0, count)
    }
  }

  //FIXME: mark closure parameter as non-escapable
  public func withUnsafeBufferPointer<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R {
    try withUnsafePointer { try body(.init(start: $0, count: $1)) }
  }
}

//MARK: load
extension BufferView /* where Element: BitwiseCopyable */ {

  public func load<T>(
    fromByteOffset offset: Int = 0, as: T.Type
  ) -> T {
    guard _isPOD(Element.self) else { fatalError() }
    _checkBounds(
      Range(uncheckedBounds: (
        .init(rawValue: baseAddress.advanced(by: offset)),
        .init(rawValue: baseAddress.advanced(by: offset+MemoryLayout<T>.size))
      ))
    )
    return baseAddress.load(fromByteOffset: offset, as: T.self)
  }

  public func load<T>(from index: Index, as: T.Type) -> T {
    let o = distance(from: startIndex, to: index)*MemoryLayout<Element>.stride
    return load(fromByteOffset: o, as: T.self)
  }

  public func loadUnaligned<T /*: BitwiseCopyable */>(
    fromByteOffset offset: Int = 0, as: T.Type
  ) -> T {
    guard _isPOD(Element.self) && _isPOD(T.self) else { fatalError() }
    _checkBounds(
      Range(uncheckedBounds: (
        .init(rawValue: baseAddress.advanced(by: offset)),
        .init(rawValue: baseAddress.advanced(by: offset+MemoryLayout<T>.size))
      ))
    )
    return baseAddress.loadUnaligned(fromByteOffset: offset, as: T.self)
  }

  public func loadUnaligned<T /*: BitwiseCopyable */>(
    from index: Index, as: T.Type
  ) -> T {
    let o = distance(from: startIndex, to: index)*MemoryLayout<Element>.stride
    return loadUnaligned(fromByteOffset: o, as: T.self)
  }
}

//MARK: integer offset subscripts

extension BufferView {

  @inlinable @inline(__always)
  public subscript(offset offset: Int) -> Element {
    get {
      precondition(0 <= offset && offset < count)
      return self[uncheckedOffset: offset]
    }
  }

  @inlinable @inline(__always)
  public subscript(uncheckedOffset offset: Int) -> Element {
    get {
      self[unchecked: index(startIndex, offsetBy: offset)]
    }
  }
}

extension BufferView {
  @inlinable
  public var first: Element? {
    isEmpty ? nil : self[unchecked: startIndex]
  }

  @inlinable
  public var last: Element? {
    isEmpty ? nil : self[unchecked: index(startIndex, offsetBy: count &- 1)]
  }
}

//MARK: prefix and suffix slicing
extension BufferView {

  //FIXME: lifetime-dependent on self
  public func prefix(_ maxLength: Int) -> Self {
    precondition(maxLength >= 0, "Can't have a prefix of negative length.")
    let nc = maxLength < count ? maxLength : count
    return Self(unsafeBaseAddress: baseAddress, count: nc, dependsOn: self)
  }

  //FIXME: lifetime-dependent on self
  public func suffix(_ maxLength: Int) -> Self {
    precondition(maxLength >= 0, "Can't have a suffix of negative length.")
    let nc = maxLength < count ? maxLength : count
    let newStart = baseAddress.advanced(by: (count&-nc)*MemoryLayout<Element>.stride)
    return Self(unsafeBaseAddress: newStart, count: nc, dependsOn: self)
  }

  //FIXME: lifetime-dependent on self
  public func dropFirst(_ k: Int = 1) -> Self {
    precondition(k >= 0, "Can't drop a negative number of elements.")
    let dc = k < count ? k : count
    let newStart = baseAddress.advanced(by: dc*MemoryLayout<Element>.stride)
    return Self(unsafeBaseAddress: newStart, count: count&-dc, dependsOn: self)
  }

  //FIXME: lifetime-dependent on self
  public func dropLast(_ k: Int = 1) -> Self {
    precondition(k >= 0, "Can't drop a negative number of elements.")
    let nc = k < count ? count&-k : 0
    return Self(unsafeBaseAddress: baseAddress, count: nc, dependsOn: self)
  }

  //FIXME: lifetime-dependent on self
  public func prefix(upTo index: Index) -> Self {
    _checkBounds(Range(uncheckedBounds: (startIndex, index)))
    return Self(
      unsafeBaseAddress: baseAddress,
      count: distance(from: startIndex, to: index),
      dependsOn: self
    )
  }

  //FIXME: lifetime-dependent on self
  public func suffix(from index: Index) -> Self {
    _checkBounds(Range(uncheckedBounds: (index, endIndex)))
    return Self(
      unsafeBaseAddress: index._rawValue,
      count: distance(from: index, to: endIndex),
      dependsOn: self
    )
  }
}
