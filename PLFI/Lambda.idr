import Decidable.Equality

%default total

----------------
---- SYNTAX ----
----------------

Id : Type
Id = String

-- Curry-style lambda calculus with Peano naturals and fixpoints
data Term : Type where
  Var  : Id -> Term                           -- Variables: x
  Lam  : Id -> Term -> Term                   -- Lambda abstractions: λx.e
  App  : Term -> Term -> Term                 -- Applications: e e
  Fix  : Id -> Term -> Term                   -- Fixpoints: μx.e
  Zero : Term                                 -- Natural: zero
  Succ : Term -> Term                         -- Natural: successor
  Case : Term -> Term -> Id -> Term -> Term   -- Case: case e of [zero => e₁ | succ n => e₂]

----------------
---- VALUES ----
----------------

-- Irreducible values in weak normal form
data Value : Term -> Type where
  VLam  : Value (Lam x e)
  VZero : Value Zero
  VSucc : Value v -> Value (Succ v)

----------------------
---- SUBSTITUTION ----
----------------------

-- NOT capture-avoiding substitution
subst : Term -> Id -> Term -> Term
subst (Var x) y v with (decEq x y)
  subst (Var x) y v | Yes _ = v
  subst (Var x) y v | No  _ = Var x
subst (Lam x e) y v with (decEq x y)
  subst (Lam x e) y v | Yes _ = Lam x e
  subst (Lam x e) y v | No  _ = Lam x (subst e y v)
subst (App e1 e2) y v = App (subst e1 y v) (subst e2 y v)
subst (Fix x e) y v with (decEq x y)
  subst (Fix x e) y v | Yes _ = Fix x e
  subst (Fix x e) y v | No  _ = Fix x (subst e x v)
subst Zero y v = Zero
subst (Succ n) y v = Succ (subst n y v)
subst (Case e e1 x e2) y v with (decEq x y)
  subst (Case e e1 x e2) y v | Yes _ = Case (subst e y v) (subst e1 y v) x e2
  subst (Case e e1 x e2) y v | No  _ = Case (subst e y v) (subst e1 y v) x (subst e2 y v)

-------------------
---- REDUCTION ----
-------------------

-- Reduction rules combined with compatible closure rules
data Red : Term -> Term -> Type where
  -- Conventional reduction rules
  Beta  : Value v -> Red (Lam x e) (subst e x v)
  Mu    : Red (Fix x e) (subst e x (Fix x e))
  IotaZ : Red (Case Zero e1 x e2) e1
  IotaS : Value v -> Red (Case (Succ v) e1 x e2) (subst e2 x v)

  -- Compatible closure rules
  XiApp1 : Red e1 e1' ->
           ----------------------------
           Red (App e1 e2) (App e1' e2)

  XiApp2 : Value v ->
           Red e2 e2' ->
           --------------------------
           Red (App v e2) (App v e2')

  XiSucc : Red n n' ->
           ----------------------
           Red (Succ n) (Succ n')

  XiCase : Red e e' ->
           --------------------------------------
           Red (Case e e1 x e2) (Case e' e1 x e2)

----------------------------
---- REFL/TRANS CLOSURE ----
----------------------------

-- Multistep reduction as a chain of reductions
infix 5 ->>
data (->>) : Term -> Term -> Type where
  End : e ->> e
  Chain : Red e1 e2 ->
          e2 ->> e3 ->
          ---------
          e1 ->> e3

-- Multistep reduction as the reflexive, transitive closure
infix 5 ->>*
data (->>*) : Term -> Term -> Type where
  Step  : Red e1 e2 ->
          ---------
          e1 ->>* e2

  Refl  : e ->>* e
  
  Trans : e1 ->>* e2 ->
          e2 ->>* e3 ->
          ---------
          e1 ->>* e3

multistepTo : (e1 ->> e2) -> (e1 ->>* e2)
multistepTo End = Refl
multistepTo (Chain red ms) = Trans (Step red) (multistepTo ms)

unravel : (e1 ->> e2) -> (e2 ->> e3) -> (e1 ->> e3)
unravel End ms = ms
unravel (Chain red ms1) ms2 = Chain red (unravel ms1 ms2)

multistepFrom : (e1 ->>* e2) -> (e1 ->> e2)
multistepFrom Refl = End
multistepFrom (Step red) = Chain red End
multistepFrom (Trans ms1 ms2) = unravel (multistepFrom ms1) (multistepFrom ms2)

-- (->>) embeds into (->>*)...
multistepFromTo : (ms : e1 ->> e2) -> multistepFrom (multistepTo ms) = ms
multistepFromTo End = Refl
multistepFromTo (Chain red ms) = rewrite multistepFromTo ms in Refl

-- ...but (->>*) does not embed into (->>)
-- because we can't simplify (Trans ms Refl) to ms
transReflLeft  : (ms : e1 ->>* e2) -> Trans Refl ms = ms
transReflRight : (ms : e1 ->>* e2) -> Trans ms Refl = ms

multiUnravel : (ms1 : e1 ->>* e2) -> (ms2 : e2 ->>* e3) ->
  multistepTo (unravel (multistepFrom ms1) (multistepFrom ms2)) = Trans (multistepTo (multistepFrom ms1)) (multistepTo (multistepFrom ms2))
multiUnravel Refl ms = rewrite transReflLeft (multistepTo (multistepFrom ms)) in Refl
multiUnravel (Step red) ms = rewrite transReflRight (Step red) in Refl
multiUnravel (Trans ms1 ms2) ms = ?transMultiUnravel

multistepToFrom : (ms : e1 ->>* e2) -> multistepTo (multistepFrom ms) = ms
multistepToFrom Refl = Refl
multistepToFrom (Step red) =
  rewrite transReflRight (Step red) in Refl
multistepToFrom (Trans ms1 ms2) =
  rewrite multiUnravel ms1 ms2 in
  rewrite multistepToFrom ms1 in
  rewrite multistepToFrom ms2 in Refl

--------------------
---- CONFLUENCE ----
--------------------