open DocOck.Paths
open Identifier

type t = {
  page : string list;
  (* in reverse order! *)

  anchor : string;

  kind : string;
}

let to_string { page; anchor; _ } =
  String.concat ~sep:"/" (List.rev page) ^ "#" ^ anchor

module Error = struct
  type nonrec t =
    | Not_linkable of string
    | Uncaught_exn of string
    (* These should basicaly never happen *)
    | Unexpected_anchor of t
    | Missing_anchor of t * string

  let to_string = function
    | Not_linkable s -> Printf.sprintf "Not_linkable %S" s
    | Uncaught_exn s -> Printf.sprintf "Uncaught_exn %S" s
    | Unexpected_anchor t -> Printf.sprintf "Unexpected_anchor %S" (to_string t)
    | Missing_anchor (t, s) ->
      Printf.sprintf "Missing_anchor on %S for %S" (to_string t) s
end

(* let (^/) x y = x ^ "/" ^ y *)

let (>>|) x f =
  match x with
  | Ok x -> Ok (f x)
  | Error _ as e -> e

let (>>=) x f =
  match x with
  | Ok x -> f x
  | Error _ as e -> e

let rec from_identifier : type a. get_package:('x -> string) -> stop_before:bool ->
  ('x, a) Identifier.t -> (t, Error.t) result =
  fun ~get_package ~stop_before ->
    let open Error in
    function
    | Root (abstr, unit_name) ->
      begin try Ok (get_package abstr)
      with exn -> Error (Uncaught_exn (Printexc.to_string exn))
      end >>| fun pkg_name ->
      let page = [ pkg_name ] in
      let kind = "module" in
      (* FIXME: for the moment we ignore [stop_before] for compilation units. At
         some point we want to change that. *)
      (*
      if stop_before then
        { page; anchor = unit_name; kind }
      else
      *)
      { page = unit_name :: page; anchor = ""; kind }
    | Module (parent, mod_name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun parent ->
      let kind = "module" in
      if stop_before then
        { page = parent; anchor = Printf.sprintf "%s-%s" kind mod_name; kind }
      else
        { page = mod_name :: parent; anchor = ""; kind }
    | Argument (functor_id, arg_num, arg_name) ->
      from_identifier_no_anchor ~get_package functor_id
      >>| fun parent ->
      let kind = "argument" in
      let suffix = Printf.sprintf "%s-%d-%s" kind arg_num arg_name in
      if stop_before then
        { page = parent; anchor = suffix; kind }
      else
        { page = suffix :: parent; anchor = ""; kind }
    | ModuleType (parent, modt_name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun parent ->
      let kind = "module-type" in
      let suffix = Printf.sprintf "%s-%s" kind modt_name in
      if stop_before then
        { page = parent; anchor = suffix; kind }
      else
        { page = suffix :: parent; anchor = ""; kind }
    | Type (parent, type_name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun page ->
      let kind = "type" in
      { page; anchor = Printf.sprintf "%s-%s" kind type_name; kind }
    | CoreType ty_name ->
      Error (Not_linkable ("core_type:"^ty_name))
    | Constructor (parent, name) ->
      from_identifier ~get_package ~stop_before:false parent
      >>= begin function
      (* FIXME: update doc-ock. *)
(*       | { anchor = ""; _ } as t -> Error (Missing_anchor (t, name)) *)
      | { page; anchor; _ } ->
        let kind = "constructor" in
        Ok { page; anchor = anchor ^ "." ^ name; kind }
      end
    | Field (parent, name) ->
      from_identifier ~get_package ~stop_before:false parent
      >>= begin function
      (* FIXME: update doc-ock. *)
(*       | { anchor = ""; _ } as t -> Error (Missing_anchor (t, name)) *)
      | { page; anchor; _ } ->
        let kind = "field" in
        Ok { page; anchor = anchor ^ "." ^ name; kind }
      end
    | Extension (parent, name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun parent ->
      let kind = "extension" in
      { page = parent; anchor = Printf.sprintf "%s-%s" kind name; kind }
    | Exception (parent, name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun parent ->
      let kind = "exception" in
      { page = parent; anchor = Printf.sprintf "%s-%s" kind name; kind }
    | CoreException name ->
      Error (Not_linkable ("core_exception:" ^ name))
    | Value (parent, name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun parent ->
      let kind = "val" in
      { page = parent; anchor = Printf.sprintf "%s-%s" kind name; kind }
    | Class (parent, name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun parent ->
      let kind = "class" in
      { page = parent; anchor = Printf.sprintf "%s-%s" kind name; kind }
    | ClassType (parent, name) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun parent ->
      let kind = "class-type" in
      { page = parent; anchor = Printf.sprintf "%s-%s" kind name; kind }
    | Method (parent, name) ->
      from_identifier ~get_package ~stop_before:false parent
      >>= begin function
      | { anchor = ""; _ } as t -> Error (Missing_anchor (t, name))
      | { page; anchor; _ } ->
        let kind = "method" in
        Ok { page; anchor = Printf.sprintf "%s-%s-%s" anchor kind name; kind }
      end
    | InstanceVariable (parent, name) ->
      from_identifier ~get_package ~stop_before:false parent
      >>= begin function
      | { anchor = ""; _ } as t -> Error (Missing_anchor (t, name))
      | { page; anchor; _ } ->
        let kind = "val" in
        Ok { page; anchor = Printf.sprintf "%s-%s-%s" anchor kind name; kind }
      end
    | Label (parent, anchor) ->
      from_identifier_no_anchor ~get_package parent
      >>| fun page ->
      { page; anchor; kind = "" }

and from_identifier_no_anchor : type a. get_package:('x -> string) ->
  ('x, a) Identifier.t -> (string list, Error.t) result =
  fun ~get_package id ->
    from_identifier ~get_package ~stop_before:false id
    >>= function
    | { page; anchor = ""; _ } -> Ok page
    | otherwise -> Error (Unexpected_anchor otherwise)

let anchor_of_id_exn ~get_package id =
  match from_identifier ~get_package ~stop_before:true id with
  | Error e -> failwith (Error.to_string e)
  | Ok { anchor; _ } -> anchor

let kind_of_id_exn ~get_package id =
  match from_identifier ~get_package ~stop_before:true id with
  | Error e -> failwith (Error.to_string e)
  | Ok { kind; _ } -> kind

let render_path : type a. (_, a) Path.t -> string =
  let rec render_resolved : type a. (_, a) Path.Resolved.t -> string =
    let open Path.Resolved in
    function
    | Identifier id -> Identifier.name id
    | Subst (_, p) -> render_resolved p
    | SubstAlias (_, p) -> render_resolved p
    | Hidden p -> render_resolved p
    | Module (p, s) -> render_resolved p ^ "." ^ s
    | Canonical (_, Path.Resolved p) -> render_resolved p
    | Canonical (p, _) -> render_resolved p
    | Apply (rp, p) -> render_resolved rp ^ "(" ^ render_path p ^ ")"
    | ModuleType (p, s) -> render_resolved p ^ "." ^ s
    | Type (p, s) -> render_resolved p ^ "." ^ s
    | Class (p, s) -> render_resolved p ^ "." ^ s
    | ClassType (p, s) -> render_resolved p ^ "." ^ s
  and render_path : type a. (_, a) Path.t -> string =
    let open Path in
    function
    | Root root -> root
    | Forward root -> root
    | Dot (prefix, suffix) -> render_path prefix ^ "." ^ suffix
    | Apply (p1, p2) -> render_path p1 ^ "(" ^ render_path p2 ^ ")"
    | Resolved rp -> render_resolved rp
  in
  render_path

module Anchor = struct
  type t = {
    kind : string;
    name : string;
  }

  module Polymorphic_variant_decl = struct
    let name_of_type_constr te =
      match te with
      | DocOck.Types.TypeExpr.Constr (path, _) -> render_path path
      | _ ->
        invalid_arg "DocOckHtml.Url.Polymorphic_variant_decl.name_of_type_constr"

    let from_element ~get_package ~type_ident elt =
      match from_identifier ~get_package ~stop_before:true type_ident with
      | Error e -> failwith (Error.to_string e)
      | Ok { anchor; _ } ->
        match elt with
        | DocOck.Types.TypeExpr.Variant.Type te ->
          { kind = "type"
          ; name = Printf.sprintf "%s.%s" anchor (name_of_type_constr te) }
        | Constructor (name, _, _) ->
          { kind = "constructor"
          ; name = Printf.sprintf "%s.%s" anchor name }
  end

  module Module_listing = struct
    module Reference = DocOck.Paths.Reference

    let fail () = failwith "Only modules allowed inside {!modules: ...}"

    let rec from_reference : type a. (_, a) Reference.t -> t = function
      | Reference.Root name -> { kind = "xref-unresolved"; name }
      | Reference.Dot (parent, suffix) ->
        let { name; _ } = from_reference parent in
        { kind = "xref-unresolved"; name = Printf.sprintf "%s.%s" name suffix }
      | Reference.Resolved r ->
        from_resolved r

    and from_resolved : type a. (_, a) Reference.Resolved.t -> t =
      let open Reference.Resolved in
      function
      | Identifier id ->
        let name = Identifier.name id in
        let kind =
          match from_identifier ~get_package:(fun _ -> "") ~stop_before:false id with
          | Ok { kind; _ } -> kind
          | Error _ -> fail ()
        in
        { name; kind }
      | Module (parent, s) ->
        let { name; _ } = from_resolved parent in
        { kind = "module"; name = Printf.sprintf "%s.%s" name s }
      | ModuleType (parent, s) ->
        let { name; _ } = from_resolved parent in
        { kind = "module-type"; name = Printf.sprintf "%s.%s" name s }
      | _ ->
        fail ()
  end
end
