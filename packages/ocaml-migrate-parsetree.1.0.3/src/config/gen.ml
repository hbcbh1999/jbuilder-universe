let write fn s =
  let oc = open_out fn in
  output_string oc s;
  close_out oc

let () =
  let ocaml_version_str = Sys.argv.(1) in
  let ocaml_version =
    Scanf.sscanf ocaml_version_str "%u.%u" (fun a b -> (a, b))
  in
  write "ast-version"
    (match ocaml_version with
     | (4, 02) -> "402"
     | (4, 03) -> "403"
     | (4, 04) -> "404"
     | (4, 05) -> "405"
     | (4, 06) -> "406"
     | _ ->
       Printf.eprintf "Unkown OCaml version %s\n" ocaml_version_str;
       exit 1);
  write "compiler-functions-file"
    (if ocaml_version < (4, 06) then
       "lt_406.ml"
     else
       "ge_406.ml")
