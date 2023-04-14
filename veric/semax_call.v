Require Import Coq.Logic.FunctionalExtensionality.
Require Import VST.veric.juicy_base.
Require Import VST.veric.juicy_mem VST.veric.juicy_mem_lemmas (*VST.veric.juicy_mem_ops*).
Require Import VST.veric.res_predicates.
Require Import VST.veric.external_state.
Require Import VST.veric.extend_tc.
Require Import VST.veric.Clight_seplog.
Require Import VST.veric.Clight_assert_lemmas.
Require Import VST.veric.Clight_core.
Require Import VST.sepcomp.extspec.
Require Import VST.sepcomp.step_lemmas.
Require Import VST.veric.juicy_safety.
Require Import VST.veric.juicy_extspec.
Require Import VST.veric.tycontext.
Require Import VST.veric.expr.
Require Import VST.veric.expr2.
Require Import VST.veric.expr_lemmas.
Require Import VST.veric.expr_lemmas4.
Require Import VST.veric.semax.
Require Import VST.veric.semax_lemmas.
Require Import VST.veric.Clight_lemmas.
Import LiftNotation.

Lemma TTL3 l: typelist_of_type_list (Clight_core.typelist2list l) = l.
Proof. induction l; simpl; trivial. f_equal; trivial . Qed.

Section mpred.

Context {CS: compspecs} `{!heapGS Σ} {Espec: OracleKind} `{!externalGS OK_ty Σ}.

Lemma typecheck_expr_sound' :
  forall Delta rho e,
    typecheck_environ Delta rho ->
    tc_expr Delta e rho ⊢ ⌜tc_val (typeof e) (eval_expr e rho)⌝.
Proof.
  apply typecheck_expr_sound.
Qed.

Lemma tc_environ_make_args':
 forall argsig retsig bl rho Delta
   (Htc : tc_environ Delta rho),
  tc_exprlist Delta (snd (split argsig)) bl rho
  ⊢ ⌜tc_environ (funsig_tycontext (argsig, retsig)) (make_args (map fst argsig)
         (eval_exprlist (snd (split argsig)) bl rho) rho)⌝.
Proof.
  intros.
  rewrite /tc_environ /tc_exprlist /=.
  revert bl; induction argsig; destruct bl as [ | b bl]; simpl; intros; unfold_lift.
  * iPureIntro; intros _; split3; hnf; try split; intros; try rewrite /funsig_tycontext /lookup /ptree_lookup ?Maps.PTree.gempty // in H |- *.
    destruct H as [? H]; inv H.
  * iPureIntro; done.
  * destruct a as [i ti]; simpl.
    destruct (split argsig) eqn:?; simpl.
    unfold_lift; iPureIntro; inversion 1.
  * destruct a as [i ti]; simpl.
    destruct (split argsig) eqn:?; simpl.
    specialize (IHargsig bl).
    rewrite /typecheck_expr; fold typecheck_expr.
    rewrite !denote_tc_assert_andp.
    unfold_lift.
    rewrite IHargsig; clear IHargsig.
    iIntros "(H & (%Ht & % & %))".
    unfold typecheck_environ; simpl.
    rewrite tc_val_sem_cast //.
    iDestruct "H" as %?%tc_val_tc_val'; iPureIntro.
    split3; auto.
    unfold typecheck_temp_environ; intros ?? Hset.
    destruct (ident_eq i id).
    - subst.
      rewrite /lookup /ptree_lookup Maps.PTree.gss in Hset; inv Hset.
      rewrite Map.gss; eauto.
    - rewrite Map.gso //.
      apply (Ht id ty).
      rewrite /lookup /ptree_lookup Maps.PTree.gso // in Hset.
Qed.

(* Scall *)

(*Lemma function_pointer_aux:
  forall A P P' Q Q' (w: rmap),
    args_super_non_expansive P ->
    super_non_expansive Q ->
    args_super_non_expansive P' ->
    super_non_expansive Q' ->
   SomeP (SpecArgsTT A) (fmap (fpi _) (approx (level w)) (approx (level w)) (packPQ P Q)) =
   SomeP (SpecArgsTT A) (fmap (fpi _) (approx (level w)) (approx (level w)) (packPQ P' Q')) ->
   ( (forall ts x vl, (! ▷ (P' ts x vl <=> P ts x vl)) w) /\
     (forall ts x vl, (! ▷ (Q' ts x vl <=> Q ts x vl)) w)).
Proof.
  intros ? ? ? ? ? ? NEP NEQ NEP' NEQ' H.
  apply someP_inj in H.
  unfold packPQ in H; simpl in H.
  split; intros.
  + apply equal_f_dep with ts in H.
    apply equal_f with x in H.
    apply equal_f_dep with true in H.
    apply equal_f with vl in H.
    simpl in H.
    rewrite @later_fash; auto with typeclass_instances.
    intros ? ? m' ?.
    assert (forall m'', necR m' m'' -> (level m'' < level w)%nat).
    {
      intros.
      clear - H0 H1 H2; hnf in H1.
      apply laterR_level in H1.
      apply necR_level in H2; simpl in *.
      lia.
    }
    split; intros ? m'' ? ? ?.
    - apply f_equal with (f:= fun x => app_pred x m'') in H.
      apply prop_unext in H.
      apply approx_p with (level w).
      rewrite NEP.
      apply H.
      rewrite <- NEP'.
      apply approx_lt; auto.
      apply necR_level in H3; apply ext_level in H4; apply laterR_level in H1; lia.
    - apply f_equal with (f:= fun x => app_pred x m'') in H.
      apply prop_unext in H.
      apply approx_p with (level w).
      rewrite NEP'.
      apply H.
      rewrite <- NEP.
      apply approx_lt; auto.
      apply necR_level in H3; apply ext_level in H4; apply laterR_level in H1; lia.
  + apply equal_f_dep with ts in H.
    apply equal_f with x in H.
    apply equal_f_dep with false in H.
    apply equal_f with vl in H.
    simpl in H.
    rewrite @later_fash; auto with typeclass_instances; intros ? ? m' ?.
    assert (forall m'', necR m' m'' -> (level m'' < level w)%nat).
    {
      intros.
      clear - H0 H1 H2; hnf in H1.
      apply laterR_level in H1.
      apply necR_level in H2; simpl in *.
      lia.
    }
    split; intros ? m'' ? ??.
    - apply f_equal with (f:= fun x => app_pred x m'') in H.
      apply prop_unext in H.
      apply approx_p with (level w).
      rewrite NEQ.
      apply H.
      rewrite <- NEQ'.
      apply approx_lt; auto.
      apply necR_level in H3; apply ext_level in H4; apply laterR_level in H1; lia.
    - apply f_equal with (f:= fun x => app_pred x m'') in H.
      apply prop_unext in H.
      apply approx_p with (level w).
      rewrite NEQ'.
      apply H.
      rewrite <- NEQ.
      apply approx_lt; auto.
      apply necR_level in H3; apply ext_level in H4; apply laterR_level in H1; lia.
Qed.*)

(*Import JuicyMemOps.

Fixpoint alloc_juicy_variables (ge: genv) (rho: env) (jm: juicy_mem) (vl: list (ident*type)) : env * juicy_mem :=
 match vl with
 | nil => (rho,jm)
 | (id,ty)::vars => match JuicyMemOps.juicy_mem_alloc jm 0 (@Ctypes.sizeof ge ty) with
                              (m1,b1) => alloc_juicy_variables ge (PTree.set id (b1,ty) rho) m1 vars
                           end
 end.

Lemma juicy_mem_alloc_core:
  forall jm lo hi jm' b, JuicyMemOps.juicy_mem_alloc jm lo hi = (jm', b) ->
    core (m_phi jm) = core (m_phi jm').
Proof.
 unfold JuicyMemOps.juicy_mem_alloc, after_alloc; intros.
 inv H.
 simpl.
 apply rmap_ext.
 repeat rewrite level_core. rewrite level_make_rmap. auto.
 intro loc.
 repeat rewrite <- core_resource_at.
 rewrite resource_at_make_rmap.
 unfold after_alloc'.
 if_tac; auto.
 destruct loc as [b z].
 simpl in H.
 rewrite core_YES.
 rewrite juicy_mem_alloc_cohere. rewrite core_NO; auto.
 simpl. destruct H.
 revert H; case_eq (alloc (m_dry jm) lo hi); intros.
 simpl in *. subst b0. apply alloc_result in H. subst b; lia.
 rewrite <- (core_ghost_of (proj1_sig _)), ghost_of_make_rmap, core_ghost_of; auto.
Qed.

Lemma alloc_juicy_variables_e:
  forall ge rho jm vl rho' jm',
    alloc_juicy_variables ge rho jm vl = (rho', jm') ->
  Clight.alloc_variables ge rho (m_dry jm) vl rho' (m_dry jm')
   /\ level jm = level jm'
   /\ core (m_phi jm) = core (m_phi jm').
Proof.
 intros.
 revert rho jm H; induction vl; intros.
 inv H. split; auto. constructor.
 unfold alloc_juicy_variables in H; fold alloc_juicy_variables in H.
 destruct a as [id ty].
 revert H; case_eq (JuicyMemOps.juicy_mem_alloc jm 0 (@Ctypes.sizeof ge ty)); intros jm1 b1 ? ?.
 specialize (IHvl (PTree.set id (b1,ty) rho) jm1 H0).
 destruct IHvl as [? [? ?]]; split3; auto.
 apply alloc_variables_cons  with  (m_dry jm1) b1; auto.
 apply JuicyMemOps.juicy_mem_alloc_succeeds in H. auto.
 apply JuicyMemOps.juicy_mem_alloc_level in H.
 congruence.
 rewrite <- H3.
 eapply  juicy_mem_alloc_core; eauto.
Qed.


Lemma alloc_juicy_variables_match_venv:
  forall ge jm vl ve' jm',
     alloc_juicy_variables ge empty_env jm vl = (ve',jm') ->
     match_venv (make_venv ve') vl.
Proof.
intros.
  intro i.
 unfold make_venv.
  destruct (ve' !! i) as [[? ?] | ] eqn:?; auto.
  assert (H0: (exists b, empty_env !! i = Some (b,t)) \/ In (i,t) vl).
2: destruct H0; auto; destruct H0; rewrite PTree.gempty in H0; inv H0.
 forget empty_env as e.
  revert jm e H; induction vl; simpl; intros.
  inv H.
  left; eexists; eauto.
  destruct a.
  apply IHvl in H; clear IHvl.
 destruct (ident_eq i0 i). subst i0.
 destruct H; auto. destruct H as [b' ?].
 rewrite PTree.gss in H. inv H. right. auto.
 destruct H; auto. left. destruct H as [b' ?].
 rewrite PTree.gso in H by auto. eauto.
Qed.*)

Lemma build_call_temp_env:
  forall f vl,
     length (fn_params f) = length vl ->
  exists te,  bind_parameter_temps (fn_params f) vl
                     (create_undef_temps (fn_temps f)) = Some te.
Proof.
 intros.
 forget (create_undef_temps (fn_temps f)) as rho.
 revert rho vl H; induction (fn_params f); destruct vl; intros; inv H; try congruence.
 exists rho; reflexivity.
 destruct a; simpl.
 apply IHl. auto.
Qed.

(*Lemma resource_decay_funassert:
  forall G rho b w w',
         necR (core w) (core w') ->
         resource_decay b w w' ->
         app_pred (funassert G rho) w ->
         app_pred (funassert G rho) w'.
Proof.
unfold resource_decay, funassert; intros until w'; intro CORE; intros.
destruct H.
destruct H0.
split; [clear H2 | clear H0].
+ intros id fs ? w2 Hw2 Hext H3.
  specialize (H0 id fs). cbv beta in H0.
  specialize (H0 _ _ (necR_refl _) (ext_refl _) H3).
  destruct H0 as [loc [? ?]].
  exists loc; split; auto.
  destruct fs as [f cc A a a0].
  simpl in H2|-*.
  pose proof (necR_resource_at (core w) (core w') (loc,0)
         (PURE (FUN f cc) (SomeP (SpecArgsTT A) (packPQ a a0))) CORE).
  pose proof (necR_resource_at _ _ (loc,0)
         (PURE (FUN f cc) (SomeP (SpecArgsTT A) (packPQ a a0))) Hw2).
  apply rmap_order in Hext as (<- & <- & _).
  apply H5.
  clear - H4 H2.
  repeat rewrite <- core_resource_at in *.
  spec H4. rewrite H2.  rewrite core_PURE.  simpl.  rewrite level_core; reflexivity.
  destruct (w' @ (loc,0)).
  rewrite core_NO in H4; inv H4.
  rewrite core_YES in H4; inv H4.
  rewrite core_PURE in H4; inv H4. rewrite level_core; reflexivity.
+
intros loc sig cc ? w2 Hw2 Hext H6.
specialize (H2 loc sig cc _ _ (necR_refl _) (ext_refl _)).
spec H2.
{ clear - Hw2 Hext CORE H6. simpl in *.
  destruct H6 as [pp H6].
  rewrite <- resource_at_approx.
  apply rmap_order in Hext as (Hl & Hr & _); rewrite <- Hr, <- Hl in H6.
  case_eq (w @ (loc,0)); intros.
  + assert (core w @ (loc,0) = resource_fmap (approx (level (core w))) (approx (level (core w))) (NO _ bot_unreadable)).
     - rewrite <- core_resource_at.
       simpl; erewrite <- core_NO, H; reflexivity.
     - pose proof (necR_resource_at _ _ _ _ CORE H0).
       pose proof (necR_resource_at _ _ _ _ (necR_core _ _ Hw2) H1).
       rewrite <- core_resource_at in H2; rewrite H6 in H2;
       rewrite core_PURE in H2; inv H2.
  + assert (core w @ (loc,0) = resource_fmap (approx (level (core w))) (approx (level (core w))) (NO _ bot_unreadable)).
    - rewrite <- core_resource_at.
      simpl; erewrite <- core_YES, H; reflexivity.
    - pose proof (necR_resource_at _ _ _ _ CORE H0).
      pose proof (necR_resource_at _ _ _ _ (necR_core _ _ Hw2) H1).
      rewrite <- core_resource_at in H2; rewrite H6 in H2;
      rewrite core_PURE in H2; inv H2.
  + pose proof (resource_at_approx w (loc,0)).
    pattern (w @ (loc,0)) at 1 in H0; rewrite H in H0.
    symmetry in H0.
    assert (core (w @ (loc,0)) = core (resource_fmap (approx (level w)) (approx (level w))
       (PURE k p))) by (f_equal; auto).
    rewrite core_resource_at in H1.
    assert (core w @ (loc,0) =
        resource_fmap (approx (level (core w))) (approx (level (core w)))
         (PURE k p)).
    - rewrite H1.  simpl resource_fmap. rewrite level_core; rewrite core_PURE; auto.
    - pose proof (necR_resource_at _ _ _ _ CORE H2).
      assert (w' @ (loc,0) = resource_fmap
         (approx (level w')) (approx (level w')) (PURE k p)).
      * rewrite <- core_resource_at in H3. rewrite level_core in H3.
        destruct (w' @ (loc,0)).
        ++ rewrite core_NO in H3; inv H3.
        ++ rewrite core_YES in H3; inv H3.
        ++ rewrite core_PURE in H3; inv H3.
           reflexivity.
      * pose proof (necR_resource_at _ _ _ _ Hw2 H4).
        inversion2 H6 H5.
        exists p. reflexivity. }
destruct H2 as [id [? ?]].
exists id. split; auto.
Qed.*)

Definition substopt {A} (ret: option ident) (v: environ -> val) (P: environ -> A)  : environ -> A :=
   match ret with
   | Some id => subst id v P
   | None => P
   end.

Lemma fst_split {T1 T2}: forall vl: list (T1*T2), fst (split vl) = map fst vl.
Proof. induction vl; try destruct a; simpl; auto.
  rewrite <- IHvl; clear IHvl.
 destruct (split vl); simpl in *; auto.
Qed.

Lemma snd_split {T1 T2}: forall vl: list (T1*T2), snd (split vl) = map snd vl.
Proof. induction vl; try destruct a; simpl; auto.
  rewrite <- IHvl; clear IHvl.
 destruct (split vl); simpl in *; auto.
Qed.

Lemma bind_parameter_temps_excludes :
forall l1 l2 t id t1,
~In id (map fst l1) ->
(bind_parameter_temps l1 l2 t) = Some t1 ->
t1 !! id = t !! id.
Proof.
induction l1;
intros.
simpl in *. destruct l2; inv H0. auto.
simpl in H0. destruct a. destruct l2; inv H0.
specialize (IHl1 l2 (Maps.PTree.set i v t) id t1).
simpl in H. intuition. setoid_rewrite Maps.PTree.gsspec in H3.
destruct (peq id i). subst; tauto. auto.
Qed.

Lemma pass_params_ni :
  forall  l2
     (te' : temp_env) (id : positive) te l,
   bind_parameter_temps l2 l (te) = Some te' ->
   (In id (map fst l2) -> False) ->
   Map.get (make_tenv te') id = te !! id.
Proof.
intros. eapply bind_parameter_temps_excludes in H.
unfold make_tenv, Map.get.
apply H. intuition.
Qed.

Lemma bind_exists_te : forall l1 l2 t1 t2 te,
bind_parameter_temps l1 l2 t1 = Some te ->
exists te2, bind_parameter_temps l1 l2 t2 = Some te2.
Proof.
induction l1; intros.
+ simpl in H. destruct l2; inv H. simpl. eauto.
+ destruct a. simpl in *. destruct l2; inv H. eapply IHl1.
  apply H1.
Qed.


Lemma smaller_temps_exists2 : forall l1 l2 t1 t2 te te2 i,
bind_parameter_temps l1 l2 t1 = Some te ->
bind_parameter_temps l1 l2 t2 = Some te2 ->
t1 !! i = t2 !! i ->
te !! i = te2 !! i.
Proof.
induction l1; intros; simpl in *; try destruct a; destruct l2; inv H; inv H0.
apply H1.
eapply IHl1. apply H3. apply H2.
repeat setoid_rewrite Maps.PTree.gsspec. destruct (peq i i0); auto.
Qed.


Lemma smaller_temps_exists' : forall l l1 te te' id i t,
bind_parameter_temps l l1 (Maps.PTree.set id Vundef t) = Some te ->
i <> id ->
(bind_parameter_temps l l1 t = Some te') -> te' !! i = te !! i.
Proof.
induction l; intros.
- simpl in *. destruct l1; inv H. inv H1. setoid_rewrite Maps.PTree.gso; auto.
- simpl in *. destruct a. destruct l1; inv H.
  eapply smaller_temps_exists2. apply H1. apply H3.
  intros. repeat setoid_rewrite Maps.PTree.gsspec. rewrite Maps.PTree.gsspec. destruct (peq i i0); auto.
  destruct (peq i id). subst. tauto. auto.
Qed.

Lemma smaller_temps_exists'' : forall l l1 te id i t,
bind_parameter_temps l l1 (Maps.PTree.set id Vundef t)=  Some te ->
i <> id ->
exists te', (bind_parameter_temps l l1 t = Some te').
Proof.
intros.
eapply bind_exists_te; eauto.
Qed.

Lemma smaller_temps_exists : forall l l1 te id i t,
bind_parameter_temps l l1 (Maps.PTree.set id Vundef t)=  Some te ->
i <> id -> 
exists te', (bind_parameter_temps l l1 t = Some te' /\ te' !! i = te !! i).
Proof.
intros. destruct (smaller_temps_exists'' _ _ _ _ _ _ H H0) as [x ?].
exists x. split. auto.
eapply smaller_temps_exists'; eauto.
Qed.


Lemma alloc_vars_lookup :
forall ge id m1 l ve m2 e ,
list_norepet (map fst l) ->
(forall i, In i (map fst l) -> e !! i = None) ->
Clight.alloc_variables ge (e) m1 l ve m2 ->
(exists v, e !! id = Some v) ->
ve !! id = e !! id.
Proof.
intros.
generalize dependent e.
revert ve m1 m2.

induction l; intros.
inv H1. auto.

inv H1. simpl in *. inv H.
destruct H2.
assert (id <> id0).
intro. subst.  specialize (H0 id0). spec H0. auto. rewrite H // in H0.
eapply IHl in H10.
setoid_rewrite Maps.PTree.gso in H10; auto.
auto. intros. setoid_rewrite Maps.PTree.gsspec. if_tac. subst. tauto.
apply H0. auto.
setoid_rewrite Maps.PTree.gso; auto. eauto.
Qed.

Lemma alloc_vars_lemma : forall ge id l m1 m2 ve ve'
(SD : forall i, In i (map fst l) -> ve !! i = None),
list_norepet (map fst l) ->
Clight.alloc_variables ge ve m1 l ve' m2 ->
(In id (map fst l) ->
exists v, ve' !! id = Some v).
Proof.
intros.
generalize dependent ve.
revert m1 m2.
induction l; intros. inv H1.
simpl in *. destruct a; simpl in *.
destruct H1. subst. inv H0. inv H.  apply alloc_vars_lookup with (id := id) in H9; auto.
rewrite H9. setoid_rewrite Maps.PTree.gss. eauto. intros.
destruct (peq i id). subst. tauto. setoid_rewrite Maps.PTree.gso; eauto.
setoid_rewrite Maps.PTree.gss; eauto.

inv H0. apply IHl in H10; auto. inv H; auto.
intros. setoid_rewrite Maps.PTree.gsspec. if_tac. subst. inv H. tauto.
eauto.
Qed.

(*Lemma semax_call_typecheck_environ:
  forall (Delta : tycontext) (args: list val) (psi : genv)
           (jm : juicy_mem) (b : block) (f : function)
     (H17 : list_norepet (map fst (fn_params f) ++ map fst (fn_temps f)))
     (H17' : list_norepet (map fst (fn_vars f)))
     (H16 : Genv.find_funct_ptr psi b = Some (Internal f))
     (ve' : env) (jm' : juicy_mem) (te' : temp_env)
     (H15 : alloc_variables psi empty_env (m_dry jm) (fn_vars f) ve' (m_dry jm'))
     (TC5: typecheck_glob_environ (filter_genv psi) (glob_types Delta))
   (H : forall (b : ident) (b0 : funspec) (a' a'' : rmap),
    necR (m_phi jm') a' -> ext_order a' a'' ->
    (glob_specs Delta) !! b = Some b0 ->
    exists b1 : block,
        filter_genv psi b = Some b1 /\
        func_at b0 (b1,0) a'')
   (TC8 : tc_vals (snd (split (fn_params f))) args)
   (H21 : bind_parameter_temps (fn_params f) args
              (create_undef_temps (fn_temps f)) = Some te'),
   typecheck_environ (func_tycontext' f Delta)
      (construct_rho (filter_genv psi) ve' te').
Proof. assert (H1:= True).
 intros.
 pose (rho3 := mkEnviron (filter_genv psi) (make_venv ve') (make_tenv te')).

unfold typecheck_environ. repeat rewrite andb_true_iff.
split3.
*
clear H H1 H15.
unfold typecheck_temp_environ in *. intros. simpl.
unfold temp_types in *. simpl in *.
apply func_tycontext_t_sound in H; auto.
 clear - H21 H TC8 H17.

destruct H. (*in params*)
forget (create_undef_temps (fn_temps f)) as temps.
rewrite snd_split in TC8.
generalize dependent temps.
generalize dependent args. generalize dependent te'.
{  induction (fn_params f); intros.
   + inv H.
   + destruct args. inv TC8. destruct a. simpl in *.
       destruct TC8 as [TC8' TC8].
       destruct H.
      - clear IHl.
        inv H.
        rewrite (pass_params_ni _ _ id _ _ H21)
           by (inv H17; contradict H1; apply in_app; auto).
        rewrite PTree.gss.
        eexists.  split. reflexivity. apply tc_val_tc_val'.
        auto.
      - inv H17.
        assert (i <> id). intro. subst.
        apply H2. apply in_or_app. left. apply in_map with (f := fst) in H. apply H.
        eapply IHl; eauto.
}

(*In temps*)
apply list_norepet_app in H17. destruct H17 as [? [? ?]].
generalize dependent (fn_params f). generalize dependent args.
generalize dependent te'.

induction (fn_temps f); intros.
inv H.

simpl in *. destruct H. destruct a. inv H. simpl in *.
clear IHl. exists Vundef. simpl in *. split; [| hnf; congruence]. inv H1.
eapply pass_params_ni with (id := id) in H21; auto.
rewrite PTree.gss in *. auto.
intros.
unfold list_disjoint in *. eapply H2. eauto. left. auto. auto.

destruct a.
destruct (peq id i). subst.
apply pass_params_ni with (id := i) in H21.
rewrite PTree.gss in *. exists Vundef. split; [auto | hnf; congruence].
intros. unfold list_disjoint in *. intuition.
eapply H2. eauto. left. auto. auto.

apply smaller_temps_exists with (i := id) in H21.
destruct H21.  destruct H3.
eapply IHl in H3; auto.
destruct H3. destruct H3.
exists x0. split. unfold Map.get in *.
unfold make_tenv in *. rewrite <- H4. auto. auto.
inv H1; auto. unfold list_disjoint in *. intros.
apply H2. auto. right. auto. auto.
*

simpl in *.
unfold typecheck_var_environ in *. intros.
simpl in *. unfold typecheck_var_environ in *.
unfold func_tycontext' in *. unfold var_types in *.
simpl in *.
rewrite (func_tycontext_v_sound (fn_vars f) id ty); auto.
transitivity ((exists b, empty_env !! id = Some (b,ty) )\/ In (id,ty) (fn_vars f)).
clear; intuition. destruct H0. unfold empty_env in H.
rewrite PTree.gempty in H; inv H.
generalize dependent (m_dry jm).
clear - H17'.
assert (forall id, empty_env !! id <> None -> ~ In id (map fst (fn_vars f))).
intros. unfold empty_env in H. rewrite PTree.gempty in H. contradiction H; auto.
generalize dependent empty_env.
unfold Map.get, make_venv.
induction (fn_vars f); intros.
inv H15.
destruct (ve' !! id); intuition.
inv H15.
inv H17'.
specialize (IHl H3); clear H3.
specialize (IHl (PTree.set id0 (b1,ty0) e)).
spec IHl.
intros id' H8; specialize (H id').
destruct (ident_eq id0 id'). subst. auto.
rewrite PTree.gso  in H8 by auto.
specialize (H H8). contradict H.
right; auto.
specialize (IHl _ H7).
clear - H H2 IHl.
destruct (ident_eq id0 id). subst id0.
rewrite PTree.gss in IHl.
split; intro.
destruct H0.
destruct H0. specialize (H id).
destruct (e!id); try discriminate.
inv H0.
spec H; [congruence | ].
contradiction H. left; auto.
destruct H0. inv H0.
apply IHl. left; eauto.
contradiction H2. apply in_map with (f:=fst) in H0. apply H0.
rewrite <- IHl in H0.
destruct H0.
destruct H0. inv H0. right; left; auto.
contradiction H2.
apply in_map with (f:=fst) in H0. auto.
rewrite PTree.gso in IHl by auto.
rewrite <- IHl.
intuition. inv H5. inv H0. tauto.
apply H4 in H0. apply H1; auto.
*
unfold ge_of in *. simpl in *. auto.
Qed.*)

Lemma free_list_free:
  forall m b lo hi l' m',
       free_list m ((b,lo,hi)::l') = Some m' ->
         {m2 | free m b lo hi = Some m2 /\ free_list m2 l' = Some m'}.
Proof.
  simpl; intros.
  destruct (free m b lo hi). eauto. inv H.
Qed.

Definition freeable_blocks: list (Values.block * BinInt.Z * BinInt.Z) -> mpred :=
  fold_right (fun (bb: Values.block*BinInt.Z * BinInt.Z) a =>
                        match bb with (b,lo,hi) =>
                                          VALspec_range (hi-lo) Share.top (b,lo) ∗ a
                        end)
                    emp.

(*Inductive free_list_juicy_mem:
      forall  (jm: juicy_mem) (bl: list (block * BinInt.Z * BinInt.Z))
                                         (jm': juicy_mem), Prop :=
| FLJM_nil: forall jm, free_list_juicy_mem jm nil jm
| FLJM_cons: forall jm b lo hi bl jm2 jm'
                          (H: free (m_dry jm) b lo hi = Some (m_dry jm2))
                          (H0 : forall ofs : Z,
                        lo <= ofs < hi ->
                        perm_of_res (m_phi jm @ (b, ofs)) = Some Freeable),
                          free_juicy_mem jm (m_dry jm2) b lo hi H = jm2 ->
                          free_list_juicy_mem jm2 bl jm' ->
                          free_list_juicy_mem jm ((b,lo,hi)::bl) jm'.*)

(*Lemma perm_of_res_val : forall r, perm_of_res r = Some Freeable ->
  exists v pp, r = YES Share.top readable_share_top (VAL v) pp.
Proof.
  destruct r; simpl; try if_tac; try discriminate.
  destruct k; try discriminate.
  unfold perm_of_sh.
  repeat if_tac; try discriminate.
  subst; intro; do 2 eexists; f_equal.
  apply proof_irr.
Qed.*)

(*Lemma free_list_juicy_mem_i:
  forall jm bl m' F,
   free_list (m_dry jm) bl = Some m' ->
   app_pred (freeable_blocks bl * F) (m_phi jm) ->
   exists jm', free_list_juicy_mem jm bl jm'
                  /\ m_dry jm' = m'
                  /\ level jm = level jm'.
Proof.
intros jm bl; revert jm; induction bl; intros.
*
 inv H; exists jm; split3; auto. constructor.
*
 simpl freeable_blocks in H0. destruct a as [[b lo] hi].
 rewrite sepcon_assoc in H0.
 destruct (free_list_free _ _ _ _ _ _ H) as [m2 [? ?]].
 generalize H0; intro H0'.
 destruct H0 as [phi1 [phi2 [? [? H6]]]].

 assert (H10:= @juicy_free_lemma' jm b lo hi m2 phi1 _ _ H1 H0' H3 H0).
 match type of H10 with context[m_phi ?A] => set (jm2:=A) in H10 end; subst.

 eapply pred_upclosed in H6; eauto.
 specialize (IHbl  jm2 m' F H2 H6).
 destruct IHbl as [jm' [? [? ?]]].
 exists jm'; split3; auto.
 apply (FLJM_cons jm b lo hi bl jm2 jm' H1
   (juicy_free_aux_lemma (m_phi jm) b lo hi (freeable_blocks bl * F) H0') (eq_refl _) H4).
 rewrite <- H7.
 unfold jm2.
 symmetry; apply free_juicy_mem_level.
Qed.*)

(*Lemma free_list_juicy_mem_lem:
  forall P jm bl jm',
     free_list_juicy_mem jm bl jm' ->
     app_pred (freeable_blocks bl * P) (m_phi jm) ->
     app_pred P (m_phi jm').
Proof.
 intros.
 revert H0; induction H; simpl freeable_blocks.
 intros.  rewrite emp_sepcon in H0; auto.
 rename H0 into H99. rename H1 into H0; rename H2 into H1.
 intro.
 rewrite sepcon_assoc in H2.
 generalize H2; intro H2'.
 destruct H2 as [phi1 [phi2 [? [? ?]]]].
 apply IHfree_list_juicy_mem.
 pose proof  (@juicy_free_lemma' jm b lo hi _ phi1 _ _ H H2' H3 H2).
 match type of H5 with context[m_phi ?A] => set (jm3 := A) in H5 end.
 replace jm2 with jm3 by (subst jm3; rewrite <- H0; apply free_juicy_mem_ext; auto).
 eapply pred_upclosed; eauto.
Qed.*)

Lemma PTree_elements_remove: forall {A} (T: Maps.PTree.tree A) i e,
  In e (Maps.PTree.elements (Maps.PTree.remove i T)) ->
  In e (Maps.PTree.elements T) /\ fst e <> i.
Proof.
  intros.
  destruct e as [i0 v0].
  apply Maps.PTree.elements_complete in H.
  destruct (peq i0 i).
  + subst.
    rewrite Maps.PTree.grs in H.
    inversion H.
  + rewrite -> Maps.PTree.gro in H by auto.
    split; [| simpl; auto].
    apply Maps.PTree.elements_correct.
    auto.
Qed.

Lemma stackframe_of_freeable_blocks:
  forall Delta f rho ge ve,
      cenv_sub (@cenv_cs CS) (genv_cenv ge) ->
      Forall (fun it => complete_type cenv_cs (snd it) = true) (fn_vars f) ->
      list_norepet (map fst (fn_vars f)) ->
      ve_of rho = make_venv ve ->
      guard_environ (func_tycontext' f Delta) f rho ->
       stackframe_of f rho ⊢ freeable_blocks (blocks_of_env ge ve).
Proof.
 intros until ve.
 intros HGG COMPLETE.
 intros.
 destruct H1. destruct H2 as [H7 _].
 unfold stackframe_of.
 unfold func_tycontext' in H1.
 unfold typecheck_environ in H1.
 destruct H1 as [_ [?  _]].
 rewrite H0 in H1.
 unfold make_venv in H1.
 unfold var_types in H1.
 simpl in H1. unfold make_tycontext_v in H1.
 unfold blocks_of_env.
 trans (foldr bi_sep emp (map (fun idt => var_block Share.top idt rho) (fn_vars f))).
 { clear; induction (fn_vars f); simpl; auto; by rewrite IHl. }
 unfold var_block. unfold eval_lvar. simpl.
 rewrite H0. unfold make_venv. forget (ge_of rho) as ZZ. rewrite H0 in H7; clear rho H0.
 revert ve H1 H7; induction (fn_vars f); simpl; intros.
 case_eq (Maps.PTree.elements ve); simpl; intros; auto.
 destruct p as [id ?].
 pose proof (Maps.PTree.elements_complete ve id p). rewrite H0 in H2. simpl in H2.
 specialize (H7 id). unfold make_venv in H7. rewrite H2 in H7; auto.
 destruct p; inv H7.
 inv H.
 destruct a as [id ty]. simpl in *.
 simpl in COMPLETE. inversion COMPLETE; subst.
 clear COMPLETE; rename H5 into COMPLETE; rename H2 into COMPLETE_HD.
 specialize (IHl COMPLETE H4 (Maps.PTree.remove id ve)).
 assert (exists b, Maps.PTree.get id ve = Some (b,ty)). {
  specialize (H1 id ty).
  setoid_rewrite Maps.PTree.gss in H1. destruct H1 as [[b ?] _]; auto. exists b; apply H.
 }
 destruct H as [b H].
 destruct (@Maps.PTree.elements_remove _ id (b,ty) ve H) as [l1 [l2 [? ?]]].
 rewrite H0.
 rewrite map_app. simpl map.
 trans (freeable_blocks ((b,0,@Ctypes.sizeof ge ty) :: (map (block_of_binding ge) (l1 ++ l2)))).
 2:{
   clear.
   induction l1; simpl; try auto.
   destruct a as [id' [hi lo]]. simpl in *.
   rewrite -IHl1.
   rewrite !assoc (comm _ (VALspec_range _ _ _ )) //. }
 unfold freeable_blocks; simpl. rewrite <- H2.
 apply bi.sep_mono.
 { unfold Map.get. rewrite H. rewrite eqb_type_refl.
   unfold memory_block. iIntros "(% & % & H)".
   rename H6 into H99.
   rewrite memory_block'_eq.
   2: rewrite Ptrofs.unsigned_zero; lia.
   2:{ rewrite Ptrofs.unsigned_zero. rewrite Zplus_0_r.
       rewrite Z2Nat.id.
       change (Ptrofs.unsigned Ptrofs.zero) with 0 in H99.
       lia.
       unfold sizeof.
       pose proof (sizeof_pos ty); lia. }
 rewrite Z.sub_0_r.
 unfold memory_block'_alt.
 rewrite -> if_true by apply readable_share_top.
 rewrite Z2Nat.id.
 + rewrite (cenv_sub_sizeof HGG); auto.
 + unfold sizeof; pose proof (sizeof_pos ty); lia. }
 etrans; last apply IHl.
 clear - H3.
 induction l; simpl; auto.
 destruct a as [id' ty']. simpl in *.
 apply bi.sep_mono; auto.
 replace (Map.get (fun id0 : positive => Maps.PTree.get id0 (Maps.PTree.remove id ve)) id')
   with (Map.get (fun id0 : positive => Maps.PTree.get id0 ve) id'); auto.
 unfold Map.get.
 rewrite Maps.PTree.gro; auto.
 intros id' ty'; specialize (H1 id' ty').
 { split; intro.
 - destruct H1 as [H1 _].
   assert (id<>id').
   intro; subst id'.
   clear - H3 H5; induction l; simpl in *. setoid_rewrite Maps.PTree.gempty in H5; inv H5.
   destruct a; simpl in *.
   setoid_rewrite Maps.PTree.gso in H5. auto. auto.
   destruct H1 as [v ?].
   setoid_rewrite Maps.PTree.gso; auto.
   exists v. unfold Map.get. rewrite Maps.PTree.gro; auto.
 - unfold Map.get in H1,H5.
   assert (id<>id').
     clear - H5; destruct H5. intro; subst. rewrite Maps.PTree.grs in H. inv H.
   rewrite -> Maps.PTree.gro in H5 by auto.
   rewrite <- H1 in H5. setoid_rewrite -> Maps.PTree.gso in H5; auto. }
 hnf; intros.
 destruct (make_venv (Maps.PTree.remove id ve) id0) eqn:H5; auto.
 destruct p.
 unfold make_venv in H5.
 destruct (peq id id0).
 subst. rewrite Maps.PTree.grs in H5. inv H5.
 rewrite -> Maps.PTree.gro in H5 by auto.
 specialize (H7 id0). unfold make_venv in H7. rewrite H5 in H7.
 destruct H7; auto. inv H6; congruence.
Qed.

Definition maybe_retval (Q: environ -> mpred) retty ret :=
 match ret with
 | Some id => fun rho => ⌜tc_val' retty (eval_id id rho)⌝ ∧ Q (get_result1 id rho)
 | None =>
    match retty with
    | Tvoid => (fun rho => Q (globals_only rho))
    | _ => fun rho => ∃ v: val, ⌜tc_val' retty v⌝ ∧ Q (make_args (ret_temp::nil) (v::nil) rho)
    end
 end.

Lemma VALspec_range_free:
  forall n b m,
  mem_auth m ∗ VALspec_range n Share.top (b, 0) ⊢
  ⌜∃ m', free m b 0 n = Some m'⌝.
Proof.
intros.
iIntros "(Hm & H)".
iAssert ⌜range_perm m b 0 n Cur Freeable⌝ as %H; last by iPureIntro; apply range_perm_free in H as [??]; eauto.
iIntros (??).
rewrite /VALspec_range (big_sepL_lookup_acc _ _ (Z.to_nat a)).
2: { apply lookup_seq; split; eauto; lia. }
rewrite Z2Nat.id; last tauto.
iDestruct "H" as "[H _]".
rewrite /VALspec.
iDestruct "H" as (?) "H".
iDestruct (mapsto_lookup with "Hm H") as %(? & ? & _ & Hacc & _); iPureIntro.
rewrite /access_cohere /access_at /= perm_of_freeable -mem_lemmas.po_oo // in Hacc.
Qed.

Lemma Forall_filter: forall {A} P (l: list A) f, Forall P l -> Forall P (List.filter f l).
Proof.
  intros.
  induction l.
  + constructor.
  + inversion H; subst.
    apply IHl in H3.
    simpl.
    simple_if_tac.
    - constructor; auto.
    - auto.
Qed.

Lemma can_free_list :
  forall E Delta f m ge ve te
  (NOREP: list_norepet (map (@fst _ _) (fn_vars f)))
  (COMPLETE: Forall (fun it => complete_type cenv_cs (snd it) = true) (fn_vars f))
  (HGG: cenv_sub (@cenv_cs CS) (genv_cenv ge)),
   guard_environ (func_tycontext' f Delta) f
        (construct_rho (filter_genv ge) ve te) ->
   mem_auth m ∗ stackframe_of f (construct_rho (filter_genv ge) ve te) ⊢
   |={E}=> ∃ m2, ⌜free_list m (blocks_of_env ge ve) = Some m2⌝ ∧ mem_auth m2.
Proof.
  intros.
  iIntros "(Hm & stack)".
  unfold stackframe_of, blocks_of_env.
  destruct H as [_ [H _]]; simpl in H.
  pose (F vl := (foldr
          (fun (P Q : environ -> _) (rho : environ) => P rho ∗ Q rho)
          (fun _ : environ => emp)
          (map (fun idt : ident * type => var_block Share.top idt) vl))).
  fold (F (fn_vars f)).
  assert (forall id b t, In (id,(b,t)) (Maps.PTree.elements ve) ->
                In (id,t) (fn_vars f)) as Hin. {
    intros ??? Hin.
    apply Maps.PTree.elements_complete in Hin.
    specialize (H id); unfold make_venv in H; rewrite Hin in H.
    apply H. }
  clear H.
  assert (Hve: forall i bt, In (i,bt) (Maps.PTree.elements ve) -> ve !! i = Some bt)
    by apply Maps.PTree.elements_complete.
  assert (Hve': forall i bt, ve !! i = Some bt -> In (i,bt) (Maps.PTree.elements ve))
    by apply Maps.PTree.elements_correct.
  assert (NOREPe: list_norepet (map (@fst _ _) (Maps.PTree.elements ve)))
    by apply Maps.PTree.elements_keys_norepet.
  forget (Maps.PTree.elements ve) as el.
  forget (fn_vars f) as vl.
  iInduction el as [|] "IHel" forall (vl m Hin Hve Hve' NOREP NOREPe COMPLETE).
  { iExists m; iFrame.
    destruct vl; first done.
    rewrite /F /= /var_block.
    admit. }
  destruct a as [id [b t]]. simpl in NOREPe, Hin |- *.
  assert (Hin': In (id,t) vl) by (apply Hin with b; auto).
  iSpecialize ("IHel" $! (Maps.PTree.remove id ve) (List.filter (fun idt => negb (eqb_ident (fst idt) id)) vl)).
  iAssert (var_block Share.top (id,t) (construct_rho (filter_genv ge) ve te)
    ∗ F (List.filter (fun idt => negb (eqb_ident (fst idt) id)) vl) (construct_rho (filter_genv ge) ve te)) with "[stack]" as "stack".
  { iClear "IHel"; clear - Hin' NOREP.
    iInduction vl as [|] "IHvl"; first by inv Hin'.
    simpl in NOREP.
    inv NOREP.
    unfold F; simpl.
    inv Hin'.
    - erewrite foldr_ext; first iApply "stack"; try done.
      f_equal; simpl.
      replace (eqb_ident id id) with true
        by (symmetry; apply (eqb_ident_spec id id); auto); simpl.
      clear - H1.
      induction vl; simpl; auto.
      replace (negb (eqb_ident (fst a) id)) with true.
      f_equal.
      apply IHvl.
      contradict H1. right; auto.
      pose proof (eqb_ident_spec (fst a) id).
      destruct (eqb_ident (fst a) id) eqn:?; auto.
      exfalso; apply H1. left. rewrite <- H; auto.
    - iDestruct "stack" as "[? stack]"; iPoseProof ("IHvl" with "[%] [%] stack") as "[$ stack]"; try done.
      replace (eqb_ident (fst a) id) with false; first iFrame.
      pose proof (eqb_ident_spec (fst a) id).
      destruct (eqb_ident (fst a) id); auto.
      assert (fst a = id) by (apply H0; auto).
      subst id.
      contradiction H1.
      replace (fst a) with (fst (fst a, t)) by reflexivity.
      apply in_map; auto. }
  iDestruct "stack" as "[block stack]".
  unfold var_block at 1.
  iDestruct "block" as (?) "block"; simpl.
  assert (0 <= sizeof t) by (unfold sizeof; pose proof (sizeof_pos t); lia).
  unfold eval_lvar, Map.get; simpl.
  unfold make_venv.
  pose proof (Hve id (b,t)) as Hvei.
  rewrite /lookup /ptree_lookup in Hvei; rewrite -> Hvei by (left; auto).
  rewrite eqb_type_refl; simpl.
  iDestruct "block" as (?) "block".
  rewrite memory_block'_eq;
  try rewrite Ptrofs.unsigned_zero; try lia.
  2:{ rewrite Z.add_0_r; rewrite -> Z2Nat.id by lia; unfold Ptrofs.max_unsigned in *; simpl in *; lia. }
  unfold memory_block'_alt.
  rewrite -> Z2Nat.id by lia.
  rewrite -> if_true by apply readable_share_top.
  iDestruct (VALspec_range_free with "[$Hm $block]") as %[m3 Hfree].
  
  rewrite /sizeof in Hfree; rewrite Hfree.
  setoid_rewrite Hfree.
  destruct (VALspec_range_free _ _ _ _ H3 H7)
   as [m3 ?H].
  assert (VR: app_pred (VALspec_range (sizeof t-0) Share.top (b, 0) * TT) (m_phi jm)).
    clear - H3 H7. destruct H7.
  rewrite Z.sub_0_r; exists phi1; exists x; split3; auto.
  pose (jm3 := free_juicy_mem _ _ _ _ _ H8 ).
  destruct H as [phix H].
  destruct (join_assoc H1 H) as [phi3 []].
  assert (ext_order phi3 (m_phi jm3)) as Hext.
  { eapply juicy_free_lemma'; eauto.
    rewrite Z.sub_0_r; auto.
  }
  assert (join_sub phi2 (m_phi jm3)) as Hphi2.
  { eapply join_sub_trans; [eexists; eauto | apply ext_join_sub; auto]. }
  destruct (IHel phi2 jm3 Hphi2) as [m4 ?]; auto; clear IHel.
  + intros.
    specialize (H2 id0 b0 t0).
    spec H2; [ auto |].
    assert (id0 <> id).
    {
      clear - NOREPe H11.
      inv NOREPe. intro; subst.
      apply H1. change id with (fst (id,(b0,t0))); apply in_map; auto.
    }
    clear - H2 H12.
    induction vl; simpl in *; auto.
    destruct H2. subst a. simpl.
    replace (eqb_ident id0 id) with false; simpl; auto.
    pose proof (eqb_ident_spec id0 id); destruct (eqb_ident id0 id); simpl in *; auto.
    contradiction H12; apply H; auto.
    pose proof (eqb_ident_spec (fst a) id); destruct (eqb_ident (fst a) id); simpl in *; auto.
  + intros; eapply Hve; eauto.
    right; auto.
  + clear - NOREP.
    induction vl; simpl; auto.
    pose proof (eqb_ident_spec (fst a) id); destruct (eqb_ident (fst a) id); simpl in *; auto.
    assert (fst a = id) by ( apply H; auto); subst.
    apply IHvl; inv NOREP; auto.
    inv NOREP.
    constructor; auto.
    clear - H2.
    contradict H2.
    induction vl; simpl in *; auto.
    destruct (eqb_ident (fst a0) id); simpl in *; auto.
    destruct H2; auto.
  + inv NOREPe; auto.
  + apply Forall_filter; auto.
  + pose proof (proj1 (Forall_forall _ _) COMPLETE (id, t) H2').
    simpl in H11.
    exists m4.
    rewrite (cenv_sub_sizeof HGG) by auto.
    unfold sizeof in H8; rewrite H8; auto.
Qed.*)

(*Lemma free_juicy_mem_resource_decay:
  forall jm b lo hi m' jm'
     (H : free (m_dry jm) b lo hi = Some m')
     (H0 : forall ofs : Z,  lo <= ofs < hi ->
             perm_of_res (m_phi jm @ (b, ofs)) = Some Freeable),
    free_juicy_mem jm m' b lo hi H = jm' ->
    resource_decay (nextblock (m_dry jm)) (m_phi jm) (m_phi jm').
Proof.
intros.
 subst jm'. simpl.
 apply (inflate_free_resource_decay _ _ _ _ _ H H0).
Qed.

Lemma free_list_resource_decay:
  forall bl jm jm',
  free_list_juicy_mem jm bl jm' ->
  resource_decay (nextblock (m_dry jm)) (m_phi jm) (m_phi jm').
Proof.
induction 1; intros.
apply resource_decay_refl; intros.
apply (juicy_mem_alloc_cohere jm l H).
apply resource_decay_trans with (nextblock (m_dry jm)) (m_phi jm2).
apply Pos.le_refl.
eapply free_juicy_mem_resource_decay; eauto.
rewrite <- (nextblock_free _ _ _ _ _ H).
apply IHfree_list_juicy_mem.
Qed.*)

Definition tc_fn_return (Delta: tycontext) (ret: option ident) (t: type) :=
 match ret with
 | None => True%type
 | Some i => match (temp_types Delta) !! i with Some t' => t=t' | _ => False%type end
 end.

(* Lemma free_juicy_mem_core:
  forall jm m b lo hi H
   (H0 : forall ofs : Z,
     lo <= ofs < hi -> perm_of_res (m_phi jm @ (b, ofs)) = Some Freeable),
   core (m_phi (free_juicy_mem jm m b lo hi H)) = core (m_phi jm).
Proof.
 intros.
 apply rmap_ext.
 do 2  rewrite level_core.
 apply free_juicy_mem_level.
 intros.
 repeat rewrite <- core_resource_at.
 simpl m_phi. unfold inflate_free. rewrite resource_at_make_rmap.
 destruct (m_phi jm @ l) eqn:?; auto.
 if_tac; rewrite !core_NO; auto.
 if_tac. rewrite core_YES, core_NO; auto. rewrite !core_YES; auto.
 if_tac; auto.
 destruct l; destruct H1; subst. specialize (H0 z).
 spec H0; [lia | ]. rewrite Heqr in H0. inv H0.
 rewrite !ghost_of_core, free_juicy_mem_ghost; auto.
Qed.*)

Lemma same_glob_funassert':
  forall Delta1 Delta2 rho rho',
     (forall id, (glob_specs Delta1) !! id = (glob_specs Delta2) !! id) ->
      ge_of rho = ge_of rho' ->
              funassert Delta1 rho ⊣⊢ funassert Delta2 rho'.
Proof.
  assert (forall Delta Delta' rho rho',
             (forall id, (glob_specs Delta) !! id = (glob_specs Delta') !! id) ->
             ge_of rho = ge_of rho' ->
             funassert Delta rho ⊢ funassert Delta' rho') as H; last by intros; iSplit; iApply H.
  intros ???? H; simpl; intros ->.
  iIntros "[#? #Hsig]"; iSplit.
  - iIntros (?); rewrite -H //.
  - iIntros "!>" (???) "?".
    setoid_rewrite <- H; iApply ("Hsig" with "[$]").
Qed.

Definition thisvar (ret: option ident) (i : ident) : Prop :=
 match ret with None => False | Some x => x=i end.

Lemma closed_wrt_modvars_Scall:
  forall ret a bl, closed_wrt_modvars (Scall ret a bl) = closed_wrt_vars (thisvar ret).
Proof.
intros.
unfold closed_wrt_modvars.
extensionality F.
f_equal.
 extensionality i; unfold modifiedvars, modifiedvars', insert_idset.
 unfold isSome, idset0, insert_idset; destruct ret; simpl; auto.
 destruct (ident_eq i0 i).
 subst. setoid_rewrite Maps.PTree.gss. apply prop_ext; split; auto.
 setoid_rewrite -> Maps.PTree.gso; last auto. rewrite Maps.PTree.gempty.
 apply prop_ext; split; intro; contradiction.
Qed.

Lemma assert_safe_for_external_call {psi E curf vx ret ret0 tx k z'} :
      assert_safe Espec psi E curf vx (set_opttemp ret (force_val ret0) tx)
         (Cont k) (construct_rho (filter_genv psi) vx (set_opttemp ret (force_val ret0) tx)) ⊢
  jsafeN Espec psi E z' (Returnstate (force_val ret0) (Kcall ret curf vx tx k)).
Proof.
  iIntros "H".
  iApply jsafe_step; rewrite /jstep_ex.
  iIntros (?) "? !>".
  iExists _, _; iSplit; first by iPureIntro; constructor.
  iFrame; iIntros "!> !>".
  by iApply assert_safe_jsafe'.
Qed.

Lemma semax_call_external
 E (Delta : tycontext)
 (A : Type)
 (P : A -> argsEnviron -> mpred)
 (Q : A -> environ -> mpred)
 (F0 : environ -> mpred)
 (ret : option ident) (curf : function) (fsig : typesig) (cc : calling_convention)
 (R : ret_assert) (psi : genv) (vx : env) (tx : temp_env)
 (k : cont) (rho : environ) (ora : OK_ty) (b : Values.block)
 (TCret : tc_fn_return Delta ret (snd fsig))
 (TC3 : guard_environ Delta curf rho)
 (TC5 : snd fsig = Tvoid -> ret = None)
 (H : closed_wrt_vars (thisvar ret) F0)
 (H0 : rho = construct_rho (filter_genv psi) vx tx)
 (args : list val)
 (ff : Clight.fundef)
 (H16 : Genv.find_funct psi (Vptr b Ptrofs.zero) = Some ff)
 (TC8 : tc_vals (fst fsig) args)
 (Hargs : Datatypes.length (fst fsig) = Datatypes.length args)
 (ctl := Kcall ret curf vx tx k : cont) :
 □ believe_external Espec psi E (Vptr b Ptrofs.zero) fsig cc A P Q -∗
 ▷ <affine> rguard Espec psi E Delta curf (frame_ret_assert R F0) k -∗
 ▷ funassert Delta rho -∗
 ▷ F0 rho -∗
 ▷ (|={E}=> ∃ (x1 : A) (F1 : environ → mpred),
               (F1 rho ∗ P x1 (ge_of rho, args))
               ∧ (∀ rho' : environ,
                    ■ ((∃ old : val, substopt ret (` old) F1 rho' ∗
                          maybe_retval (Q x1) (snd fsig) ret rho') -∗ RA_normal R rho'))) -∗
 ▷ jsafeN Espec psi E ora (Callstate ff args ctl).
Proof.
pose proof TC3 as Hguard_env.
destruct TC3 as [TC3 TC3'].
rewrite /believe_external H16.
iIntros "#ext".
destruct ff; first done.
iDestruct "ext" as "((-> & -> & %Eef & %Hinline) & He & Htc)".
rename t into tys.
iIntros "rguard fun F0 HR !>".
iMod "HR" as (??) "((F1 & P) & #HR)".
iMod ("He" $! psi x1 (F0 rho ∗ F1 rho) (typlist_of_typelist tys) args with "[F0 F1 P]") as "He1".
{ subst rho; iFrame; iPureIntro; split; auto.
  (* typechecking arguments *)
  rewrite Eef; simpl.
  clear - TC8. rewrite TTL2.
  revert args TC8; induction (Clight_core.typelist2list tys); destruct args; intros; try discriminate; auto.
  inv TC8.
  split; auto.
  apply tc_val_has_type; auto. }
clear TC8. simpl fst in *. simpl snd in *.
rewrite /jsafeN jsafe_unfold /jsafe_pre.
iIntros "!>" (?) "s"; iDestruct ("He1" with "s") as (x') "(pre & #post)".
destruct Hinline as [Hinline | ?]; last done.
iRight; iRight; iExists _, _, _; iSplit.
{ iPureIntro; simpl.
  rewrite Hinline //. }
rewrite Eef TTL3; iFrame "pre".
Search plainly bi_intuitionistically.
iDestruct "rguard" as "#rguard"; iDestruct "fun" as "#fun".
iNext.
iIntros "!>" (??? [??]) "?".
iMod ("post" with "[$]") as "($ & Q & F0 & F)".
iDestruct ("Htc" with "[Q]") as %Htc; first by iFrame.
pose (tx' := match ret,ret0 with
                   | Some id, Some v => Maps.PTree.set id v tx
                   | _, _ => tx
                   end).
iSpecialize ("rguard" $! EK_normal None tx' vx).
set (rho' := construct_rho _ _ _).
iPoseProof ("HR" $! rho' with "[Q F]") as "R".
{ iExists match ret with
       | Some id =>
           match tx !! id with
           | Some old => old
           | None => Vundef
           end
       | None => Vundef
       end; subst rho' tx'; unfold_lift; destruct ret; simpl.
  * destruct ret0.
    2: { clear - TC5 Htc; destruct t0; try contradiction; by spec TC5. }
    destruct TC3 as [TC3 _].
    hnf in TC3; simpl in TC3.
    hnf in TCret.
    destruct ((temp_types Delta) !! i) as [ti|] eqn: Hi; try contradiction.
    destruct (TC3 _ _ Hi) as (vi & Htx & ?); subst. 
    rewrite /get_result1 /eval_id /= /make_tenv /Map.get in Htx |- *; rewrite /lookup /ptree_lookup Maps.PTree.gss Htx.
    rewrite /subst /env_set /= -map_ptree_rel Map.override Map.override_same //; iFrame.
    iSplit; first by iPureIntro; apply tc_val_tc_val'; destruct ti; try (specialize (TC5 eq_refl)).
    rewrite /make_ext_rval.
    destruct ti; try destruct i0, s; try destruct f; try (specialize (TC5 eq_refl)); iFrame; first done; destruct v; contradiction.
  * subst rho; iFrame.
    destruct (eq_dec t0 Tvoid); first by subst.
    destruct ret0; last by destruct t0; contradiction.
    iAssert (∃ v0 : val, ⌜tc_val' t0 v0⌝ ∧ Q x1 (env_set (globals_only (construct_rho (filter_genv psi) vx tx)) ret_temp v0)) with "[Q]" as "?"; last by destruct t0; iFrame.
    iExists v; iSplit; first by iPureIntro; apply tc_val_tc_val'; destruct t0.
    rewrite /make_ext_rval /env_set /=.
    destruct t0; try destruct i, s; try destruct f; try (specialize (TC5 eq_refl)); iFrame; first done; destruct v; contradiction. }
iIntros "!>"; iExists _; iSplit; first done.
assert (tx' = set_opttemp ret (force_val ret0) tx) as Htx'.
{ subst tx'.
  clear - Htc TCret TC5. hnf in Htc, TCret.
  destruct ret0, ret; simpl; auto.
  destruct ((temp_types Delta) !! i); try contradiction.
  destruct t0; try contradiction. spec TC5; auto. inv TC5. }
iSpecialize ("rguard" with "[-]").
{ rewrite proj_frame; iFrame.
  iSplit; [|iSplit].
  * iPureIntro; subst rho rho' tx'.
    destruct ret; last done; destruct ret0; last done.
    rewrite /construct_rho -map_ptree_rel.
    apply guard_environ_put_te'; try done.
    simpl in TCret; intros ? Hi; rewrite Hi in TCret; subst.
    apply tc_val_tc_val'; destruct t; try (specialize (TC5 eq_refl)); done.
  * iSplit; last done.
    rewrite (H _ (make_tenv tx')); first by subst.
    subst rho tx'; rewrite /= /Map.get /make_tenv.
    destruct ret; last auto; destruct ret0; last auto.
    intros j; destruct (eq_dec j i); simpl; subst; auto.
    rewrite Maps.PTree.gso; auto.
  * rewrite - same_glob_funassert'; subst rho rho'; done. }
subst ctl rho'.
rewrite Htx'; by iApply assert_safe_for_external_call.
Qed.

(*Lemma alloc_juicy_variables_resource_decay:
  forall ge rho jm vl rho' jm',
    alloc_juicy_variables ge rho jm vl = (rho', jm') ->
    resource_decay (nextblock (m_dry jm)) (m_phi jm) (m_phi jm') /\
    (nextblock (m_dry jm) <= nextblock (m_dry jm'))%positive.
Proof.
 intros.
 revert rho jm H; induction vl; intros.
 inv H. split. apply resource_decay_refl.
   apply juicy_mem_alloc_cohere. apply Pos.le_refl.
 destruct a as [id ty].
 unfold alloc_juicy_variables in H; fold alloc_juicy_variables in H.
 revert H; case_eq (juicy_mem_alloc jm 0 (@Ctypes.sizeof ge ty)); intros jm1 b1 ? ?.
 pose proof (juicy_mem_alloc_succeeds _ _ _ _ _ H).
 specialize (IHvl _ _ H0).
 symmetry in H1; pose proof (nextblock_alloc _ _ _ _ _ H1).
 destruct IHvl.
 split; [ |  rewrite H2 in H4; lia].
 eapply resource_decay_trans; try eassumption.
 rewrite H2; lia.
 clear - H H1.
 pose proof (juicy_mem_alloc_level _ _ _ _ _ H).
 unfold resource_decay.
 split. repeat rewrite <- level_juice_level_phi; rewrite H0; auto.
 intro loc.
 split.
 apply juicy_mem_alloc_cohere.
 rewrite (juicy_mem_alloc_at _ _ _ _ _ H).
 rewrite Z.sub_0_r.
 destruct loc as [b z]. simpl in *.
 if_tac. destruct H2; subst b1.
 right. right. left. split. apply alloc_result in H1; subst b; lia.
 eauto.
 rewrite <- H0. left. apply resource_at_approx.
Qed.*)

Lemma ge_of_make_args:
    forall s a rho, ge_of (make_args s a rho) = ge_of rho.
Proof.
induction s; intros.
 destruct a; auto.
 simpl in *. destruct a0; auto.
 rewrite <- (IHs a0 rho); auto.
Qed.

Lemma ve_of_make_args:
    forall s a rho, length s = length a -> ve_of (make_args s a rho) = (Map.empty _).
Proof.
induction s; intros.
 destruct a; inv H; auto.
 simpl in *. destruct a0; inv H; auto.
 rewrite <- (IHs a0 rho); auto.
Qed.

Fixpoint make_args' (il: list ident) (vl: list val)  : tenviron :=
  match il, vl with
  | i::il', v::vl' => Map.set i v (make_args' il' vl')
  | _, _ => Map.empty _
  end.

Lemma make_args_eq:  forall il vl, length il = length vl ->
    forall rho,
    make_args il vl rho = mkEnviron (ge_of rho) (Map.empty _) (make_args' il vl).
Proof.
induction il; destruct vl; intros; inv H; simpl.
auto.
unfold env_set.
rewrite IHil; auto.
Qed.

Lemma make_args_close_precondition:
  forall bodyparams args ge tx ve' te' P,
    list_norepet (map fst bodyparams) ->
    bind_parameter_temps bodyparams args tx = Some te' ->
    Forall (fun v : val => v <> Vundef) args ->
    P (filter_genv ge, args)
   ⊢ close_precondition (map fst bodyparams) P
           (construct_rho (filter_genv ge) ve' te').
Proof.
intros *. intros LNR BP VUNDEF.
iIntros "P"; iExists args; iFrame; iPureIntro; repeat (split; auto).
clear - LNR BP VUNDEF.
generalize dependent te'. generalize dependent tx. generalize dependent args.
induction bodyparams; simpl; intros; destruct args; inv BP; simpl; auto.
+ destruct a; discriminate.
+ destruct a. inv LNR. inv VUNDEF. simpl. erewrite <- IHbodyparams by eauto.
  f_equal.
  rewrite (pass_params_ni _ _ _ _ _ H0 H2) /lookup /ptree_lookup Maps.PTree.gss //.
Qed.

(*Lemma after_alloc_block:
 forall phi n F b (Hno : forall ofs : Z, phi @ (b, ofs) = NO Share.bot bot_unreadable),
   app_pred F phi ->
   0 <= n < Ptrofs.modulus ->
   app_pred (F * memory_block Share.top n (Vptr b Ptrofs.zero)) (after_alloc 0 n b phi Hno).
Proof.
intros. rename H0 into Hn.
unfold after_alloc.
match goal with |- context [proj1_sig ?A] => destruct A; simpl proj1_sig end.
rename x into phi2.
destruct a as (? & ? & Hg).
unfold after_alloc' in H1.
destruct (allocate phi
    (fun loc : address =>
      if adr_range_dec (b, 0) (n - 0) loc
      then YES Share.top readable_share_top (VAL Undef) NoneP
      else core (phi @ loc)) nil)
  as [phi3 [phi4  [? [? Hg']]]].
* extensionality loc; unfold compose.
  if_tac. unfold resource_fmap. rewrite preds_fmap_NoneP. reflexivity.
  repeat rewrite core_resource_at.
  rewrite <- level_core.
  apply resource_at_approx.
*
 intros.
 if_tac.
 exists (YES Share.top readable_share_top (VAL Undef) NoneP).
 destruct l as [b0 ofs]; destruct H2.
 subst; rewrite Hno; constructor.
 apply join_unit1; auto.
 exists (phi @ l).
 apply join_comm.
 apply core_unit.
*
reflexivity.
*
eexists; constructor.
*
assert (phi4 = phi2). {
 apply rmap_ext. apply join_level in H2. destruct H2; lia.
 intro loc; apply (resource_at_join _ _ _ loc) in H2.
 rewrite H3 in H2; rewrite H1.
 if_tac.
 inv H2; apply YES_ext; apply (join_top _ _ (join_comm RJ)).
 apply join_comm in H2.
 eapply join_eq; eauto; apply core_unit.
 apply ghost_of_join in H2.
 rewrite <- Hg, Hg' in H2.
 inv H2; auto.
}
subst phi4.
exists phi, phi3; split3; auto.
split.
do 3 red.
rewrite Ptrofs.unsigned_zero.
lia.
rewrite Ptrofs.unsigned_zero.
rewrite memory_block'_eq; try lia.
unfold memory_block'_alt.
rewrite if_true by apply readable_share_top.
intro loc. hnf.
rewrite Z2Nat.id by lia.
if_tac.
exists Undef.
exists readable_share_top.
hnf.
rewrite H3.
rewrite Z.sub_0_r.
rewrite if_true by auto.
rewrite preds_fmap_NoneP.
f_equal.
unfold noat. simpl.
rewrite H3.
rewrite Z.sub_0_r.
rewrite if_false by auto.
apply core_identity.
Qed.

Lemma juicy_mem_alloc_block:
 forall jm n jm2 b F,
   juicy_mem_alloc jm 0 n = (jm2, b) ->
   app_pred F (m_phi jm)  ->
   0 <= n < Ptrofs.modulus ->
   app_pred (F * memory_block Share.top n (Vptr b Ptrofs.zero)) (m_phi jm2).
Proof.
intros.
inv H; simpl m_phi.
apply after_alloc_block; auto.
Qed.

Lemma alloc_juicy_variables_lem2 {CS}:
  forall jm f (ge: genv) ve te jm' (F: mpred)
      (HGG: cenv_sub (@cenv_cs CS) (genv_cenv ge))
      (COMPLETE: Forall (fun it => complete_type cenv_cs (snd it) = true) (fn_vars f))
      (Hsize: Forall (fun var => @Ctypes.sizeof ge (snd var) <= Ptrofs.max_unsigned) (fn_vars f)),
      list_norepet (map fst (fn_vars f)) ->
      alloc_juicy_variables ge empty_env jm (fn_vars f) = (ve, jm') ->
      app_pred F (m_phi jm) ->
      app_pred (F * stackframe_of f (construct_rho (filter_genv ge) ve te)) (m_phi jm').
Proof.
intros.
unfold stackframe_of.
forget (fn_vars f) as vars. clear f.
forget empty_env as ve0.
revert F ve0 jm Hsize H0 H1; induction vars; intros.
simpl in H0. inv H0.
simpl fold_right. rewrite sepcon_emp; auto.
inv Hsize. rename H4 into Hsize'; rename H5 into Hsize.
simpl fold_right.
unfold alloc_juicy_variables in H0; fold alloc_juicy_variables in H0.
destruct a as [id ty].
destruct (juicy_mem_alloc jm 0 (@Ctypes.sizeof ge ty)) eqn:?H.
rewrite <- sepcon_assoc.
inv H.
simpl in COMPLETE; inversion COMPLETE; subst.
rename H7 into COMPLETE'.
rename H4 into COMPLETE_HD.
eapply IHvars; eauto. clear IHvars.
pose proof I.
unfold var_block, eval_lvar.
simpl sizeof; simpl typeof.
simpl Map.get. simpl ge_of.
assert (Map.get (make_venv ve) id = Some (b,ty)). {
 clear - H0 H5.
 unfold Map.get, make_venv.
 assert ((PTree.set id (b,ty) ve0) !! id = Some (b,ty)) by (apply PTree.gss).
 forget (PTree.set id (b, ty) ve0) as ve1.
 rewrite <- H; clear H.
 revert ve1 j H0 H5; induction vars; intros.
 inv H0; auto.
 unfold alloc_juicy_variables in H0; fold alloc_juicy_variables in H0.
 destruct a as [id' ty'].
 destruct (juicy_mem_alloc j 0 (@Ctypes.sizeof ge ty')) eqn:?H.
 rewrite (IHvars _ _ H0).
 rewrite PTree.gso; auto. contradict H5. subst; left; auto.
 contradict H5; right; auto.
}
rewrite H3. rewrite eqb_type_refl.
simpl in Hsize'. unfold sizeof.
rewrite <- (cenv_sub_sizeof HGG); auto.
rewrite prop_true_andp by auto.
assert (0 <= @Ctypes.sizeof ge ty <= Ptrofs.max_unsigned) by (pose proof (@Ctypes.sizeof_pos ge ty); lia).
simpl.
forget (@Ctypes.sizeof ge ty) as n.
clear - H2 H1 H4.
eapply juicy_mem_alloc_block; eauto.
unfold Ptrofs.max_unsigned in H4; lia.
Qed.

Lemma free_list_juicy_mem_ghost: forall m l m', free_list_juicy_mem m l m' ->
  ghost_of (m_phi m') = ghost_of (m_phi m).
Proof.
  induction 1; auto.
  rewrite IHfree_list_juicy_mem, <- H1.
  apply free_juicy_mem_ghost.
Qed.

Lemma alloc_juicy_variables_ghost: forall l ge rho jm,
  ghost_of (m_phi (snd (alloc_juicy_variables ge rho jm l))) = ghost_of (m_phi jm).
Proof.
  induction l; auto; simpl; intros.
  destruct a; simpl.
  rewrite IHl; simpl.
  apply ghost_of_make_rmap.
Qed.*)

Lemma map_snd_typeof_params:
  forall al bl, map snd al = map snd bl -> type_of_params al = type_of_params bl.
Proof.
induction al as [|[? ?]]; destruct bl as [|[? ?]]; intros; inv H; simpl; f_equal; auto.
Qed.

(*Lemma jsafeN_local_step':
  forall {Espec: OracleKind} ge ora s1 m s2 m2,
  cl_step  ge s1 (m_dry m) s2 (m_dry m2) ->
  resource_decay (nextblock (m_dry m)) (m_phi m) (m_phi m2) ->
  level m = S (level m2) /\
   ghost_of (m_phi m2) =ghost_fmap (approx (level m2)) (approx (level m2)) (ghost_of (m_phi m)) ->
  jsafeN (@OK_spec Espec) ge ora s2 m2 ->
  jsafeN (@OK_spec Espec) ge ora s1 m.
Proof.
  intros.
  rename H into Hstep.
  eapply jsafeN_step with
    (m' := m2).
  split3; auto.
  apply Hstep.
  apply jm_fupd_intro, H2; intros.
  eapply necR_safe; eauto.
Qed.*)

Lemma call_cont_idem: forall k, call_cont (call_cont k) = call_cont k.
Proof.
induction k; intros; simpl; auto.
Qed.

Lemma guard_fallthrough_return:
 forall (psi : genv) E (f : function)
   (ctl : cont) (ek : exitkind) (vl : option val)
  (te : temp_env) (ve : env) (rho' : environ)
  (P4 : environ -> mpred),
  call_cont ctl = ctl ->
  (bind_ret vl (fn_return f) P4 rho' -∗
     assert_safe Espec psi E f ve te (exit_cont EK_return vl ctl) rho') ⊢
  (proj_ret_assert (function_body_ret_assert (fn_return f) P4) ek
      vl rho' -∗
   assert_safe Espec psi E f ve te (exit_cont ek vl ctl) rho').
Proof.
intros.
iIntros "Hsafe ret".
destruct ek; try iDestruct "ret" as "[_ []]"; last by iApply "Hsafe"; iFrame.
unfold function_body_ret_assert, proj_ret_assert,
               RA_normal, RA_return.
iDestruct "ret" as (->) "ret"; simpl.
destruct (type_eq (fn_return f) Tvoid).
2:{ destruct (fn_return f); first contradiction; done. }
rewrite e.
iSpecialize ("Hsafe" with "[$]").
rewrite /assert_safe.
iIntros (? Hrho); iSpecialize ("Hsafe" $! _ Hrho).
destruct ctl; try done;
exfalso; clear - H; simpl in H; set (k:=ctl) in *;
unfold k at 1 in H; clearbody k;
induction ctl; try discriminate; eauto.
Qed.

Lemma semax_call_aux2
  E (Delta : tycontext)
  (A : Type)
  (P : A -> argsEnviron -> mpred)
  (Q : A -> environ -> mpred)
  (x : A)
  (F : environ -> mpred)
  (F0 : environ -> mpred)
  (ret : option ident)
  (curf : function)
  (fsig : typesig)
  (cc : calling_convention)
  (a : expr) (bl : list expr) (R : ret_assert)
  (psi : genv)
  (f : function)
  (TCret : tc_fn_return Delta ret (snd fsig))
  (TC5 : snd fsig = Tvoid -> ret = None)
  (H : closed_wrt_modvars (Scall ret a bl) F0)
  (HGG : cenv_sub cenv_cs (genv_cenv psi))
  (COMPLETE : Forall
             (fun it : ident * type => complete_type cenv_cs (snd it) = true)
             (fn_vars f))
  (H17 : list_norepet (map fst (fn_params f) ++ map fst (fn_temps f)))
  (H17' : list_norepet (map fst (fn_vars f)))
  (H18 : fst fsig = map snd (fst (fn_funsig f)) /\
      snd fsig = snd (fn_funsig f))
  vx tx k rho
  (H0 : rho = construct_rho (filter_genv psi) vx tx)
  (TC3 : guard_environ Delta curf rho):
  (∀ rho' : environ,
        ■ ((∃ old : val,
               substopt ret (liftx old) F rho' ∗
               maybe_retval (Q x) (snd fsig) ret rho') -∗
              RA_normal R rho')) -∗
  ▷ rguard Espec psi E Delta curf (frame_ret_assert R F0) k -∗
  ⌜closed_wrt_modvars (fn_body f) (fun _ : environ => F0 rho ∗ F rho)⌝ ∧
  rguard Espec psi E (func_tycontext' f Delta) f
         (frame_ret_assert
            (frame_ret_assert (function_body_ret_assert (fn_return f) (Q x))
                              (stackframe_of' cenv_cs f)) (fun _ : environ => F0 rho ∗ F rho))
         (Kcall ret curf vx tx k).
Proof.
  iIntros "#HR #rguard"; iSplit.
  { iPureIntro; repeat intro; f_equal. }
  iIntros (ek vl te ve) "!>".
  rewrite !proj_frame.
  iIntros "(% & (F & stack & Q) & #fun)".
  iApply (guard_fallthrough_return with "[-Q] Q"); first done.
  iIntros "Q".
  set (rho' := construct_rho _ _ _).
  change (stackframe_of' cenv_cs f rho') with (stackframe_of f rho').
  rewrite /assert_safe.
  iIntros (? _); simpl.
  rewrite stackframe_of_freeable_blocks //.
  set (ctl := Kcall ret curf vx tx k).
  pose (rval := force_val vl).
  iAssert (jsafeN Espec psi E ora (Returnstate rval (call_cont ctl))) with "[-]" as "Hsafe". {
    admit. }
  destruct vl.
  admit.
  + iApply jsafe_step.
    rewrite /jstep_ex.
    iIntros (?) "? !>"; iExists _, _; iSplit.
    iPureIntro; econstructor.
iApply (jsafe_step with "Hsafe").
    econstructor.
; [iIntros (???); iApply (bi.impl_intro_l with "Hsafe"); iIntros "H"|]; iApply jsafe_local_step; [| by iDestruct "H" as "[_ $]" | | iApply "Hsafe"].
    econstructor.

 assert (FL: exists m2, free_list (m_dry jm'')  (Clight.blocks_of_env psi ve) = Some m2). {
    rewrite <- (age_jm_dry H24).
    subst rho'.
    rewrite (sepcon_comm (stackframe_of f _)) in H10.
    repeat rewrite <- sepcon_assoc in H10.
    destruct H10 as [H10 _].
    eapply can_free_list; try eassumption.
    }
 unfold ctl. fold ctl.
 clear Hora ora P.
 fold ctl.
 destruct FL as [m2 FL2].
 assert (H25: ve_of rho' = make_venv ve) by (subst rho'; reflexivity).
 assert (SFFB := stackframe_of_freeable_blocks Delta _ rho' _ ve HGG COMPLETE H17' H25 H5);
   clear HGG COMPLETE.
 clear H25.
 destruct (free_list_juicy_mem_i _ _ _ (F0 rho * F rho * bind_ret vl (fn_return f) (Q ts x) rho') FL2)
 as [jm2 [FL [H21' FL3]]].
 eapply sepcon_derives. apply SFFB. apply derives_refl.
 forget (F0 rho * F rho) as F0F.
 rewrite <- sepcon_assoc.
 rewrite (sepcon_comm (stackframe_of _ _)). rewrite sepcon_assoc.
 destruct H10 as [H22 _].
 eapply pred_nec_hereditary; try apply H22.
 apply laterR_necR. apply age_laterR. apply age_jm_phi; auto.
 subst m2.
 clear dependent a'.
 assert (jsafeN OK_spec psi ora'
             (Returnstate rval (call_cont ctl)) jm2). {
   assert (LATER2': (level jmx > level (m_phi jm2))%nat). {
     apply age_level in H24.
     repeat rewrite <- level_juice_level_phi in *. lia.
    }
   assert (HH1 : forall a' : rmap,
     necR (m_phi jm2) a' ->
     (⌜ guard_environ Delta curf (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx)) ∧
      seplog.sepcon (fun rho0 : environ => ∃ old : val, substopt ret (`old) F rho0 * maybe_retval (Q ts x) (snd fsig) ret rho0) F0
        (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx)) ∧ funassert Delta (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx))) a' ->
     (assert_safe Espec psi curf vx (set_opttemp ret rval tx) (exit_cont EK_normal None k) (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx))) a').
   { intros. hnf in H1.
     assert (Help0: laterM (level (m_phi jm)) (level (m_phi jm2))). {
       clear - LATER2' LATER.
       eapply necR_laterR. apply laterR_necR; eassumption.
       apply later_nat. rewrite <- !level_juice_level_phi in *. lia. }
     specialize (H1 _ Help0 EK_normal None (set_opttemp ret rval tx) vx).
     assert (Help1: (level (m_phi jm2) >= level (m_phi jm2))%nat) by lia.
    destruct H9 as [[? HB] ?].
    assert (fupd (RA_normal R (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx)) * F0 (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx))) a') as Ha'.
    { apply fupd.fupd_frame_r.
      destruct HB as [a1 [a2 [J [A1 A2]]]]; simpl; exists a1, a2; split; auto; split; auto.
      assert (JMX: laterM (m_phi jm) (m_phi jmx)). { constructor. apply age_jm_phi. apply H13. }
      eapply (HR _ _ JMX a1); auto.
      destruct (join_level _ _ _ J) as [-> ?]; auto. apply necR_level in H8; rewrite <- level_juice_level_phi in *; lia. }
    eapply fupd.subp_fupd in H1; [|apply derives_refl].
    eapply assert_safe_fupd, H1; eauto.
    rewrite andp_comm; apply fupd.fupd_andp_corable; [apply corable_funassert|].
    split; auto.
   apply fupd.fupd_andp_prop; split; auto.
    rewrite proj_frame_ret_assert; unfold proj_ret_assert.
    eapply fupd.fupd_mono, Ha'; simpl.
    rewrite prop_true_andp; auto. }
   clear H1.
   specialize (HH1 _ (necR_refl _)). simpl in H5.
   spec HH1; [clear HH1 | ].
   - split; [split |].
    + destruct H10 as [H22 _].
        destruct H18 as [H18 H18b].
        simpl.
        destruct ret; unfold rval; [destruct vl | ].
        *
         assert (tc_val' (fn_return f) v).
           apply tc_val_tc_val'.
           clear - H22; unfold bind_ret in H22; normalize in H22; try contradiction; auto.
         unfold construct_rho. unfold set_opttemp. rewrite <- map_ptree_rel.
         apply guard_environ_put_te'. subst rho; auto.
         intros.
         cut (t = fn_return f). intros. rewrite H9; auto.
         hnf in TCret; rewrite H8 in TCret. subst; auto.
        *
         assert (f.(fn_return)=Tvoid).
         clear - H22; unfold bind_ret in H22; destruct (f.(fn_return)); normalize in H22; try contradiction; auto.
         unfold fn_funsig in H18b. rewrite H1 in H18b. rewrite H18b in TC5. simpl in TC5.
         specialize (TC5 (eq_refl _)); congruence.
        * unfold set_opttemp. rewrite <- H0. auto.
    +
       destruct H10 as [H22a H22b].
       simpl seplog.sepcon.
       rewrite sepcon_comm in H22a|-*.
       rewrite sepcon_assoc in H22a.
       assert (bind_ret vl (fn_return f) (Q ts x) rho' * (F0 rho * F rho)
            ⊢ (maybe_retval (Q ts x) (snd fsig) ret (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx)) *
                   (F0 (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx)) *
                    ∃ old: val, substopt ret (`old) F (construct_rho (filter_genv psi) vx (set_opttemp ret rval tx))))). {
        apply sepcon_derives.
        *
         clear dependent a.
         clear Hora' H6 H7 ora'.
         destruct fsig as [f_params f_ret].
         simpl in H18; destruct H18 as [H18 H18b]; subst rho' f_ret.
         clear H22b VR. clear LATER2' jm2 FL FL2 FL3.
         unfold rval; clear rval.
         unfold bind_ret.
         unfold get_result1. simpl.
         unfold bind_ret.
         destruct vl.
         + 
           unfold maybe_retval.
           destruct ret.
           - unfold get_result1; simpl.
             apply andp_derives.
             ++ apply prop_derives. intros ? ?. simpl. unfold eval_id; simpl.
                rewrite <- map_ptree_rel, Map.gss. simpl. apply H.
             ++ unfold env_set; simpl.
                unfold eval_id; simpl. rewrite <- map_ptree_rel, Map.gss. simpl; trivial.
           - unfold set_opttemp; simpl. unfold env_set; simpl. clear - TC5 H0.
              destruct (fn_return f); simpl; normalize.
             all: exists v; simpl; split; [ intros ? ; apply H | apply H1].
         +
           unfold fn_funsig in TC5. simpl in TC5.
           destruct (fn_return f) eqn:?; try apply FF_derives.
           specialize (TC5 (eq_refl _)). subst ret.
           unfold maybe_retval. apply derives_refl.
        *
          subst rho.
         destruct ret; apply sepcon_derives; auto.
         +
          clear - H.
          apply derives_refl'.
          apply H. intros. destruct (ident_eq i i0).
          subst; left. red. unfold modifiedvars', insert_idset. rewrite PTree.gss; hnf; auto.
          right; unfold Map.get; simpl; unfold make_tenv; simpl.
          rewrite PTree.gso; auto.
        +
          simpl in TCret.
          destruct ((temp_types Delta) !! i) eqn:?; try contradiction.
          subst t.
          destruct TC3 as [[TC3 _] _].
          hnf in TC3; simpl in TC3.
          specialize (TC3 _ _ Heqo).
          destruct TC3 as [old [? _]].
          apply exp_right with old. unfold substopt, subst.
          apply derives_refl'. f_equal.
          unfold env_set, construct_rho.
           f_equal. unfold make_tenv. extensionality j.
          simpl. unfold Map.set. if_tac. subst.
          apply H0. rewrite PTree.gso; auto.
        +
          apply exp_right with Vundef; simpl; auto.
       }
      eapply derives_trans. 3: apply H1. apply derives_refl.
      normalize. intros v. exists v. rewrite <- sepcon_assoc. rewrite sepcon_comm in H8. apply H8.
      eapply free_list_juicy_mem_lem. eauto.
      eapply pred_nec_hereditary.
      apply laterR_necR. apply age_jm_phi in H24. apply age_laterR; eauto.
      eapply sepcon_derives; try apply H22a; auto.
   +
     destruct H10 as [H22a H22b].
     eapply pred_nec_hereditary in H22b.
     2:{  apply laterR_necR. apply age_jm_phi in H24. apply age_laterR; eauto. }
     rewrite VR in H22b; clear - FL H22b. {
      eapply corable_core, H22b. apply corable_funassert.
      clear - FL.
      induction FL; auto.
      rewrite <-IHFL.
      rewrite <- H1.
      rewrite free_juicy_mem_core; auto.
     }
  -
    clear - HH1.
    destruct (level jm2) eqn:H26; try solve [constructor; auto];
    destruct (levelS_age _ _ (eq_sym H26)) as [jm2' [H27 ?]].
    subst n;
    apply jsafeN_step with (c' := State curf Sskip k vx (set_opttemp ret rval tx)) (m' := jm2');
    simpl.
    split; [ rewrite <- (age_jm_dry H27); constructor | ].
    split3;
    [ apply age1_resource_decay; auto | auto
    | apply age1_ghost_of; apply age_jm_phi; auto].
    eapply pred_nec_hereditary in HH1;
     [ | apply laterR_necR; apply age_jm_phi in H27; apply age_laterR; eauto];
    apply assert_safe_jsafe'; auto.
 }
   clear H1.
    destruct H18 as [H18 H18b].
    simpl.
    clear n0 H21.
    destruct vl; intros;
    (eapply jsafeN_local_step' with (m2 := jm2);
     [econstructor; eauto |  .. ]).
    1,5: rewrite (age_jm_dry H24); auto.
    1,4:
    eapply resource_decay_trans;
    [ | | eapply free_list_resource_decay; eauto];
    [ rewrite (age_jm_dry H24); apply Pos.le_refl |
      apply age1_resource_decay ].
    1,2: auto.
    1,3: split; [change (level (m_phi ?a)) with (level a); rewrite <- FL3; apply age_level in H24; lia |].
    1,2:rewrite (free_list_juicy_mem_ghost _ _ _ FL);
      erewrite age1_ghost_of by (eapply age_jm_phi; eauto);
      change (level (m_phi jm'')) with (level jm'');
      rewrite FL3; auto.
      change v with rval; auto.
      change Vundef with rval; auto.
Qed.*)

Lemma tc_eval_exprlist:
  forall {CS'} Delta tys bl rho,
    typecheck_environ Delta rho ->
    tc_exprlist(CS := CS') Delta tys bl rho ⊢
    ⌜tc_vals tys (eval_exprlist tys bl rho)⌝.
Proof.
induction tys; destruct bl; simpl; intros; auto.
unfold tc_exprlist in *; simpl.
unfold typecheck_expr; fold typecheck_expr.
rewrite !denote_tc_assert_andp IHtys // tc_val_sem_cast //.
unfold_lift; auto.
Qed.

Lemma tc_vals_length: forall tys vs, tc_vals tys vs -> length tys = length vs.
Proof.
induction tys; destruct vs; simpl; intros; auto; try contradiction.
destruct H; auto.
Qed.

Lemma eval_exprlist_relate:
  forall CS' (Delta : tycontext) (tys: typelist)
     (bl : list expr) (psi : genv) (vx : env) (tx : temp_env)
     (rho : environ) m,
   typecheck_environ Delta rho ->
   cenv_sub (@cenv_cs CS') (genv_cenv psi) ->
   rho = construct_rho (filter_genv psi) vx tx ->
   mem_auth m ∗ denote_tc_assert (typecheck_exprlist(CS := CS') Delta (typelist2list tys) bl) rho ⊢
   ⌜Clight.eval_exprlist psi vx tx m bl
     tys
     (@eval_exprlist CS' (typelist2list tys) bl rho)⌝.
Proof.
  intros.
  revert bl; induction tys; destruct bl; simpl; intros; iIntros "[Hm H]"; try iDestruct "H" as "[]".
  { iPureIntro; constructor. }
  unfold typecheck_expr; fold typecheck_expr.
  rewrite !denote_tc_assert_andp.
  iDestruct (IHtys with "[$Hm H]") as %?; first by iDestruct "H" as "[_ $]".
  rewrite bi.and_elim_l.
  iDestruct (eval_expr_relate with "[$Hm H]") as %?; first by iDestruct "H" as "[$ _]".
  iDestruct (cast_exists with "H") as %?.
  rewrite typecheck_expr_sound //; iDestruct "H" as (?) "H".
  iDestruct (cop2_sem_cast' with "[$Hm $H]") as %?; iPureIntro.
  econstructor; eauto.
  unfold_lift; congruence.
Qed.

Lemma believe_exists_fundef:
  forall {CS}
    {b : Values.block} {id_fun : ident} {psi : genv} E {Delta : tycontext}
    {fspec: funspec}
  (Findb : Genv.find_symbol (genv_genv psi) id_fun = Some b)
  (H3: (glob_specs Delta) !! id_fun = Some fspec),
  believe(CS := CS) Espec E Delta psi Delta ⊢
  ⌜∃ f : Clight.fundef,
   Genv.find_funct_ptr (genv_genv psi) b = Some f /\
   type_of_fundef f = type_of_funspec fspec⌝.
Proof.
  intros.
  destruct fspec as [[params retty] cc A P Q].
  simpl.
  iIntros "Believe".
  iSpecialize ("Believe" with "[%]").
  { exists id_fun; eauto. }
  iDestruct "Believe" as "[BE|BI]".
  - rewrite /believe_external /=.
    if_tac; last done.
    destruct (Genv.find_funct_ptr psi b) eqn: Hf; last done.
    iExists _; iSplit; first done.
    destruct f as [ | ef sigargs sigret c'']; first done.
    iDestruct "BE" as ((Es & -> & ASD & _)) "(#? & _)"; inv Es.
    rewrite TTL3 //.
  - iDestruct "BI" as (b' fu (? & WOB & ? & ? & ? & ? & wob & ? & ?)) "_"; iPureIntro.
    unfold fn_funsig in *. simpl fst in *; simpl snd in *.
    assert (b' = b) by congruence. subst b'.
    eexists; split; first done; simpl.
    unfold type_of_function; subst.
    rewrite TTL1 //.
Qed.

Lemma eval_exprlist_relate':
  forall CS' (Delta : tycontext) (tys: typelist)
     (bl : list expr) (psi : genv) (vx : env) (tx : temp_env)
     (rho : environ) m tys',
   typecheck_environ Delta rho ->
   cenv_sub (@cenv_cs CS') (genv_cenv psi) ->
   rho = construct_rho (filter_genv psi) vx tx ->
   tys' = typelist2list tys ->
   mem_auth m ∗ denote_tc_assert (typecheck_exprlist(CS := CS') Delta (typelist2list tys) bl) rho ⊢
   ⌜Clight.eval_exprlist psi vx tx m bl
     tys
     (@eval_exprlist CS' tys' bl rho)⌝.
Proof. intros. subst tys'. eapply eval_exprlist_relate; eassumption. Qed.

Lemma tc_vals_Vundef {args ids} (TC:tc_vals ids args): Forall (fun v : val => v <> Vundef) args.
Proof.
generalize dependent ids. induction args; intros. constructor.
destruct ids; simpl in TC. contradiction. destruct TC.
constructor; eauto. intros N; subst. apply (tc_val_Vundef _ H).
Qed.

Lemma semax_call_aux {CS'}
  E (Delta : tycontext) (psi : genv) (ora : OK_ty) (b : Values.block) (id : ident) cc
  A0 P (x : A0) A deltaP deltaQ retty clientparams
  (F0 : environ -> mpred) F (ret : option ident) (curf: function) args (a : expr)
  (bl : list expr) (R : ret_assert) (vx:env) (tx:Clight.temp_env) (k : cont) (rho : environ)

  (Spec: (glob_specs Delta)!!id = Some (mk_funspec (clientparams, retty) cc A deltaP deltaQ))
  (FindSymb: Genv.find_symbol psi id = Some b)

  (Classify: Cop.classify_fun (typeof a) = Cop.fun_case_f (typelist_of_type_list clientparams) retty cc)
  (TCRet: tc_fn_return Delta ret retty)
  (Argsdef: args = @eval_exprlist CS' clientparams bl rho)
  (Hlen : length clientparams = length args)
  (GuardEnv: guard_environ Delta curf rho)
  (Hretty: retty=Tvoid -> ret=None)
  (Closed: closed_wrt_modvars (Scall ret a bl) F0)
  (CSUB: cenv_sub (@cenv_cs CS') (genv_cenv psi))
  (Hrho: rho = construct_rho (filter_genv psi) vx tx)
  (EvalA: eval_expr a rho = Vptr b Ptrofs.zero):

  □ believe Espec E Delta psi Delta -∗
  (▷tc_expr Delta a rho ∧ ▷tc_exprlist Delta clientparams bl rho) ∧
  (▷ (F0 rho ∗ F rho ∗ P x (ge_of rho, args))) -∗
  funassert Delta rho -∗
  □ ▷ ■ (F rho ∗ P x (ge_of rho, args) ={E}=∗
                          ∃ (x1 : A) (F1 : environ -> mpred),
                            (F1 rho ∗ deltaP x1 (ge_of rho, args))
                            ∧ (∀ rho' : environ,
                                 ■ ((∃ old:val, substopt ret (`old) F1 rho' ∗ maybe_retval (deltaQ x1) retty ret rho') -∗
                                    RA_normal R rho'))) -∗
  ▷ <affine> rguard Espec psi E Delta curf (frame_ret_assert R F0) k -∗
   jsafeN Espec psi E ora
     (State curf (Scall ret a bl) k vx tx).
Proof.
  iIntros "#Bel H #fun #HR rguard".
  iDestruct (believe_exists_fundef with "Bel") as %[ff [H16 H16']].
  rewrite <- Genv.find_funct_find_funct_ptr in H16.
  iPoseProof ("Bel" with "[%]") as "Bel'".
  { exists id; eauto. }
  rewrite /jsafeN jsafe_unfold /jsafe_pre.
  iIntros "!>" (?) "(Hm & ?)".
  iRight; iLeft.
  iExists _, _; iSplit.
  { iNext.
    iDestruct "H" as "[H _]".
    destruct GuardEnv.
    iDestruct (eval_expr_relate with "[$Hm H]") as %?; first by iDestruct "H" as "($ & _)".
    rewrite -(@TTL5 clientparams).
    iDestruct (eval_exprlist_relate' with "[$Hm H]") as %Hargs; first done; first by iDestruct "H" as "(_ & $)".
    rewrite TTL5 in Hargs.
    iPureIntro; eapply step_call with (vargs:=args); subst; eauto.
    rewrite EvalA //. }
  rewrite (add_and (_ ∧ _) (▷_)); last by iIntros "H"; iNext; iDestruct "H" as "((_ & H) & _)"; destruct GuardEnv; iApply (tc_eval_exprlist with "H").
  iDestruct "H" as "(H & >%TC8)".
  iDestruct "H" as "(_ & F0 & P)".
  iFrame.
  rewrite closed_wrt_modvars_Scall in Closed.
  iDestruct "Bel'" as "[BE | BI]".
  - (* external call *)
    rewrite -(fupd_intro E (jsafe _ _ _ _ _ _)).
    rewrite EvalA; subst args; iApply (semax_call_external with "BE rguard fun F0 [-]").
    iNext; by iApply "HR".
  - (* internal call *)
    iDestruct "BI" as (b' f (H3a & H3b & COMPLETE & H17 & H17' & Hvars & H18 & H18')) "BI".
    rewrite H3a in EvalA; inv EvalA.
    change (Genv.find_funct psi (Vptr b Ptrofs.zero) = Some (Internal f)) in H3b.
    rewrite H16 in H3b; inv H3b.
    iSpecialize ("BI" with "[%] [%]").
    { intros; apply tycontext_sub_refl. }
    { apply cenv_sub_refl. }
    iNext.
    iMod ("HR" with "P") as (??) "((? & ?) & #post)".
    iSpecialize ("BI" $! x1); rewrite semax_fold_unfold.
    iSpecialize ("BI" with "[%] [Bel] [rguard]").
    { split3; eauto; [apply tycontext_sub_refl | apply cenv_sub_refl]. }
    { done. }
    { iApply semax_call_aux2. }

    spec H19. {
      eapply semax_call_aux2 with (bl:=nil)(a:=Econst_int Int.zero tint)
                                  (Q:=Q)(fsig:=(clientparams,retty)); try apply HR; eauto.
      + apply (ext_join_sub_approx _ (level z)) in H4.
        eapply joins_comm, join_sub_joins_trans; eauto.
        eapply joins_comm, join_sub_joins_trans; eauto.
        eexists; apply ghost_of_join; eauto.
      + rewrite closed_wrt_modvars_Scall; auto.
      + tauto.
      + apply now_later; eapply pred_nec_hereditary; eauto. }

    remember (alloc_juicy_variables psi empty_env jm0 (fn_vars f)) eqn:AJV.
    destruct p as [ve' jm'']; symmetry in AJV.
    destruct (alloc_juicy_variables_e _ _ _ _ _ _ AJV) as [H15 [H20' CORE]].
    assert (MATCH := alloc_juicy_variables_match_venv _ _ _ _ _ AJV).
    assert (H20 := alloc_juicy_variables_resource_decay _ _ _ _ _ _ AJV).
    destruct (build_call_temp_env f args) as [te' H21]; auto.
    { clear - H16' Hargs.
      simpl in H16'. unfold type_of_function in H16'. inv H16'. rewrite <- Hargs.
      clear - H0.
      revert clientparams H0; induction (fn_params f) as [|[? ?]];
        destruct clientparams; simpl; intros; try discriminate; auto.
        inv H0; f_equal; auto. }
    pose proof (age_twin' _ _ _ H20' H13) as [jm''' [_ H20x]].
    apply @jsafeN_step with (c' := State f (f.(fn_body)) ctl ve' te')
                           (m' := jm'''); auto.
    + split; auto.
      * apply step_internal_function.
        apply list_norepet_append_inv in H17; destruct H17 as [H17 [H22 H23]];
          constructor; auto. rewrite <- (age_jm_dry H20x); auto.
      * split.
        -- destruct H20; apply resource_decay_trans with
                             (nextblock (m_dry jm'')) (m_phi jm''); auto.
           apply age1_resource_decay; auto.
        -- split.
           ++ rewrite H20'; apply age_level; auto.
           ++ erewrite <- (alloc_juicy_variables_ghost _ _ _ jm0), AJV; simpl.
              apply age1_ghost_of, age_jm_phi; auto.
    + assert (H22: (level jm2 >= level jm''')%nat)
        by (apply age_level in H13; apply age_level in H20x; lia).
      pose (rho3 := mkEnviron (ge_of rho) (make_venv ve') (make_tenv te')).
      assert (H23: app_pred (funassert Delta rho3) (m_phi jm''')). {
        apply (resource_decay_funassert _ _ (nextblock (m_dry jm0)) _ (m_phi jm'''))
          in Funassert'. 2: apply laterR_necR; apply age_laterR; auto.
        unfold rho3; clear rho3. apply Funassert'.
        rewrite CORE. apply age_core. apply age_jm_phi; auto.
        destruct H20;  apply resource_decay_trans with
                           (nextblock (m_dry jm'')) (m_phi jm''); auto.
        apply age1_resource_decay; auto. }
      specialize (H19 te' ve' _ H22 _ _ (necR_refl _) (ext_refl _)).
      spec H19; [clear H19|]. {
        split; [split |]; auto.
        split; [ | simpl; split; [ | reflexivity]; apply MATCH ].
        - rewrite (age_jm_dry H20x) in H15.
          clear - GuardEnv TC8 H18 H16 H21 H15 H23 H17 H17' H13.
          unfold rho3 in *. simpl in *. destruct H23.
          destruct rho. simpl in *.
          remember (split (fn_params f)). destruct p.
          simpl in *. if_tac in H16; try congruence.
          destruct GuardEnv as [[_ [_ TC5]] _].
          eapply semax_call_typecheck_environ with (jm := jm2); try eassumption.
          + erewrite <- age_jm_dry by apply H13; auto.
          + rewrite snd_split, <- H18; apply TC8.
        - normalize.
          split; auto. unfold rho3 in H23.
          simpl ge_of in H23. auto. unfold bind_args. unfold tc_formals.
          normalize. rewrite <- sepcon_assoc. normalize.
          simpl fst in H18; simpl snd in H18. split.
          + hnf. destruct H18' as [H18b H18']. simpl snd in *.
            subst retty. subst clientparams. clear - TC8 H21 H17. simpl in *.
            match goal with H: tc_vals _ ?A |- tc_vals _ ?B =>
                            replace B with A; auto end.
            rewrite list_norepet_app in H17. destruct H17 as [H17 [_ _]].
            clear - H17 H21. forget (create_undef_temps (fn_temps f)) as te.
            revert  args te te' H21 H17.
            induction (fn_params f); destruct args; intros; auto; try discriminate.
            destruct a; inv H21. destruct a. simpl in H21. inv H17.
            simpl. f_equal. unfold eval_id, construct_rho; simpl.
            inv H21. erewrite pass_params_ni; try eassumption.
            rewrite PTree.gss. reflexivity. eapply IHl; try eassumption.
          + fold rho in H14'.
            forget (F0 rho * F rho) as Frame.
             destruct H18' as [H18b H18']. simpl snd in *. rewrite H18 in *.
             simpl @fst in *. apply (alloc_juicy_variables_age H13 H20x) in AJV.
             forget (fn_params f) as fparams.
             clear - H18 H21 H14' AJV H17 H17' Hvars
                         CSUB COMPLETE H13 ArgsNotVundef.
             assert (app_pred (Frame * close_precondition
                                         (map fst fparams) (deltaP ts x)
                                         (construct_rho (filter_genv psi) ve' te'))
                              (m_phi jm2)). {
               eapply pred_nec_hereditary.
               - apply laterR_necR. apply age_laterR. eapply age_jm_phi. apply H13.
               - eapply sepcon_derives; try apply H14'; auto.
                 eapply make_args_close_precondition; eauto.
                 apply list_norepet_app in H17; intuition. }
             clear H14'.
             subst rho; forget (Frame *
                     close_precondition (map fst fparams) (deltaP ts x)
                                        (construct_rho (filter_genv psi) ve' te')) as
                 Frame2.
             clear - H17' H21 AJV H Hvars CSUB COMPLETE.
             change (stackframe_of' cenv_cs) with stackframe_of.
             eapply alloc_juicy_variables_lem2; eauto.
             unfold var_sizes_ok in Hvars;
               rewrite Forall_forall in Hvars, COMPLETE |- *.
             intros v H0. specialize (COMPLETE v H0). specialize (Hvars v H0).
             rewrite (cenv_sub_sizeof CSUB); auto. }
      replace (level jm2) with (level jm''')
        by (clear - H13 H20x H20'; apply age_level in H13;
            apply age_level in H20x; lia).
      eapply assert_safe_jsafe, H19.
Qed.

Lemma eval_exprlist_length : forall lt le rho, length lt = length le -> length (eval_exprlist lt le rho) = length le.
Proof.
  induction lt; simpl; auto; intros.
  destruct le; inv H; simpl.
  rewrite IHlt //.
Qed.

Lemma semax_call_si:
  forall E Delta (A: Type)
   (P : A -> argsEnviron -> mpred)
   (Q : A -> environ -> mpred)
   (x : A)
   F ret argsig retsig cc a bl
   (TCF : Cop.classify_fun (typeof a) = Cop.fun_case_f (typelist_of_type_list argsig) retsig cc)
   (TC5 : retsig = Tvoid -> ret = None)
   (TC7 : tc_fn_return Delta ret retsig),
  semax Espec E Delta
       (fun rho => (▷(tc_expr Delta a rho ∧ tc_exprlist Delta argsig bl rho)) ∧
           (func_ptr_si E (mk_funspec (argsig,retsig) cc A P Q) (eval_expr a rho) ∗
          (▷(F rho ∗ P x (ge_of rho, eval_exprlist argsig bl rho)))))
         (Scall ret a bl)
         (normal_ret_assert
          (fun rho => (∃ old:val, substopt ret (`old) F rho ∗ maybe_retval (Q x) retsig ret rho))).
Proof.
  intros.
  rewrite semax_unfold; intros.
  rename argsig into clientparams. rename retsig into retty.
  iIntros "#Prog_OK" (???) "[%Closed #rguard]".
  iIntros (tx vx) "!> (%TC3 & (F0 & H) & #fun)".
  assert (TC7': tc_fn_return Delta' ret retty).
  { clear - TC7 TS.
    hnf in TC7|-*. destruct ret; auto.
    destruct ((temp_types Delta) !! i) eqn:?; try contradiction.
    destruct TS as [H _].
    specialize (H i); rewrite Heqo in H. subst t; done. }
  assert (Hpsi: filter_genv psi = ge_of (construct_rho (filter_genv psi) vx tx)) by reflexivity.
  remember (construct_rho (filter_genv psi) vx tx) as rho.
  iAssert (func_ptr_si E (mk_funspec (clientparams, retty) cc A P Q) (eval_expr(CS := CS) a rho)) as "#funcatb".
  { iDestruct "H" as "(_ & $ & _)". }
  rewrite {2}(affine (func_ptr_si _ _ _)) left_id.
  rewrite /func_ptr_si.
  iDestruct "funcatb" as (b EvalA nspec) "[SubClient funcatb]".
  set (args := @eval_exprlist CS clientparams bl rho).
  set (args' := @eval_exprlist CS' clientparams bl rho).
  iAssert (∃ id, ⌜Map.get (ge_of rho) id = Some b /\
         (glob_specs Delta') !! id = Some nspec⌝) with "[]" as "(%id & %RhoID & %SpecOfID)".
  { iDestruct "fun" as "[#FA #FD]".
    destruct nspec; iDestruct ("FD" with "[funcatb]") as %(id & Hid & fs & ?).
    { rewrite /sigcc_at; iExists _, _, _; iApply "funcatb". }
    iExists id; iSplit; first done.
    iDestruct ("FA" with "[%]") as "(% & %Hid' & funcatv)"; first done.
    rewrite Hid' in Hid; inv Hid.
    destruct fs; iDestruct (mapsto_agree with "funcatb funcatv") as %[=]; subst.
    repeat match goal with H : existT ?A _ = existT ?A _ |- _ => apply inj_pair2 in H end; subst; done. }
  destruct nspec as [nsig ncc nA nP nQ].
  iDestruct "SubClient" as "[[%NSC %Hcc] ClientAdaptation]"; subst cc. destruct nsig as [nparams nRetty].
  inversion NSC; subst nRetty nparams; clear NSC.
  simpl fst in *; simpl snd in *.
  assert (typecheck_environ Delta rho) as TC4.
  { clear - TC3 TS.
    destruct TC3 as [TC3 TC4].
    eapply typecheck_environ_sub in TC3; [| eauto].
    auto. }
  rewrite (add_and (_ ∧ _) (▷_)); last by iIntros "H"; iNext; iDestruct "H" as "((_ & H) & _)"; destruct HGG; iApply (typecheck_exprlist_sound_cenv_sub with "H").
  iDestruct "H" as "(H & >%HARGS)".
  fold args in HARGS; fold args' in HARGS.
  rewrite tc_exprlist_sub // tc_expr_sub //.
  rewrite (add_and (_ ∧ _) (▷_)); last by iIntros "H"; iNext; iDestruct "H" as "((_ & H) & _)"; destruct HGG; iApply (tc_exprlist_length with "H").
  iDestruct "H" as "(H & >%LENbl)".
  assert (LENargs: Datatypes.length clientparams = Datatypes.length args).
  { rewrite LENbl eval_exprlist_length //. }
  assert (TCD': tc_environ Delta' rho) by eapply TC3.
  rewrite (add_and (_ ∧ _) (▷_)); last by iIntros "H"; iNext; iDestruct "H" as "((_ & H) & _)"; iApply (tc_eval_exprlist with "H").
  iDestruct "H" as "(H & >%TCargs)"; fold args in TCargs.
  iSpecialize ("ClientAdaptation" $! x (ge_of rho, args)).
  rewrite bi.pure_True.
  2: { clear -TCargs. clearbody args. generalize dependent clientparams.
       induction args; intros.
       - destruct clientparams; simpl in *. constructor. contradiction.
       - destruct clientparams; simpl in *. contradiction. destruct TCargs.
         apply tc_val_has_type in H; simpl. apply IHargs in H0.
         constructor; eauto. }
  rewrite bi.True_and.
  iIntros (? _).
  assert (CSUBpsi:cenv_sub (@cenv_cs CS) psi).
  { destruct HGG as [CSUB' HGG]. apply (cenv_sub_trans CSUB' HGG). }
  destruct HGG as [CSUB HGG].
  rewrite (add_and (_ ∧ _) (▷_)); last by iIntros "H"; iNext; iDestruct "H" as "((H & _) & _)"; iApply (typecheck_expr_sound_cenv_sub with "H").
  iDestruct "H" as "(H & >%Heval_eq)"; rewrite Heval_eq in EvalA.
  subst rho; iApply (@semax_call_aux CS' with "Prog_OK [F0 H] fun [] rguard"); try reflexivity.
  - iCombine "F0 H" as "H"; rewrite bi.sep_and_l; iSplit.
    + rewrite bi.later_and; iDestruct "H" as "[(_ & ?) _]".
      rewrite tc_exprlist_cenv_sub // tc_expr_cenv_sub //.
    + iNext; iDestruct "H" as "[_ $]".
  - iClear "fun funcatb". iIntros "!> !> !>".
    iIntros "(F & P)".
    iMod ("ClientAdaptation" with "P") as (??) "[H #post]".
    iExists x1, (λ rho, F rho ∗ F1); iIntros "!>"; iSplit; first by iDestruct "H" as "($ & $)".
    iIntros (?) "!> (% & F & nQ)"; simpl.
    destruct ret; simpl.
    + iExists old; iDestruct "F" as "($ & F1)".
      iDestruct "nQ" as "($ & nQ)"; iApply "post"; iFrame; by iPureIntro.
    + iExists Vundef; iDestruct "F" as "($ & F1)".
      destruct (type_eq retty Tvoid).
      * subst; iApply "post"; iFrame; by iPureIntro.
      * destruct retty; first contradiction; iDestruct "nQ" as (v ?) "nQ"; iExists v; (iSplit; [by iPureIntro|];
          iApply "post"; iFrame; by iPureIntro).
Qed.

Definition semax_call_alt := semax_call_si.

Require Import VST.veric.semax_conseq.

Lemma semax_call:
  forall E Delta (A: Type)
  (P : A -> argsEnviron -> mpred)
  (Q : A -> environ -> mpred)
  (x : A)
  F ret argsig retsig cc a bl
  (TCF : Cop.classify_fun (typeof a) = Cop.fun_case_f (typelist_of_type_list argsig) retsig cc)
  (TC5 : retsig = Tvoid -> ret = None)
  (TC7 : tc_fn_return Delta ret retsig),
  semax Espec E Delta
       (fun rho => (▷(tc_expr Delta a rho ∧ tc_exprlist Delta argsig bl rho))  ∧
           (func_ptr E (mk_funspec (argsig,retsig) cc A P Q) (eval_expr a rho) ∗
          (▷(F rho ∗ P x (ge_of rho, eval_exprlist argsig bl rho)))))
         (Scall ret a bl)
         (normal_ret_assert
          (fun rho => (∃ old:val, substopt ret (`old) F rho ∗ maybe_retval (Q x) retsig ret rho))).
Proof.
  intros.
  eapply semax_pre, semax_call_si; [|done..].
  intros; rewrite bi.and_elim_r func_ptr_fun_ptr_si //.
Qed.

(*Lemma semax_call_ext {CS Espec}:
   forall (IF_ONLY: False),
     forall Delta P Q ret a tl bl a' bl',
      typeof a = typeof a' ->
      map typeof bl = map typeof bl' ->
      (forall rho,
          ⌜ (typecheck_environ Delta rho) ∧ P rho ⊢
            tc_expr Delta a rho ∧ tc_exprlist Delta tl bl rho ∧
            tc_expr Delta a' rho ∧ tc_exprlist Delta tl bl' rho ∧
            ⌜ (eval_expr a rho = eval_expr a' rho /\
                eval_exprlist tl bl rho = eval_exprlist tl bl' rho)) ->
  semax Espec Delta P (Scall ret a bl) Q ->
  @semax CS Espec Delta P (Scall ret a' bl') Q.
Proof.
intros until 2. intro Hbl. intros.
rewrite semax_unfold in H1|-*.
rename H1 into H2. pose proof I.
intros.
assert (HGpsi: cenv_sub (@cenv_cs CS)  psi).
{ destruct HGG as [CSUB HGG]. apply (cenv_sub_trans CSUB HGG). }
specialize (H2 psi Delta' CS' w TS HGG Prog_OK k F f H3 H4).
intros tx vx; specialize (H2 tx vx).
intros ? ? ? ? ? Hext ?.
specialize (H2 y H5 _ _ H6 Hext H7).
destruct H7 as[[? ?] _].
hnf in H7.
pose proof I.
eapply fupd.fupd_mono, H2.
intros ? Hsafe ?? Hora ???.
specialize (Hsafe ora jm Hora H10).
intros.
spec Hsafe; auto.
spec Hsafe; auto.
simpl in Hsafe.
eapply convergent_controls_jsafe; try apply Hsafe.
reflexivity.
simpl; intros ? ?. unfold cl_after_external. destruct ret0; auto.
reflexivity.
intros.
destruct H8 as [w1 [w2 [H8' [_ ?]]]].
assert (H8'': @extendM rmap _ _ _ _ _ _ w2 a'') by (eexists; eauto). clear H8'.
remember (construct_rho (filter_genv psi) vx tx) as rho.
assert (H7': typecheck_environ Delta rho).
destruct H7; eapply typecheck_environ_sub; eauto.
destruct H7 as [H7 _].
specialize (H0 rho w2 (conj H7' H8)).
destruct H0 as [[[[TCa TCbl] TCa'] TCbl'] [? ?]].
apply (boxy_e _ _ (extend_tc_expr _ _ _) _ _ H8'') in TCa.
apply (boxy_e _ _ (extend_tc_exprlist _ _ _ _) _ _ H8'') in TCbl.
apply (boxy_e _ _ (extend_tc_expr _ _ _) _ _ H8'') in TCa'.
apply (boxy_e _ _ (extend_tc_exprlist _ _ _ _) _ _ H8'') in TCbl'.
(*eapply @denote_tc_resource with (a' := m_phi jm) in TCa; auto.
eapply @denote_tc_resource with (a' := m_phi jm) in TCa'; auto.
eapply @denote_tc_resource with (a' := m_phi jm) in TCbl; auto.
eapply @denote_tc_resource with (a' := m_phi jm) in TCbl'; auto.*)
assert (forall vf, Clight.eval_expr psi vx tx (m_dry jm) a vf
               -> Clight.eval_expr psi vx tx (m_dry jm) a' vf). {
clear - TCa TCa' H7 H7' H0 Heqrho HGG TS HGpsi.
intros.
eapply tc_expr_sub in TCa; [| eauto | eauto].
(* In theory, we might have given up ownership of a relevant location
   in the viewshift from a'' to jm. In practice, if we did,
   surely the evaluation of a would fail too? *)
pose proof (eval_expr_relate _ _ _ _ _ _ jm HGpsi Heqrho H7 TCa).
pose proof (eval_expr_fun H H1). subst vf.
rewrite H0.
eapply eval_expr_relate; eauto.
}
assert (forall tyargs vargs,
             Clight.eval_exprlist psi vx tx (m_dry jm) bl tyargs vargs ->
             Clight.eval_exprlist psi vx tx (m_dry jm) bl' tyargs vargs). {
clear - IF_ONLY TCbl TCbl' H13 Hbl H7' Heqrho HGpsi.
revert bl bl' H13 Hbl TCbl TCbl'; induction tl; destruct bl, bl'; simpl; intros; auto;
 try (clear IF_ONLY; contradiction).
 unfold tc_exprlist in TCbl,TCbl'. simpl in TCbl, TCbl'.
repeat rewrite denote_tc_assert_andp in TCbl, TCbl'.
destruct TCbl as [[TCe ?] ?].
destruct TCbl' as [[TCe0 ?] ?].
inversion H; clear H. subst bl0 tyargs vargs.
inversion Hbl; clear Hbl. rewrite <- H5 in *.
pose proof (eval_expr_relate _ _ _ _ _ _ _ HGpsi Heqrho H7' TCe).
pose proof (eval_expr_fun H H6).
repeat rewrite <- cop2_sem_cast in *.
unfold force_val in H1.
rewrite H9 in *.
subst.
clear H.
unfold_lift in H13.
inv H13.
specialize (IHtl _ _ H9 H8); clear H9 H8.
assert (exists v1, Clight.eval_expr psi vx tx (m_dry jm) e0 v1 /\
                             Cop.sem_cast v1 (typeof e0) ty (m_dry jm) = Some v2). {
 clear - IF_ONLY H4 H6 H7 TCe H0 TCe0 H2 HGpsi H7'.
   contradiction IF_ONLY.  (* still some work to do here *)
}
destruct H as [v1 [? ?]];
econstructor; try eassumption.
eapply IHtl; eauto.
}
destruct H12; split; auto.
inv H12.
eapply step_call; eauto.
rewrite <- H; auto.
destruct H25 as [H25 | H25]; inv H25.
destruct H25 as [H25 | H25]; inv H25.
Qed.*)

Definition cast_expropt {CS} (e: option expr) t : environ -> option val :=
 match e with Some e' => `Some (@eval_expr CS (Ecast e' t))  | None => `None end.

Definition tc_expropt {CS} Delta (e: option expr) (t: type) : environ -> mpred :=
   match e with None => `⌜(t=Tvoid)
                     | Some e' => @denote_tc_assert CS (typecheck_expr Delta (Ecast e' t))
   end.

Lemma tc_expropt_char {CS} Delta e t: @tc_expropt CS Delta e t =
                                      match e with None => `⌜(t=Tvoid)
                                              | Some e' => @tc_expr CS Delta (Ecast e' t)
                                      end.
Proof. reflexivity. Qed.

Lemma RA_return_castexpropt_cenv_sub {CS CS'} (CSUB: cenv_sub (@cenv_cs CS) (@cenv_cs CS')) Delta rho (D:typecheck_environ Delta rho) ret t:
  @tc_expropt CS Delta ret t rho ⊢ ⌜(@cast_expropt CS ret t rho = @cast_expropt CS' ret t rho).
Proof.
  intros w W. simpl. unfold tc_expropt in W. destruct ret.
  + simpl in W. simpl.
    unfold force_val1, liftx, lift; simpl. rewrite denote_tc_assert_andp in W. destruct W.
    rewrite <- (typecheck_expr_sound_cenv_sub CSUB Delta rho D w); trivial.
  + simpl in W; subst. simpl; trivial.
Qed.

Lemma tc_expropt_cenv_sub {CS CS'} (CSUB: cenv_sub (@cenv_cs CS) (@cenv_cs CS')) Delta rho (D:typecheck_environ Delta rho) ret t:
  @tc_expropt CS Delta ret t rho ⊢ @tc_expropt CS' Delta ret t rho.
Proof.
  intros w W. simpl. rewrite  tc_expropt_char in W; rewrite tc_expropt_char.
  specialize (tc_expr_cenv_sub CSUB); intros.
  destruct ret; trivial; auto.
Qed.

Lemma tc_expropt_cspecs_sub {CS CS'} (CSUB: cspecs_sub CS CS') Delta rho (D:typecheck_environ Delta rho) ret t:
  @tc_expropt CS Delta ret t rho ⊢ @tc_expropt CS' Delta ret t rho.
Proof.
  destruct CSUB as [CSUB _].
  apply (@tc_expropt_cenv_sub _ _ CSUB _ _ D).
Qed.

Lemma tc_expropt_sub {CS} Delta Delta' rho (TS:tycontext_sub Delta Delta') (D:typecheck_environ Delta rho) ret t:
  @tc_expropt CS Delta ret t rho ⊢ @tc_expropt CS Delta' ret t rho.
Proof.
  intros w W. rewrite  tc_expropt_char in W; rewrite tc_expropt_char.
  specialize (tc_expr_sub _ _ _ TS); intros.
  destruct ret; [ eapply H; assumption | trivial].
Qed.

(*Lemma val_casted_sem_cast : forall v t1 t2, val_casted (force_val (sem_cast t1 t2 v)) t2.
Proof.
  intros; unfold sem_cast.
  destruct (classify_cast t1 t2) eqn: Hclass; simpl; auto.
25: { Search val_casted *)

Lemma  semax_return {CS Espec}:
   forall Delta R ret,
      @semax CS Espec Delta
                (fun rho => tc_expropt Delta ret (ret_type Delta) rho ∧
                             RA_return R (cast_expropt ret (ret_type Delta) rho) rho)
                (Sreturn ret)
                R.
Proof.
  intros.
  hnf; intros.
  rewrite semax_fold_unfold.
  intros psi Delta' CS'.
  apply prop_imp_i. intros [TS [CSUB HGG]].
  replace (ret_type Delta) with (ret_type Delta')
    by (destruct TS as [_ [_ [? _]]]; auto).
  apply derives_imp.
  clear n.
  intros w ? k F f.
  intros ? w' ? Hext H1.
  clear H.
  clear w H0.
  rename w' into w.
  destruct H1.
  do 3 red in H.
  intros te ve.
  intros n ? ? w' ? Hext' ?.
  assert (necR w (level w')) as H4.
  {
    apply nec_nat.
    apply necR_level in H2.
    apply Nat.le_trans with (level n); auto.
    apply ext_level in Hext' as <-; auto.
  }
  apply (pred_nec_hereditary _ _ _ H4) in H0.
  clear w n Hext H2 H1 H4.
  destruct H3 as [[H3 ?] ?].
  pose proof I.
  remember ((construct_rho (filter_genv psi) ve te)) as rho.
  assert (H1': ((F rho * proj_ret_assert R EK_return (cast_expropt ret (ret_type Delta') rho) rho))%pred w').
  {
    eapply sepcon_derives; try apply H1; auto.
    intros w [W1 W2]. simpl in H3; destruct H3 as [TCD' _].
    assert (TCD: typecheck_environ Delta rho) by (eapply typecheck_environ_sub; eauto).
    apply (tc_expropt_sub _ _ _ TS) in W1; trivial.
    rewrite <- (RA_return_castexpropt_cenv_sub CSUB Delta' rho TCD' _ _ _ W1); trivial.
  }
  assert (TC: (tc_expropt Delta ret (ret_type Delta') rho) w').
  {
    simpl in H3; destruct H3 as [TCD' _].
    clear - H1 TCD' TS CSUB Espec.
    assert (TCD: typecheck_environ Delta rho) by (eapply typecheck_environ_sub; eauto); clear TS.
    destruct H1 as [w1 [w2 [? [? [? ?]]]]].
    apply (tc_expropt_cenv_sub CSUB) in H1; trivial.
    rewrite tc_expropt_char; rewrite tc_expropt_char in H1. destruct ret; [ |trivial].
    apply (boxy_e _ _ (extend_tc_expr _ _ _) w2); auto.
    exists w1; auto.
  }
  clear H1; rename H1' into H1.
  specialize (H0 EK_return (cast_expropt ret (ret_type Delta') rho) te ve).
  specialize (H0 _ (Nat.le_refl _) _ _ (necR_refl _) (ext_refl _)).
  spec H0.
  {
    rewrite <- Heqrho.
    rewrite proj_frame_ret_assert.
    split; auto.
    split; auto.
    rewrite seplog.sepcon_comm; auto.
  }
  unfold tc_expropt in TC; destruct ret; simpl in TC.
  + intros ?? Hora ??.
    rename H0 into Hsafe.
    specialize (Hsafe ora jm Hora (eq_refl _) H6).
    intros. subst w'.
    specialize (Hsafe LW e (eval_expr e rho)).
    destruct H3 as [H3a [H3b H3c]].
    rewrite H3c in Hsafe,TC.
    rewrite denote_tc_assert_andp in TC; destruct TC as [?TC ?TC].
    spec Hsafe.
    eapply eval_expr_relate; eauto.
    eapply tc_expr_sub; try eassumption.
    eapply typecheck_environ_sub; try eassumption.
    spec Hsafe. {
    rewrite cop2_sem_cast'; auto.
    2:{ eapply typecheck_expr_sound; eauto.
    eapply tc_expr_sub; try eassumption.
    eapply typecheck_environ_sub; try eassumption.
    }
    eapply cast_exists; eauto.
    eapply tc_expr_sub; try eassumption.
    eapply typecheck_environ_sub; try eassumption.
   }
    clear - Hsafe.
    apply jm_fupd_intro'.
    eapply convergent_controls_jsafe; try apply Hsafe; auto.
    intros ? ? [? ?]; split; auto.
    inv H.
    1,3: destruct H9; discriminate.
    rewrite call_cont_idem.
    econstructor; eauto.
  + intros ?? Hora ???.
    rename H0 into Hsafe.
    specialize (Hsafe ora jm Hora (eq_refl _) H6 LW).
     simpl in Hsafe.
    apply jm_fupd_intro'.
    eapply convergent_controls_jsafe; try apply Hsafe; auto.
    intros.
    destruct H0; split; auto.
    inv H0.
    1,3: destruct H16; discriminate.
    rewrite call_cont_idem.
    econstructor; eauto.
Qed.
