// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Tests the absence of the functionality proposed in
// https://github.com/dart-lang/language/issues/1618#issuecomment-1507241494
// when the `inference-update-3` language feature is not enabled, using switch
// expressions.

// @dart=3.3

import '../static_type_helper.dart';

/// Ensures a context type of `Iterable<T>` for the operand, or `Iterable<_>` if
/// no type argument is supplied.
Object? contextIterable<T>(Iterable<T> x) => x;

test(int i) {
  // The static type of a switch expression `E` of the form `switch (e0) { p1 =>
  // e1, p2 => e2, ... pn => en }` with context type `K` is computed as follows:
  //
  // - The scrutinee (`e0`) is first analyzed with context type `_`.
  // - If the switch expression has no cases, its static type is `Never`.
  // - Otherwise, for each case `pi => ei`, let `Ti` be the type of `ei`
  //   inferred with context type `K`.
  {
    // Check the context type of each `ei`:
    // - Where the context is established using a function call argument.
    context<String>(switch (i) {
      0 => (contextType('')..expectStaticType<Exactly<String>>()),
      1 => (contextType('')..expectStaticType<Exactly<String>>()),
      _ => (contextType('')..expectStaticType<Exactly<String>>())
    });

    // - Where the context is established using local variable promotion.
    var o = '' as Object?;
    if (o is String) {
      o = switch (i) {
        0 => (contextType('')..expectStaticType<Exactly<String>>()),
        1 => (contextType('')..expectStaticType<Exactly<String>>()),
        _ => (contextType('')..expectStaticType<Exactly<String>>())
      };
    }
  }

  // - Let `T` be the least upper bound of the static types of all the case
  //   expressions.
  // - Let `S` be the greatest closure of `K`.
  // - If `T <: S`, then the type of `E` is `T`.
  {
    // K=Object, T1=int, and T2=double, therefore T=num and S=Object, so T <: S,
    // and hence the type of E is num.
    var d = 2.0;
    context<Object>(
        (switch (i) { 0 => i, _ => d })..expectStaticType<Exactly<num>>());

    // K=Iterable<_>, T1=Iterable<int>, and T2=Iterable<double>, therefore
    // T=Iterable<num> and S=Iterable<Object?>, so T <: S, and hence the type of
    // E is Iterable<num>.
    var iterableInt = <int>[] as Iterable<int>;
    var iterableDouble = <double>[] as Iterable<double>;
    contextIterable((switch (i) { 0 => iterableInt, _ => iterableDouble })
      ..expectStaticType<Exactly<Iterable<num>>>());
  }

  // - Otherwise, if `Ti <: S` for all `i`, then the type of `E` is `S` if
  //   `inference-update-3` is enabled, else the type of `E` is `T`.
  {
    // K=Iterable<num>, T1=Iterable<int>, and T2=List<num>, therefore T=Object
    // and S=Iterable<num>, so T is not <: S, but T1 <: S and T2 <: S, hence the
    // type of E is Object.
    var iterableInt = <int>[] as Iterable<int>;
    var listNum = <num>[];
    var o = [0] as Object?;
    if (o is Iterable<num>) {
      // We avoid having a compile-time error because `o` can be demoted.
      o = (switch (i) { 0 => iterableInt, _ => listNum })
        ..expectStaticType<Exactly<Object>>();
    }
  }

  // - Otherwise, the type of `E` is `T`.
  {
    var o = '' as Object?;
    var d = 2.0;
    if (o is String?) {
      // K=String?, T1=Null, and T2=int, therefore T=int? and S=String?, so T is
      // not <: S. T1 <: S, but T2 is not <: S. Hence the type of E is int?.
      // We avoid having a compile-time error because `o` can be demoted.
      o = (switch (i) { 0 => null, _ => i })..expectStaticType<Exactly<int?>>();
    }
    o = '' as Object?;
    if (o is String?) {
      // K=String?, T1=int, and T2=Null, therefore T=int? and S=String?, so T is
      // not <: S. T2 <: S, but T1 is not <: S. Hence the type of E is int?.
      // We avoid having a compile-time error because `o` can be demoted.
      o = (switch (i) { 0 => i, _ => null })..expectStaticType<Exactly<int?>>();
    }
    o = '' as Object?;
    if (o is String?) {
      // K=String?, T1=int, and T2=double, therefore T=num and S=String?, so
      // none of T, T1, nor T2 are <: S. Hence the type of E is num.
      // We avoid having a compile-time error because `o` can be demoted.
      o = (switch (i) { 0 => i, _ => d })..expectStaticType<Exactly<num>>();
    }
  }
}

main() {
  test(0);
  test(1);
  test(2);
}
