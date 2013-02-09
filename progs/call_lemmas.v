Load loadpath.
Require Import Coqlib compositional_compcert.Coqlib2.
Require Import veric.SeparationLogic.
Require veric.SequentialClight.
Import SequentialClight.SeqC.CSL.
Require Import progs.client_lemmas.
Require Import progs.field_mapsto.
Require Import progs.assert_lemmas.

Local Open Scope logic.

Lemma semax_call': forall Delta A (Pre Post: A -> assert) (x: A) ret fsig a bl P Q R,
   Cop.classify_fun (typeof a) = Cop.fun_case_f (type_of_params (fst fsig)) (snd fsig) ->
   match fsig, ret with
   | (_, Tvoid), None => True
   | (_, Tvoid), Some _ => False
   | _, Some _ => True
   | _, _ => False
   end ->
  semax Delta
         (PROPx P (LOCALx (tc_expr Delta a :: tc_exprlist Delta (snd (split (fst fsig))) bl :: Q)
            (SEPx (`(Pre x) ( (make_args' fsig (eval_exprlist (snd (split (fst fsig))) bl))) ::
                      `(fun_assert_emp fsig A Pre Post) (eval_expr a) :: R))))
          (Scall ret a bl)
          (normal_ret_assert 
            (EX old:val, 
              PROPx P (LOCALx (map (substopt ret (`old)) Q) 
                (SEPx (`(Post x) (get_result ret) :: map (substopt ret (`old)) R))))).
Proof.
 intros.
eapply semax_pre_post ; [ | | 
   apply (semax_call Delta A Pre Post x (PROPx P (LOCALx Q (SEPx R))) ret fsig a bl H)].
 Focus 3.
 clear - H0.
 destruct fsig. destruct t; destruct ret; simpl in *; try contradiction; split; intros; congruence.
 intro rho; normalize.
unfold fun_assert_emp.
repeat rewrite corable_andp_sepcon2 by apply corable_fun_assert.
normalize.
rewrite corable_sepcon_andp1 by apply corable_fun_assert.
rewrite sepcon_comm; auto. 
intros.
normalize.
intro old.
apply exp_right with old; destruct ret; normalize.
intro rho; normalize.
rewrite sepcon_comm; auto.
intro rho; normalize.
rewrite sepcon_comm; auto.
unfold substopt.
repeat rewrite list_map_identity.
normalize.
Qed.

Lemma semax_call1: forall Delta A (Pre Post: A -> assert) (x: A) id fsig a bl P Q R,
   Cop.classify_fun (typeof a) = Cop.fun_case_f (type_of_params (fst fsig)) (snd fsig) ->
   match fsig with
   | (_, Tvoid) => False
   | _ => True
   end ->
  semax Delta
         (PROPx P (LOCALx (tc_expr Delta a :: tc_exprlist Delta (snd (split (fst fsig))) bl :: Q)
            (SEPx (`(Pre x) ( (make_args' fsig (eval_exprlist (snd (split (fst fsig))) bl))) ::
                      `(fun_assert_emp fsig A Pre Post) (eval_expr a) :: R))))
          (Scall (Some id) a bl)
          (normal_ret_assert 
            (EX old:val, 
              PROPx P (LOCALx (map (subst id (`old)) Q) 
                (SEPx (`(Post x) (get_result1 id) :: map (subst id (`old)) R))))).
Proof.
intros.
apply semax_call'; auto.
Qed.

Lemma semax_call0: forall Delta A (Pre Post: A -> assert) (x: A) fsig a bl P Q R,
   Cop.classify_fun (typeof a) = Cop.fun_case_f (type_of_params (fst fsig)) (snd fsig) ->
   match fsig with
   | (_, Tvoid) => True
   | _ => False
   end ->
  semax Delta
         (PROPx P (LOCALx (tc_expr Delta a :: tc_exprlist Delta (snd (split (fst fsig))) bl :: Q)
            (SEPx (`(Pre x) ( (make_args' fsig (eval_exprlist (snd (split (fst fsig))) bl))) ::
                      `(fun_assert_emp fsig A Pre Post) (eval_expr a) :: R))))
          (Scall None a bl)
          (normal_ret_assert 
            (PROPx P (LOCALx Q (SEPx (`(Post x) (make_args nil nil) :: R))))).
Proof.
intros.
eapply semax_pre_post ; [ | | 
   apply (semax_call Delta A Pre Post x (PROPx P (LOCALx Q (SEPx R))) None fsig a bl H)].
 Focus 3.
 clear - H0.
 destruct fsig. destruct t; simpl in *; try contradiction; split; intros; congruence.
 intro rho; normalize.
unfold fun_assert_emp.
repeat rewrite corable_andp_sepcon2 by apply corable_fun_assert.
normalize.
rewrite corable_sepcon_andp1 by apply corable_fun_assert.
rewrite sepcon_comm; auto. 
intros.
normalize.
intro rho; normalize.
rewrite sepcon_comm; auto.
Qed.


Lemma semax_fun_id':
      forall id fsig (A : Type) (Pre Post : A -> assert)
              Delta P Q R PostCond c
            (GLBL: (var_types Delta) ! id = None),
            (glob_types Delta) ! id = Some (Global_func (mk_funspec fsig A Pre Post)) ->
       semax Delta 
        (PROPx P (LOCALx Q (SEPx (`(fun_assert_emp fsig A Pre Post)
                         (eval_lvalue (Evar id (type_of_funsig fsig))) :: R))))
                              c PostCond ->
       semax Delta (PROPx P (LOCALx Q (SEPx R))) c PostCond.
Proof.
intros. 
apply (semax_fun_id id fsig A Pre Post Delta); auto.
eapply semax_pre; [ | apply H0].
forget (eval_lvalue (Evar id (type_of_funsig fsig))) as f.
intro rho; normalize.
rewrite andp_comm.
unfold fun_assert_emp.
rewrite corable_andp_sepcon2 by apply corable_fun_assert.
rewrite emp_sepcon; auto.
Qed.

Lemma eqb_typelist_refl: forall tl, eqb_typelist tl tl = true.
Proof.
induction tl; simpl; auto.
apply andb_true_iff.
split; auto.
apply eqb_type_refl.
Qed.


Lemma semax_call_id0:
 forall Delta P Q R id argtys bl fsig A x Pre Post
   (GLBL: (var_types Delta) ! id = None),
   (glob_types Delta) ! id = Some (Global_func (mk_funspec fsig A Pre Post)) ->
   match fsig with
   | (_, Tvoid) => True
   | _ => False
   end ->
   argtys = type_of_params (fst fsig) ->
   Tvoid = snd fsig ->
  semax Delta (PROPx P (LOCALx (tc_exprlist Delta (snd (split (fst fsig))) bl :: Q) (SEPx (`(Pre x) (make_args' fsig (eval_exprlist (snd (split (fst fsig))) bl)) :: R))))
    (Scall None (Evar id (Tfunction argtys Tvoid)) bl)
    (normal_ret_assert 
       (PROPx P (LOCALx Q (SEPx (`(Post x) (make_args nil nil) :: R))))).
Proof.
intros.
assert (Cop.classify_fun (typeof (Evar id (Tfunction argtys Tvoid)))=
               Cop.fun_case_f (type_of_params (fst fsig)) (snd fsig)).
rewrite <- H2; subst; reflexivity.
apply semax_fun_id' with id fsig A Pre Post; auto.
subst. 

eapply semax_pre; [ | apply (semax_call0 Delta A Pre Post x fsig  _ bl P Q R H3 H0)].
apply andp_left2.
apply andp_derives; auto.
apply andp_derives; auto.
intro rho; simpl.
subst.
autorewrite with normalize.
apply andp_right.
apply prop_right. hnf.
rewrite <- H2 in *.
simpl.
unfold get_var_type. rewrite GLBL. rewrite H.
simpl.
rewrite eqb_typelist_refl.
simpl. rewrite <- H2. split; hnf; auto.
auto.
change SEPx with SEPx'.
simpl.
intro rho.
rewrite H2.
rewrite sepcon_comm.
rewrite sepcon_assoc.
autorewrite with normalize.
apply sepcon_derives; auto.
rewrite sepcon_comm.
apply sepcon_derives; auto.
Qed.

Lemma semax_call_id1:
 forall Delta P Q R ret id argtys retty bl fsig A x Pre Post
   (GLBL: (var_types Delta) ! id = None),
   (glob_types Delta) ! id = Some (Global_func (mk_funspec fsig A Pre Post)) ->
   match fsig with
   | (_, Tvoid) => False
   | _ => True
   end ->
   argtys = type_of_params (fst fsig) ->
   retty = snd fsig ->
  semax Delta (PROPx P (LOCALx (tc_exprlist Delta (snd (split (fst fsig))) bl :: Q) (SEPx (`(Pre x) (make_args' fsig (eval_exprlist (snd (split (fst fsig))) bl)) :: R))))
    (Scall (Some ret)
             (Evar id (Tfunction argtys retty))
             bl)
    (normal_ret_assert 
       (EX old:val, 
          PROPx P (LOCALx (map (subst ret (`old)) Q) 
             (SEPx (`(Post x) (get_result1 ret) :: map (subst ret (`old)) R))))).
Proof.
intros.
assert (Cop.classify_fun (typeof (Evar id (Tfunction argtys retty)))=
               Cop.fun_case_f (type_of_params (fst fsig)) (snd fsig)).
subst; reflexivity.
apply semax_fun_id' with id fsig A Pre Post; auto.
subst. 
eapply semax_pre; [ | apply (semax_call1 Delta A Pre Post x ret fsig  _ bl P Q R H3 H0)].
apply andp_left2.
apply andp_derives; auto.
apply andp_derives; auto.
intro rho; simpl.
subst.
autorewrite with normalize.
apply andp_right.
apply prop_right. hnf.
simpl.
unfold get_var_type. rewrite GLBL. rewrite H.
simpl.
rewrite eqb_typelist_refl.
rewrite eqb_type_refl.
simpl. split; hnf; auto.
auto.
change SEPx with SEPx'.
simpl.
intro rho.
rewrite sepcon_comm.
rewrite sepcon_assoc.
autorewrite with normalize.
apply sepcon_derives; auto.
rewrite sepcon_comm.
apply sepcon_derives; auto.
Qed.


Lemma semax_call_id1':
 forall Delta P Q R ret id argtys retty bl fsig A x Pre Post
   (GLBL: (var_types Delta) ! id = None),
   (glob_types Delta) ! id = Some (Global_func (mk_funspec fsig A Pre Post)) ->
   match fsig with
   | (_, Tvoid) => False
   | _ => True
   end ->
   argtys = type_of_params (fst fsig) ->
   retty = snd fsig ->
  forall 
   (CLOSQ: Forall (closed_wrt_vars (eq ret)) Q)
   (CLOSR: Forall (closed_wrt_vars (eq ret)) R),
  semax Delta (PROPx P (LOCALx (tc_exprlist Delta (snd (split (fst fsig))) bl :: Q) (SEPx (`(Pre x) (make_args' fsig (eval_exprlist (snd (split (fst fsig))) bl)) :: R))))
    (Scall (Some ret)
             (Evar id (Tfunction argtys retty))
             bl)
    (normal_ret_assert 
       (PROPx P (LOCALx Q   (SEPx (`(Post x) (get_result1 ret) ::  R))))).
Proof.
intros.
eapply semax_post;
  [ | apply (semax_call_id1 Delta P Q R ret id argtys retty bl fsig A x Pre Post 
     GLBL H H0 H1 H2)].
intros ek vl.
apply andp_left2.
unfold normal_ret_assert.
apply andp_derives; auto.
apply andp_derives; auto.
apply exp_left; intro v.
apply andp_derives; auto.
apply andp_derives.
unfold local, lift1 ;intro rho.
clear - CLOSQ.
apply prop_left. intro.
apply prop_right.
induction Q; simpl; auto.
inv CLOSQ.
destruct H.
split.
rewrite closed_wrt_subst in H; auto.
auto.
clear - CLOSR.
change SEPx with SEPx'.
unfold SEPx'. intro rho.
simpl.
apply sepcon_derives; auto.
induction R; simpl; auto.
inv CLOSR.
apply sepcon_derives.
rewrite closed_wrt_subst; auto.
apply IHR; auto.
Qed.

Lemma semax_call_id1_Eaddrof:
 forall Delta P Q R ret id argtys retty bl fsig A x Pre Post
   (GLBL: (var_types Delta) ! id = None),
   (glob_types Delta) ! id = Some (Global_func (mk_funspec fsig A Pre Post)) ->
   match fsig with
   | (_, Tvoid) => False
   | _ => True
   end ->
   argtys = type_of_params (fst fsig) ->
   retty = snd fsig ->
  semax Delta (PROPx P (LOCALx (tc_exprlist Delta (snd (split (fst fsig))) bl :: Q) (SEPx (`(Pre x) (make_args' fsig (eval_exprlist (snd (split (fst fsig))) bl)) :: R))))
    (Scall (Some ret)
             (Eaddrof (Evar id (Tfunction argtys retty)) (Tpointer (Tfunction argtys retty) noattr))
             bl)
    (normal_ret_assert 
       (EX old:val, 
          PROPx P (LOCALx (map (subst ret (`old)) Q) 
             (SEPx (`(Post x) (get_result1 ret) :: map (subst ret (`old)) R))))).
Proof.
intros.
assert (Cop.classify_fun (typeof (Eaddrof (Evar id (Tfunction argtys retty)) (Tpointer (Tfunction argtys retty) noattr)))=
               Cop.fun_case_f (type_of_params (fst fsig)) (snd fsig)).
subst; reflexivity.
apply semax_fun_id' with id fsig A Pre Post; auto.
subst. 
eapply semax_pre; [ | apply (semax_call1 Delta A Pre Post x ret fsig  _ bl P Q R H3 H0)].
apply andp_left2.
apply andp_derives; auto.
apply andp_derives; auto.
intro rho; simpl.
subst.
autorewrite with normalize.
apply andp_right.
apply prop_right. hnf.
simpl.
unfold get_var_type. rewrite GLBL. rewrite H.
simpl.
rewrite eqb_typelist_refl.
rewrite eqb_type_refl.
simpl. apply I.
auto.
change SEPx with SEPx'.
simpl.
intro rho.
cancel.
Qed.


Lemma semax_call_id_aux1: forall P Q1 Q R S,
     PROPx P (LOCALx (Q1::Q) R) |-- S -> local Q1 && PROPx P (LOCALx Q R) |-- S.
Proof. intros. eapply derives_trans; try apply H.
  intro rho; normalize.
 unfold PROPx. simpl.
 apply andp_derives; auto.
 unfold LOCALx. simpl.
 unfold local,lift2,lift1.
 apply derives_extract_prop; intro.
 apply andp_right; auto.
 apply prop_right; split; auto.
Qed.
