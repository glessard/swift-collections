//===--- RawSpanTests.swift -----------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import XCTest
@testable import Future

final class RawSpanTests: XCTestCase {

  func testOptionalStorage() {
//    XCTAssertEqual(
//      MemoryLayout<RawSpan>.size, MemoryLayout<RawSpan?>.size
//    )
//    XCTAssertEqual(
//      MemoryLayout<RawSpan>.stride, MemoryLayout<RawSpan?>.stride
//    )
//    XCTAssertEqual(
//      MemoryLayout<RawSpan>.alignment, MemoryLayout<RawSpan?>.alignment
//    )
  }

  func testInitWithSpanOfIntegers() {
    let capacity = 4
    let a = Array(0..<capacity)
    let span = RawSpan(_unsafeSpan: a.storage)
    XCTAssertEqual(span.byteCount, capacity*MemoryLayout<Int>.stride)
    XCTAssertFalse(span.isEmpty)
  }

  func testInitWithEmptySpanOfIntegers() {
    let a: [Int] = []
    let span = RawSpan(_unsafeSpan: a.storage)
    XCTAssertTrue(span.isEmpty)
  }

  func testInitWithRawBytes() {
    let capacity = 4
    var a = Array(0..<capacity)
    a.withUnsafeBytes {
      let span = RawSpan(_unsafeBytes: $0)
      XCTAssertEqual(span.byteCount, capacity*MemoryLayout<Int>.stride)
    }

    a.withUnsafeMutableBytes {
      let span = RawSpan(_unsafeBytes: $0)
      XCTAssertEqual(span.byteCount, capacity*MemoryLayout<Int>.stride)
    }
  }

  func testWithRawPointer() {
    let capacity = 4
    var a = Array(0..<capacity)
    a.withUnsafeBytes {
      let pointer = $0.baseAddress!
      let span = RawSpan(
        _unsafeStart: pointer,
        byteCount: capacity*MemoryLayout<Int>.stride
      )
      XCTAssertEqual(span.byteCount, $0.count)
    }

    a.withUnsafeMutableBytes {
      let pointer = $0.baseAddress!
      let span = RawSpan(
        _unsafeStart: pointer,
        byteCount: capacity*MemoryLayout<Int>.stride
      )
      XCTAssertEqual(span.byteCount, $0.count)
    }
  }

  func testLoad() {
    let capacity = 4
    let s = (0..<capacity).map({ "\(#file)+\(#function) #\($0)" })
    s.withUnsafeBytes {
      let span = RawSpan(_unsafeBytes: $0)
      let stride = MemoryLayout<String>.stride

      let s0 = span.unsafeLoad(as: String.self)
      XCTAssertEqual(s0.contains("0"), true)
      let s1 = span.unsafeLoad(fromByteOffset: stride, as: String.self)
      XCTAssertEqual(s1.contains("1"), true)
      let s2 = span.unsafeLoad(fromUncheckedByteOffset: 2*stride, as: String.self)
      XCTAssertEqual(s2.contains("2"), true)
    }
  }

  func testLoadUnaligned() {
    let capacity = 64
    let a = Array(0..<UInt8(capacity))
    a.withUnsafeBytes {
      let span = RawSpan(_unsafeBytes: $0)

      var copy = span
      copy._shrink(droppingFirst: 2)
      let u0 = copy.unsafeLoadUnaligned(as: UInt64.self)
      XCTAssertEqual(u0 & 0xff, 2)
      XCTAssertEqual(u0.byteSwapped & 0xff, 9)
      let u1 = span.unsafeLoadUnaligned(fromByteOffset: 6, as: UInt64.self)
      XCTAssertEqual(u1 & 0xff, 6)
      let u3 = span.unsafeLoadUnaligned(fromUncheckedByteOffset: 7, as: UInt32.self)
      XCTAssertEqual(u3 & 0xff, 7)
    }
  }

  func testSubscript() {
    let capacity = 4
    let b = (0..<capacity).map(Int8.init)
    b.withUnsafeBytes {
      let span = RawSpan(_unsafeBytes: $0)
      let sub1 = span._extracting(0..<2)
      let sub2 = span._extracting(..<2)
      let sub3 = span._extracting(...)
      let sub4 = span._extracting(unchecked: 2...)
      XCTAssertTrue(
        sub1.unsafeView(as: UInt8.self)._elementsEqual(sub2.unsafeView(as: UInt8.self))
      )
      XCTAssertTrue(
        sub3.unsafeView(as: Int8.self)._elementsEqual(span.unsafeView(as: Int8.self))
      )
      XCTAssertFalse(
        sub4.unsafeView(as: Int8.self)._elementsEqual(sub3.unsafeView(as: Int8.self))
      )
    }
  }

  func testUncheckedSubscript() {
    let capacity = 32
    let b = (0..<capacity).map(UInt8.init)
    b.withUnsafeBytes {
      let span = RawSpan(_unsafeBytes: $0)
      var prefix = span
      prefix._shrink(to: 0..<8)
      var beyond = prefix
      beyond._shrink(toUnchecked: 16..<24)
      XCTAssertEqual(beyond.byteCount, 8)
      XCTAssertEqual(beyond.unsafeLoad(as: UInt8.self), 16)
    }
  }

  func testUnsafeBytes() {
    let capacity = 4
    let array = Array(0..<capacity)
    let span = RawSpan(_unsafeSpan: array.storage)
    array.withUnsafeBytes {  b1 in
      span.withUnsafeBytes { b2 in
        XCTAssertTrue(b1.elementsEqual(b2))
      }
    }

    // Should we be able to derive a non-escapable value from a Span via unsafe pointers?
    let copy = span.withUnsafeBytes { RawSpan(_unsafeBytes: $0) }
    _ = copy
  }

  func testStrangeBorrow() {
    let array: [String] = ["0", "1", "2", "3"]
    _ = array

//    let rs = RawSpan(array.storage) // Initializer 'init(_:)' requires that 'String' conform to 'BitwiseCopyable'

//    let rs1 = array.storage.withUnsafeBufferPointer {
//      RawSpan(unsafeBytes: UnsafeRawBufferPointer($0))
//    }                               // Lifetime-dependent value escapes its scope
//    _ = rs1

//    let rs2 = array.storage.withUnsafeBufferPointer {
//      UnsafeRawBufferPointer($0).withMemoryRebound(to: UInt8.self) { // requires that `Span` conform to `Escapable`
//        return Span(unsafeBufferPointer: $0)
//      }
//    }
//    _ = rs2
  }

  func testPrefix() {
    let capacity = 4
    let a = Array(0..<UInt8(capacity))
    a.withUnsafeBytes {
      let span = RawSpan(_unsafeBytes: $0)
      XCTAssertEqual(span.byteCount, capacity)
      XCTAssertEqual(span._extracting(first: 1).unsafeLoad(as: UInt8.self), 0)
      XCTAssertEqual(
        span._extracting(first: capacity).unsafeLoad(
          fromByteOffset: capacity-1, as: UInt8.self
        ),
        UInt8(capacity-1)
      )
      XCTAssertTrue(span._extracting(droppingLast: capacity).isEmpty)
      XCTAssertEqual(
        span._extracting(droppingLast: 1).unsafeLoad(
          fromByteOffset: capacity-2, as: UInt8.self
        ),
        UInt8(capacity-2)
      )
    }

    do {
      let b = UnsafeRawBufferPointer(start: nil, count: 0)
      let span = RawSpan(_unsafeBytes: b)
      XCTAssertEqual(span.byteCount, b.count)
      XCTAssertEqual(span._extracting(first: 1).byteCount, b.count)
      XCTAssertEqual(span._extracting(droppingLast: 1).byteCount, b.count)
    }
  }

  func testSuffix() {
    let capacity = 4
    let a = Array(0..<UInt8(capacity))
    a.withUnsafeBytes {
      let span = RawSpan(_unsafeBytes: $0)
      XCTAssertEqual(span.byteCount, capacity)
      XCTAssertEqual(span._extracting(last: capacity).unsafeLoad(as: UInt8.self), 0)
      XCTAssertEqual(span._extracting(last: capacity-1).unsafeLoad(as: UInt8.self), 1)
      XCTAssertEqual(span._extracting(last: 1).unsafeLoad(as: UInt8.self), UInt8(capacity-1))
      XCTAssertTrue(span._extracting(droppingFirst: capacity).isEmpty)
      XCTAssertEqual(span._extracting(droppingFirst: 1).unsafeLoad(as: UInt8.self), 1)
    }

    do {
      let b = UnsafeRawBufferPointer(start: nil, count: 0)
      let span = RawSpan(_unsafeBytes: b)
      XCTAssertEqual(span.byteCount, b.count)
      XCTAssertEqual(span._extracting(last: 1).byteCount, b.count)
      XCTAssertEqual(span._extracting(droppingFirst: 1).byteCount, b.count)
    }
  }

  func testBoundsChecking() {
    let capacity = 4
    let a = Array(0..<capacity)
    let span = RawSpan(_unsafeSpan: a.storage)
    for o in span._byteOffsets {
      XCTAssertTrue(span.boundsContain(o))
    }
    XCTAssertFalse(span.boundsContain(span.byteCount))
  }

  func testByteOffsetsOf() {
    let b = UnsafeMutableRawBufferPointer.allocate(byteCount: 8, alignment: 8)
    defer { b.deallocate() }

    let span = RawSpan(_unsafeBytes: b)
    let subSpan1 = span._extracting(first: 6)
    let subSpan2 = span._extracting(last: 6)
    let emptySpan = span._extracting(first: 0)
    let nilSpan = RawSpan(
      _unsafeBytes: UnsafeRawBufferPointer(start: nil, count: 0)
    )

    var bounds: Range<Int>?
    bounds = span.byteOffsets(of: subSpan1)
    XCTAssertEqual(bounds, span._byteOffsets.prefix(6))
    bounds = span.byteOffsets(of: subSpan2)
    XCTAssertEqual(bounds, span._byteOffsets.suffix(6))
    bounds = subSpan2.byteOffsets(of: subSpan1)
    XCTAssertNil(bounds)
    bounds = subSpan1.byteOffsets(of: subSpan2)
    XCTAssertNil(bounds)
    bounds = subSpan2.byteOffsets(of: span)
    XCTAssertNil(bounds)
    bounds = nilSpan.byteOffsets(of: emptySpan)
    XCTAssertNil(bounds)
    bounds = span.byteOffsets(of: nilSpan)
    XCTAssertNil(bounds)
    bounds = nilSpan.byteOffsets(of: nilSpan)
    XCTAssertEqual(bounds, 0..<0)
  }
}