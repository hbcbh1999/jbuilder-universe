(*---------------------------------------------------------------------------
   Copyright (c) 2016 Vincent Bernardoff. All rights reserved.
   Distributed under the ISC license, see terms at the end of the file.
   %%NAME%% %%VERSION%%
  ---------------------------------------------------------------------------*)

open OUnit2
module M = Msgpck

let buf = Bytes.create (5+2*0xffff)

let wr ?(section="") ?expected size v =
  let expected = match expected with Some v -> v | None -> v in
  let nb_written = M.Bytes.write buf v in
  let computed_size = M.Bytes.size v in
  assert_equal ~msg:(section ^ ": nb_written") ~printer:string_of_int size nb_written;
  assert_equal ~msg:(section ^ ": size") ~printer:string_of_int nb_written computed_size;
  let nb_read, msg = M.Bytes.read buf in
  assert_equal ~msg:(section ^ ": nb_read") ~printer:string_of_int size nb_read;
  assert_equal expected msg

let check ~expected buf =
  let nb_read, msg = M.Bytes.read buf in
  assert_equal expected msg

let negative_ints ctx =
  check ~expected:(Int (-1)) @@ Bytes.of_string "\xff" ;
  check ~expected:(Int (-33)) @@ Bytes.of_string "\xd0\xdf" ;
  check ~expected:(Int (-32767)) @@ Bytes.of_string "\xd1\x80\x01" ;
  check ~expected:(Int (-32768)) @@ Bytes.of_string "\xd2\xff\xff\x80\x00" ;
  check ~expected:(Int (-2147483647)) @@ Bytes.of_string "\xd2\x80\x00\x00\x01" ;
  check ~expected:(Int (-2147483648)) @@ Bytes.of_string "\xd3\xff\xff\xff\xff\x80\x00\x00\x00"

let size1 ctx =
  let l = M.[Nil; Bool true; Bool false; Int 127;
             Int (-32); Int (-31); Int (-30); Int (-2) ;Int (-1)] in
  ListLabels.iter l ~f:(wr 1)

let size2 ctx =
  let l = M.[Int (-0x7f-1); Int 0xff] in
  ListLabels.iter l ~f:(wr 2)

let size3 ctx =
  let l = M.[Int (-0x7fff-1); Int 0xffff] in
  ListLabels.iter l ~f:(wr 3)

let size5 ctx =
  let l = M.[Some (Int Int32.(to_int max_int)), Int32 Int32.max_int;
             None, Int 0xffff_ffff
            ]
  in
  ListLabels.iter l ~f:(fun (expected, v) -> wr ?expected 5 v)

let size9 ctx =
  let l = M.[None, Int64 Int64.max_int; None, Float 0.] in
  ListLabels.iter l ~f:(fun (expected, v) -> wr ?expected 9 v)

let str ctx =
  wr ~section:"empty string" 1 @@ M.String "";
  wr 5 (M.String "Bleh");
  wr (0x20+2) (M.String (Bytes.create 0x20 |> Bytes.unsafe_to_string));
  wr (0x100+3) (M.String (Bytes.create 0x100 |> Bytes.unsafe_to_string));
  wr (0x10000+5) (M.String (Bytes.create 0x10000 |> Bytes.unsafe_to_string))

let bytes ctx =
  wr (0x20+2) (M.Bytes (Bytes.create 0x20 |> Bytes.unsafe_to_string));
  wr (0x100+3) (M.Bytes (Bytes.create 0x100 |> Bytes.unsafe_to_string));
  wr (0x10000+5) (M.Bytes (Bytes.create 0x10000 |> Bytes.unsafe_to_string))

let ext ctx =
  wr 3 (M.Ext (4, "1"));
  wr 4 (M.Ext (4, "22"));
  wr 6 (M.Ext (4, "4444"));
  wr 10 (M.Ext (4, Bytes.create 8 |> Bytes.unsafe_to_string));
  wr 18 (M.Ext (4, Bytes.create 16 |> Bytes.unsafe_to_string));
  wr (0xff+3) (M.Ext (4, Bytes.create 0xff |> Bytes.unsafe_to_string));
  wr (0xffff+4) (M.Ext (4, Bytes.create 0xffff |> Bytes.unsafe_to_string))

let gen_list f n =
  let rec inner acc n =
    if n > 0 then inner ((f n)::acc) (pred n) else acc
  in inner [] n

let array ctx =
  wr ~section:"empty list" 1 @@ M.List [];
  wr ~section:"one elt" 2 M.(List [Nil]);
  wr ~section:"small array" (15+1) M.(List (gen_list (fun i -> Int i) 15));
  wr ~section:"medium array" (0xffff+3) M.(List (gen_list (fun i -> Int 0) 0xffff));
  wr ~section:"large array" (0x10000+5) M.(List (gen_list (fun i -> Int 0) 0x10000));
  wr ~section:"concatenated lists" 2 M.(List [List []]);
  wr ~section:"string list" 2 M.(List [String ""]);
  wr ~section:"hello wamp" 33 M.(List [Int 23; String "http://google.com"; Map [String "subscriber", Map []]])

let map ctx =
  wr ~section:"small map" (2*15+1) M.(Map (gen_list (fun i -> Int i, Int i) 15));
  wr ~section:"medium map" (2*0xffff+3) M.(Map (gen_list (fun i -> Int 0, Int 0) 0xffff));
  wr ~section:"large map" (2*0x10000+5) M.(Map (gen_list (fun i -> Int 0, Int 0) 0x10000));
  wr ~section:"concatenated maps" 3 M.(Map [Nil, Map []]);
  wr ~section:"string -> string" 3 M.(Map [String "", String ""])

let suite =
  "msgpck" >::: [
    "negative_ints" >:: negative_ints;
    "size1" >:: size1;
    "size2" >:: size2;
    "size3" >:: size3;
    "size5" >:: size5;
    "size9" >:: size9;
    "str" >:: str;
    "bytes" >:: bytes;
    "ext" >:: ext;
    "array" >:: array;
    "map" >:: map;
  ]

let () = run_test_tt_main suite

(*---------------------------------------------------------------------------
   Copyright (c) 2016 Vincent Bernardoff

   Permission to use, copy, modify, and/or distribute this software for any
   purpose with or without fee is hereby granted, provided that the above
   copyright notice and this permission notice appear in all copies.

   THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
   WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
   MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
   ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
   WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
   ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
   OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
  ---------------------------------------------------------------------------*)
