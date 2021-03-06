open! Core
open! Async

(* This module is designed to help processess maintain update subscriptions that will
   automatically recover from lost connections. It exposes to the client when the
   subscription has been lost or recovered, so the client can choose how to handle a lost
   connection. *)

module Update : sig
  type ('response, 'error) t =
    | Attempting_new_connection
    | Connection_success of Rpc.Pipe_rpc.Metadata.t
    | Lost_connection
    | Failed_to_connect of Error.t
    | Rpc_error of 'error
    | Update of 'response
end

(* [create] will immediately dispatch the the supplied [Rpc.Pipe_rpc.t] with [query] over
   the [Rpc.Connection.t Durable.t]. If a connection attempt fails or if the subscription
   closes, it waits [resubscribe_delay] and dispatches again to create a new subscription.
   The pipe returned by [create] contains all the responses that come over the internal
   subscription, as well as updates about the state of the [t].

   Closing the returned pipe will permanently close the subscription.
*)
val create
  :  Rpc.Connection.t Durable.t
  -> ('query, 'response, 'error) Rpc.Pipe_rpc.t
  -> query:'query
  -> resubscribe_delay:Time.Span.t
  -> ('response, 'error) Update.t Pipe.Reader.t

(* [create_or_fail] will return an [Error e] if the initial attempt to dispatch the
   supplied [Rpc.Pipe_rpc.t] does not succeed, or an [Ok (Error 'error)] if the initial
   dispatch returns a server side rpc error. *)
val create_or_fail
  :  Rpc.Connection.t Durable.t
  -> ('query, 'response, 'error) Rpc.Pipe_rpc.t
  -> query:'query
  -> resubscribe_delay:Time.Span.t
  -> (('response, 'error) Update.t Pipe.Reader.t, 'error) Result.t Or_error.t Deferred.t
