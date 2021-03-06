open Core_kernel.Std
open Bistro.Std
open Bistro.EDSL
open Defs

let env = docker_image ~account:"pveber" ~name:"htseq" ~tag:"0.6.1" ()

class type count_tsv = object
  inherit [ < header : [`no] ; .. > ] tsv
  method f1 : string
  method f2 : int
end

let string_of_mode = function
  | `union -> "union"
  | `intersection_strict -> "intersection-strict"
  | `intersection_nonempty -> "intersection-nonempty"

let string_of_strandedness = function
  | `yes -> "yes"
  | `no -> "no"
  | `reverse -> "reverse"

let string_of_order = function
  | `name -> "name"
  | `position -> "pos"

let count ?order ?mode ?stranded ?feature_type ?minaqual ?idattribute alns gff =
  let format, input = match alns with
    | `sam sam -> "sam", dep sam
    | `bam bam -> "bam", dep bam
  in
  workflow ~descr:"htseq-count" [
    cmd "htseq-count" ~env ~stdout:dest [
      opt "-f" string format ;
      option (opt "-m" (string_of_mode % string)) mode ;
      option (opt "-r" (string_of_order % string)) order ;
      option (opt "-s" (string_of_strandedness % string)) stranded ;
      option (opt "-t" string) feature_type ;
      option (opt "-a" int) minaqual ;
      option (opt "-i" string) idattribute ;
      input ;
      dep gff ;
    ]
  ]
