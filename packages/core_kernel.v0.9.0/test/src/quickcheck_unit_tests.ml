open! Core_kernel

module Test (S : sig val default_seed : Quickcheck.seed end) : sig end = struct

  let int_middle_bits =
    match Word_size.word_size with
    | W64 -> Int.of_string "0x0000_ffff_ffff_0000"
    | W32 -> Int.of_string "0x00ff_ff00"

  module Q = Quickcheck.Configure (struct
      include Quickcheck
      include S
    end)

  open Q

  module G = Quickcheck.Generator
  module O = Quickcheck.Observer

  let memo k =
    let hashable = Hashtbl_intf.Hashable.of_key k in
    let memoize f = Memo.general f ~hashable in
    (fun gen -> G.map gen ~f:memoize)

  let%test_module "examples" =
    (module struct
      let example = "some silly string that is unlikely to be generated randomly"

      let example_occurs ~examples =
        with_return (fun r ->
          test String.gen ~examples ~f:(fun str ->
            if String.equal str example then r.return true);
          false)

      let%test_unit _ = [%test_result: bool] (example_occurs ~examples:[])        ~expect:false
      let%test_unit _ = [%test_result: bool] (example_occurs ~examples:[example]) ~expect:true
    end)

  let%test_module "failure" =
    (module struct
      let%test_unit _ =
        test_can_generate
          (List.gen'
             ~length:(`Exactly 100)
             G.(filter Int.gen ~f:(fun x -> (x mod 2) = 0)))
          ~f:(fun _ -> true)

      let%test_unit _ =
        test Int.gen ~filter:(fun _ -> true) ~f:(fun _ -> ())
      let%test_unit _ =
        test Int.gen ~filter:(fun x -> (x mod 2) = 0) ~f:(fun x -> assert ((x mod 2) = 0))
      let%test_unit _ =
        assert (Exn.does_raise (fun () ->
          test Int.gen ~filter:(fun _ -> false) ~f:(fun _ -> ())))
    end)

  let%test_module "duplicates" =
    (module struct
      let gen = G.map Int.gen ~f:ignore
      let sexp_of = Unit.sexp_of_t
      let compare = Unit.compare

      let%test_unit _ =
        assert (Exn.does_raise (fun () ->
          test_distinct_values gen ~sexp_of ~compare ~trials:1_000 ~distinct_values:2))

      let%test_unit _ =
        test_distinct_values gen ~sexp_of ~compare ~trials:1_000 ~distinct_values:1
    end)

  let%test_module "unit" =
    (module struct
      let sexp_of = Unit.sexp_of_t
      let gen = Unit.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = can_generate (fun () -> true)
    end)

  let%test_module "bool" =
    (module struct
      let sexp_of = Bool.sexp_of_t
      let gen = Bool.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = can_generate (fun x -> x = true)
      let%test_unit _ = can_generate (fun x -> x = false)
    end)

  let%test_module "int" =
    (module struct
      let sexp_of = Int.Hex.sexp_of_t
      let compare = Int.compare
      let gen = Int.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500
      let%test_unit _ = can_generate (fun x -> Int.popcount x < Int.num_bits / 2)
      let%test_unit _ = can_generate (fun x -> Int.popcount x > Int.num_bits / 2)
      let%test_unit _ =
        for i = 0 to Int.num_bits - 1 do
          can_generate (fun x -> x land (1 lsl i) = 0)
        done
      let%test_unit _ =
        for i = 0 to Int.num_bits - 1 do
          can_generate (fun x -> x land (1 lsl i) <> 0)
        done
    end)

  let%test_module "float" =
    (module struct
      let bits_compare x y = Int64.compare (Int64.bits_of_float x) (Int64.bits_of_float y)
      let bits_equal x y = (bits_compare x y) = 0
      let sexp_of = Float.sexp_of_t
      let compare = bits_compare
      let gen = Float.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let has_class x c =
        match Float.classify x, (c : Float.Class.t) with
        | Infinite,  Infinite
        | Nan,       Nan
        | Normal,    Normal
        | Subnormal, Subnormal
        | Zero,      Zero
          -> true
        | _ -> false

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500
      let%test_unit _ = can_generate (fun x -> has_class x Infinite)
      let%test_unit _ = can_generate (fun x -> has_class x Nan)
      let%test_unit _ = can_generate (fun x -> has_class x Normal)
      let%test_unit _ = can_generate (fun x -> has_class x Subnormal)
      let%test_unit _ = can_generate (fun x -> has_class x Zero)
      let%test_unit _ = can_generate (fun x -> Float.(<) x 0.)
      let%test_unit _ = can_generate (fun x -> Float.(>) x 0.)
      let%test_unit _ = can_generate (fun x -> Float.(=) x 0. && bits_equal x 0.)
      let%test_unit _ = can_generate (fun x -> Float.(=) x 0. && not (bits_equal x 0.))
      let%test_unit _ = can_generate (fun x -> Float.(=) x Float.neg_infinity)

      let%test_unit _ =
        test_can_generate ~sexp_of Float.gen_without_nan ~f:(fun f ->
          Float.equal f Float.infinity)
      let%test_unit _ =
        test_can_generate ~sexp_of Float.gen_without_nan ~f:(fun f ->
          Float.equal f Float.neg_infinity)
      let%test_unit _ =
        test_can_generate ~sexp_of Float.gen_without_nan ~f:(fun f ->
          Float.is_finite f)
      let%test_unit _ =
        test ~sexp_of Float.gen_without_nan ~f:(fun f ->
          assert (not (Float.is_nan f)))

      let%test_unit _ =
        test_can_generate Float.gen_finite ~f:(fun f ->
          Float.equal (f +. 1.0) f)
      let%test_unit _ =
        test_can_generate Float.gen_finite ~f:(fun f ->
          not (Float.equal f 0.) && Float.equal (f +. 1.0) 1.0)
      let%test_unit _ =
        test ~sexp_of Float.gen_finite ~f:(fun f ->
          assert (not (Float.is_nan f)))
      let%test_unit _ =
        test ~sexp_of Float.gen_finite ~f:(fun f ->
          assert (not (Float.is_inf f)))

      let%test_unit _ =
        test ~sexp_of Float.gen_positive ~f:(fun f -> assert (f > 0.))
      let%test_unit _ =
        test_can_generate ~sexp_of Float.gen_positive ~f:(fun x ->
          has_class x Subnormal)
      let%test_unit _ =
        test_can_generate ~sexp_of Float.gen_positive ~f:(fun x ->
          has_class x Normal)

      let%test_unit _ =
        test ~sexp_of Float.gen_negative ~f:(fun f -> assert (f < 0.))
      let%test_unit _ =
        test_can_generate ~sexp_of Float.gen_negative ~f:(fun x ->
          has_class x Subnormal)
      let%test_unit _ =
        test_can_generate ~sexp_of Float.gen_negative ~f:(fun x ->
          has_class x Normal)

      let%test_unit _ =
        test ~sexp_of (Float.gen_uniform_excl (-1.) (1.)) ~f:(fun f ->
          assert (f > -1. && f < 1.))
      let%test_unit _ =
        test_can_generate ~sexp_of (Float.gen_uniform_excl (-1.) (1.)) ~f:(fun f ->
          f < 0.)
      let%test_unit _ =
        test_can_generate ~sexp_of (Float.gen_uniform_excl (-1.) (1.)) ~f:(fun f ->
          f > 0.)

    end)

  let%test_module "string" =
    (module struct
      let sexp_of = String.sexp_of_t
      let compare = String.compare
      let gen = String.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500
      let%test_unit _ = can_generate (fun x -> String.length x = 0)
      let%test_unit _ = can_generate (fun x -> String.length x = 1)
      let%test_unit _ = can_generate (fun x -> String.length x = 2)
      let%test_unit _ = can_generate (fun x -> String.length x > 2)
      let%test_unit _ = can_generate (fun x -> String.uppercase x <> x)
      let%test_unit _ = can_generate (fun x -> String.lowercase x <> x)
      let%test_unit _ = can_generate (fun x ->
        match Int.of_string x with
        | _ -> true
        | exception _ -> false)
    end)

  let%test_module "char" =
    (module struct
      let sexp_of = Char.sexp_of_t
      let gen = Char.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = can_generate Char.is_digit
      let%test_unit _ = can_generate Char.is_lowercase
      let%test_unit _ = can_generate Char.is_uppercase
      let%test_unit _ = can_generate Char.is_print
      let%test_unit _ = can_generate Char.is_whitespace
      let%test_unit _ = can_generate (fun c ->
        not (Char.is_digit c)
        && not (Char.is_lowercase c)
        && not (Char.is_uppercase c)
        && not (Char.is_print c)
        && not (Char.is_whitespace c))
    end)

  let%test_module "tuple2" =
    (module struct
      let sexp_of = [%sexp_of: char * char]
      let compare = [%compare: char * char]
      let gen = G.tuple2 Char.gen Char.gen
      let can_generate ?trials f = test_can_generate gen ~sexp_of ~f ?trials

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500
      let%test_unit _ = can_generate (fun (x,y) -> Char.( = ) x y) ~trials:2_000
      let%test_unit _ = can_generate (fun (x,y) -> Char.( < ) x y)
      let%test_unit _ = can_generate (fun (x,y) -> Char.( > ) x y)
    end)

  let%test_module "option" =
    (module struct
      let sexp_of = [%sexp_of: Int.Hex.t option]
      let compare = [%compare: int option]
      let gen = Option.gen Int.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ =
        test_distinct_values (G.filter gen ~f:Option.is_some) ~sexp_of ~compare
          ~trials:1_000 ~distinct_values:500
      let%test_unit _ = can_generate Option.is_none
      let%test_unit _ = can_generate Option.is_some
    end)

  let%test_module "function" =
    (module struct
      module F = Fn_for_testing.Make (Int) (Int) (struct
          let examples =
            [ Int.min_value
            ; Int.bit_not int_middle_bits
            ; -2 ; -1 ; 0 ; 1 ; 2
            ; int_middle_bits
            ; Int.max_value
            ]
        end)
      let sexp_of = [%sexp_of: F.t]
      let compare = [%compare: F.t]
      let gen =
        (* memoizing these functions makes [test_no_duplicates] run much faster *)
        G.(fn Int.obs Int.gen) |> memo (module Int)
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500

      let%test_unit _ = can_generate (fun f -> f 0 < f (-1))
      let%test_unit _ = can_generate (fun f -> f 0 > f (-1))

      let%test_unit _ = can_generate (fun f -> f 1 < f 0)
      let%test_unit _ = can_generate (fun f -> f 1 > f 0)

      let%test_unit _ = can_generate (fun f -> f 2 < f 1)
      let%test_unit _ = can_generate (fun f -> f 2 > f 1)

      let%test_unit _ = can_generate (fun f ->
        f (-1) <> f 0 && f 0 <> f 1 && f 1 <> f (-1))
      let%test_unit _ = can_generate (fun f ->
        f int_middle_bits <> f 0)

    end)

  let%test_module "higher-order function" =
    (module struct

      (* [First_order] defines a flat representation for [int -> int] functions that has
         [sexp_of] and [compare], but which can map to functions and use [Observer.fn] on
         below. *)
      module First_order = struct
        type t = Id | Neg | Abs | Succ | Pred
        [@@deriving sexp_of, compare, enumerate, hash]

        let apply = function
          | Id   -> Fn.id
          | Neg  -> Int.neg
          | Abs  -> Int.abs
          | Succ -> Int.succ
          | Pred -> Int.pred
      end

      module Higher_order =
        Fn_for_testing.Make (First_order) (Int)
          (struct let examples = First_order.all end)

      let sexp_of = [%sexp_of: Higher_order.t]
      let compare = [%compare: Higher_order.t]
      let gen =
        (* memoizing these functions makes [test_no_duplicates] run much faster *)
        G.(fn O.(fn Int.gen Int.obs |> unmap ~f:First_order.apply) Int.gen)
        |> memo (module First_order)
      let can_generate f = test_can_generate gen ~f ~sexp_of

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500

      let%test_unit _ = can_generate (fun f -> f Succ = f Pred)
      let%test_unit _ = can_generate (fun f -> f Succ > f Pred)
      let%test_unit _ = can_generate (fun f -> f Succ < f Pred)

      let%test_unit _ = can_generate (fun f -> f Neg <> f Abs)
      let%test_unit _ = can_generate (fun f -> f Neg <> f Id)
      let%test_unit _ = can_generate (fun f -> f Abs <> f Id)

      let%test_unit _ = can_generate (fun f ->
        let x = f Id  in
        let y = f Neg in
        let z = f Abs in
        x <> y && y <> z && z <> x)

    end)

  let%test_module "list" =
    (module struct
      let sexp_of = [%sexp_of: char list]
      let compare = [%compare: char list]
      let gen = List.gen Char.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500
      let%test_unit _ = can_generate List.is_empty
      let%test_unit _ = can_generate (function [_]   -> true           | _ -> false)
      let%test_unit _ = can_generate (function [x;y] -> Char.( < ) x y | _ -> false)
      let%test_unit _ = can_generate (function [x;y] -> Char.( > ) x y | _ -> false)
      let%test_unit _ = can_generate (fun list ->
        List.length list > 2
        && List.is_sorted_strictly list ~compare:Char.compare)
      let%test_unit _ = can_generate (fun list ->
        List.length list > 2
        && List.is_sorted_strictly (List.rev list) ~compare:Char.compare)
    end)

  let%test_module "sexp" =
    (module struct
      let sexp_of = [%sexp_of: Sexp.t]
      let compare = [%compare: Sexp.t]
      let gen = Sexp.gen
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500
      let%test_unit _ = can_generate (function Sexp.Atom _       -> true | _ -> false)
      let%test_unit _ = can_generate (function Sexp.List _       -> true | _ -> false)
      let%test_unit _ = can_generate (function Sexp.Atom ""      -> true | _ -> false)
      let%test_unit _ = can_generate (function Sexp.List []      -> true | _ -> false)
      let%test_unit _ = can_generate (function Sexp.List [_]     -> true | _ -> false)
      let%test_unit _ = can_generate (function Sexp.List [_;_]   -> true | _ -> false)
      let%test_unit _ = can_generate (function Sexp.List [_;_;_] -> true | _ -> false)
      let%test_unit _ = can_generate (function Sexp.Atom _ -> false | Sexp.List list ->
        let is_atom = function Sexp.Atom _ -> true | Sexp.List _ -> false in
        List.length list >= 2 && List.for_all list ~f:is_atom)
    end)

  let%test_module "function on recursive data" =
    (module struct

      module Bool_list = struct
        type t = bool list [@@deriving sexp_of, compare, hash]
      end

      module F =
        Fn_for_testing.Make
          (Bool_list)
          (Char)
          (struct
            let examples =
              [ []
              ; [ true  ]
              ; [ false ]
              ; [ true  ; true  ]
              ; [ true  ; false ]
              ; [ false ; true  ]
              ; [ false ; false ]
              ; [ true  ; true  ; true  ]
              ; [ true  ; true  ; false ]
              ; [ true  ; true  ; true  ; true  ]
              ; [ true  ; true  ; true  ; false ]
              ]
          end)

      let sexp_of = [%sexp_of: F.t]
      let compare = [%compare: F.t]
      let gen =
        (* memoizing these functions makes [test_no_duplicates] run much faster *)
        G.(fn (List.obs Bool.obs) Char.gen) |> memo (module Bool_list)
      let can_generate f = test_can_generate gen ~sexp_of ~f

      let%test_unit _ = test_distinct_values gen ~sexp_of ~compare
                          ~trials:1_000 ~distinct_values:500

      let%test_unit _ = can_generate (fun f -> f []     <> f [true])
      let%test_unit _ = can_generate (fun f -> f []     <> f [false])
      let%test_unit _ = can_generate (fun f -> f [true] <> f [false])

      let%test_unit _ = can_generate (fun f -> f [true;true]      <> f [true;false])
      let%test_unit _ = can_generate (fun f -> f [true;true;true] <> f [true;true;false])

    end)

  let%test_module "deep recursion" =
    (module struct

      let test length =
        test ~trials:1 (List.gen' Char.gen ~length:(`Exactly length)) ~f:(fun input ->
          [%test_result: int] (List.length input) ~expect:length)

      let%test_unit "used to cause a stack overflow" = test 100_000

    end)

end

let%test_module _ = (module Test (Quickcheck))
let%test_module _ = (module Test (struct let default_seed = `Deterministic "foo" end))
let%test_module _ = (module Test (struct let default_seed = `Deterministic "bar" end))
(* let%test_module _ = (module Test (struct let default_seed = `Deterministic "baz" end))
 * let%test_module _ = (module Test (struct let default_seed = `Deterministic "quux" end))
 * let%test_module _ = (module Test (struct let default_seed = `Deterministic "zanzibar" end))
 * let%test_module _ = (module Test (struct let default_seed = `Deterministic "lorem ipsum" end)) *)
