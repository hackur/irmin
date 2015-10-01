(*
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

module type STORE = sig
  include Ir_bc.STORE
  module Key: Ir_path.S with type t = key
  module Val: Ir_contents.S with type t = value
  module Branch: Ir_tag.S with type t = branch_id
  module Head: Ir_hash.S with type t = head
  module Private: sig
    include Ir_bc.PRIVATE
      with type Contents.value = value
       and module Contents.Path = Key
       and type Commit.key = head
       and type Slice.t = slice
       and type Branch.key = branch_id
    val config: t -> Ir_conf.t
    val contents_t: t -> Contents.t
    val node_t: t -> Node.t
    val commit_t: t -> Commit.t
    val branch_t: t -> Branch.t
    val read_node: t -> key -> Node.key option Lwt.t
    val mem_node: t -> key -> bool Lwt.t
    val update_node: t -> key -> Node.key -> unit Lwt.t
    val merge_node: t -> key -> (head * Node.key) -> unit Ir_merge.result Lwt.t
    val remove_node: t -> key -> unit Lwt.t
    val iter_node: t -> Node.key ->
      (key -> value Lwt.t -> unit Lwt.t) -> unit Lwt.t
  end
end

module type MAKER =
  functor (C: Ir_contents.S) ->
  functor (B: Ir_tag.S) ->
  functor (H: Ir_hash.S) ->
    STORE with type key = C.Path.t
           and type value = C.t
           and type branch_id = B.t
           and type head = H.t

module Make_ext (P: Ir_bc.PRIVATE) = struct
  module P = Ir_bc.Make_ext(P)
  include (P: module type of P with module Private := P.Private)
  module Branch = P.Private.Branch.Key
  module Head = P.Private.Commit.Key
  module Private = struct
    include P.Private
    let config = P.config
    let contents_t = P.contents_t
    let node_t = P.node_t
    let commit_t = P.commit_t
    let branch_t = P.branch_t
    let update_node = P.update_node
    let merge_node = P.merge_node
    let remove_node = P.remove_node
    let mem_node = P.mem_node
    let read_node = P.read_node
    let iter_node = P.iter_node
  end
end

module Make
    (AO: Ir_ao.MAKER)
    (RW: Ir_rw.MAKER)
    (C: Ir_contents.S)
    (B: Ir_tag.S)
    (H: Ir_hash.S) =
struct
  module X = struct
    module Contents = Ir_contents.Make(struct
        include AO(H)(C)
        module Key = H
        module Val = C
      end)
    module Node = struct
      module Key = H
      module Val = Ir_node.Make (H)(H)(C.Path)
      module Path = C.Path
      include AO (Key)(Val)
    end
    module Commit = struct
      module Key = H
      module Val = Ir_commit.Make (H)(H)
      include AO (Key)(Val)
    end
    module Branch = struct
      module Key = B
      module Val = H
      include RW (Key)(Val)
    end
    module Slice = Ir_slice.Make(Contents)(Node)(Commit)
    module Sync = Ir_sync.None(H)(B)
  end
  include Make_ext(X)
end

module Default (S: MAKER) (C: Ir_contents.S) = S(C)(Ir_tag.String)(Ir_hash.SHA1)
