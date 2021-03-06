open Lwt

include Faraday_lwt

let write fd buf off len =
  try Lwt_unix.write fd buf off len >|= fun n -> `Ok n
  with Unix.Unix_error (Unix.EBADF, "check_descriptor", _) -> return `Closed

let write_string fd buf off len =
  try Lwt_unix.write_string fd buf off len >|= fun n -> `Ok n
  with Unix.Unix_error (Unix.EBADF, "check_descriptor", _) -> return `Closed

let write_bigstring fd buf off len =
  try Lwt_bytes.write fd buf off len >|= fun n -> `Ok n
  with Unix.Unix_error (Unix.EBADF, "check_descriptor", _) -> return `Closed

let writev_of_fd fd =
  (* XXX(seliopou): This function only writes the first iovec because lwt
     currently does not expose a writev function. That system call should be
     bound manually at some point in the future. *)
  function
  | []       -> assert false
  | { Faraday.buffer = `Bytes     buf; off; len }::_ -> write           fd buf off len
  | { Faraday.buffer = `String    buf; off; len }::_ -> write_string    fd buf off len
  | { Faraday.buffer = `Bigstring buf; off; len }::_ -> write_bigstring fd buf off len
