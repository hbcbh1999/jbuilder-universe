(*
 * Copyright (C) 2016-present David Scott <dave.scott@docker.com>
 * Copyright (c) 2011-present Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2013-present Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(** {1 Flow-related devices using lwt}

    This module define flow-related devices for MirageOS, using lwt for I/O.

    {e Release v1.3.0 } *)

open Result
open Mirage_flow

module type S = Mirage_flow.S
  with type 'a io = 'a Lwt.t
   and type buffer = Cstruct.t

module type ABSTRACT = Mirage_flow.ABSTRACT
  with type 'a io = 'a Lwt.t
   and type buffer = Cstruct.t

module type CONCRETE =  Mirage_flow.CONCRETE
  with type 'a io = 'a Lwt.t
   and type buffer = Cstruct.t

module Concrete (S: S): CONCRETE
  with type buffer = S.buffer
   and type flow = S.flow

module type SHUTDOWNABLE = Mirage_flow.SHUTDOWNABLE
  with type 'a io = 'a Lwt.t
   and type buffer = Cstruct.t

module Copy (Clock: Mirage_clock.MCLOCK) (A: S) (B: S): sig

  type error = [`A of A.error | `B of B.write_error]
  (** The type for copy errors. *)

  val pp_error: error Fmt.t
  (** [pp_error] pretty-prints errors. *)

val copy: Clock.t -> src:A.flow -> dst:B.flow -> (stats, error) result Lwt.t
(** [copy clock source destination] copies data from [source] to
    [destination] using the clock to compute a transfer rate. On
    successful completion, some statistics are returned. On failure we
    return a printable error. *)

end

module Proxy (Clock: Mirage_clock.MCLOCK) (A: SHUTDOWNABLE) (B: SHUTDOWNABLE):
sig

  type error
  (** The type for proxy errors. *)

  val pp_error: error Fmt.t
  (** [pp_error] pretty-prints errors. *)

  val proxy: Clock.t -> A.flow -> B.flow -> ((stats * stats), error) result Lwt.t
  (** [proxy clock a b] proxies data between [a] and [b] until both
      sides close. If either direction encounters an error then so
      will [proxy]. If both directions succeed, then return I/O
      statistics. *)

end

module F: sig

  (** In-memory, function-based flows. *)

  include S

  type refill = Cstruct.t -> int -> int -> int Lwt.t
  (** The type for refill functions. *)

  val make:
    ?close:(unit -> unit Lwt.t) ->
    ?input:refill ->
    ?output:refill ->
    unit -> flow
  (** [make ~close ~input ~output ()] is a flow using [input] to
      refill its internal input buffer when needed and [output] to
      refill its external output buffer. It is using [close] to
      eventually clean-up other resources on close. *)

  (** {1 String flows} *)

  val input_string: string -> refill
  (** [input_string buf] is the refill function reading its inputs
      from the string [buf]. *)

  val output_bytes: bytes -> refill
  (** [output_bytes buf] is the refill function writing its outputs in
      the buffer [buf]. *)

  val string: ?input:string -> ?output:bytes -> unit -> flow
  (** The flow built using {!input_string} and {!output_bytes}. *)

  val input_strings: string list -> refill
  (** [input_strings bufs] is the refill function reading its inputs
      from the list of buffers [bufs]. Empty strings are ignored. *)

  val output_bytess: bytes list -> refill
  (** [output_bytess buf] is the refill function writing its outputs in
      the list of buffers [buf]. Empty strings are ignored. *)

  val strings: ?input:string list -> ?output:bytes list -> unit -> flow
  (** The flow built using {!input_strings} and {!output_bytess}. *)

  (** {1 Cstruct buffers flows} *)

  val input_cstruct: Cstruct.t -> refill
  (** Same as {!input_string} but for {!Cstruct.t} buffers. *)

  val output_cstruct: Cstruct.t -> refill
  (** Same as {!output_string} buf for {!Cstruct.t} buffers. *)

  val cstruct: ?input:Cstruct.t -> ?output:Cstruct.t -> unit -> flow
  (** Same as {!string} but for {!Cstruct.t} buffers. *)

  val input_cstructs: Cstruct.t list -> refill
  (** Same as {!input_strings} but for {!Cstruct.t} buffers. *)

  val output_cstructs: Cstruct.t list -> refill
  (** Same as {!output_strings} but for {!Cstruct.t} buffers. *)

  val cstructs: ?input:Cstruct.t list -> ?output:Cstruct.t list -> unit -> flow
  (** Same as {!strings} but for {!Cstruct.t} buffers. *)

end
