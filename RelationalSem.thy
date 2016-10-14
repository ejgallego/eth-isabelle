theory RelationalSem

(* This is a relational semantics trying to capture
 * one element of the call stack *)

imports Main "./ContractSem"

begin

inductive account_state_natural_change :: "account_state \<Rightarrow> account_state \<Rightarrow> bool"
where
natural:
"account_address new = account_address old \<Longrightarrow>
 account_storage new = account_storage old \<Longrightarrow>
 account_code new = account_code old \<Longrightarrow>
 account_balance old \<le> account_balance old \<Longrightarrow>
 account_ongoing_calls new = account_ongoing_calls old \<Longrightarrow>
 account_state_natural_change old new"
 
declare account_state_natural_change.simps [simp]

inductive world_turn :: "(account_state * program_result) \<Rightarrow> (account_state * variable_env) \<Rightarrow> bool"
where
(*  world_continue: "world_turn (orig, (InstructionContinue v)) (orig, v)"*)
(* TODO  enable this with invariant. *)
  world_call: (* This excludes the reentrance, because that will be treated by the invariant *)
  "account_state_natural_change old_state new_state \<Longrightarrow>
   build_venv_called new_state callargs next_venv \<Longrightarrow>
   world_turn (old_state, ProgramInit) (new_state, next_venv)"
| world_return_from_call:
  "account_state_natural_change account_state_going_out account_state_back \<Longrightarrow>
   build_venv_returned account_state_back result new_v \<Longrightarrow>
   world_turn (account_state_going_out, (ProgramToWorld (ContractCall _, _, _, _))) (account_state_back, new_v)"
| world_return_from_create:
  "account_state_natural_change account_state_going_out account_state_back \<Longrightarrow>
   build_venv_returned account_state_back result new_v \<Longrightarrow>
   world_turn (account_state_going_out, (ProgramToWorld (ContractCreate _, _, _, _))) (account_state_back, new_v)"
| world_fail_from_call:
  "account_state_natural_change account_state_going_out account_state_back \<Longrightarrow>
   build_venv_failed account_state_back = Some new_v \<Longrightarrow>
   world_turn (account_state_going_out, (ProgramToWorld (ContractCall _, _, _, _))) (account_state_back, new_v)"
| world_fail_from_create:
  "account_state_natural_change account_state_going_out account_state_back \<Longrightarrow>
   build_venv_failed account_state_back = Some new_v \<Longrightarrow>
   world_turn (account_state_going_out, (ProgramToWorld (ContractCreate _, _, _, _))) (account_state_back, new_v)"


abbreviation next_instruction :: "variable_env \<Rightarrow> inst \<Rightarrow> bool"
where
"next_instruction v i ==
  (case venv_prg_sfx v of
      i' # _ \<Rightarrow> i = i'
    | _ \<Rightarrow> False)"

inductive contract_turn :: "(account_state * variable_env) \<Rightarrow> (account_state * program_result) \<Rightarrow> bool"
where
  contract_to_world:
  "build_cenv old_account = cenv \<Longrightarrow>
   program_sem old_venv cenv (venv_prg_sfx old_venv) steps = ProgramToWorld (act, opt_v, st, bal) \<Longrightarrow>
   account_state_going_out = update_account_state a act opt_v st bal \<Longrightarrow>
   contract_turn (old_account, old_venv) (account_state_going_out, ProgramToWorld (act, opt_v, st, bal))"
| contract_annotation_failure:
  "build_cenv old_account = cenv \<Longrightarrow>
   program_sem old_venv cenv (venv_prg_sfx old_venv) steps = ProgramAnnotationFailure \<Longrightarrow>
   contract_turn (old_account, old_venv) (old_account, ProgramAnnotationFailure)"


inductive one_step :: "(account_state * program_result) \<Rightarrow> (account_state * program_result) \<Rightarrow> bool"
where
step:
"world_turn a b \<Longrightarrow> contract_turn b c \<Longrightarrow> one_step a c"

inductive initial_program_result :: "account_state \<Rightarrow> (account_state * program_result) \<Rightarrow> bool"
where
initial:
"initial_program_result a (a, ProgramInit)"

(* taken from the book Concrete Semantics *)
inductive star :: "('a \<Rightarrow> 'a \<Rightarrow> bool) \<Rightarrow> 'a \<Rightarrow> 'a \<Rightarrow> bool"
where
refl: "star r x x" |
step: "r x y \<Longrightarrow> star r y z \<Longrightarrow> star r x z"

(*
inductive reachable :: "account_state \<Rightarrow> (account_state * program_result) \<Rightarrow> bool"
where
"star one_step init fin \<Longrightarrow>
 initial_program_result original init \<Longrightarrow>
 reachable original fin"
*)

lemma star_case' :
"
star r init dst \<Longrightarrow>
(P init) \<Longrightarrow>
(\<forall> next future. r init next \<longrightarrow>
 star r next future \<longrightarrow> (P future))
\<Longrightarrow> P dst
"
apply(induction rule: star.induct; auto)
done

lemma star_case'' :
"
P init \<Longrightarrow>
(\<forall> next future. r init next \<longrightarrow>
 star r next future \<longrightarrow> P future) \<Longrightarrow>
star r init dst \<longrightarrow> P dst
"
apply(auto)
apply(drule star_case'; auto)
done

lemma star_case :
"star r a c \<Longrightarrow>
 (a = c \<or> (\<exists> b. r a b \<and> star r b c))"
apply(induction rule: star.induct; auto)
done

(*
lemma reachable_ind :
"\<forall> init. initial_program_result a init \<longrightarrow>
    (P init \<and> (\<forall> next future. one_step init next \<longrightarrow> star one_step next future \<longrightarrow> P future)) \<Longrightarrow>
 \<forall> fin. reachable a fin \<longrightarrow> P fin"
apply(rule allI)
apply(rule impI)
apply(erule allE)
apply(simp add: reachable.simps)
apply(erule exE)
*)

(*
inductive one_run :: "account_state \<Rightarrow> (account_state * instruction_result) \<Rightarrow> bool"
where
"initial_instruction_result original init \<Longrightarrow>
 one_step (original, init) fin \<Longrightarrow>
 one_run original fin"
*)
definition no_assertion_failure :: "account_state \<Rightarrow> bool"
where
"no_assertion_failure a ==
  (\<forall> init. initial_program_result a init \<longrightarrow>
  (\<forall> fin. star one_step init fin \<longrightarrow>
  snd fin \<noteq> ProgramAnnotationFailure))"

(* TODO: define calls_of_code *)

(*
definition no_assertion_failure_one_run :: "program \<Rightarrow> bool"
where
"no_assertion_failure_one_run code ==
 \<forall> a fin r.
 account_code a = code \<longrightarrow>
 calls_of_code code (account_ongoing_calls a) \<longrightarrow>
 one_run a (fin, r) \<longrightarrow>
 r \<noteq> InstructionAnnotationFailure"

*)
end
