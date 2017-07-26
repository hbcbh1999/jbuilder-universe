---
title: ppx_hash
parent: ../README.md
---

A ppx writer that generates hash functions from type expressions and definitions.

Syntax
------

Type definitions: `[@@deriving hash]`
Expressions: `[%hash_fold: TYPE]` and `[%hash: TYPE]`
Record fields: `[@no_hashing]`

Basic usage
-----------

```ocaml
    type t = {
      s : string;
      x : (int * bool) list;
    } [@@deriving hash]
```

This will generate a function `hash_fold_t : Hash.state -> t -> Hash.state`.

Where `Hash` is `Ppx_hash_lib.Std.Hash`.

The generated function follows the structure of the type; allowing user overrides at every
level. This is in contrast to ocaml's builtin polymorphic hashing `Hashtbl.hash` which
ignores user overrides.
  
Also generated is a direct hash-function `hash : t -> Hash.hash_value`, as a wrapper
around the hash-fold function.. (named `hash_<T>` when <T> != "t")

The direct hash function is the one suitable for `Hashable.Make`.

Signature
---------

In a module signature, `type t [@@deriving hash]` will add both `hash_fold_t` and `hash`
(or `hash_<T>`) to the signature.

Hashing without a type definition
---------------------------------

A folding hash function is accessed/created as `[%hash_fold: TYPE]`.
A direct hash function is accessed/created as `[%hash: TYPE]`.

Special support for record fields
---------------------------------

Record fields can be annotated with `[@no_hashing]` so that they are not incorporated into
the computed hash value. In the case of mutable fields, there must be such an annotation.

```ocaml
    type t = {
      mutable s : string; [@no_hashing]
      x : (int * bool) list;
    } [@@deriving hash]
```

Adapting code to `ppx_hash`
---------------------------

So long as all types in <TYPE-EXP> support hashing, the following common pattern:

```ocaml
    module T = struct
      type t = <TYPE-EXP> [@@deriving sexp, compare]
      let hash = Hashtbl.hash
    end
    include T
    include Hashable.Make(T)
```

Can this be written as:

```ocaml
    module T = struct
      type t = <TYPE-EXP> [@@deriving sexp, compare, hash]
    end
    include T
    include Hashable.Make(T)
```

More information
----------------

    ppx/ppx_hash/doc/design.notes
    ppx/ppx_hash/runtime-lib/make_std.ml