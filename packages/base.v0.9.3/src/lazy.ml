open! Import

type 'a t = 'a lazy_t [@@deriving_inline sexp]
let t_of_sexp : 'a . (Sexplib.Sexp.t -> 'a) -> Sexplib.Sexp.t -> 'a t =
  let _tp_loc = "src/lazy.ml.t"  in
  fun _of_a  -> fun t  -> (lazy_t_of_sexp _of_a) t
let sexp_of_t : 'a . ('a -> Sexplib.Sexp.t) -> 'a t -> Sexplib.Sexp.t =
  fun _of_a  -> fun v  -> (sexp_of_lazy_t _of_a) v
[@@@end]

include (Caml.Lazy : module type of Caml.Lazy with type 'a t := 'a t)

let map t ~f = lazy (f (force t))

let compare compare_a t1 t2 = compare_a (force t1) (force t2)

let hash_fold_t = Hash.Builtin.hash_fold_lazy_t

include Monad.Make (struct
    type nonrec 'a t = 'a t

    let return x = from_val x

    let bind t ~f = lazy (force (f (force t)))

    let map = map

    let map = `Custom map
  end)

module T_unforcing = struct
  type nonrec 'a t = 'a t

  let sexp_of_t sexp_of_a t =
    if is_val t
    then sexp_of_a (force t)
    else sexp_of_string "<unforced lazy>"
  ;;
end
