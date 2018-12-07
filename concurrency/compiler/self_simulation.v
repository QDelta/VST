Require Import Coq.omega.Omega.
Require Import compcert.cfrontend.Clight.
Require Import compcert.common.Events.
Require Import compcert.common.Globalenvs.
Require Import compcert.lib.Maps.
Require Import compcert.common.Memory.
Require Import compcert.common.Values.
Require Import compcert.lib.Coqlib.
Require Import compcert.common.Smallstep.


Require Import VST.sepcomp.semantics.
Require Import VST.sepcomp.event_semantics.
Require Import VST.concurrency.common.semantics.
Require Import VST.concurrency.common.permissions.
Require Import VST.concurrency.lib.tactics.

Require Import VST.concurrency.compiler.mem_equiv.
Require Import VST.concurrency.lib.setoid_help.
Require Import Coq.Classes.Morphisms.

Set Bullet Behavior "Strict Subproofs".



(*Self simulations say that a program has equivalent executions 
  in equivalent memories. 
  - Equivalent memories: VISIBLE locations are injected 
    one to one (same values and permissions).
  - Equivalent executions: the executions have equivalent memories and
    none visible locations are unchanged (in the execution).  
 *)

Section SelfSim.

  Variable Sem: semantics.
  
  (*Separate state and memory*)
  Variable core: Type.
  Variable state_to_memcore: state Sem -> (core * Mem.mem).
  Variable memcore_to_state: core -> Mem.mem -> state Sem.
  Hypothesis state_to_memcore_correct:
    forall c m, state_to_memcore (memcore_to_state c m) = (c,m).
  Hypothesis memcore_to_state_correct: forall s c m,
   state_to_memcore  s = (c,m) -> s = memcore_to_state c m.
  
  
  (*extension of a mem_injection 
  (slightly stengthens the old inject_separated - LENB: not sure you need the stronger prop*)
  Definition is_ext (f1:meminj)(nb1: positive)(f2:meminj)(nb2:positive) : Prop:=
    forall b1 b2 ofs,
      f2 b1 = Some (b2, ofs) ->
      f1 b1 = None -> 
      (ofs = 0 /\ ~ Plt b1 nb1 /\  ~ Plt b2 nb2).
  
  (*The code is also injected*)
  Variable code_inject: meminj -> core -> core -> Prop.
  Variable code_inj_incr: forall c1 mu c2 mu',
      code_inject mu c1 c2 ->
      inject_incr mu mu' ->
      code_inject mu' c1 c2.
  
  (*The current permisions OF THIS THREAD are unchanged! *)
  (*This is slightly stronger than Mem.inject/mi_inj which allows
    permissions to grow (on compilation). *)
  (*also it could be restricted to take only the Cur permissions*)
  (*NEVERMIND... BOTH FOLLOW from Mem.inject!*)
  Definition perm_inject1 (f:meminj)(m1:mem)(m2:mem): Prop:=
    forall b1 b2 delta,
      f b1 = Some (b2, delta) ->
      forall ofs p,
        Mem.perm m1 b1 (ofs ) Cur p  ->
        Mem.perm m2 b2 (ofs + delta) Cur p.
  
  Definition perm_inject2 (f:meminj)(m1:mem)(m2:mem): Prop:=
    forall b1 b2 delta,
      f b1 = Some (b2, delta) ->
      forall ofs p,
        Mem.perm m2 b2 (ofs + delta) Cur p ->
        Mem.perm m1 b1 (ofs ) Cur p \/ ~ Mem.perm m1 b1 ofs Cur Nonempty.

  (* The injection maps all visible locations*)
  Definition perm_image_old (f:meminj)(m1:mem)(m2:mem): Prop:=
    forall b1 ofs,
      Mem.perm m1 b1 ofs Cur Nonempty ->
    exists b2 delta,
      f b1 = Some (b2, delta).
  
  Definition perm_image (f:meminj) (a1: access_map): Prop:=
    forall b1 ofs,
      Mem.perm_order' (a1 !! b1 ofs) (Nonempty) ->
    exists b2 delta,
      f b1 = Some (b2, delta).

  (* The injection maps to every visible location *)
  Definition perm_preimage_old (f:meminj)(m1:mem)(m2:mem): Prop:=
    forall b2 ofs_delta,
      Mem.perm m2 b2 ofs_delta Cur Nonempty ->
    exists b1 delta ofs,
      f b1 = Some (b2, delta) /\
      Mem.perm m1 b1 ofs Cur Nonempty /\
      ofs_delta = ofs + delta.
  Definition perm_preimage (mu:meminj) (a1 a2: access_map):=
    forall b2 ofs_delt,
      Mem.perm_order' (a2 !! b2 ofs_delt) (Nonempty) ->
      exists b1 ofs delt,
        mu b1 = Some (b2, delt) /\
        ofs_delt = ofs + delt /\
        a1 !! b2 ofs_delt = a2 !! b1 ofs.
  
  Global Instance perm_preimage_setoid:
    Proper (Logic.eq ==> access_map_equiv ==> access_map_equiv ==> iff)
           perm_preimage.
  Proof.
    proper_iff. proper_intros; subst.
    unfold perm_preimage in *; intros ?? HH.
    rewrite <- H1 in HH.
    eapply H2 in HH.
    destruct HH as (?&?&?&?&?&?); subst.
    do 3 econstructor. repeat (split; eauto).
    rewrite <- H1, <- H0; auto.
  Qed.

  Record match_mem (f: meminj) (m1:mem) (m2:mem): Prop:=
    { minject: Mem.inject f m1 m2 
    ; pimage: perm_image f (getCurPerm m1) 
    ; ppreimage: perm_preimage f (getCurPerm m1) (getCurPerm m2)
    }.
   
  Record match_self (f: meminj) (c1:core) (m1:mem) (c2:core) (m2:mem): Prop:=
    { cinject: code_inject f c1 c2
    ; matchmem: match_mem f m1 m2 
    }.

  
  Record same_visible (m1 m2: mem):=
    { same_cur:
        forall b ofs p,
          (Mem.perm m1 b ofs Cur p <->
                Mem.perm m2 b ofs Cur p);
      same_visible12:
        forall b ofs,
          Mem.perm m1 b ofs Cur Readable ->
          (Maps.ZMap.get ofs (Maps.PMap.get b (Mem.mem_contents m1))) =
          (Maps.ZMap.get ofs (Maps.PMap.get b (Mem.mem_contents m2)));
      same_visible21:
        forall b ofs,
          Mem.perm m2 b ofs Cur Readable ->
          (Maps.ZMap.get ofs (Maps.PMap.get b (Mem.mem_contents m1))) =
          (Maps.ZMap.get ofs (Maps.PMap.get b (Mem.mem_contents m2)));
    }.



  Lemma all_order_eq:
    forall a b, (forall p, Mem.perm_order' a p <->  Mem.perm_order' b p) <-> a = b.
  Proof.
    clear.
    intros. destruct a, b; auto.
    4: tauto.
    3: { simpl; split; intros; try congruence.
         specialize (H Nonempty).
         destruct H as [_ HH].
         contradict HH. apply perm_any_N. }
    
    2: { simpl; split; intros; try congruence.
         specialize (H Nonempty).
         destruct H as [ HH _].
         contradict HH. apply perm_any_N. }

    intros; split.
    - intros.
      dup H as H'.
      specialize (H p ); destruct H as [H _].
      specialize (H ltac:(simpl; apply perm_refl)).
      specialize (H' p0); destruct H' as [_ H'].
      specialize (H' ltac:(simpl; apply perm_refl)).
      simpl in *.
      destruct p, p0; inversion H; inversion H'; auto.
    - intros H; invert H; intros; auto. reflexivity.
  Qed.
    
  Lemma match_source_forward:
    forall mu c1 m1 c2 m2,
      match_self mu c1 m1 c2 m2 ->
      forall mu' m1' m2',
        inject_incr mu mu' ->
        Mem.inject mu' m1' m2' ->
        same_visible m1 m1' ->
        same_visible m2 m2' ->
        match_self mu' c1 m1' c2 m2'.
  Proof.
  intros ? ? ? ? ? MATCH ? ? ? INCR INJ VIS1 VIS2.
  constructor.
  - eapply code_inj_incr; eauto; apply MATCH. 
  - inv MATCH.
    split; trivial.
    * (*perm_image*) (*Easy ... use lemmas to simplify same_visible*)
      intros b1 ofs PERM.
      assert (PERM':Mem.perm m1' b1 ofs Cur Nonempty).
      { rewrite getCurPerm_correct in *; auto. }
      apply VIS1 in PERM'.
      pose proof (pimage _ _ _ matchmem0 b1 ofs); unfold perm_image in *.
      rewrite getCurPerm_correct in H.
      eapply H in PERM'; eauto.
      destruct PERM' as (? & ? & ?).
      do 2 eexists; eapply INCR; eauto.
    * (*Pre_image*) (*Easy ... use lemmas to simplify same_visible*)
      intros b2 ofs_delta PERM.
      assert (PERM':Mem.perm m2' b2 ofs_delta Cur Nonempty).
      { rewrite getCurPerm_correct in *; auto. }
      apply VIS2 in PERM'.
      pose proof (ppreimage _ _ _ matchmem0 b2 ofs_delta).
      rewrite getCurPerm_correct in H.
      eapply H in PERM'; eauto.
      destruct PERM' as (? & ? & ? & ? & ? & ?).
      do 3 eexists; repeat split; try eapply INCR; eauto.
      repeat rewrite getCurPerm_correct in *.
      repeat unfold permission_at in *.
      pose proof (same_cur _ _ VIS1 b2 ofs_delta) as HH1.
      pose proof (same_cur _ _ VIS2 x x0) as HH2.
      unfold Mem.perm in *.
      etransitivity. etransitivity.
      symmetry.
      1,3: eapply all_order_eq.
      eapply HH1.
      eapply HH2.
      eauto.
  Qed.

End SelfSim.
Arguments match_self {core}.

Section SelfSimulation.

  Variable state:Type.
  Variable Sem: semantics.CoreSemantics state mem.
  Variable state_to_memcore: state -> (state * Mem.mem).
  Variable memcore_to_state: state -> Mem.mem -> state.
  Notation get_core s:= (fst (state_to_memcore s)). 
  Notation get_mem s:= (snd (state_to_memcore s)). 


  Import Integers.
  Import Ptrofs.

  
  Definition self_preserves_atx_inj {s m} (Sem:semantics.CoreSemantics s m) match_states:=
    forall (j:meminj) s1 m1 s2 m2,
      match_states j s1 m1 s2 m2 ->
      forall f args,
        at_external Sem s1 m1 = Some (f,args) ->
        exists args',
          at_external Sem s2 m2 = Some (f,args') /\
          Val.inject_list j args args'.
  
 Record self_simulation: Type :=
    { code_inject: meminj -> state -> state -> Prop;
      code_inj_incr: forall c1 mu c2 mu',
          code_inject mu c1 c2 ->
          inject_incr mu mu' ->
          code_inject mu' c1 c2;
      ssim_diagram: forall f t c1 m1 c2 m2,
        match_self code_inject f c1 m1 c2 m2 ->
        forall c1' m1',
          semantics.corestep Sem c1 m1  c1' m1' ->
          exists c2' f' t' m2',
          semantics.corestep Sem c2 m2  c2' m2'  /\
          match_self code_inject f' c1' m1' c2' m2' /\
          inject_incr f f' /\
          is_ext f (Mem.nextblock m1) f' (Mem.nextblock m2) /\
          Events.inject_trace f' t t'
      ; ssim_external: forall c1 c2 m1 m2 j b1 ofs func_name, 
        code_inject j c1 c2 ->
        Mem.inject j m1 m2 ->
        semantics.at_external Sem c1 m1  =  
        Some (func_name, Vptr b1 ofs :: nil) ->
        exists b2 delt,
        j b1 = Some (b2, delt) /\
        semantics.at_external Sem c2 m2 =  
        Some (func_name, Vptr b2 (add ofs (repr delt)) :: nil)
      ; ssim_preserves_atx:
          self_preserves_atx_inj Sem (match_self code_inject)
    }. 

End SelfSimulation. 



