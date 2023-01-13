(* Do not edit this file, it was generated automatically *)
(** Heavily annotated for a tutorial introduction. *)

(** First, import the entire Floyd proof automation system, which includes
 ** the VeriC program logic and the MSL theory of separation logic**)
Require Import VST.floyd.proofauto.

(** Import the [reverse.v] file, which is produced by CompCert's clightgen
 ** from reverse.c.   The file reverse.v defines abbreviations for identifiers
 ** (variable names, etc.) of the C program, such as _head, _reverse.
 ** It also defines "prog", which is the entire abstract syntax tree
 ** of the C program *)
Require Import VST.progs64.reverse.

(* The C programming language has a special namespace for struct
** and union identifiers, e.g., "struct foo {...}".  Some type-based operators
** in the program logic need access to an interpretation of this namespace,
** i.e., the meaning of each struct-identifier such as "foo".  The next
** line (which looks identical for any program) builds this
** interpretation, called "CompSpecs" *)
#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.

(** Calculate the "types-of-global-variables" specification
 ** directly from the program *)
Definition Vprog : varspecs. mk_varspecs prog. Defined.

(** A convenience definition *)
Definition t_struct_list := Tstruct _list noattr.

(** Inductive definition of linked lists *)
Fixpoint listrep (sigma: list val) (x: val) : mpred :=
 match sigma with
 | h::hs => 
    EX y:val, 
      data_at Tsh t_struct_list (h,y) x  *  listrep hs y
 | nil => 
    !! (x = nullval) && emp
 end.

Arguments listrep sigma x : simpl never.

(** Whenever you define a new spatial operator, such as
 ** [listrep] here, it's useful to populate two hint databases.
 ** The [saturate_local] hint is a lemma that extracts
 ** pure propositional facts from a spatial fact.
 ** The [valid_pointer] hint is a lemma that extracts a
 ** valid-pointer fact from a spatial lemma.
 **)

Lemma listrep_local_facts:
  forall sigma p,
   listrep sigma p |--
   !! (is_pointer_or_null p /\ (p=nullval <-> sigma=nil)).
Proof.
intros.
revert p; induction sigma; 
  unfold listrep; fold listrep; intros. entailer!. intuition.
Intros y. entailer!.
split; intro. subst p. destruct H; contradiction. inv H2.
Qed.

#[export] Hint Resolve listrep_local_facts : saturate_local.

Lemma listrep_valid_pointer:
  forall sigma p,
   listrep sigma p |-- valid_pointer p.
Proof.
 destruct sigma; unfold listrep; fold listrep; intros; Intros; subst.
 auto with valid_pointer.
 Intros y.
 apply sepcon_valid_pointer1.
 apply data_at_valid_ptr; auto.
 simpl;  computable.
Qed.

#[export] Hint Resolve listrep_valid_pointer : valid_pointer.

(** Specification of the [reverse] function.  It characterizes
 ** the precondition required for calling the function,
 ** and the postcondition guaranteed by the function.
 **)
Definition reverse_spec :=
 DECLARE _reverse
  WITH sigma : list val, p: val
  PRE  [ tptr t_struct_list ]
     PROP ()
     PARAMS (p)
     SEP (listrep sigma p)
  POST [ (tptr t_struct_list) ]
    EX q:val,
     PROP () RETURN (q)
     SEP (listrep(rev sigma) q).

(** The global function spec, characterizing the
 ** preconditions/postconditions of all the functions
 ** that your proved-correct program will call. 
 ** Normally you include all the functions here, but
 ** in this tutorial example we include only one. *)
Definition Gprog : funspecs :=[ reverse_spec ].

(** For each function definition in the C program, prove that the
 ** function-body (in this case, f_reverse) satisfies its specification
 ** (in this case, reverse_spec).
 **)

Inductive funspec_part :=
   mk_funspec_part: compcert_rmaps.typesig -> calling_convention -> forall (A: rmaps.TypeTree)
     (P: forall ts, functors.MixVariantFunctor._functor (rmaps.dependent_type_functor_rec ts (ArgsTT A)) mpred)
     (P_ne: args_super_non_expansive P),
     funspec_part.

Definition semax_body_part
   (V: varspecs) (G: funspecs) {C: compspecs} (f: function) (spec: ident * funspec_part) :=
match spec with (_, mk_funspec_part fsig cc A P _) => { Q & (*{ Q_ne |*)
  fst fsig = map snd (fst (fn_funsig f)) /\ 
  snd fsig = snd (fn_funsig f) /\
forall Espec ts x,
  @semax C Espec (func_tycontext f V G nil)
      (fun rho => close_precondition (map fst f.(fn_params)) (P ts x) rho * stackframe_of f rho)%logic
       f.(fn_body)
      (frame_ret_assert (function_body_ret_assert (fn_return f) (Q ts x)) (stackframe_of f)) (*}*) }
end.

Notation reverse_pre := (fun (_ : list Type) x => match x with (sigma, p) => PROP () PARAMS (p) SEP (listrep sigma p) end).

Program Definition reverse_spec_part := (_reverse, mk_funspec_part ([tptr t_struct_list], tptr t_struct_list)
  cc_default (rmaps.ConstType (list val * val)) reverse_pre (args_const_super_non_expansive _ reverse_pre)).

Ltac start_function1 ::=
 leaf_function;
 lazymatch goal with |- @semax_body_part ?V ?G ?cs ?F ?spec =>
    check_normalized F;
    function_body_unsupported_features F;
    let s := fresh "spec" in
    pose (s:=spec); hnf in s; cbn zeta in s; (* dependent specs defined with Program Definition often have extra lets *)
   repeat lazymatch goal with
    | s := (_, NDmk_funspec _ _ _ _ _) |- _ => fail
    | s := (_, mk_funspec _ _ _ _ _ _ _) |- _ => fail
    | s := (_, ?a _ _ _ _) |- _ => unfold a in s
    | s := (_, ?a _ _ _) |- _ => unfold a in s
    | s := (_, ?a _ _) |- _ => unfold a in s
    | s := (_, ?a _) |- _ => unfold a in s
    | s := (_, ?a) |- _ => unfold a in s
    end;
    lazymatch goal with
    | s :=  (_,  WITH _: globals
               PRE  [] main_pre _ _ _
               POST [ tint ] _) |- _ => idtac
    | s := ?spec' |- _ => check_canonical_funspec spec'
   end;
   change (@semax_body_part V G cs F s); subst s;
   unfold NDmk_funspec'
 end;
 let DependedTypeList := fresh "DependedTypeList" in
 unfold NDmk_funspec; 
 match goal with |- semax_body_part _ _ _ (pair _ (mk_funspec_part _ _ _ ?Pre _)) =>

   eexists; split3; [check_parameter_types' | check_return_type | ];
    match Pre with
   | (fun _ => convertPre _ _ (fun i => _)) =>  intros Espec DependedTypeList i
   | (fun _ x => match _ with (a,b) => _ end) => intros Espec DependedTypeList [a b]
   | (fun _ i => _) => intros Espec DependedTypeList i
   end;
   simpl fn_body; simpl fn_params; simpl fn_return
 end;
 try match goal with |- semax _ (fun rho => ?A rho * ?B rho)%logic _ _ =>
     change (fun rho => ?A rho * ?B rho)%logic with (A * B)%logic
  end;
 simpl functors.MixVariantFunctor._functor in *;
 simpl rmaps.dependent_type_functor_rec;
 rewrite_old_main_pre;
 repeat match goal with
 | |- @semax _ _ _ (match ?p with (a,b) => _ end * _)%logic _ _ =>
             destruct p as [a b]
 | |- @semax _ _ _ (close_precondition _ match ?p with (a,b) => _ end * _)%logic _ _ =>
             destruct p as [a b]
 | |- @semax _ _ _ ((match ?p with (a,b) => _ end) eq_refl * _)%logic _ _ =>
             destruct p as [a b]
 | |- @semax _ _ _ (close_precondition _ ((match ?p with (a,b) => _ end) eq_refl) * _)%logic _ _ =>
             destruct p as [a b]
 | |- semax _ (close_precondition _
                                                (fun ae => !! (Datatypes.length (snd ae) = ?A) && ?B
                                                      (make_args ?C (snd ae) (mkEnviron (fst ae) _ _))) * _)%logic _ _ =>
          match B with match ?p with (a,b) => _ end => destruct p as [a b] end
       end;
(* this speeds things up, but only in the very rare case where it applies,
   so maybe not worth it ...
  repeat match goal with H: reptype _ |- _ => progress hnf in H; simpl in H; idtac "reduced a reptype" end;
*)
 try start_func_convert_precondition.

Lemma body_reverse: semax_body_part Vprog Gprog
                                    f_reverse reverse_spec_part.
Proof.
start_function.
(** For each assignment statement, "symbolically execute" it
 ** using the forward tactic *)
unfold POSTCONDITION, abbreviate.
forward.  (* w = NULL; *)
forward.  (* v = p; *)
(** To prove a while-loop, you must supply a loop invariant,
 ** in this case (EX s1  PROP(...)LOCAL(...)(SEP(...)).  *)
forward_while
   (EX s1: list val, EX s2 : list val, 
    EX w: val, EX v: val,
     PROP (sigma = rev s1 ++ s2)
     LOCAL (temp _w w; temp _v v)
     SEP (listrep s1 w; listrep s2 v)).
(** The forward_while tactic leaves four subgoals,
 ** which we mark with * (the Coq "bullet") *)
* (* Prove that precondition implies loop invariant *)
Exists (@nil val) sigma nullval p.
entailer!.
unfold listrep.
entailer!.
* (* Prove that loop invariant implies typechecking of loop condition *)
entailer!.
* (* Prove that loop body preserves invariant *)
destruct s2 as [ | h r].
 - unfold listrep at 2. 
   Intros. subst. contradiction.
 - unfold listrep at 2; fold listrep.
   Intros y.
   forward. (* t = v->tail *)
   forward. (* v->tail = w; *)
   forward. (* w = v; *)
   forward. (* v = t; *)
   (* At end of loop body; reestablish invariant *)
   entailer!.
   Exists (h::s1,r,v,y).
   entailer!.
   + simpl. rewrite app_ass. auto.
   + unfold listrep at 3; fold listrep.
     Exists w. entailer!.
* (* after the loop *)
unfold POSTCONDITION, abbreviate.
instantiate (1 := fun '(sigma, p) => EX w, PROP () RETURN (w) SEP (listrep (rev sigma) w)).
forward.  (* return w; *)
Exists w; entailer!.
rewrite (proj1 H1) by auto.
unfold listrep at 2; fold listrep.
entailer!.
rewrite <- app_nil_end, rev_involutive.
auto.
Defined.

Eval simpl in projT1 body_reverse.
