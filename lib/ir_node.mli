(*
 * Copyright (c) 2013      Louis Gesbert     <louis.gesbert@ocamlpro.com>
 * Copyright (c) 2013-2015 Thomas Gazagnaire <thomas@gazagnaire.org>
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

(** Nodes represent structured values serialized in the block
    store. *)

module Make (C: Tc.S0) (N: Tc.S0) (P: Ir_s.PATH):
  Ir_s.NODE with type contents = C.t
             and type node = N.t
             and type step = P.step

module type GRAPH = sig
  type t
  type contents
  type node
  type step
  type path
  type metadata

  val empty: t -> node Lwt.t
  val create: t -> (step * [`Contents of contents | `Node of node]) list -> node Lwt.t

  val read_full: t -> node -> path ->
    (metadata * [`Contents of contents | `Node of node]) option Lwt.t

  val contents: t -> node -> step -> contents option Lwt.t
  val succ: t -> node -> step -> node option Lwt.t
  val steps: t -> node -> step list Lwt.t

  val iter_contents: t -> node -> (step -> contents -> unit) -> unit Lwt.t
  val iter_succ: t -> node -> (step -> node -> unit) -> unit Lwt.t

  val mem_contents: t -> node -> path -> bool Lwt.t
  val read_contents: t -> node -> path -> contents option Lwt.t
  val read_contents_exn: t -> node -> path -> contents Lwt.t
  val add_contents: t -> node -> path -> contents -> node Lwt.t
  val remove_contents: t -> node -> path -> node Lwt.t

  val mem_node: t -> node -> path -> bool Lwt.t
  val read_node: t -> node -> path -> node option Lwt.t
  val read_node_exn: t -> node -> path -> node Lwt.t
  val add_node: t -> node -> path -> node -> node Lwt.t
  val remove_node: t -> node -> path -> node Lwt.t

  val closure: t -> min:node list -> max:node list -> node list Lwt.t

  module Store: Ir_s.CONTENTS_STORE
    with type t = t
     and type key = node
     and type Path.t = path
     and type Path.step = step
end

module Graph (C: Ir_s.CONTENTS_STORE)
    (S: Ir_s.NODE_STORE with type Val.contents = C.key and module Path = C.Path)
  : GRAPH with type t = C.t * S.t
           and type contents = C.key
           and type node = S.key
           and type step = S.Path.step
           and type path = S.Path.t
           and type metadata = S.Val.metadata
