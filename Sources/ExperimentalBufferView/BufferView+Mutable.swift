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
public struct MutableBufferView<Element>: ~Copyable /* & ~Escapable */ {
  @usableFromInline let start: BufferViewIndex<Element>
  public let count: Int

  private var baseAddress: UnsafeMutableRawPointer {
    UnsafeMutableRawPointer(start._rawValue._rawValue)
  }

  @inlinable
  public init<Owner>(
    unsafeBaseAddress: UnsafeMutableRawPointer,
    count: Int,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    self.init(
      start: .init(rawValue: unsafeBaseAddress), count: count, dependsOn: owner
    )
  }

  @inlinable
  public init<Owner>(
    unsafeBaseAddress: UnsafeMutablePointer<Element>,
    count: Int,
    dependsOn owner: /*borrowing*/ Owner
  ) {
    self.init(
      unsafeBaseAddress: UnsafeMutableRawPointer(unsafeBaseAddress),
      count: count,
      dependsOn: owner
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

//  public init?<Owner>(
//    unsafeMutableBufferPointer buffer: UnsafeMutableBufferPointer<Element>,
//    dependsOn owner: /*borrowing*/ Owner
//  ) {
//    guard let base = UnsafeMutableRawPointer(buffer.baseAddress) else { return nil }
//    self.init(baseAddress: base, count: buffer.count, dependsOn: owner)
//  }
}

extension MutableBufferView /*where Element: BitwiseCopyable*/ {

//  public init?<Owner>(
//    unsafeMutableRawBufferPointer buffer: UnsafeMutableRawBufferPointer,
//    dependsOn owner: /*borrowing*/ Owner
//  ) {
//    guard _isPOD(Element.self) else { fatalError() }
//    guard let p = buffer.baseAddress else { return nil }
//    let (q, r) = buffer.count.quotientAndRemainder(dividingBy: MemoryLayout<Element>.stride)
//    precondition(r == 0)
//    self.init(baseAddress: p, count: q, dependsOn: owner)
//  }
}

extension MutableBufferView {
  public var view: /* borrows(self) */ BufferView<Element> {
    BufferView(
      start: startIndex, count: count, dependsOn: /* self */ startIndex
    )
  }
}

//MARK: Sequence

extension MutableBufferView /* : Sequence */ {

  public func makeIterator() -> BufferViewIterator<Element> {
    .init(from: startIndex, to: endIndex, dependsOn: /* self */ baseAddress)
  }

  //FIXME: mark closure parameter as non-escaping
  public func withContiguousStorageIfAvailable<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    try view.withContiguousStorageIfAvailable(body)
  }
}

@available(*, unavailable)
extension MutableBufferView: Sendable {}

extension MutableBufferView where Element: Equatable {

  public func elementsEqual(_ other: borrowing Self) -> Bool {
    view.elementsEqual(other.view)
  }
}

//MARK: Collection, RandomAccessCollection
extension MutableBufferView /* :
  Collection,
  MutableCollection,
  BidirectionalCollection,
  RandomAccessCollection */ {

  public typealias Element = Element
  public typealias Index = BufferViewIndex<Element>
  public typealias SubSequence = Self

  @inlinable @inline(__always)
  public var startIndex: Index { start }

  @inlinable @inline(__always)
  public var endIndex: Index { start.advanced(by: count) }

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
    precondition(
      distance(from: startIndex, to: bounds.lowerBound) >= 0 &&
      distance(from: bounds.lowerBound, to: bounds.upperBound) >= 0 &&
      distance(from: bounds.upperBound, to: endIndex) >= 0,
      "Range of indices out of bounds"
    )
    //FIXME: Use `BitwiseCopyable` layout constraint
    if !_isPOD(Element.self) {
      precondition(
        bounds.lowerBound.isAligned && bounds.upperBound.isAligned,
        "Range of indices is unaligned for Element"
      )
    }
  }

  @inlinable @inline(__always)
  public func index(after i: Index) -> Index {
    i.advanced(by: +1)
  }

  @inlinable @inline(__always)
  public func index(before i: Index) -> Index {
    i.advanced(by: -1)
  }

  @inlinable @inline(__always)
  public func formIndex(after i: inout Index) {
    i = index(after: i)
  }

  @inlinable @inline(__always)
  public func formIndex(before i: inout Index) {
    i = index(before: i)
  }

  @inlinable @inline(__always)
  public func index(_ i: Index, offsetBy distance: Int) -> Index {
    i.advanced(by: distance)
  }

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
    nonmutating _modify {
      _checkBounds(position)
      yield &self[unchecked: position]
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
    nonmutating set {
      UnsafeMutableRawPointer(mutating: position._rawValue).withMemoryRebound(
        to: Element.self, capacity: 1
      ) {
        $0.pointee = newValue
      }
    }
/*  // Verify whether a _modify accessor would be better
    nonmutating _modify { // requires `import Builtin`
      let rp = position._rawValue._rawValue
      let binding = Builtin.bindMemory(rp, 1._builtinWordValue, Element.self)
      defer {
        Builtin.rebindMemory(rp, binding)
      }
      yield &(UnsafeMutablePointer(rp).pointee)
    }
*/
  }

  @inlinable @inline(__always)
  public subscript(bounds: Range<Index>) -> Self {
    get {
      _checkBounds(bounds)
      return self[unchecked: bounds]
    }
    nonmutating set {
      _checkBounds(bounds)
      precondition(
        bounds.count == newValue.count,
        "selected slice and assigned slice must have the same element count."
      )
      self[unchecked: bounds] = newValue
    }
  }

  @inlinable @inline(__always)
  public subscript(unchecked bounds: Range<Index>) -> Self {
    get {
      MutableBufferView(
        unsafeBaseAddress: .init(mutating: bounds.lowerBound._rawValue),
        count: bounds.count,
        dependsOn: /* self */ startIndex
      )
    }
    nonmutating set {
      assert(bounds.count == newValue.count)
      let count = bounds.count
      let dest = UnsafeMutableRawPointer(mutating: bounds.lowerBound._rawValue)
      let source = UnsafeRawPointer(newValue.start._rawValue)
      dest.withMemoryRebound(to: Element.self, capacity: count) {
        source.withMemoryRebound(to: Element.self, capacity: count) {
          [dest = $0 ] source in
          dest.update(from: source, count: newValue.count)
        }
      }
    }
  }

/*
  @_alwaysEmitIntoClient
  public subscript(bounds: some RangeExpression<Index>) -> Self {
    get {
      self[bounds.relative(to: self)]
    }
    nonmutating set {
      self[bounds.relative(to: self)] = newValue
    }
  }

  @_alwaysEmitIntoClient
  public subscript(unchecked bounds: some RangeExpression<Index>) -> Self {
    get {
      self[unchecked: bounds.relative(to: self)]
    }
    nonmutating set {
      self[unchecked: bounds.relative(to: self)] = newValue
    }
  }
*/

  @_alwaysEmitIntoClient
  public subscript(x: UnboundedRange) -> Self {
    get {
      self[unchecked: indices]
    }
    nonmutating set {
      precondition(count == newValue.count)
      self[unchecked: indices] = newValue
    }
  }

  //FIXME: mark closure parameter as non-escaping
  public func withContiguousMutableStorageIfAvailable<R>(
    _ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R? {
    try baseAddress.withMemoryRebound(to: Element.self, capacity: count) {
      ptr -> R in
      var buf = UnsafeMutableBufferPointer<Element>(start: ptr, count: count)
      defer {
        precondition(
          (buf.baseAddress, buf.count) == (ptr, count),
          "MutableBufferView.withContiguousMutableStorageIfAvailable: replacing the buffer is not allowed"
        )
      }
      return try body(&buf)
    }
  }
}

//MARK: copyMemory
extension MutableBufferView /* where Element: BitwiseCopyable */ {

  //FIXME: does copyMemory make sense without the `BitwiseCopyable` constraint?

  public func copyMemory(from source: borrowing MutableBufferView<Element>) -> Index {
    guard _isPOD(Element.self) else { fatalError() }
    precondition(
      source.count <= count,
      "MutableBufferView.copyMemory source has too many elements"
    )
    baseAddress.copyMemory(
      from: source.startIndex._rawValue,
      byteCount: source.count*MemoryLayout<Element>.stride
    )
    return startIndex.advanced(by: source.count)
  }

  public func copyMemory(from source: BufferView<Element>) -> Index {
    guard _isPOD(Element.self) else { fatalError() }
    precondition(
      source.count <= count,
      "MutableBufferView.copyMemory source has too many elements"
    )
    baseAddress.copyMemory(
      from: source.startIndex._rawValue,
      byteCount: source.count*MemoryLayout<Element>.stride
    )
    return startIndex.advanced(by: source.count)
  }

  //TODO: also overload the various `update` functions to use memcpy?
}

//MARK: UMBP-style update functions
extension MutableBufferView {

  public func update(repeating repeatedValue: Element) {
    baseAddress.withMemoryRebound(to: Element.self, capacity: count) {
      $0.update(repeating: repeatedValue, count: count)
    }
  }

  public func update<S: Sequence>(
    from source: S
  ) -> (unwritten: S.Iterator, index: Index) where S.Element == Element {
    var iterator = source.makeIterator()
    guard !self.isEmpty else { return (iterator, startIndex) }
    var index = startIndex
    while index < endIndex {
      guard let value = iterator.next() else { break }
      self[unchecked: index] = value
      formIndex(after: &index)
    }
    return (iterator, index)
  }

  public func update(fromContentsOf source: some Collection<Element>) -> Index {
    let updated = source.withContiguousStorageIfAvailable {
      [ count = self.count, baseAddress = self.baseAddress ] sourceBuffer in
      guard let sourceAddress = sourceBuffer.baseAddress else {
        return 0
      }
      precondition(
        sourceBuffer.count <= count,
        "destination buffer view cannot contain every element from source."
      )
      baseAddress.withMemoryRebound(to: Element.self, capacity: sourceBuffer.count) {
        $0.update(from: sourceAddress, count: sourceBuffer.count)
      }
      return sourceBuffer.count
    }
    if let updated {
      return startIndex.advanced(by: updated)
    }

    if self.isEmpty {
      precondition(
        source.isEmpty,
        "destination buffer view cannot contain every element from source."
      )
      return startIndex
    }

    var iterator = source.makeIterator()
    var index = startIndex
    while let value = iterator.next() {
      guard index < endIndex else {
        preconditionFailure(
          "destination buffer view cannot contain every element from source."
        )
        break
      }
      self[unchecked: index] = value
      formIndex(after: &index)
    }
    return index
  }
}

//MARK: withUnsafeRaw...
extension MutableBufferView /* where Element: BitwiseCopyable */ {

  //FIXME: mark closure parameter as non-escaping
  public func withUnsafeRawPointer<R>(
    _ body: (_ pointer: UnsafeRawPointer, _ count: Int) throws -> R
  ) rethrows -> R {
    try body(baseAddress, count*MemoryLayout<Element>.stride)
  }

  //FIXME: mark closure parameter as non-escaping
  public func withUnsafeMutableRawPointer<R>(
    _ body: (_ pointer: UnsafeMutableRawPointer, _ count: Int) throws -> R
  ) rethrows -> R {
    try body(baseAddress, count*MemoryLayout<Element>.stride)
  }

  //FIXME: mark closure parameter as non-escaping
  public func withUnsafeBytes<R>(
    _ body: (_ pointer: UnsafeRawBufferPointer) throws -> R
  ) rethrows -> R {
    try withUnsafeRawPointer { try body(.init(start: $0, count: $1)) }
  }

  //FIXME: mark closure parameter as non-escaping
  public func withUnsafeMutableBytes<R>(
    _ body: (_ pointer: UnsafeMutableRawBufferPointer) throws -> R
  ) rethrows -> R {
    try withUnsafeMutableRawPointer { try body(.init(start: $0, count: $1)) }
  }
}

//MARK: withUnsafePointer, etc.
extension MutableBufferView {

  //FIXME: mark closure parameter as non-escaping
  public func withUnsafePointer<R>(
    _ body: (
      _ pointer: UnsafePointer<Element>,
      _ capacity: Int
    ) throws -> R
  ) rethrows -> R {
    try baseAddress.withMemoryRebound(
      to: Element.self, capacity: count, { try body($0, count) }
    )
  }

  public func withUnsafeBufferPointer<R>(
    _ body: (UnsafeBufferPointer<Element>) throws -> R
  ) rethrows -> R {
    try withUnsafePointer { try body(.init(start: $0, count: $1)) }
  }

  //FIXME: mark closure parameter as non-escaping
  public func withUnsafeMutablePointer<R>(
    _ body: (
      _ pointer: UnsafeMutablePointer<Element>,
      _ capacity: Int
    ) throws -> R
  ) rethrows -> R {
    try baseAddress.withMemoryRebound(
      to: Element.self, capacity: count, { try body($0, count) }
    )
  }

  public func withUnsafeMutableBufferPointer<R>(
    _ body: (UnsafeMutableBufferPointer<Element>) throws -> R
  ) rethrows -> R {
    try withUnsafeMutablePointer { try body(.init(start: $0, count: $1)) }
  }
}

//MARK: load and store
extension MutableBufferView /* where Element: BitwiseCopyable */ {

  public func load<T>(
    fromByteOffset offset: Int, as: T.Type
  ) -> T {
    view.load(fromByteOffset: offset, as: T.self)
  }

  public func load<T>(from index: Index, as: T.Type) -> T {
    view.load(from: index, as: T.self)
  }

  public func loadUnaligned<T /*: BitwiseCopyable */>(
    fromByteOffset offset: Int, as: T.Type
  ) -> T {
    view.loadUnaligned(fromByteOffset: offset, as: T.self)
  }

  public func loadUnaligned<T /*: BitwiseCopyable */>(
    from index: Index, as: T.Type
  ) -> T {
    view.loadUnaligned(from: index, as: T.self)
  }

  public func storeBytes<T /*: BitwiseCopyable */>(
    of value: T, toByteOffset offset: Int, as: T.Type
  ) {
    guard _isPOD(Element.self) && _isPOD(T.self) else { fatalError() }
    _checkBounds(
      Range(uncheckedBounds: (
        .init(rawValue: baseAddress.advanced(by: offset)),
        .init(rawValue: baseAddress.advanced(by: offset&+MemoryLayout<T>.size))
      ))
    )
    baseAddress.storeBytes(of: value, toByteOffset: offset, as: T.self)
  }

  public func storeBytes<T /*: BitwiseCopyable */>(
    of value: T, to index: Index, as: T.Type
  ) {
    let o = distance(from: startIndex, to: index)*MemoryLayout<Element>.stride
    storeBytes(of: value, toByteOffset: o, as: T.self)
  }
}

//MARK: integer offset subscripts

extension MutableBufferView {

  @inlinable @inline(__always)
  public subscript(offset offset: Int) -> Element {
    get {
      precondition(0 <= offset && offset < count)
      return self[unchecked: offset]
    }
    nonmutating _modify {
      precondition(0 <= offset && offset < count)
      yield &self[unchecked: offset]
    }
  }

  @inlinable @inline(__always)
  public subscript(unchecked offset: Int) -> Element {
    get {
      self[unchecked: index(startIndex, offsetBy: offset)]
    }
    nonmutating _modify {
      yield &self[unchecked: index(startIndex, offsetBy: offset)]
    }
  }
}

extension MutableBufferView {
  @inlinable
  public var first: Element? {
    view.first
  }

  @inlinable
  public var last: Element? {
    view.last
  }
}

//MARK: prefix and suffix slicing
extension MutableBufferView {

  consuming public func prefix(_ maxLength: Int) -> Self {
    precondition(maxLength >= 0, "Can't have a prefix of negative length.")
    let nc = maxLength < count ? maxLength : count
    return Self(
      unsafeBaseAddress: baseAddress, count: nc, dependsOn: /* self */ startIndex
    )
  }

  consuming public func suffix(_ maxLength: Int) -> Self {
    precondition(maxLength >= 0, "Can't have a suffix of negative length.")
    let nc = maxLength < count ? maxLength : count
    let newStart = baseAddress.advanced(by: (count&-nc)*MemoryLayout<Element>.stride)
    return Self(
      unsafeBaseAddress: newStart, count: nc, dependsOn: /* self */ startIndex
    )
  }

  consuming public func dropFirst(_ k: Int = 1) -> Self {
    precondition(k >= 0, "Can't drop a negative number of elements.")
    let dc = k < count ? k : count
    let newStart = baseAddress.advanced(by: dc*MemoryLayout<Element>.stride)
    return Self(
      unsafeBaseAddress: newStart, count: count&-dc, dependsOn: /* self */ startIndex
    )
  }

  consuming public func dropLast(_ k: Int = 1) -> Self {
    precondition(k >= 0, "Can't drop a negative number of elements.")
    let nc = k < count ? count&-k : 0
    return Self(
      unsafeBaseAddress: baseAddress, count: nc, dependsOn: /* self */ startIndex
    )
  }

  consuming public func prefix(upTo index: Index) -> Self {
    _checkBounds(Range(uncheckedBounds: (startIndex, index)))
    return Self(
      unsafeBaseAddress: baseAddress,
      count: distance(from: startIndex, to: index),
      dependsOn: /* self */ startIndex
    )
  }

  consuming public func suffix(from index: Index) -> Self {
    _checkBounds(Range(uncheckedBounds: (index, endIndex)))
    return Self(
      unsafeBaseAddress: .init(mutating: index._rawValue),
      count: distance(from: index, to: endIndex),
      dependsOn: /* self */ startIndex
    )
  }
}
