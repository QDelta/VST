From compcert Require Export Clightdefs.
Require Export VST.veric.SeparationLogic.
Require Export VST.msl.Extensionality.
Require Export compcert.lib.Coqlib.
Require Export VST.msl.Coqlib2 VST.veric.coqlib4 VST.floyd.coqlib3.
Require Export VST.floyd.jmeq_lemmas.
Require Export VST.floyd.find_nth_tactic.
Require Export VST.veric.juicy_extspec.
Require VST.veric.SeparationLogicSoundness.
Export SeparationLogicSoundness.SoundSeparationLogic.CSL.
Require Import VST.veric.NullExtension.
Require Import VST.floyd.assert_lemmas.
Require Import VST.floyd.SeparationLogicFacts.
Local Open Scope logic.

Fixpoint all_suf_of_labeled_statements (P: labeled_statements -> Prop) (L: labeled_statements): Prop :=
  match L with
  | LSnil => P L
  | LScons _ s L' => P L /\ all_suf_of_labeled_statements P L'
  end.

Lemma all_suf_self: forall P L,
  all_suf_of_labeled_statements P L -> P L.
Proof.
  intros.
  destruct L; simpl in *; tauto.
Qed.

Lemma all_suf_LSnil: forall P L,
  all_suf_of_labeled_statements P L -> P LSnil.
Proof.
  intros.
  induction L; simpl in *; tauto.
Qed.

Lemma all_suf_select_switch: forall P L,
  all_suf_of_labeled_statements P L ->
  forall n, P (select_switch n L).
Proof.
  intros.
  unfold select_switch.
  destruct (select_switch_case) eqn:?H.
  + revert l H0; induction L; intros.
    - inv H0.
    - simpl in H0.
      destruct o; [if_tac in H0 |].
      * subst z; inv H0.
        destruct H as [? _]; auto.
      * apply IHL; auto.
        destruct H as [_ ?]; auto.
      * apply IHL; auto.
        destruct H as [_ ?]; auto.
  + clear H0.
    induction L.
    - apply all_suf_LSnil in H.
      auto.
    - simpl.
      destruct o.
      * destruct H as [_ ?].
        apply IHL; auto.
      * destruct H as [? _].
        auto.
Qed.

Section statement_ind.

Variables
  (P: statement -> Prop)
  (Hskip: P Sskip)
  (Hassign: forall e e0, P (Sassign e e0))
  (Hset : forall (i : ident) (e : expr), P (Sset i e))
  (Hcall : forall (o : option ident) (e : expr) (l : list expr), P (Scall o e l))
  (Hbuiltin : forall o e t l, P (Sbuiltin o e t l))
  (Hsequence : forall s : statement, P s -> forall s0 : statement, P s0 -> P (Ssequence s s0))
  (Hifthenelse : forall e s, P s -> forall s0, P s0 -> P (Sifthenelse e s s0))
  (Hloop : forall s : statement, P s -> forall s0 : statement, P s0 -> P (Sloop s s0))
  (Hbreak : P Sbreak)
  (Hcontinue : P Scontinue)
  (Hreturn : forall o : option expr, P (Sreturn o))
  (Hswitch : forall e L, all_suf_of_labeled_statements (fun L => P (seq_of_labeled_statement L)) L -> P (Sswitch e L))
  (Hlabel : forall (l : label) (s : statement), P s -> P (Slabel l s))
  (Hgoto : forall l : label, P (Sgoto l)).

Fixpoint statement_ind (s: statement): P s :=
  match s as s0 return (P s0) with
  | Sskip => Hskip
  | Sassign e e0 => Hassign e e0
  | Sset i e => Hset i e
  | Scall o e l => Hcall o e l
  | Sbuiltin o e t l => Hbuiltin o e t l
  | Ssequence s0 s1 => Hsequence s0 (statement_ind s0) s1 (statement_ind s1)
  | Sifthenelse e s0 s1 => Hifthenelse e s0 (statement_ind s0) s1 (statement_ind s1)
  | Sloop s0 s1 => Hloop s0 (statement_ind s0) s1 (statement_ind s1)
  | Sbreak => Hbreak
  | Scontinue => Hcontinue
  | Sreturn o => Hreturn o
  | Sswitch e l => Hswitch e l (labeled_statements_ind l)
  | Slabel l s0 => Hlabel l s0 (statement_ind s0)
  | Sgoto l => Hgoto l
  end
with labeled_statements_ind (L: labeled_statements): all_suf_of_labeled_statements (fun L => P (seq_of_labeled_statement L)) L :=
  match L with
  | LSnil => Hskip
  | LScons _ s L' => conj (Hsequence _ (statement_ind s) _ (all_suf_self _ _ (labeled_statements_ind L'))) (labeled_statements_ind L')
  end.

End statement_ind.

Ltac induction_stmt s :=
  revert dependent s;
  let s1 := fresh s "1" in
  let s2 := fresh s "2" in
  let IHs := fresh "IH" s in
  let IHs1 := fresh "IH" s1 in
  let IHs2 := fresh "IH" s2 in
  refine (statement_ind _ _ _ _ _ _ _ _ _ _ _ _ _ _ _);
  [
  | intros ?e ?e
  | intros ?i ?e
  | intros ?o ?e ?l
  | intros ?o ?e ?t ?l
  | intros s1 IHs1 s2 IHs2
  | intros ?e s1 IHs1 s2 IHs2
  | intros s1 IHs1 s2 IHs2
  |
  |
  | intros ?o
  | intros ?e ?l ?IH; specialize (all_suf_select_switch _ _ IH); clear IH; intro IH; cbv beta in IH
  | intros ?l s IHs
  | intros ?l ].

Module ClightSeparationHoareLogic.

Module AuxDefs.

Inductive semax {CS: compspecs} {Espec: OracleKind} (Delta: tycontext): (environ -> mpred) -> statement -> ret_assert -> Prop :=
| semax_ifthenelse :
   forall P (b: expr) c d R,
     @semax CS Espec Delta (P && local (`(typed_true (typeof b)) (eval_expr b))) c R ->
     @semax CS Espec Delta (P && local (`(typed_false (typeof b)) (eval_expr b))) d R ->
     @semax CS Espec Delta (!! (bool_type (typeof b) = true) && tc_expr Delta (Eunop Cop.Onotbool b (Tint I32 Signed noattr)) && P) (Sifthenelse b c d) R
| semax_seq:
  forall R P Q h t,
    @semax CS Espec Delta P h (overridePost Q R) ->
    @semax CS Espec Delta Q t R ->
    @semax CS Espec Delta P (Ssequence h t) R
| semax_break: forall Q,
    @semax CS Espec Delta (RA_break Q) Sbreak Q
| semax_continue: forall Q,
    @semax CS Espec Delta (RA_continue Q) Scontinue Q
| semax_loop: forall Q Q' incr body R,
     @semax CS Espec Delta  Q body (loop1_ret_assert Q' R) ->
     @semax CS Espec Delta Q' incr (loop2_ret_assert Q R) ->
     @semax CS Espec Delta Q (Sloop body incr) R
| semax_switch: forall (Q: environ->mpred) a sl R,
     (forall rho, Q rho |-- tc_expr Delta a rho) ->
     (forall n,
     @semax CS Espec Delta 
               (local (`eq (eval_expr a) `(Vint n)) &&  Q)
               (seq_of_labeled_statement (select_switch (Int.unsigned n) sl))
               (switch_ret_assert R)) ->
     @semax CS Espec Delta (!! (is_int_type (typeof a) = true) && Q) (Sswitch a sl) R
| semax_call_backward: forall ret a bl R,
     @semax CS Espec Delta
         (EX argsig: _, EX retsig: _, EX cc: _,
          EX A: _, EX P: _, EX Q: _, EX NEP: _, EX NEQ: _, EX ts: _, EX x: _,
         !! (Cop.classify_fun (typeof a) =
             Cop.fun_case_f (type_of_params argsig) retsig cc /\
             (retsig = Tvoid -> ret = None) /\
             tc_fn_return Delta ret retsig) &&
          (|>((tc_expr Delta a) && (tc_exprlist Delta (snd (split argsig)) bl)))  &&
         `(func_ptr (mk_funspec  (argsig,retsig) cc A P Q NEP NEQ)) (eval_expr a) &&
          |>((`(P ts x: environ -> mpred) (make_args' (argsig,retsig) (eval_exprlist (snd (split argsig)) bl))) * oboxopt Delta ret (maybe_retval (Q ts x) retsig ret -* R)))
         (Scall ret a bl)
         (normal_ret_assert R)
| semax_return: forall (R: ret_assert) ret ,
      @semax CS Espec Delta
                ( (tc_expropt Delta ret (ret_type Delta)) &&
                `(RA_return R : option val -> environ -> mpred) (cast_expropt ret (ret_type Delta)) (@id environ))
                (Sreturn ret)
                R
| semax_set_ptr_comparison_load_cast_load_backward: forall (P: environ->mpred) id e,
    @semax CS Espec Delta
       ((|> ( (tc_expr Delta e) &&
             (tc_temp_id id (typeof e) Delta e) &&
             subst id (eval_expr e) P)) ||
        (EX cmp: Cop.binary_operation, EX e1: expr, EX e2: expr,
         EX ty: type, EX sh1: share, EX sh2: share,
          !! (e = Ebinop cmp e1 e2 ty /\
              sepalg.nonidentity sh1 /\ sepalg.nonidentity sh2 /\
              is_comparison cmp = true /\
              eqb_type (typeof e1) int_or_ptr_type = false /\
              eqb_type (typeof e2) int_or_ptr_type = false /\
              typecheck_tid_ptr_compare Delta id = true) &&
            ( |> ( (tc_expr Delta e1) &&
              (tc_expr Delta e2)  &&
          local (`(blocks_match cmp) (eval_expr e1) (eval_expr e2)) &&
          (`(mapsto_ sh1 (typeof e1)) (eval_expr e1) * TT) &&
          (`(mapsto_ sh2 (typeof e2)) (eval_expr e2) * TT) &&
          subst id (eval_expr (Ebinop cmp e1 e2 ty)) P))) ||
        (EX sh: share, EX t2: type, EX v2: val,
              !! (typeof_temp Delta id = Some t2 /\
                  is_neutral_cast (typeof e) t2 = true /\
                  readable_share sh) &&
         |> ( (tc_lvalue Delta e) &&
              local (`(tc_val (typeof e) v2)) &&
              (`(mapsto sh (typeof e)) (eval_lvalue e) (`v2) * TT) &&
              subst id (`v2) P)) ||
        (EX sh: share, EX e1: expr, EX t1: type, EX v2: val,
              !! (e = Ecast e1 t1 /\
                  typeof_temp Delta id = Some t1 /\
                  cast_pointer_to_bool (typeof e1) t1 = false /\
                  readable_share sh) &&
         |> ( (tc_lvalue Delta e1) &&
              local (`(tc_val t1) (`(eval_cast (typeof e1) t1 v2))) &&
              (`(mapsto sh (typeof e1)) (eval_lvalue e1) (`v2) * TT) &&
              subst id (`(force_val (sem_cast (typeof e1) t1 v2))) P)))
        (Sset id e) (normal_ret_assert P)
| semax_store_backward: forall e1 e2 P,
   @semax CS Espec Delta
          (EX sh: share, !! writable_share sh && |> ( (tc_lvalue Delta e1) &&  (tc_expr Delta (Ecast e2 (typeof e1)))  &&
             ((`(mapsto_ sh (typeof e1)) (eval_lvalue e1)) * (`(mapsto sh (typeof e1)) (eval_lvalue e1) (`force_val (`(sem_cast (typeof e2) (typeof e1)) (eval_expr e2))) -* P))))
          (Sassign e1 e2)
          (normal_ret_assert P)
| semax_skip: forall P, @semax CS Espec Delta P Sskip (normal_ret_assert P)
| semax_builtin: forall P opt ext tl el, @semax CS Espec Delta FF (Sbuiltin opt ext tl el) P
| semax_label: forall P l c, @semax CS Espec Delta FF (Slabel l c) P
| semax_goto: forall P l, @semax CS Espec Delta FF (Sgoto l) P
| semax_pre_post_indexed_bupd: forall P' (R': ret_assert) P c (R: ret_assert) ,
    (local (tc_environ Delta) && P |-- |==> ((|> FF) || P')) ->
    local (tc_environ Delta) && RA_normal R' |-- |==> ((|> FF) || RA_normal R) ->
    local (tc_environ Delta) && RA_break R' |-- |==> ((|> FF) || RA_break R) ->
    local (tc_environ Delta) && RA_continue R' |-- |==> ((|> FF) || RA_continue R) ->
    (forall vl, local (tc_environ Delta) && RA_return R' vl |-- |==> ((|> FF) || RA_return R vl)) ->
   @semax CS Espec Delta P' c R' -> @semax CS Espec Delta P c R.

End AuxDefs.

Module Defs<: CLIGHT_SEPARATION_HOARE_LOGIC_DEF.

Definition semax: forall {CS: compspecs} {Espec: OracleKind} (Delta: tycontext), (environ -> mpred) -> statement -> ret_assert -> Prop := @AuxDefs.semax.

End Defs.

Module IConseq: CLIGHT_SEPARATION_HOARE_LOGIC_STEP_INDEXED_CONSEQUENCE with Module CSHL_Def := Defs.

Module CSHL_Def := Defs.
Import CSHL_Def.

Definition semax_pre_post_indexed_bupd := @AuxDefs.semax_pre_post_indexed_bupd.

End IConseq.

Module IConseqFacts := CSHL_IConseqFacts (Defs) (IConseq).

Module Conseq := CSHL_GenConseq (Defs) (IConseq).

Module ConseqFacts := CSHL_ConseqFacts (Defs) (Conseq).

Export Defs IConseq IConseqFacts Conseq ConseqFacts.

Lemma semax_skip_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R,
    @semax CS Espec Delta P Sskip R ->
    local (tc_environ Delta) && P |-- |==> |> FF || RA_normal R.
Proof.
  intros.
  remember Sskip as c eqn:?H.
  induction H; try solve [inv H0].
  + apply derives_bupd0_refl.
  + specialize (IHsemax H0).
    solve_derives_trans.
Qed.

Lemma semax_break_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R,
    @semax CS Espec Delta P Sbreak R ->
    local (tc_environ Delta) && P |-- |==> |> FF || RA_break R.
Proof.
  intros.
  remember Sbreak as c eqn:?H.
  induction H; try solve [inv H0].
  + apply derives_bupd0_refl.
  + specialize (IHsemax H0).
    solve_derives_trans.
Qed.

Lemma semax_continue_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R,
    @semax CS Espec Delta P Scontinue R ->
    local (tc_environ Delta) && P |-- |==> |> FF || RA_continue R.
Proof.
  intros.
  remember Scontinue as c eqn:?H.
  induction H; try solve [inv H0].
  + apply derives_bupd0_refl.
  + specialize (IHsemax H0).
    solve_derives_trans.
Qed.

Lemma semax_return_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P ret R,
  @semax CS Espec Delta P (Sreturn ret) R ->
  local (tc_environ Delta) && P |-- |==> |> FF || ((tc_expropt Delta ret (ret_type Delta)) && `(|==> |> FF || RA_return R : option val -> environ -> mpred) (cast_expropt ret (ret_type Delta)) (@id environ)).
Proof.
  intros.
  remember (Sreturn ret) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0.
    reduce2ENTAIL.
    apply andp_ENTAIL; [apply ENTAIL_refl |].
    reduce2derives.
    unfold_lift.
    intro rho.
    simpl.
    eapply derives_trans; [| apply bupd_intro].
    apply orp_right2; auto.
  + derives_rewrite -> H; clear H.
    derives_rewrite -> (IHsemax H0); clear IHsemax.
    reduce2ENTAIL.
    apply andp_ENTAIL; [apply ENTAIL_refl |].
    unfold_lift.
    intro rho.
    simpl.
    forget (cast_expropt ret (ret_type Delta) rho) as vl.
    revert rho.
    change (local (tc_environ Delta) && (|==> |> FF || RA_return R' vl) |-- |==> |> FF || RA_return R vl).
    apply derives_bupd0_bupd0_left.
    apply H4.
Qed.

Lemma semax_seq_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R h t,
    @semax CS Espec Delta P (Ssequence h t) R ->
    exists Q, @semax CS Espec Delta P h (overridePost Q R) /\
              @semax CS Espec Delta Q t R.
Proof.
  intros.
  remember (Ssequence h t) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0.
    exists Q; auto.
  + subst c.
    pose proof IHsemax eq_refl. clear IHsemax.
    destruct H0 as [Q [? ?]].
    exists Q.
    split.
    - apply (AuxDefs.semax_pre_post_indexed_bupd _ P' (overridePost Q R')); auto.
      * clear.
        destruct R, R'.
        apply derives_bupd0_refl.
      * destruct R, R'; auto.
      * destruct R, R'; auto.
      * destruct R, R'; auto.
    - apply (semax_post_indexed_bupd R'); auto.
Qed.

Lemma semax_seq_inv': forall {CS: compspecs} {Espec: OracleKind} Delta P R h t,
    @semax CS Espec Delta P (Ssequence h t) R ->
    @semax CS Espec Delta P h (overridePost (EX Q: environ -> mpred, !! (@semax CS Espec Delta Q t R) && Q) R).
Proof.
  intros.
  remember (Ssequence h t) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0.
    clear IHsemax1 IHsemax2.
    eapply semax_post; [.. | exact H].
    - apply andp_left2; destruct R; unfold overridePost, tycontext.RA_normal.
      apply (exp_right Q).
      apply andp_right; [apply prop_right |]; auto.
    - destruct R; apply andp_left2, derives_refl.
    - destruct R; apply andp_left2, derives_refl.
    - intro; destruct R; apply andp_left2, derives_refl.
  + subst c.
    pose proof IHsemax eq_refl. clear IHsemax.
    eapply AuxDefs.semax_pre_post_indexed_bupd; [.. | exact H0]; auto.
    - unfold overridePost, tycontext.RA_normal.
      destruct R' as [R'0 R'1 R'2 R'3] at 1; clear R'0 R'1 R'2 R'3.
      destruct R as [R0 R1 R2 R3] at 1; clear R0 R1 R2 R3.
      reduce2derives.
      apply exp_derives.
      intros Q.
      normalize.
      apply andp_right; [apply prop_right | auto].
      eapply semax_post_indexed_bupd; [.. | apply H6]; auto.
    - destruct R, R'; auto.
    - destruct R, R'; auto.
    - destruct R, R'; auto.
Qed.

Lemma semax_store_inv: forall {CS: compspecs} {Espec: OracleKind} Delta e1 e2 P Q,
  @semax CS Espec Delta P (Sassign e1 e2) Q ->
  local (tc_environ Delta) && P |-- |==> |> FF || (EX sh: share, !! writable_share sh && |> ( (tc_lvalue Delta e1) &&  (tc_expr Delta (Ecast e2 (typeof e1)))  &&
             ((`(mapsto_ sh (typeof e1)) (eval_lvalue e1)) * (`(mapsto sh (typeof e1)) (eval_lvalue e1) (`force_val (`(sem_cast (typeof e2) (typeof e1)) (eval_expr e2))) -* |==> |> FF || RA_normal Q)))).
Proof.
  intros.
  remember (Sassign e1 e2) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0.
    reduce2derives.
    apply exp_derives; intro sh.
    apply andp_derives; auto.
    apply later_derives; auto.
    apply andp_derives; auto.
    apply sepcon_derives; auto.
    apply wand_derives; auto.
    eapply derives_trans; [| apply bupd_intro].
    apply orp_right2, derives_refl.
  + subst c.
    derives_rewrite -> H.
    derives_rewrite -> (IHsemax eq_refl).
    reduce2ENTAIL.
    apply exp_ENTAIL; intro sh.
    apply andp_ENTAIL; [apply ENTAIL_refl |].
    apply later_ENTAIL.
    apply andp_ENTAIL; [apply ENTAIL_refl |].
    apply sepcon_ENTAIL; [apply ENTAIL_refl |].
    apply wand_ENTAIL; [apply ENTAIL_refl |].
    apply derives_bupd0_bupd0_left, H1.
Qed.

Lemma oboxopt_ENTAIL: forall Delta ret retsig P Q,
  tc_fn_return Delta ret retsig ->
  local (tc_environ Delta) && P |-- Q ->
  local (tc_environ Delta) && oboxopt Delta ret P |-- oboxopt Delta ret Q.
Proof.
  intros.
  apply oboxopt_left2; auto.
  destruct ret; hnf in H |- *; [destruct ((temp_types Delta) ! i) |]; auto; congruence.
Qed.

Lemma semax_call_inv: forall {CS: compspecs} {Espec: OracleKind} Delta ret a bl Pre Post,
  @semax CS Espec Delta Pre (Scall ret a bl) Post ->
  local (tc_environ Delta) && Pre |-- |==> |> FF ||
         (EX argsig: _, EX retsig: _, EX cc: _,
          EX A: _, EX P: _, EX Q: _, EX NEP: _, EX NEQ: _, EX ts: _, EX x: _,
         !! (Cop.classify_fun (typeof a) =
             Cop.fun_case_f (type_of_params argsig) retsig cc /\
             (retsig = Tvoid -> ret = None) /\
             tc_fn_return Delta ret retsig) &&
          (|>((tc_expr Delta a) && (tc_exprlist Delta (snd (split argsig)) bl)))  &&
         `(func_ptr (mk_funspec  (argsig,retsig) cc A P Q NEP NEQ)) (eval_expr a) &&
          |>((`(P ts x: environ -> mpred) (make_args' (argsig,retsig) (eval_exprlist (snd (split argsig)) bl))) * oboxopt Delta ret (maybe_retval (Q ts x) retsig ret -* |==> |> FF || RA_normal Post))).
Proof.
  intros.
  remember (Scall ret a bl) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0.
    reduce2derives.
    apply exp_derives; intro argsig.
    apply exp_derives; intro retsig.
    apply exp_derives; intro cc.
    apply exp_derives; intro A.
    apply exp_derives; intro P.
    apply exp_derives; intro Q.
    apply exp_derives; intro NEP.
    apply exp_derives; intro NEQ.
    apply exp_derives; intro ts.
    apply exp_derives; intro x.
    apply andp_derives; auto.
    apply later_derives; auto.
    apply sepcon_derives; auto.
    apply oboxopt_K; auto.
    apply wand_derives; auto.
    eapply derives_trans; [| apply bupd_intro].
    apply orp_right2, derives_refl.
  + subst c.
    rename P into Pre, R into Post.
    derives_rewrite -> H.
    derives_rewrite -> (IHsemax eq_refl); clear IHsemax.
    reduce2ENTAIL.
    apply exp_ENTAIL; intro argsig.
    apply exp_ENTAIL; intro retsig.
    apply exp_ENTAIL; intro cc.
    apply exp_ENTAIL; intro A.
    apply exp_ENTAIL; intro P.
    apply exp_ENTAIL; intro Q.
    apply exp_ENTAIL; intro NEP.
    apply exp_ENTAIL; intro NEQ.
    apply exp_ENTAIL; intro ts.
    apply exp_ENTAIL; intro x.
    normalize.
    destruct H0 as [? [? ?]].
    apply andp_ENTAIL; [apply ENTAIL_refl |].
    apply later_ENTAIL.
    apply sepcon_ENTAIL; [apply ENTAIL_refl |].
    eapply oboxopt_ENTAIL; eauto.
    apply wand_ENTAIL; [apply ENTAIL_refl |].
    apply derives_bupd0_bupd0_left, H1.
Qed.

Lemma semax_Sset_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R id e,
  @semax CS Espec Delta P (Sset id e) R ->
  local (tc_environ Delta) && P |-- |==> |> FF ||
    ( (|> ( (tc_expr Delta e) &&
             (tc_temp_id id (typeof e) Delta e) &&
             subst id (eval_expr e) (|==> |> FF || RA_normal R))) ||
      (EX cmp: Cop.binary_operation, EX e1: expr, EX e2: expr,
         EX ty: type, EX sh1: share, EX sh2: share,
          !! (e = Ebinop cmp e1 e2 ty /\
              sepalg.nonidentity sh1 /\ sepalg.nonidentity sh2 /\
              is_comparison cmp = true /\
              eqb_type (typeof e1) int_or_ptr_type = false /\
              eqb_type (typeof e2) int_or_ptr_type = false /\
              typecheck_tid_ptr_compare Delta id = true) &&
            ( |> ( (tc_expr Delta e1) &&
              (tc_expr Delta e2)  &&
          local (`(blocks_match cmp) (eval_expr e1) (eval_expr e2)) &&
          (`(mapsto_ sh1 (typeof e1)) (eval_expr e1) * TT) &&
          (`(mapsto_ sh2 (typeof e2)) (eval_expr e2) * TT) &&
          subst id (eval_expr (Ebinop cmp e1 e2 ty)) (|==> |> FF || RA_normal R)))) ||
      (EX sh: share, EX t2: type, EX v2: val,
              !! (typeof_temp Delta id = Some t2 /\
                  is_neutral_cast (typeof e) t2 = true /\
                  readable_share sh) &&
         |> ( (tc_lvalue Delta e) &&
              local (`(tc_val (typeof e) v2)) &&
              (`(mapsto sh (typeof e)) (eval_lvalue e) (`v2) * TT) &&
              subst id (`v2) (|==> |> FF || RA_normal R))) ||
      (EX sh: share, EX e1: expr, EX t1: type, EX v2: val,
              !! (e = Ecast e1 t1 /\
                  typeof_temp Delta id = Some t1 /\
                  cast_pointer_to_bool (typeof e1) t1 = false /\
                  readable_share sh) &&
         |> ( (tc_lvalue Delta e1) &&
              local (`(tc_val t1) (`(eval_cast (typeof e1) t1 v2))) &&
              (`(mapsto sh (typeof e1)) (eval_lvalue e1) (`v2) * TT) &&
              subst id (`(force_val (sem_cast (typeof e1) t1 v2))) (|==> |> FF || RA_normal R)))).
Proof.
  intros.
  remember (Sset id e) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0.
    reduce2derives.
    apply orp_derives; [apply orp_derives; [apply orp_derives |] |].
    - apply later_derives.
      apply andp_derives; auto.
      apply subst_derives.
      eapply derives_trans; [| apply bupd_intro].
      apply orp_right2, derives_refl.
    - apply exp_derives; intros cmp.
      apply exp_derives; intros e1.
      apply exp_derives; intros e2.
      apply exp_derives; intros ty.
      apply exp_derives; intros sh1.
      apply exp_derives; intros sh2.
      apply andp_derives; auto.
      apply later_derives; auto.
      apply andp_derives; auto.
      apply subst_derives.
      eapply derives_trans; [| apply bupd_intro].
      apply orp_right2, derives_refl.
    - apply exp_derives; intros sh.
      apply exp_derives; intros t2.
      apply exp_derives; intros v2.
      apply andp_derives; auto.
      apply later_derives.
      apply andp_derives; auto.
      apply subst_derives.
      eapply derives_trans; [| apply bupd_intro].
      apply orp_right2, derives_refl.
    - apply exp_derives; intros sh.
      apply exp_derives; intros e1.
      apply exp_derives; intros t1.
      apply exp_derives; intros v2.
      apply andp_derives; auto.
      apply later_derives.
      apply andp_derives; auto.
      apply subst_derives.
      eapply derives_trans; [| apply bupd_intro].
      apply orp_right2, derives_refl.
  + subst c.
    rename P into Pre, R into Post.
    derives_rewrite -> H.
    derives_rewrite -> (IHsemax eq_refl); clear IHsemax.
    reduce2ENTAIL.
    apply orp_ENTAIL; [apply orp_ENTAIL; [apply orp_ENTAIL |] |].
    - apply later_ENTAIL.
      unfold tc_temp_id, typecheck_temp_id.
      destruct ((temp_types Delta) ! id) eqn:?H; [| normalize].
      eapply andp_subst_ENTAIL; [eauto | | apply ENTAIL_refl |].
      * destruct (is_neutral_cast (implicit_deref (typeof e)) t) eqn:?H; [| normalize].
        intro rho; unfold_lift; unfold local, lift1; simpl.
        normalize.
        apply andp_left1.
        eapply derives_trans; [apply typecheck_expr_sound; auto |].
        normalize.
        intros _.
        eapply expr2.neutral_cast_subsumption'; eauto.
      * apply derives_bupd0_bupd0_left.
        auto.
    - apply exp_ENTAIL; intro cmp.
      apply exp_ENTAIL; intro e1.
      apply exp_ENTAIL; intro e2.
      apply exp_ENTAIL; intro ty.
      apply exp_ENTAIL; intro sh1.
      apply exp_ENTAIL; intro sh2.
      normalize.
      destruct H0 as [He [? [? [? [? [? ?]]]]]].
      apply later_ENTAIL.
      unfold typecheck_tid_ptr_compare in H10.
      destruct ((temp_types Delta) ! id) eqn:?H; [| inv H10].
      eapply andp_subst_ENTAIL; [eauto | | apply ENTAIL_refl |].
      * unfold_lift; unfold local, lift1; intro rho.
        rewrite <- He; simpl.
        normalize.
        apply andp_left1.
        apply andp_left1.
        eapply derives_trans; [apply andp_derives; [| apply derives_refl]; apply andp_derives; apply typecheck_expr_sound; auto |].
        normalize.
        subst e.
        simpl.
        unfold_lift.
        replace (sem_binary_operation' cmp) with (sem_cmp (expr.op_to_cmp cmp)); [| destruct cmp; inv H7; auto].
        apply binop_lemmas2.tc_val'_sem_cmp; auto.
      * apply derives_bupd0_bupd0_left.
        auto.
    - apply exp_ENTAIL; intro sh.
      apply exp_ENTAIL; intro t2.
      apply exp_ENTAIL; intro v2.
      normalize.
      destruct H0 as [? [? ?]].
      apply later_ENTAIL.
      unfold typeof_temp in H0.
      destruct ((temp_types Delta) ! id) eqn:?H; inv H0.
      eapply andp_subst_ENTAIL; [eauto | | apply ENTAIL_refl |].
      * apply andp_left2.
        apply andp_left1.
        apply andp_left2.
        unfold_lift; unfold local, lift1; intro rho; simpl; normalize.
        intros _; eapply expr2.neutral_cast_subsumption; eauto.
      * apply derives_bupd0_bupd0_left.
        auto.
    - apply exp_ENTAIL; intro sh.
      apply exp_ENTAIL; intro e1.
      apply exp_ENTAIL; intro t1.
      apply exp_ENTAIL; intro t2.
      normalize.
      destruct H0 as [He [? [? ?]]].
      apply later_ENTAIL.
      unfold typeof_temp in H0.
      destruct ((temp_types Delta) ! id) eqn:?H; inv H0.
      eapply andp_subst_ENTAIL; [eauto | | apply ENTAIL_refl |].
      * apply andp_left2.
        apply andp_left1.
        apply andp_left2.
        unfold_lift; unfold local, lift1; intro rho; simpl; normalize.
        intros _; auto.
      * apply derives_bupd0_bupd0_left.
        auto.
Qed.

Lemma semax_Sbuiltin_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R opt ext tl el,
  @semax CS Espec Delta P (Sbuiltin opt ext tl el) R -> local (tc_environ Delta) && P |-- |==> |> FF || FF.
Proof.
  intros.
  remember (Sbuiltin opt ext tl el) as c eqn:?H.
  induction H; try solve [inv H0].
  + apply andp_left2, FF_left.
  + derives_rewrite -> H.
    derives_rewrite -> (IHsemax H0).
    apply andp_left2, FF_left.
Qed.

Lemma semax_Slabel_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R l c,
  @semax CS Espec Delta P (Slabel l c) R -> local (tc_environ Delta) && P |-- |==> |> FF || FF.
Proof.
  intros.
  remember (Slabel l c) as c0 eqn:?H.
  induction H; try solve [inv H0].
  + apply andp_left2, FF_left.
  + derives_rewrite -> H.
    derives_rewrite -> (IHsemax H0).
    apply andp_left2, FF_left.
Qed.

Lemma semax_Sgoto_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R l,
  @semax CS Espec Delta P (Sgoto l) R -> local (tc_environ Delta) && P |-- |==> |> FF || FF.
Proof.
  intros.
  remember (Sgoto l) as c eqn:?H.
  induction H; try solve [inv H0].
  + apply andp_left2, FF_left.
  + derives_rewrite -> H.
    derives_rewrite -> (IHsemax H0).
    apply andp_left2, FF_left.
Qed.

Lemma semax_ifthenelse_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R b c1 c2,
  @semax CS Espec Delta P (Sifthenelse b c1 c2) R ->
  local (tc_environ Delta) && P |--
  |==> |> FF || (!! (bool_type (typeof b) = true) && tc_expr Delta (Eunop Cop.Onotbool b (Tint I32 Signed noattr)) &&
  EX P': environ -> mpred,
  !! (@semax CS Espec Delta (P' && local (`(typed_true (typeof b)) (eval_expr b))) c1 R /\
      @semax CS Espec Delta (P' && local (`(typed_false (typeof b)) (eval_expr b))) c2 R) &&
  P').
Proof.
  intros.
  remember (Sifthenelse b c1 c2) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0; clear IHsemax1 IHsemax2.
    reduce2derives.
    apply andp_derives; auto.
    apply (exp_right P).
    apply andp_right; [apply prop_right; auto |].
    auto.
  + derives_rewrite -> H.
    derives_rewrite -> (IHsemax H0); clear IHsemax.
    reduce2derives.
    apply andp_derives; auto.
    apply exp_derives; intros P''.
    normalize.
    apply andp_right; auto.
    apply prop_right.
    destruct H6; split.
    - eapply semax_post_indexed_bupd; eauto.
    - eapply semax_post_indexed_bupd; eauto.
Qed.

Lemma semax_loop_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R body incr,
  @semax CS Espec Delta P (Sloop body incr) R ->
  local (tc_environ Delta) && P |--
  |==> |> FF || EX Q: environ -> mpred, EX Q': environ -> mpred,
  !! (@semax CS Espec Delta Q body (loop1_ret_assert Q' R) /\
      @semax CS Espec Delta Q' incr (loop2_ret_assert Q R)) &&
  Q.
Proof.
  intros.
  remember (Sloop body incr) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0; clear IHsemax1 IHsemax2.
    reduce2derives.
    apply (exp_right Q).
    apply (exp_right Q').
    apply andp_right; [apply prop_right; auto |].
    auto.
  + derives_rewrite -> H.
    derives_rewrite -> (IHsemax H0); clear IHsemax.
    reduce2derives.
    apply exp_derives; intros Q.
    apply exp_derives; intros Q'.
    normalize.
    apply andp_right; [apply prop_right |]; auto.
    destruct H6.
    split.
    - destruct R as [nR bR cR rR], R' as [nR' bR' cR' rR']; simpl in H6, H7 |- *.
      simpl RA_normal in H1; simpl RA_break in H2; simpl RA_continue in H3; simpl RA_return in H4.
      eapply semax_post_indexed_bupd; [.. | eassumption]; unfold loop1_ret_assert.
      * simpl RA_normal.
        apply andp_left2.
        eapply derives_trans; [| apply bupd_intro].
        apply orp_right2, derives_refl.
      * simpl RA_break.
        auto.
      * simpl RA_continue.
        apply andp_left2.
        eapply derives_trans; [| apply bupd_intro].
        apply orp_right2, derives_refl.
      * simpl RA_return.
        auto.
    - destruct R as [nR bR cR rR], R' as [nR' bR' cR' rR']; simpl in H6, H7 |- *.
      simpl RA_normal in H1; simpl RA_break in H2; simpl RA_continue in H3; simpl RA_return in H4.
      eapply semax_post_indexed_bupd; [.. | eassumption]; unfold loop1_ret_assert.
      * simpl RA_normal.
        apply andp_left2.
        eapply derives_trans; [| apply bupd_intro].
        apply orp_right2, derives_refl.
      * simpl RA_break.
        auto.
      * simpl RA_continue.
        apply andp_left2.
        eapply derives_trans; [| apply bupd_intro].
        apply orp_right2, derives_refl.
      * simpl RA_return.
        auto.
Qed.

Lemma semax_switch_inv: forall {CS: compspecs} {Espec: OracleKind} Delta P R a sl,
  @semax CS Espec Delta P (Sswitch a sl) R ->
  local (tc_environ Delta) && P |--
        |==> |> FF || !! (is_int_type (typeof a) = true) && (tc_expr Delta a) &&
        EX P': environ -> mpred,
  !! (forall n,
     @semax CS Espec Delta 
               (local (`eq (eval_expr a) `(Vint n)) && P')
               (seq_of_labeled_statement (select_switch (Int.unsigned n) sl))
               (switch_ret_assert R)) && P'.
Proof.
  intros.
  remember (Sswitch a sl) as c eqn:?H.
  induction H; try solve [inv H0].
  + inv H0.
    reduce2derives.
    rewrite andp_assoc.
    apply andp_derives; auto.
    apply andp_right; auto.
    apply (exp_right Q).
    apply andp_right; [apply prop_right; auto |].
    auto.
  + derives_rewrite -> H.
    derives_rewrite -> (IHsemax H0); clear IHsemax.
    reduce2derives.
    apply andp_derives; auto.
    apply exp_derives; intros P''.
    apply andp_derives; auto.
    apply prop_derives; intro.
    intro n; specialize (H6 n).
    eapply semax_post_indexed_bupd; [.. | exact H6].
    - destruct R as [nR bR cR rR], R' as [nR' bR' cR' rR'].
      apply andp_left2, FF_left.
    - destruct R as [nR bR cR rR], R' as [nR' bR' cR' rR'].
      exact H1.
    - destruct R as [nR bR cR rR], R' as [nR' bR' cR' rR'].
      exact H3.
    - destruct R as [nR bR cR rR], R' as [nR' bR' cR' rR'].
      exact H4.
Qed.
  
Lemma extract_exists_pre:
  forall {CS: compspecs} {Espec: OracleKind},
  forall (A : Type)  (P : A -> environ->mpred) c (Delta: tycontext) (R: ret_assert),
  (forall x, @semax CS Espec Delta (P x) c R) ->
   @semax CS Espec Delta (EX x:A, P x) c R.
Proof.
  intros.
  revert A P R H; induction_stmt c; intros.
  + pose proof (fun x => semax_skip_inv _ _ _ (H x)).
    eapply semax_pre_indexed_bupd.
    - rewrite exp_andp2; apply exp_left.
      intro x.
      apply H0.
    - eapply semax_post''; [.. | apply AuxDefs.semax_skip].
      apply ENTAIL_refl.
  + pose proof (fun x => semax_store_inv _ _ _ _ _ (H x)).
    clear H.
    apply exp_left in H0.
    rewrite <- (exp_andp2 A) in H0.
    eapply semax_pre_indexed_bupd; [exact H0 | clear H0].
    eapply semax_post''_indexed_bupd; [.. | apply AuxDefs.semax_store_backward].
    apply andp_left2, derives_refl.
  + pose proof (fun x => semax_Sset_inv _ _ _ _ _ (H x)).
    clear H.
    apply exp_left in H0.
    rewrite <- (exp_andp2 A) in H0.
    eapply semax_pre_indexed_bupd; [exact H0 | clear H0].
    eapply semax_post''_indexed_bupd; [.. | apply AuxDefs.semax_set_ptr_comparison_load_cast_load_backward].
    apply andp_left2, derives_refl.
  + pose proof (fun x => semax_call_inv _ _ _ _ _ _ (H x)).
    clear H.
    apply exp_left in H0.
    rewrite <- (exp_andp2 A) in H0.
    eapply semax_pre_indexed_bupd; [exact H0 | clear H0].
    eapply semax_post''_indexed_bupd; [.. | apply AuxDefs.semax_call_backward].
    apply andp_left2, derives_refl.
  + pose proof (fun x => semax_Sbuiltin_inv _ _ _ _ _ _ _ (H x)).
    apply semax_pre_indexed_bupd with FF; [| apply AuxDefs.semax_builtin].
    rewrite exp_andp2.
    apply exp_left; intros x; specialize (H0 x).
    auto.
  + apply AuxDefs.semax_seq with (EX Q: environ -> mpred, !! (semax Delta Q c2 R) && Q).
    - apply IHc1.
      intro x.
      apply semax_seq_inv'; auto.
    - apply IHc2.
      intros Q.
      apply semax_pre with (EX H0: semax Delta Q c2 R, Q).
      * apply andp_left2.
        apply derives_extract_prop; intros.
        apply (exp_right H0).
        auto.
      * apply IHc2.
        intro H0.
        auto.
  + eapply semax_pre_indexed_bupd; [| apply (AuxDefs.semax_ifthenelse _ (EX P': environ -> mpred, !! (semax Delta (P' && local (`(typed_true (typeof e)) (eval_expr e))) c1 R /\ semax Delta (P' && local (`(typed_false (typeof e)) (eval_expr e))) c2 R) && P'))].
    - pose proof (fun x => semax_ifthenelse_inv _ _ _ _ _ _ (H x)).
      clear H.
      apply exp_left in H0.
      rewrite <- (exp_andp2 A) in H0.
      eapply derives_bupd_trans; [exact H0 | clear H0].
      apply andp_left2, bupd_intro.
    - rewrite exp_andp1.
      apply IHc1.
      intro P'.
      apply semax_pre with (EX H0: semax Delta (P' && local ((` (typed_true (typeof e))) (eval_expr e))) c1 R, P' && local ((` (typed_true (typeof e))) (eval_expr e))).
      * apply andp_left2.
        rewrite !andp_assoc.
        apply derives_extract_prop; intros.
        apply (exp_right (proj1 H0)).
        solve_andp.
      * apply IHc1.
        intro H0.
        auto.
    - rewrite exp_andp1.
      apply IHc2.
      intro P'.
      apply semax_pre with (EX H0: semax Delta (P' && local ((` (typed_false (typeof e))) (eval_expr e))) c2 R, P' && local ((` (typed_false (typeof e))) (eval_expr e))).
      * apply andp_left2.
        rewrite !andp_assoc.
        apply derives_extract_prop; intros.
        apply (exp_right (proj2 H0)).
        solve_andp.
      * apply IHc2.
        intro H0.
        auto.
  + pose proof (fun x => semax_loop_inv _ _ _ _ _ (H x)).
    eapply semax_pre_indexed_bupd with
      (EX Q : environ -> mpred, EX Q' : environ -> mpred,
         EX H: semax Delta Q c1 (loop1_ret_assert Q' R),
           EX H0: semax Delta Q' c2 (loop2_ret_assert Q R), Q).
    {
      rewrite exp_andp2.
      apply exp_left.
      intros x.
      derives_rewrite -> (H0 x).
      reduce2derives.
      apply exp_derives; intros Q.
      apply exp_derives; intros Q'.
      apply derives_extract_prop; intros [? ?].
      apply (exp_right H1).
      apply (exp_right H2).
      auto.
    }
    apply (AuxDefs.semax_loop _ _
      (EX Q : environ -> mpred, EX Q' : environ -> mpred,
         EX H: semax Delta Q c1 (loop1_ret_assert Q' R),
           EX H0: semax Delta Q' c2 (loop2_ret_assert Q R), Q')).
    - apply IHc1.
      intros Q.
      apply IHc1.
      intros Q'.
      apply IHc1.
      intros ?H.
      apply IHc1.
      intros ?H.
      eapply semax_post; [.. | exact H1].
      * destruct R as [nR bR cR rR].
        unfold loop1_ret_assert.
        apply (exp_right Q), (exp_right Q'), (exp_right H1), (exp_right H2).
        apply andp_left2, derives_refl.
      * destruct R as [nR bR cR rR].
        apply andp_left2, derives_refl.
      * destruct R as [nR bR cR rR].
        unfold loop1_ret_assert.
        apply (exp_right Q), (exp_right Q'), (exp_right H1), (exp_right H2).
        apply andp_left2, derives_refl.
      * intros.
        destruct R as [nR bR cR rR].
        apply andp_left2, derives_refl.
    - apply IHc2.
      intros Q.
      apply IHc2.
      intros Q'.
      apply IHc2.
      intros ?H.
      apply IHc2.
      intros ?H.
      eapply semax_post; [.. | exact H2].
      * destruct R as [nR bR cR rR].
        unfold loop1_ret_assert.
        apply (exp_right Q), (exp_right Q'), (exp_right H1), (exp_right H2).
        apply andp_left2, derives_refl.
      * destruct R as [nR bR cR rR].
        apply andp_left2, derives_refl.
      * destruct R as [nR bR cR rR].
        apply andp_left2, derives_refl.
      * intros.
        destruct R as [nR bR cR rR].
        apply andp_left2, derives_refl.
  + pose proof (fun x => semax_break_inv _ _ _ (H x)).
    eapply semax_pre_indexed_bupd.
    - rewrite exp_andp2; apply exp_left.
      intro x; apply H0.
    - apply AuxDefs.semax_break.
  + pose proof (fun x => semax_continue_inv _ _ _ (H x)).
    eapply semax_pre_indexed_bupd.
    - rewrite exp_andp2; apply exp_left.
      intro x; apply H0.
    - apply AuxDefs.semax_continue.
  + pose proof (fun x => semax_return_inv _ _ _ _ (H x)).
    eapply (semax_pre_post_indexed_bupd _ _ {| RA_normal := _; RA_break := _; RA_continue := _; RA_return := |==> |> FF || RA_return R |}); [.. | apply AuxDefs.semax_return].
    - rewrite exp_andp2.
      apply exp_left; intros x.
      derives_rewrite -> (H0 x).
      reduce2ENTAIL.      
      apply andp_ENTAIL; [apply ENTAIL_refl |].
      apply ENTAIL_refl.
    - apply derives_bupd_refl.
    - apply derives_bupd_refl.
    - apply derives_bupd_refl.
    - intros; apply derives_bupd_bupd_left, derives_bupd_refl.
  + pose proof (fun x => semax_switch_inv _ _ _ _ _ (H x)).
    eapply semax_pre_indexed_bupd.
    - rewrite exp_andp2; apply exp_left.
      intro x; apply H0.
    - rewrite andp_assoc.
      apply AuxDefs.semax_switch; [intros; simpl; solve_andp |].
      intros.
      specialize (IH (Int.unsigned n)).
      rewrite !exp_andp2.
      apply IH.
      intros P'.
      apply semax_pre with (EX H: forall n0 : int,
           semax Delta (local ((` eq) (eval_expr e) (` (Vint n0))) && P')
             (seq_of_labeled_statement (select_switch (Int.unsigned n0) l))
             (switch_ret_assert R), local ((` eq) (eval_expr e) (` (Vint n))) && P').
      * rewrite (andp_comm (prop _)), <- !andp_assoc, <- (andp_comm (prop _)).
        apply derives_extract_prop; intros.
        apply (exp_right H1).
        solve_andp.
      * apply IH.
        intros ?H.
        auto.
  + pose proof (fun x => semax_Slabel_inv _ _ _ _ _ (H x)).
    apply semax_pre_indexed_bupd with FF; [| apply AuxDefs.semax_label].
    rewrite exp_andp2.
    apply exp_left; intros x; specialize (H0 x).
    auto.
  + pose proof (fun x => semax_Sgoto_inv _ _ _ _ (H x)).
    apply semax_pre_indexed_bupd with FF; [| apply AuxDefs.semax_goto].
    rewrite exp_andp2.
    apply exp_left; intros x; specialize (H0 x).
    auto.
Qed.

Module Extr: CLIGHT_SEPARATION_HOARE_LOGIC_EXTRACTION with Module CSHL_Def := Defs.

Module CSHL_Def := Defs.
Import CSHL_Def.

Definition semax_extract_exists := @extract_exists_pre.

End Extr.

Module ExtrFacts := CSHL_ExtrFacts (Defs) (Conseq) (Extr).
Module ExtrIFacts := CSHL_IExtrFacts (Defs) (IConseq) (Extr).

Import ExtrFacts ExtrIFacts.

Lemma semax_frame:
  forall {Espec: OracleKind}{CS: compspecs},
  forall Delta P s R F,
   closed_wrt_modvars s F ->
  @semax CS Espec Delta P s R ->
    @semax CS Espec Delta (P * F) s (frame_ret_assert R F).
Proof.
  intros.
  induction H0.
  + apply semax_pre with (!! (bool_type (typeof b) = true) && tc_expr Delta (Eunop Cop.Onotbool b (Tint I32 Signed noattr)) && (P * F)).
    - normalize.
      apply andp_left2, andp_right.
      * eapply derives_trans; [apply sepcon_derives; [apply andp_left1 |]; apply derives_refl |].
        intro rho.
        apply (predicates_sl.extend_sepcon (extend_tc.extend_tc_expr Delta (Eunop Cop.Onotbool b (Tint I32 Signed noattr)) rho)).
      * eapply derives_trans; [apply sepcon_derives; [apply andp_left2 |]; apply derives_refl |].
        auto.
    - rewrite semax_lemmas.closed_Sifthenelse in H; destruct H.
      apply AuxDefs.semax_ifthenelse.
      * eapply semax_pre; [| apply IHsemax1; auto].
        apply andp_left2.
        unfold_lift.
        intro rho; unfold local, lift1; simpl.
        normalize.
      * eapply semax_pre; [| apply IHsemax2; auto].
        apply andp_left2.
        unfold_lift.
        intro rho; unfold local, lift1; simpl.
        normalize.
  + rewrite semax_lemmas.closed_Ssequence in H; destruct H.
    apply AuxDefs.semax_seq with (Q * F).
    - destruct R; apply IHsemax1; auto.
    - destruct R; apply IHsemax2; auto.
  + replace (RA_break Q * F) with (RA_break (frame_ret_assert Q F)) by (destruct Q; auto).
    apply AuxDefs.semax_break.
  + replace (RA_continue Q * F) with (RA_continue (frame_ret_assert Q F)) by (destruct Q; auto).
    apply AuxDefs.semax_continue.
  + rewrite semax_lemmas.closed_Sloop in H; destruct H.
    eapply AuxDefs.semax_loop with (Q' * F).
    - destruct R; apply IHsemax1; auto.
    - replace (loop2_ret_assert (Q * F) (frame_ret_assert R F))
        with (frame_ret_assert (loop2_ret_assert Q R) F)
        by (destruct R; simpl; f_equal; extensionality rho; apply pred_ext; normalize).
      apply IHsemax2; auto.
  + rewrite corable_andp_sepcon1 by (apply corable_prop).
    eapply AuxDefs.semax_switch; auto.
    - intro.
      eapply derives_trans; [apply sepcon_derives; [apply H0 | apply derives_refl] |].
      apply (predicates_sl.extend_sepcon (extend_tc.extend_tc_expr Delta a rho)).
    - intros.
      rewrite <- corable_andp_sepcon1 by (intro; apply corable_prop).
      replace (switch_ret_assert (frame_ret_assert R F)) with
        (frame_ret_assert (switch_ret_assert R) F)
        by (destruct R; simpl; f_equal; extensionality rho; apply pred_ext; normalize).
      apply (H2 n).
      eapply semax_lemmas.closed_Sswitch; eauto.
  + replace (frame_ret_assert (normal_ret_assert R) F) with (normal_ret_assert (R * F))
      by (unfold normal_ret_assert, frame_ret_assert; f_equal; [.. | extensionality]; rewrite FF_sepcon; auto).
    eapply semax_pre; [.. | apply AuxDefs.semax_call_backward; auto].
    - rewrite exp_sepcon1. apply exp_ENTAIL; intros argsig.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros retsig.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros cc.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros A.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros P.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros Q.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros NEP.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros NEQ.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros ts.
      rewrite exp_sepcon1. apply exp_ENTAIL; intros x.
      normalize.
      apply andp_right; [apply andp_right |].
      * apply andp_left2.
        apply wand_sepcon_adjoint.
        apply andp_left1.
        apply andp_left1.
        apply wand_sepcon_adjoint.
        eapply derives_trans; [apply sepcon_derives; [apply derives_refl | apply now_later] |].
        rewrite <- later_sepcon.
        apply later_derives.
        intro rho.
        simpl.
        apply (predicates_sl.extend_sepcon (extend_tc.extend_andp _ _ (extend_tc.extend_tc_expr Delta a rho) (extend_tc.extend_tc_exprlist Delta (snd (split argsig)) bl rho))).
      * apply andp_left2.
        apply wand_sepcon_adjoint.
        apply andp_left1, andp_left2.
        apply wand_sepcon_adjoint.
        apply derives_left_sepcon_right_corable; auto.
        intro.
        apply corable_func_ptr.
      * apply andp_left2.
        apply wand_sepcon_adjoint.
        apply andp_left2.
        apply wand_sepcon_adjoint.
        eapply derives_trans; [apply sepcon_derives; [apply derives_refl | apply now_later] |].
        rewrite <- later_sepcon.
        apply later_derives.
        rewrite sepcon_assoc; apply sepcon_derives; auto.
Abort.

Definition loop_nocontinue_ret_assert (Inv: environ->mpred) (R: ret_assert) : ret_assert :=
 match R with 
  {| RA_normal := n; RA_break := b; RA_continue := c; RA_return := r |} =>
  {| RA_normal := Inv;
     RA_break := n; 
     RA_continue := seplog.FF;
     RA_return := r |}
 end.

Lemma semax_loop_nocontinue:
  forall {CS: compspecs} {Espec: OracleKind},
 forall Delta P body incr R,
 @semax CS Espec Delta P (Ssequence body incr) (loop_nocontinue_ret_assert P R) ->
 @semax CS Espec Delta P (Sloop body incr) R.
Proof.
  intros.
  apply semax_seq_inv in H.
  destruct H as [Q [? ?]].
  eapply (AuxDefs.semax_loop _ P Q).
  + clear - H.
    unfold overridePost, loop_nocontinue_ret_assert, loop1_ret_assert in *.
    eapply semax_post; [| | | | exact H].
    - apply andp_left2.
      destruct R.
      apply derives_refl.
    - apply andp_left2.
      destruct R.
      apply derives_refl.
    - apply andp_left2.
      destruct R.
      apply FF_left.
    - intro.
      apply andp_left2.
      destruct R.
      apply derives_refl.
  + clear - H0.
    unfold overridePost, loop_nocontinue_ret_assert, loop2_ret_assert in *.
    auto.
Qed.

Lemma semax_if_seq:
 forall {CS: compspecs} {Espec: OracleKind} Delta P e c1 c2 c Q,
 semax Delta P (Sifthenelse e (Ssequence c1 c) (Ssequence c2 c)) Q ->
 semax Delta P (Ssequence (Sifthenelse e c1 c2) c) Q.
Proof.
  intros.
  apply semax_ifthenelse_inv in H.
  eapply semax_pre_indexed_bupd; [exact H |].
  rewrite exp_andp2.
  apply extract_exists_pre.
  intros P'.
  rewrite andp_comm, andp_assoc.
  apply semax_extract_prop; intros [? ?].
  rewrite andp_comm.
  apply semax_seq_inv in H0.
  apply semax_seq_inv in H1.
  destruct H0 as [Q1 [? ?]], H1 as [Q2 [? ?]].
  apply AuxDefs.semax_seq with (orp Q1 Q2); [apply AuxDefs.semax_ifthenelse |].
  + eapply semax_post; [| | | | exact H0].
    - destruct Q; apply andp_left2, orp_right1, derives_refl.
    - destruct Q; apply andp_left2, derives_refl.
    - destruct Q; apply andp_left2, derives_refl.
    - intro; destruct Q; apply andp_left2, derives_refl.
  + eapply semax_post; [| | | | exact H1].
    - destruct Q; apply andp_left2, orp_right2, derives_refl.
    - destruct Q; apply andp_left2, derives_refl.
    - destruct Q; apply andp_left2, derives_refl.
    - intro; destruct Q; apply andp_left2, derives_refl.
  + rewrite orp_is_exp.
    apply extract_exists_pre.
    intro.
    destruct x; auto.
Qed.

Lemma semax_loop_unroll1:
  forall {CS: compspecs} {Espec: OracleKind} Delta P P' Q body incr R,
  @semax CS Espec Delta P body (loop1_ret_assert P' R) ->
  @semax CS Espec Delta P' incr (loop2_ret_assert Q R) ->
  @semax CS Espec Delta Q (Sloop body incr) R ->
  @semax CS Espec Delta P (Sloop body incr) R.
Proof.
  intros.
  apply semax_loop_inv in H1.
  apply semax_pre with (P || Q ||
                  (EX Q : environ -> mpred,
                    (EX Q' : environ -> mpred,
                     !! (semax Delta Q body (loop1_ret_assert Q' R) /\
                         semax Delta Q' incr (loop2_ret_assert Q R)) && Q))).
  { apply andp_left2, orp_right1, orp_right1, derives_refl. }
  apply AuxDefs.semax_loop with (P' ||
                  (EX Q : environ -> mpred,
                    (EX Q' : environ -> mpred,
                     !! (semax Delta Q body (loop1_ret_assert Q' R) /\
                         semax Delta Q' incr (loop2_ret_assert Q R)) && Q'))).
  + apply semax_orp; [apply semax_orp |].
    - eapply semax_post; [.. | exact H].
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, orp_right1, derives_refl.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, orp_right1, derives_refl.
      * intros.
        unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
    - eapply semax_pre_indexed_bupd; [exact H1 |].
      apply extract_exists_pre; intros Q'.
      apply extract_exists_pre; intros Q''.
      apply semax_extract_prop; intros [?H ?H].
      apply semax_post with (loop1_ret_assert Q'' R); auto.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, orp_right2, (exp_right Q'), (exp_right Q'').
        apply andp_right; [apply prop_right; auto | apply derives_refl].
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, orp_right2, (exp_right Q'), (exp_right Q'').
        apply andp_right; [apply prop_right; auto | apply derives_refl].
      * intros.
        unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
    - apply extract_exists_pre; intros Q'.
      apply extract_exists_pre; intros Q''.
      apply semax_extract_prop; intros [?H ?H].
      apply semax_post with (loop1_ret_assert Q'' R); auto.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, orp_right2, (exp_right Q'), (exp_right Q'').
        apply andp_right; [apply prop_right; auto | apply derives_refl].
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, orp_right2, (exp_right Q'), (exp_right Q'').
        apply andp_right; [apply prop_right; auto | apply derives_refl].
      * intros.
        unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
  + apply semax_orp.
    - apply semax_post with (loop2_ret_assert Q R); auto.
      * unfold loop2_ret_assert; destruct R.
        apply andp_left2, orp_right1, orp_right2, derives_refl.
      * unfold loop2_ret_assert; destruct R.
        apply andp_left2, derives_refl.
      * unfold loop2_ret_assert; destruct R.
        apply andp_left2, derives_refl.
      * intros.
        unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
    - apply extract_exists_pre; intros Q'.
      apply extract_exists_pre; intros Q''.
      apply semax_extract_prop; intros [?H ?H].
      apply semax_post with (loop2_ret_assert Q' R); auto.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, orp_right2, (exp_right Q'), (exp_right Q'').
        apply andp_right; [apply prop_right; auto | apply derives_refl].
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
      * unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
      * intros.
        unfold loop1_ret_assert; destruct R.
        apply andp_left2, derives_refl.
Qed.

Theorem seq_assoc:
  forall {CS: compspecs} {Espec: OracleKind},
   forall Delta P s1 s2 s3 R,
        @semax CS Espec Delta P (Ssequence s1 (Ssequence s2 s3)) R <->
        @semax CS Espec Delta P (Ssequence (Ssequence s1 s2) s3) R.
Proof.
  intros.
  split; intros.
  + apply semax_seq_inv in H.
    destruct H as [? [? ?]].
    apply semax_seq_inv in H0.
    destruct H0 as [? [? ?]].
    eapply AuxDefs.semax_seq; eauto.
    eapply AuxDefs.semax_seq; eauto.
    destruct R; auto.
  + apply semax_seq_inv in H.
    destruct H as [? [? ?]].
    apply semax_seq_inv in H.
    destruct H as [? [? ?]].
    eapply AuxDefs.semax_seq with x0; [destruct R; exact H |].
    eapply AuxDefs.semax_seq; eauto.
Qed.

Theorem semax_seq_skip:
  forall {CS: compspecs} {Espec: OracleKind},
  forall Delta P s Q,
    @semax CS Espec Delta P s Q <-> @semax CS Espec Delta P (Ssequence s Sskip) Q.
Proof.
  intros.
  split; intros.
  + apply AuxDefs.semax_seq with (RA_normal Q).
    - destruct Q; auto.
    - eapply semax_post; [.. | apply AuxDefs.semax_skip].
      * apply ENTAIL_refl.
      * apply andp_left2, FF_left.
      * apply andp_left2, FF_left.
      * intros; apply andp_left2, FF_left.
  + apply semax_seq_inv in H.
    destruct H as [? [? ?]].
    apply semax_skip_inv in H0.
    eapply semax_post_indexed_bupd; [.. | exact H].
    - destruct Q; auto.
    - destruct Q; apply derives_bupd0_refl.
    - destruct Q; apply derives_bupd0_refl.
    - intros; destruct Q; apply derives_bupd0_refl.
Qed.

Theorem semax_skip_seq:
  forall {CS: compspecs} {Espec: OracleKind},
  forall Delta P s Q,
    @semax CS Espec Delta P s Q <-> @semax CS Espec Delta P (Ssequence Sskip s) Q.
Proof.
  intros.
  split; intros.
  + apply AuxDefs.semax_seq with P; auto.
    eapply semax_post; [.. | apply AuxDefs.semax_skip].
    - destruct Q; apply ENTAIL_refl.
    - apply andp_left2, FF_left.
    - apply andp_left2, FF_left.
    - intros; apply andp_left2, FF_left.
  + apply semax_seq_inv in H.
    destruct H as [? [? ?]].
    apply semax_skip_inv in H.
    eapply semax_pre_indexed_bupd; [.. | exact H0].
    destruct Q; auto.
Qed.
(*
Axiom semax_extensionality_Delta:
  forall {CS: compspecs} {Espec: OracleKind},
  forall Delta Delta' P c R,
       tycontext_sub Delta Delta' ->
     @semax CS Espec Delta P c R -> @semax CS Espec Delta' P c R.

Axiom semax_unfold_Ssequence: forall {CS: compspecs} {Espec: OracleKind} c1 c2,
  unfold_Ssequence c1 = unfold_Ssequence c2 ->
  (forall P Q Delta, @semax CS Espec Delta P c1 Q -> @semax CS Espec Delta P c2 Q).

Axiom semax_set_forward_nl:
  forall {CS: compspecs} {Espec: OracleKind},
forall (Delta: tycontext) P id e v t,
    typeof_temp Delta id = Some t ->
    P |-- rel_expr e v ->
    tc_val t v ->
    @semax CS Espec Delta
        ( |> P ) (Sset id e)
        (normal_ret_assert (EX old:val, local (`(eq v) (eval_id id)) && subst id `(old) P)).

Axiom semax_loadstore:
  forall {CS: compspecs} {Espec: OracleKind},
 forall v0 v1 v2 (Delta: tycontext) e1 e2 sh P P',
   writable_share sh ->
   P |-- !! (tc_val (typeof e1) v2)
           && rel_lvalue e1 v1
           && rel_expr (Ecast e2 (typeof e1)) v2
           && (`(mapsto sh (typeof e1) v1 v0) * P') ->
   @semax CS Espec Delta (|> P) (Sassign e1 e2)
          (normal_ret_assert (`(mapsto sh (typeof e1) v1 v2) * P')).

Axiom semax_Slabel:
   forall {cs:compspecs} {Espec: OracleKind},
     forall Delta (P:environ -> mpred) (c:statement) (Q:ret_assert) l,
   @semax cs Espec Delta P c Q -> @semax cs Espec Delta P (Slabel l c) Q.

Axiom semax_seq_Slabel:
   forall {cs:compspecs} {Espec: OracleKind},
     forall Delta (P:environ -> mpred) (c1 c2:statement) (Q:ret_assert) l,
   @semax cs Espec Delta P (Ssequence (Slabel l c1) c2) Q <-> 
   @semax cs Espec Delta P (Slabel l (Ssequence c1 c2)) Q.

Axiom semax_frame:
  forall {CS: compspecs} {Espec: OracleKind},
  forall Delta P s R F,
   closed_wrt_modvars s F ->
  @semax CS Espec Delta P s R ->
    @semax CS Espec Delta (P * F) s (frame_ret_assert R F).

Axiom semax_ext:
  forall  (Espec : OracleKind)
         (ext_link: Strings.String.string -> ident)
         (id : Strings.String.string) (ids : list ident) (sig : funsig) (sig' : signature)
         cc A P Q NEP NEQ (fs : funspecs),
  let f := mk_funspec sig cc A P Q NEP NEQ in
  In (ext_link id,f) fs ->
  funspecs_norepeat fs ->
  ids = fst (split (fst sig)) ->
  sig' = funsig2signature sig cc ->
  @semax_external (add_funspecs Espec ext_link fs) ids (EF_external id sig') _ P Q.

Axiom semax_ext_void:
  forall  (Espec : OracleKind)
         (ext_link: Strings.String.string -> ident)
         (id : Strings.String.string) (ids : list ident) sig (sig' : signature)
         cc A P Q NEP NEQ (fs : funspecs),
  let f := mk_funspec (sig, tvoid) cc A P Q NEP NEQ in
  In (ext_link id,f) fs ->
  funspecs_norepeat fs ->
  ids = fst (split sig) ->
  sig' = mksignature (map typ_of_type (map snd sig)) None cc ->
  @semax_external (add_funspecs Espec ext_link fs) ids (EF_external id sig') _ P Q.

Axiom semax_external_FF:
 forall Espec ids ef A,
  @semax_external Espec ids ef A (fun _ _ => FF) (fun _ _ => FF).

*)
End ClightSeparationHoareLogic.

(* After this succeeds, remove "weakest_pre" in veric/semax.v. *)
