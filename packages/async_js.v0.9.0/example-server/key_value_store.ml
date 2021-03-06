open Core
open Async
open Cohttp_async_lib.Std
open Ocaml_uri

type state = string String.Table.t

let respond_with_string s =
  Server.respond_with_string
    ~headers:(Cohttp.Header.of_list ["Access-Control-Allow-Origin","*"])
    s

let respond_with_error () =
  Server.respond_with_string ~code:`Not_found "no such endpoint"
    ~headers:(Cohttp.Header.of_list ["Access-Control-Allow-Origin","*"])
;;

let state = String.Table.create ()

let main port_opt () =
  let port = Option.value ~default:8000 port_opt in
  Server.create (Tcp.on_port port) (fun ~body:_ _addr request ->
    match request.meth with
    | `GET ->
      let uri_path = Uri.path request.uri in
      (* This should be a post, but getting the request body was too annoying. *)
      begin match uri_path with
      | "/set" ->
        let res =
          let open Option.Let_syntax in
          let%map key = Uri.get_query_param request.uri "key"
          and data = Uri.get_query_param request.uri "value"
          in
          printf "Setting %s %s\n" key data;
          Hashtbl.set state ~key ~data
        in
        begin match res with
        | None -> respond_with_error ()
        | Some () -> respond_with_string (Sexp.to_string (Unit.sexp_of_t ()))
        end
      | "/get" ->
        begin match Uri.get_query_param request.uri "key" with
        | None -> respond_with_error ()
        | Some key ->
          respond_with_string
            (Sexp.to_string
               ([%sexp_of: string option] (Hashtbl.find state key)))
        end
      | _ -> respond_with_error ()
      end
    | _ -> respond_with_error ()
  )
  >>= fun _ ->
  Deferred.never ()
;;

let () =
  Command.async
    ~summary:"key value store server"
    Command.Spec.(
      empty
      +> flag "-p" (optional int) ~doc:" port"
    )
    main
  |> Command.run

