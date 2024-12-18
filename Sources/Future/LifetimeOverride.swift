//===----------------------------------------------------------------------===//
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

import Builtin

@_unsafeNonescapableResult
@inlinable @inline(__always)
@lifetime(borrow source)
public func _overrideLifetime<
  T: ~Copyable & ~Escapable,
  U: ~Copyable & ~Escapable
>(
  of dependent: consuming T,
  to source: borrowing U
) -> T {
  dependent
}

@_unsafeNonescapableResult
@inlinable @inline(__always)
@lifetime(source)
public func _overrideLifetime<
  T: ~Copyable & ~Escapable,
  U: ~Copyable & ~Escapable
>(
  of dependent: consuming T,
  copyingFrom source: consuming U
) -> T {
  dependent
}

@_unsafeNonescapableResult
@inlinable @inline(__always)
@lifetime(source)
public func _overrideLifetime<
  T: ~Copyable & ~Escapable,
  U: ~Copyable & ~Escapable
>(
  of dependent: consuming T,
  mutating source: inout U
) -> T {
  dependent
}
