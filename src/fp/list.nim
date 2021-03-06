import future, option

{.experimental.}

type
  ListNodeKind = enum 
    lnkNil, lnkCons
  List*[T] = ref object
    ## List ADT
    case kind: ListNodeKind
    of lnkNil:
      discard
    of lnkCons:
      value: T
      next: List[T]

proc Cons*[T](head: T, tail: List[T]): List[T] =
  ## Constructs non empty list
  List[T](kind: lnkCons, value: head, next: tail)

proc Nil*[T](): List[T] =
  ## Constructs empty list
  List[T](kind: lnkNil)

proc head*[T](xs: List[T]): T =
  ## Returns list's head
  case xs.kind
  of lnkCons: return xs.value
  else: doAssert(xs.kind == lnkCons)

proc isEmpty*(xs: List): bool =
  ## Checks  if list is empty
  xs.kind == lnkNil

proc headOption*[T](xs: List[T]): Option[T] =
  ## Returns list's head option
  if xs.isEmpty: T.none else: xs.head.some

proc tail*[T](xs: List[T]): List[T] =
  ## Returns list's tail
  case xs.kind
  of lnkCons: xs.next
  else: xs

iterator items*[T](xs: List[T]): T =
  var curr = xs
  while not curr.isEmpty:
    yield curr.head
    curr = curr.tail

proc `==`*[T](xs, ys: List[T]): bool =
  ## Compares two lists
  if (xs.isEmpty, ys.isEmpty) == (true, true): true
  elif (xs.isEmpty, ys.isEmpty) == (false, false): xs.head == ys.head and xs.tail == ys.tail
  else: false

type
  ListFormat = enum
    lfADT, lfSTD

proc asString[T](xs: List[T], f: ListFormat): string =
  proc asAdt(xs: List[T]): string =
    case xs.isEmpty
    of true: "Nil"
    else: "Cons(" & $xs.head & ", " & xs.tail.asAdt & ")"

  proc asStd(xs: List[T]): string = "List(" & xs.foldLeft("", (s: string, v: T) => (if s == "": $v else: s & ", " & $v)) & ")"

  case f
  of lfADT: xs.asAdt
  else: xs.asStd

proc `$`*[T](xs: List[T]): string =
  ## Converts list to string
  result = xs.asString(lfSTD)

proc `^^`*[T](v: T, xs: List[T]): List[T] =
  ## List construction operator, like ``::`` in Haskell
  Cons(v, xs)

proc `++`*[T](xs, ys: List[T]): List[T] =
  ## Concatenates two lists
  xs.append(ys)

proc foldLeft*[T,U](xs: List[T], z: U, f: (U, T) -> U): U =
  ## Fold left operation
  case xs.isEmpty
  of true: z
  else: foldLeft(xs.tail, f(z, xs.head), f)

# foldRight can be recursive, or realized via foldLeft.
proc foldRight*[T,U](xs: List[T], z: U, f: (T, U) -> U): U =
  ## Fold right operation. Can be defined via foldLeft (-d:foldRightViaLeft switch), or be recursive bu default.
  when defined(foldRightViaLeft):
    foldLeft[T, U -> U](xs, (b: U) => b, (g: U -> U, x: T) => ((b: U) => g(f(x, b))))(z)
  else:
    case xs.isEmpty
    of true: z
    else: f(xs.head, xs.tail.foldRight(z, f))

proc drop*(xs: List, n: int): List =
  ## Drops `n` first elements of the list
  case xs.isEmpty
  of true: xs
  else: (if n == 0: xs else: xs.tail.drop(n - 1))

proc dropWhile*[T](xs: List[T], p: T -> bool): List[T] =
  ## Drops elements of the list while `p` returns true.
  case xs.isEmpty
  of true: xs
  else: (if not xs.head.p(): xs else: xs.tail.dropWhile(p))

proc dup*[T](xs: List[T]): List[T] =
  ## Duplicates the list
  xs.foldRight(Nil[T](), (x: T, xs: List[T]) => Cons(x, xs))

proc length*[T](xs: List[T]): int =
  ## Calculates the length of the list
  xs.foldRight(0, (_: T, x: int) => x+1)

proc reverse*[T](xs: List[T]): List[T] =
  ## Reverses the list
  xs.foldLeft(Nil[T](), (xs: List[T], x: T) => Cons(x, xs))

proc append*[T](xs: List[T], ys: List[T]): List[T] =
  ## Concatenates two lists
  xs.foldRight(ys, (x: T, xs: List[T]) => Cons(x, xs))

proc join*[T](xs: List[List[T]]): List[T] =
  ## Joins the list of lists into single list
  xs.foldRight(Nil[T](), append)

proc map*[T, U](xs: List[T], f: T -> U): List[U] =
  ## ``map`` operation for the list
  case xs.isEmpty
  of true: Nil[U]()
  else: Cons(f(xs.head), map(xs.tail, f))

proc filter*[T](xs: List[T], p: T -> bool): List[T] =
  ## ``filter`` operation for the list
  case xs.isEmpty
  of true: xs
  else: (if p(xs.head): Cons(xs.head, filter(xs.tail, p)) else: filter(xs.tail, p))

proc forEach*[T](xs: List[T], f: T -> void): void =
  ## Executes operation for all elements in list
  if not xs.isEmpty:
    f(xs.head)
    xs.tail.forEach(f)

proc forAll*[T](xs: List[T], p: T -> bool): bool =
  ## Tests whether `p` holds for all elements of the list
  if xs.isEmpty:
    true
  elif not p(xs.head):
    false
  else:
    xs.tail.forAll(p)

proc flatMap*[T,U](xs: List[T], f: T -> List[U]): List[U] =
  xs.map(f).join

proc zipWith*[T,U,V](xs: List[T], ys: List[U], f: (T,U) -> V): List[V] =
  if xs.isEmpty or ys.isEmpty:
    Nil[V]()
  else:
    Cons(f(xs.head, ys.head), zipWith(xs.tail, ys.tail, f))

proc zip*[T,U](xs: List[T], ys: List[U]): List[(T,U)] =
  xs.zipWith(ys, (x, y) => (x, y))

# See https://github.com/nim-lang/Nim/issues/4061
proc unzip*[T,U](xs: List[tuple[t: T, u: U]]): (List[T], List[U]) =
  xs.foldRight((Nil[T](), Nil[U]()), (v: (T,U), r: (List[T], List[U])) => (v[0] ^^ r[0], v[1] ^^ r[1]))

proc find*[T](xs: List[T], p: T -> bool): Option[T] =
  ## Finds the first element that satisfies the predicate `p`
  if xs.isEmpty:
    T.none
  else:
    if p(xs.head): xs.head.some else: xs.tail.find(p)

proc hasSubsequence*[T](xs: List[T], ys: List[T]): bool =
  ## Checks if `ys` in `xs`
  if ys.isEmpty:
    true
  elif xs.isEmpty:
    false
  elif xs.head == ys.head:
    xs.tail.hasSubsequence(ys.tail)
  else:
    xs.tail.hasSubsequence(ys)

proc traverse*[T,U](xs: List[T], f: T -> Option[U]): Option[List[U]] =
  ## Transforms the list of `T` into the list of `U` f via `f` only if
  ## all results of applying `f` are defined
  xs.foldRight(Nil[U]().some, (x: T, ys: Option[List[U]]) => f(x).map2(ys, (y: U, ys: List[U]) => y ^^ ys))

proc sequence*[T](xs: List[Option[T]]): Option[List[T]] =
  ## Transforms the list of options into the option of list, which
  ## is defined only if all of the source list options are defined
  xs.traverse((x: Option[T]) => x)

proc asList*[T](xs: varargs[T]): List[T] =
  ## Creates list from varargs
  proc initListImpl(i: int, xs: openarray[T]): List[T] =
    if i > high(xs):
      Nil[T]()
    else:
      Cons(xs[i], initListImpl(i+1, xs))
  initListImpl(0, xs)

proc asSeq*[T](xs: List[T]): seq[T] =
  ## Converts list to sequence
  var s: seq[T] = @[]
  xs.forEach((v: T) => (add(s, v)))
  result = s

template elemType*(v: List): typedesc =
  ## Part of ``do notation`` contract
  type(v.head)
