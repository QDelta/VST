(* Main File putting all together. *)

From mathcomp.ssreflect Require Import ssreflect ssrbool ssrnat ssrfun eqtype seq fintype finfun.
Set Implicit Arguments.

Require Import compcert.common.Globalenvs.

Require Import compcert.cfrontend.Clight.
Require Import compcert.common.Memory.
Require Import VST.concurrency.juicy.erasure_safety.

Require Import VST.concurrency.compiler.concurrent_compiler_safety_proof.
Require Import VST.concurrency.compiler.sequential_compiler_correct.

Require Import VST.concurrency.sc_drf.mem_obs_eq.
Require Import VST.concurrency.sc_drf.x86_inj.
Require Import VST.concurrency.sc_drf.x86_safe.
Require Import VST.concurrency.sc_drf.executions.
Require Import VST.concurrency.sc_drf.spinlocks.
Require Import compcert.lib.Coqlib.
Require Import VST.concurrency.lib.tactics.

Require Import VST.concurrency.common.threadPool.
Require Import VST.concurrency.common.erased_machine.
Require Import VST.concurrency.common.HybridMachineSig.

Require Import VST.concurrency.compiler.concurrent_compiler_simulation_definitions.
Require Import VST.concurrency.main_definitions. Import main_definitions.

Set Bullet Behavior "Strict Subproofs".
Set Nested Proofs Allowed.
Section Main.
         Context {CC_correct: CompCert_correctness}
          {Args: ThreadSimulationArguments}.
  (*Import the *)
  (*Import the safety of the compiler for concurrent programs*)
  
  (* Module ConcurCC_safe:= (SafetyStatement CC_correct). *)
  (*Module ConcurCC_safe := (Concurrent_Safety CC_correct Args).
  Import ConcurCC_safe. *)

  (*Importing the definition for ASM semantics and machines*)
  Import dry_context.AsmContext.

  (*Use a section to contain the parameters.*)
  Section MainTheorem.
    Import semax_to_juicy_machine.
  (*Assumptions *)
  Context (CPROOF : semax_to_juicy_machine.CSL_proof).
  Context (program_proof : CSL_prog CPROOF = C_program).
  Definition main_ident_src:= Ctypes.prog_main C_program.
  Definition main_ident_tgt:= AST.prog_main Asm_program.
  Context (fb: positive).
  Context (main_symbol_source : Genv.find_symbol (Clight.globalenv C_program) main_ident_src = Some fb).
  Context (main_symbol_target : Genv.find_symbol (Genv.globalenv Asm_program) main_ident_tgt = Some fb).
  Definition Main_ptr:= Values.Vptr fb Integers.Ptrofs.zero.
  Context (compilation : CompCert_compiler C_program = Some Asm_program).
  
  Context (asm_genv_safe: Asm_core.safe_genv
                            (@x86_context.X86Context.the_ge Asm_program))
          (Hextern: single_thread_simulation_proof.Asm_externals_have_events Asm_g).
  Instance SemTarget : Semantics:= @x86_context.X86Context.X86Sem Asm_program asm_genv_safe.
  Existing Instance X86Inj.X86Inj.

  Variable init_mem_wd:
    forall m,
      Genv.init_mem Asm_program = Some m ->
      mem_obs_eq.MemoryWD.valid_mem m /\
      mem_obs_eq.CoreInjections.ge_wd (Renamings.id_ren m) semantics.the_ge.
        
  (* This should be instantiated:
     it says initial_Clight_state taken from CPROOF, is an initial state of CompCert.
   *)
  
  Context (CPROOF_initial:
             entry_point (Clight.globalenv C_program)
                                (erasure_safety.init_mem CPROOF)
                                (Clight_safety.initial_Clight_state CPROOF)
                                Main_ptr nil).

 (* MOVE THIS TO ANOTHER FILE *)
  Lemma CPROOF_initial_mem:  Genv.init_mem (Ctypes.program_of_program C_program) = Some (erasure_safety.init_mem CPROOF).
  Proof.
    unfold erasure_safety.init_mem, semax_to_juicy_machine.init_mem, 
    semax_initial.init_m, semax_to_juicy_machine.prog, Ctypes.program_of_program.
    rewrite <- program_proof.
    
  clear - program_proof.
  pose proof (semax_to_juicy_machine.init_mem_not_none CPROOF) as H.
  unfold Ctypes.program_of_program in H.
  match goal with
      |- ?LHS = ?RHS => destruct RHS eqn:HH
  end; inversion HH; clear HH. revert H1.
  destruct_sig; simpl; auto.
  Qed. 

  (*Safety from CSL to Coarse Asm*)
  Definition SemSource p:= (ClightSemanticsForMachines.ClightSem (Clight.globalenv p)).
  Definition asm_concursem m:=
    (HybridMachineSig.HybridMachineSig.ConcurMachineSemantics
       (Sem:=SemTarget)
       (ThreadPool:= threadPool.OrdinalPool.OrdinalThreadPool(Sem:=SemTarget))
       (HybridMachine:=concurrent_compiler_safety.TargetHybridMachine)
       (machineSig:= HybridMachine.DryHybridMachine.DryHybridMachineSig) m).
  Definition asm_init_machine:=
    machine_semantics.initial_machine (asm_concursem (Genv.init_mem Asm_program)).
  (* Context {SW : Clight_safety.spawn_wrapper CPROOF}. *)
  
  Lemma CSL2CoarseAsm_safety:
    forall U,
    exists init_mem_target init_mem_target' init_thread_target,
      let res_target := permissions.getCurPerm init_mem_target' in
      let res:=(res_target, permissions.empty_map) in
  let init_tp_target :=
      threadPool.ThreadPool.mkPool
        (Sem:=SemTarget)
        (resources:=erasure_proof.Parching.DR)
        (Krun init_thread_target)
      res in
  let init_MachState_target := (U, nil, init_tp_target) in  
      asm_init_machine (Some res) init_mem_target init_tp_target init_mem_target' Main_ptr nil /\
  forall n,
    HybridMachineSig.HybridMachineSig.HybridCoarseMachine.csafe
      (ThreadPool:=threadPool.OrdinalPool.OrdinalThreadPool
                     (Sem:=SemTarget))
      (machineSig:= HybridMachine.DryHybridMachine.DryHybridMachineSig)
      init_MachState_target init_mem_target' n.
  Proof.
    intros.
    assert(compilation':= compilation).  
    pose proof (ConcurrentCompilerSafety asm_genv_safe compilation' asm_genv_safe Hextern) as H.
    unfold concurrent_compiler_safety.concurrent_simulation_safety_preservation in *.
    specialize (H U (erasure_safety.init_mem CPROOF) (erasure_safety.init_mem CPROOF) (Clight_safety.initial_Clight_state CPROOF) Main_ptr nil).
    rewrite <- program_proof in *.

    (*The following matches can be replaced with an [exploit]*)
    match type of H with
      | ?A -> _ => cut A
    end.
    intros HH; specialize (H HH);
    match type of H with
      | ?A -> _ => cut A
    end.
    intros HH'; specialize (H HH');
      match type of H with
      | ?A -> _ => cut A
      end.
    intros HH''; specialize (H HH'').
    - destruct H as (mem_t& mem_t' & thread_target & INIT_mem & INIT & SAFE).
      exists mem_t, mem_t', thread_target; split (*;[|split] *).
      + eauto. (*Initial memory*)
      + eapply SAFE.
    - intros. eapply Clight_initial_safe; auto.
    - clear H. split; eauto; econstructor; repeat (split; try reflexivity; eauto).
    - rewrite program_proof; apply CPROOF_initial_mem.
  Qed.

  Notation sc_execution := (@Executions.fine_execution _ BareDilMem BareMachine.resources
                                            BareMachine.BareMachineSig).
  Theorem CSL2FineBareAsm_safety:
    forall U,
    exists (init_mem_target init_mem_target':Memory.mem) init_thread_target,
      let init_tp_target :=
          threadPool.ThreadPool.mkPool
            (Sem:=SemTarget)
            (resources:=BareMachine.resources)
            (Krun init_thread_target) tt in  
      permissionless_init_machine Asm_program _
                             init_mem_target
                             init_tp_target
                             init_mem_target'
                             main_ident_tgt nil /\
      
      (forall n,
        HybridMachineSig.HybridMachineSig.HybridFineMachine.fsafe
          (dilMem:= BareDilMem)
          (ThreadPool:=threadPool.OrdinalPool.OrdinalThreadPool
                         (resources:=BareMachine.resources)
                         (Sem:=SemTarget))
          (machineSig:= BareMachine.BareMachineSig)
          init_tp_target (@HybridMachineSig.diluteMem BareDilMem init_mem_target') U n) /\
      (forall final_state final_mem tr,
          sc_execution (U, [::], init_tp_target)
                       (@HybridMachineSig.diluteMem BareDilMem init_mem_target')
                       ([::], tr, final_state) final_mem ->
          SpinLocks.spinlock_synchronized tr).
  Proof.
    intros U.
    destruct (CSL2CoarseAsm_safety U) as
        (init_mem_target & init_mem_target' & init_thread_target & INIT & Hsafe).
    simpl in INIT.
    unfold HybridMachineSig.init_machine'' in INIT.
    destruct INIT as [Hinit_mem Hinit].
    simpl in Hinit.
    unfold HybridMachine.DryHybridMachine.init_mach in Hinit.
    destruct Hinit as [c [Hinit Heq]].
    exists init_mem_target, init_mem_target',
    init_thread_target.
    assert (init_thread_target = c).
    { inversion Heq.
      assert (0 < 1)%nat by auto.
      eapply Extensionality.EqdepTh.inj_pair2 in H0.
      apply equal_f in H0.
      inversion H0; subst.
      reflexivity.
      simpl.
      econstructor;
        now eauto.
    }
    subst.
    split.
    - simpl.
      unfold HybridMachineSig.init_machine''.
      exists fb; split; auto.
      + simpl. split; eauto. simpl. unfold BareMachine.init_mach.
      exists c. simpl.
      split; auto.
    - intros.
      destruct (init_mem_wd  Hinit_mem ) as [Hvalid_mem Hvalid_ge].
      pose (fineConc_safe.FineConcInitial.Build_FineInit Hvalid_mem Hvalid_ge).
      eapply @X86Safe.x86SC_safe with (Main_ptr := Main_ptr) (FI := f); eauto.
      intro; apply Classical_Prop.classic.
      (* proof of safety for new schedule *)
      intros.
      pose proof (CSL2CoarseAsm_safety sched) as
          (init_mem_target2 & init_mem_target2' & init_thread_target2 & INIT2 & Hsafe2).
      simpl in INIT2.
      unfold HybridMachineSig.init_machine'' in INIT2.
      destruct INIT2 as [Hinit_mem2 Hinit2].
      rewrite Hinit_mem2 in Hinit_mem.
      inversion Hinit_mem; subst.
      simpl in Hinit2.
      unfold HybridMachine.DryHybridMachine.init_mach in Hinit2.
      destruct Hinit2 as [c2 [Hinit2 Heq2]].
      destruct (Asm.semantics_determinate Asm_program).
      simpl in sd_initial_determ.
      simpl in Hinit, Hinit2.
      destruct Hinit as [Hinit ?], Hinit2 as [Hinit2 ?]; subst.
      specialize (sd_initial_determ _ _ _ _ _ Hinit Hinit2); subst.
      simpl.
      replace init_thread_target2 with c2 in Hsafe2; eauto.
      clear - Heq2.
      inv Heq2.
      eapply Eqdep.EqdepTheory.inj_pair2 in H0; eauto.
      simpl in H0.
      assert (x:'I_1).
      apply (@Ordinal _ 0). constructor.
      eapply (f_equal (fun F=> F x)) in H0. inv H0; reflexivity.
  Qed.
  

    
  End MainTheorem.
  Arguments permissionless_init_machine _ _ _ _ _ _ _: clear implicits.

  Section CleanMainTheorem.
    Import Integers.Ptrofs Values Ctypes.
    Import MemoryWD machine_semantics.
    Import HybridMachineSig.HybridMachineSig.HybridFineMachine.
    Import ThreadPool BareMachine CoreInjections HybridMachineSig.
    Import main_definitions.

    Inductive parch_CSL_proof (prog: Clight.program): Prop:=
    | CSL_witness:
      forall (b : block)
        (q : veric.Clight_core.CC_core)
        m_init,
        Genv.init_mem prog = Some m_init ->
        Genv.find_symbol (globalenv prog) (prog_main prog) = Some b ->
         initial_core (veric.Clight_core.cl_core_sem (globalenv prog)) 0 m_init q m_init (Vptr b zero) [::] ->
         parch_CSL_proof prog.
    Lemma CSL_proof_parch:
      forall CPROOF : CSL_proof,
        parch_CSL_proof (prog CPROOF).
    Proof.
      intros CPROOF. destruct (spr CPROOF) as (a&b&(c&d)&e&f&g).
      specialize (d e f).
      instantiate (1:=O) in g.
      destruct d as (m & Hinit_core).
      inv Hinit_core. inv H0.
      destruct (init_mem CPROOF) as (m_init & Hm).
      econstructor; eauto.
      econstructor; eauto.
      destruct H1 as [? [? [? ?]]].
      split; auto.
      econstructor.
      split; auto.
      simpl. simpl in f. rewrite <- f.
      split; auto.
    Qed.
        
        
  Theorem main_safety_clean':
      (* C program is proven to be safe in CSL*)
      forall main, CSL_correct C_program main ->

      (* C program compiles to some assembly program*)
      CompCert_compiler C_program = Some Asm_program ->
      
      forall (src_m:Memory.mem) (src_cpm:state),
        
        (* Initial State for CSL *)
        CSL_init_setup C_program src_m src_cpm ->
        
        (* ASM memory good. *)
        forall (limited_builtins:Asm_core.safe_genv x86_context.X86Context.the_ge)
          (Hextern: single_thread_simulation_proof.Asm_externals_have_events Asm_g),
          Genv.find_symbol (Genv.globalenv Asm_program) main_ident_tgt = Some main ->
        asm_prog_well_formed Asm_program limited_builtins ->
        
        forall U, exists tgt_m0 tgt_m tgt_cpm,
            (* inital asm machine *)
            permissionless_init_machine
              Asm_program limited_builtins
              tgt_m0 tgt_cpm tgt_m main_ident_tgt nil /\

            (*it's spinlock safe: well synchronized and safe *)
            spinlock_safe U tgt_cpm tgt_m.
  Proof.
    intros * Hcsafe * Hcompiled * HCSL_init Hlimit_biltin
                                            Hextern_trace  Hfind_main Hasm_wf *.
    
    inv Hcsafe.
    rename H into Hprog.
    rename H0 into Hfind_main_src.
    
    inversion HCSL_init. subst init_st.
    
    assert (HH2 : projT1 (semax_to_juicy_machine.spr CPROOF) = b_main).
    { destruct (semax_to_juicy_machine.spr CPROOF) as (BB & q & [HH Hinit] & ?); simpl.
      unfold semax_to_juicy_machine.prog in *.
      rewrite Hprog in HH.
      rewrite HH in H0; inversion H0; reflexivity. }
    assert (sval (Clight_safety.f_main CPROOF) = f_main).
    { destruct_sig; simpl.
      unfold Clight_safety.ge, Clight_safety.prog in e.
      rewrite HH2 Hprog in e.
      rewrite H1 in e; inversion e; reflexivity.
    }
    assert (HH4: erasure_safety.init_mem CPROOF = src_m).
    { unfold erasure_safety.init_mem.
      clear - Hprog H.
      destruct_sig; simpl.
      unfold semax_to_juicy_machine.prog in *.
      rewrite Hprog in e.
      rewrite H in e; inv e; reflexivity. }

    subst. 
    exploit CSL2FineBareAsm_safety; eauto.
    - rewrite Hfind_main.
      f_equal.
      clear - Hfind_main_src H0 Hprog.
      rewrite <- Hprog in H0; simpl in *. 
      rewrite H0 in Hfind_main_src.
      inv Hfind_main_src; auto.
    - inv HCSL_init. unfold Main_ptr.

      replace b_main with (projT1 (spr CPROOF)) in *.
      replace src_cpm with (Clight_safety.initial_Clight_state CPROOF)
        in H6; auto.
      + unfold Clight_safety.initial_Clight_state.
        inv H6. f_equal.
        * simpl. rewrite <- Hprog in H9.
          destruct (Clight_safety.f_main CPROOF) as (?&HH); simpl.
          clear - HH H9.
          unfold Clight_safety.ge, Clight_safety.prog in *.
          rewrite H9 in HH; inv HH; reflexivity.
        * clear - H13. unfold vals_have_type in H13.
          destruct targs; eauto.
          inv H13.
      + (* b_main = projT1 (spr CPROOF) *)
        rewrite <- Hprog in H4.
        clear - H5 H4.
        destruct (spr CPROOF) as (?&?&(?&?)&?); simpl.
        rewrite H4 in e; inv e; auto.
          
    - simpl; intros.
        (*The following line constructs the machine with [init_tp] *)
        (unshelve normal; try eapply init_tp; shelve_unifiable); eauto.
      (*spinlock_safe*)
      constructor; eauto.
  Qed.

  Inductive asm_prog_well_formed' (Asm_prog: Asm.program):=
| AM_WF: forall asm_genv_safe, asm_prog_well_formed Asm_prog asm_genv_safe ->
                          asm_prog_well_formed' Asm_prog.

  Inductive initial_state (Asm_program : Asm.program) limited_builtins:
    t -> Memory.Mem.mem -> Prop :=
    | Build_init_state:
        forall tgt_m0 tgt_m tgt_cpm,
            permissionless_init_machine
              Asm_program limited_builtins
              tgt_m0 tgt_cpm tgt_m (AST.prog_main Asm_program) nil ->
            initial_state Asm_program limited_builtins tgt_cpm tgt_m.
  Arguments initial_state _ _ _ _: clear implicits.

  Notation CPM:=t.
  Record static_validation (asm_prog:Asm.program) (main:AST.ident) :=
    {   limited_builtins:> Asm_core.safe_genv (Genv.globalenv asm_prog)
        ; limited_externals: single_thread_simulation_proof.Asm_externals_have_events
                               (Genv.globalenv asm_prog) 
        ; init_mem_no_dangling: forall init_mem_target,
            Genv.init_mem asm_prog = Some init_mem_target ->
                              valid_mem init_mem_target
        ; global_envs_allocated: forall init_mem_target,
            Genv.init_mem asm_prog = Some init_mem_target ->
            X86Inj.ge_wd (Renamings.id_ren init_mem_target) (Genv.globalenv asm_prog)
                         (* This last one should be provable and can remove. *)
        ; main_ident_correct: Genv.find_symbol (Genv.globalenv Asm_program) main_ident_tgt
                              = Some main
          }.
  
  Theorem main_safety_clean:
      (* C program is proven to be safe in CSL*)
      forall (main:AST.ident), CSL_correct C_program main ->

      (* C program compiles to some assembly program*)
      CompCert_compiler C_program = Some Asm_program ->
        
      (* Statically checkable properties of ASM program *)
      forall (STATIC: static_validation Asm_program main),

      (* For all schedules, *)
      forall U : schedule,
        
      (*The asm program can be initialized with a memory and CPM state*)
      exists (tgt_m : mem) (tgt_cpm : CPM),
        initial_state Asm_program STATIC tgt_cpm tgt_m /\
        
        (* The assembly language program 
         is correct  and well-synchronized  *)
        spinlock_safe U tgt_cpm tgt_m.
  Proof.
    intros.
    dup STATIC as HH; inv HH.
    dup H as HH; inv HH.
    unshelve(exploit CSL_proof_parch); eauto.
    intros HH; destruct HH.
    inv H5. dup H6 as Hinit.
    simpl in H6.
    destruct H7 as [? [? ?]].
    repeat match_case in H6;
      destruct H6 as (?&?&?&?&?).
     
    2:{ exfalso; assumption. }
    
    exploit main_safety_clean'; eauto.
    - !goal (CSL_init_setup _ _ _).
      rewrite <- H1.
      econstructor; eauto.
      eapply Clight_safety.intial_simulation; eauto.
      
      econstructor; eauto.
    - econstructor.
      eapply init_mem_no_dangling0; eauto.
      eapply global_envs_allocated0; eauto.

    - intros (?&?&?&?&?).
      do 3 econstructor.
      + econstructor; eauto.
      + eauto.

        Unshelve.
        exact O.
  Qed.
  End CleanMainTheorem.
End Main.

(*
Module TestMain 
       (CC_correct: CompCert_correctness)
       (Args: ThreadSimulationArguments).

  Module MyMain := Main CC_correct Args.
  Import MyMain.

  Check main_safety_clean.
  
End TestMain.
  *)