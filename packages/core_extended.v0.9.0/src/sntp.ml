open Core ;;

module Internal = struct
  type t =
    { client_xmit : float
    ; server_recv : float
    ; server_xmit : float
    ; client_recv : float
    }
  ;;

  let ntp_conv_const = 2. ** 32.

  let delta = 2208988800. (** difference in seconds between 1900 and 1970 *)

  let ntpfp_to_float (ipart,fpart) =
    Int64.to_float ipart +. Int64.to_float fpart /. ntp_conv_const
    -. delta
  ;;

  let float_to_ntpfp f =
    let f = f +. delta in
    let ipart = Int64.of_float f in
    let fpart = Int64.of_float ((f -. Float.round ~dir:`Down f) *. ntp_conv_const) in
    (ipart,fpart)
  ;;

  let bytemask = Int64.of_int 0xFF

  let short_int64_to_buf buf pos bits =
    for i = 0 to 3 do
      let byte64 = Int64.bit_and (Int64.shift_right_logical bits (8 * i)) bytemask in
      let char = Char.of_int_exn (Int64.to_int_exn byte64) in
      String.set buf (pos + 3 - i) char
    done
  ;;

  let short_int64_of_buf buf pos =
    let value = ref Int64.zero in
    for i = 0 to 3 do
      let byte = Int64.of_int (Char.to_int (String.get buf (pos + 3 - i))) in
      value := Int64.(+) !value (Int64.shift_left byte (i * 8))
    done;
    !value
  ;;

  let float_to_buf buf pos f =
    let (ipart,fpart) = float_to_ntpfp f in
    short_int64_to_buf buf pos ipart;
    short_int64_to_buf buf (pos + 4) fpart
  ;;

  let float_from_buf buf pos =
    let ipart = short_int64_of_buf buf pos in
    let fpart = short_int64_of_buf buf (pos + 4) in
    ntpfp_to_float (ipart,fpart)
  ;;

  let ntp_packet_length = 48

  let buf = String.create ntp_packet_length

  let reset_buffer () =
    String.fill ~pos:0 ~len:ntp_packet_length buf '\000'
  ;;

  let query ~timeout ~port ipaddr =
    reset_buffer ();
    let addr = Unix.get_sockaddr ipaddr port in
    Exn.protectx
      (Unix.socket ~domain:Unix.PF_INET ~kind:Unix.SOCK_DGRAM ~protocol:0)
      ~f:(fun s ->
        (* Emulating the packets that `ntpdate -p 1 -q server' sends *)
        String.set buf 0 (Char.of_int_exn 0b11100011);
        float_to_buf buf 40 (Unix.gettimeofday ());
        Unix.sendto s ~buf ~pos:0 ~len:(String.length buf) ~mode:[] ~addr
        |> ignore;
        let sfds =
          Unix.select
            ~read:[s]
            ~write:[]
            ~except:[]
            ~timeout:(`After (Time_ns.Span.of_span timeout)) ()
        in
        match sfds.Unix.Select_fds.read with
        | [] -> None
        | s :: [] ->
          begin
            Unix.recvfrom s ~buf ~pos:0 ~len:(String.length buf) ~mode:[]
            |> ignore;
            let client_recv = Unix.gettimeofday () in
            Some {
              client_xmit = float_from_buf buf 24;
              server_recv = float_from_buf buf 32;
              server_xmit = float_from_buf buf 40;
              client_recv = client_recv
            }
          end
        | _ -> failwithf "BUG! too many file descriptors?!" ())
      ~finally:Unix.close
  ;;
end

let query ?(timeout=Time.Span.of_sec 5.0) ?(port=123) hostname =
  try
    begin match Internal.query ~timeout ~port hostname with
    | None -> `Timeout
    | Some x ->
      (* See rfc4330 and rfc5905 *)
      let t21 = x.Internal.server_recv -. x.Internal.client_xmit in
      let t34 = x.Internal.server_xmit -. x.Internal.client_recv in
      let offset = (t21 +. t34) /. 2.0 in
      `Offset (Time.Span.of_sec offset)
    end
  with e ->
    `Error e
;;
