-- {-# LANGUAGE TypeInType #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE UndecidableSuperClasses #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE AllowAmbiguousTypes #-} -- experiment
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE CPP #-}

{-# OPTIONS_GHC -Wall #-}

{-# OPTIONS_GHC -fno-warn-unused-imports #-}  -- TEMP
{-# OPTIONS_GHC -fconstraint-solver-iterations=10 #-} -- for Oks

-- #define DefaultCat

-- | Constrained categories

module ConCat.Category where

import Prelude hiding (id,(.),curry,uncurry,const)
import qualified Prelude as P
#ifdef DefaultCat
import qualified Control.Category as C
#endif
import Control.Arrow (Kleisli(..),arr)
import qualified Control.Arrow as A
import Control.Applicative (liftA2)
import Control.Monad ((<=<))
import Data.Proxy (Proxy)
import GHC.Generics hiding (Rep)
import GHC.Types (Constraint)
import Data.Constraint hiding ((&&&),(***),(:=>))
-- import GHC.Types (type (*))  -- experiment with TypeInType
-- import qualified Data.Constraint as K

import Control.Newtype (Newtype(..))

import Data.MemoTrie

import ConCat.Misc hiding ((<~),(~>))
import ConCat.Rep
import ConCat.Orphans ()

{--------------------------------------------------------------------
    Constraint utilities
--------------------------------------------------------------------}

-- Lower fixity
infixr 1 |-
type (|-) = (:-)

infixl 1 <+
-- | Synonym for '(\\)'
(<+) :: a => (b => r) -> (a |- b) -> r
(<+) = (\\)

conj :: (a,b) |- a && b
conj = Sub Dict

unconj :: a && b |- (a,b)
unconj = Sub Dict

{--------------------------------------------------------------------
    Constraints with product consequences
--------------------------------------------------------------------}

type UnitCon con = con ()

class OpCon op con where
  inOp :: con a && con b |- con (a `op` b)

inOpL :: OpCon op con => (con a && con b) && con c |- con ((a `op` b) `op` c)
inOpL = inOp . first  inOp

inOpR :: OpCon op con => con a && (con b && con c) |- con (a `op` (b `op` c))
inOpR = inOp . second inOp

inOpL' :: OpCon op con 
       => (con a && con b) && con c |- con (a `op` b) && con ((a `op` b) `op` c)
inOpL' = second inOp . rassocP . first (dup . inOp)

-- (con a && con b) && con c
-- con (a `op` b) && con c
-- (con (a `op` b) && con (a `op` b)) && con c
-- con (a `op` b) && (con (a `op` b) && con c)
-- con (a `op` b) && con ((a `op` b) `op` c)

inOpR' :: OpCon op con => con a && (con b && con c) |- con (a `op` (b `op` c)) &&  con (b `op` c)
inOpR' = first inOp . lassocP . second (dup . inOp)

inOpLR :: forall op con a b c. OpCon op con =>
  ((con a && con b) && con c) && (con a && (con b && con c))
  |- con ((a `op` b) `op` c) && con (a `op` (b `op` c))
inOpLR = inOpL *** inOpR

#if 0
-- Experiment
inO :: forall op con a b r. OpCon op con => (con (a `op` b) => r) -> (con a && con b => r)
inO = (<+ inOp @op @con @a @b)

inOL :: forall op con a b c r. OpCon op con
     => (con ((a `op` b) `op` c) => r) -> ((con a && con b) && con c => r)
-- inOL r = inO @op @con @a @b $ inO @op @con @(a `op` b) @c $ r
inOL = inO @op @con @a @b . inO @op @con @(a `op` b) @c -- nope
#endif

instance OpCon op Yes1 where
  inOp = Sub Dict

#if 1
-- type C1 (con :: u -> Constraint) a = con a
-- type C2 con a b         = C1 con a && con b

type C2 (con :: u -> Constraint) a b = con a && con b

type C3 con a b c       = C2 con a b && con c
type C4 con a b c d     = C3 con a b c && con d
type C5 con a b c d e   = C4 con a b c d && con e
type C6 con a b c d e f = C5 con a b c d e && con f

type Ok2 k a b         = C2 (Ok k) a b
type Ok3 k a b c       = C3 (Ok k) a b c
type Ok4 k a b c d     = C4 (Ok k) a b c d
type Ok5 k a b c d e   = C5 (Ok k) a b c d e
type Ok6 k a b c d e f = C6 (Ok k) a b c d e f

-- Experiments:

type Ok5' k a b c d e   = C5 (Ok k) a b c d e && C5 (Compat k a) a b c d e && C4 (Flip (Compat k) a) b c d e
#endif

#if 1
type Oks k as = AllC (Ok k) as
#else
-- Oks with pairwise compatibility (quadratic):
type Oks k as = AllC (Ok k) as && AllC2 (Compat k) as as
#endif

-- -- TODO. Try out this more convenient alternative to inOp
-- inOp' :: forall op k a b. OpCon (op k) (Ok k)
--       => Ok k a && Ok k b |- Ok k (op k a b)
-- inOp' = inOp

class OpCon' k op con where
  inOp' :: (Ok k (con a), Ok k (con b)) => Prod k (con a) (con b) `k` con (a `op` b)

-- inOpLs :: (ProductCat k, OpCon' k op con)
--        => (Ok k (con a), Ok k (con b))
--        => Prod k (Prod k (con a) (con b)) (con c)
--        `k` con ((a `op` b) `op` c)
-- inOpLs = inOp' . first  inOp'

{--------------------------------------------------------------------
    Categories
--------------------------------------------------------------------}

class Category (k :: u -> u -> *) where
  type Ok k :: u -> Constraint
  type Ok k = Yes1
  type Compat k :: u -> u -> Constraint  -- experiment
  type Compat k = Yes2
  id  :: Ok k a => a `k` a
  infixr 9 .
  -- (.) :: forall b c a. Oks k [a,b,c] => (b `k` c) -> (a `k` b) -> (a `k` c)
  (.) :: forall b c a. Ok3 k a b c => (b `k` c) -> (a `k` b) -> (a `k` c)
  -- (.) :: forall b c a. (Ok k a,Ok k b,Ok k c) => (b `k` c) -> (a `k` b) -> (a `k` c)
#ifdef DefaultCat
  -- Defaults experiment
  default id :: C.Category k => a `k` a
  id = C.id
  default (.) :: C.Category k => b `k` c -> a `k` b -> a `k` c
  (.) = (C..)
#endif

-- type CatOk k ok = (Category k, ok ~ Ok k)

infixl 1 <~
infixr 1 ~>
-- | Add post- and pre-processing
(<~) :: (Category k, Oks k [a,b,a',b']) 
     => (b `k` b') -> (a' `k` a) -> ((a `k` b) -> (a' `k` b'))
(h <~ f) g = h . g . f

-- | Add pre- and post-processing
(~>) :: (Category k, Oks k [a,b,a',b']) 
     => (a' `k` a) -> (b `k` b') -> ((a `k` b) -> (a' `k` b'))
f ~> h = h <~ f

#if DefaultCat
instance Category (->)
instance Monad m => Category (Kleisli m)
#else
instance Category (->) where
  id  = P.id
  (.) = (P..)

instance Monad m => Category (Kleisli m) where
  id  = pack return
  (.) = inNew2 (<=<)
#endif

{--------------------------------------------------------------------
    Products
--------------------------------------------------------------------}

infixr 3 ***, &&&

okProd :: forall k a b. OpCon (Prod k) (Ok k)
       => Ok k a && Ok k b |- Ok k (Prod k a b)
okProd = inOp

-- | Category with product.
class (OpCon (Prod k) (Ok k), Category k) => ProductCat k where
  type Prod k :: u -> u -> u
  -- type Prod k = (:*)
  exl :: Oks k [a,b] => Prod k a b `k` a
  exr :: Oks k [a,b] => Prod k a b `k` b
  dup :: Ok  k a => a `k` Prod k a a
  dup = id &&& id
  swapP :: forall a b. Oks k [a,b] => Prod k a b `k` Prod k b a
  swapP = exr &&& exl
          <+ okProd @k @a @b
  (***) :: forall a b c d. Oks k [a,b,c,d] 
        => (a `k` c) -> (b `k` d) -> (Prod k a b `k` Prod k c d)
  f *** g = f . exl &&& g . exr
            <+ okProd @k @a @b
  (&&&) :: forall a c d. Oks k [a,c,d] 
        => (a `k` c) -> (a `k` d) -> (a `k` Prod k c d)
  f &&& g = (f *** g) . dup
    <+ okProd @k @a @a
    <+ okProd @k @c @d
  first :: forall a a' b. Oks k [a,b,a'] 
        => (a `k` a') -> (Prod k a b `k` Prod k a' b)
  first = (*** id)
  second :: forall a b b'. Oks k [a,b,b'] 
         => (b `k` b') -> (Prod k a b `k` Prod k a b')
  second = (id ***)
  lassocP :: forall a b c. Oks k [a,b,c]
          => Prod k a (Prod k b c) `k` Prod k (Prod k a b) c
  lassocP = second exl &&& (exr . exr)
            <+ okProd @k @a @b
            <+ inOpR' @(Prod k) @(Ok k) @a @b @c
  rassocP :: forall a b c. Oks k [a,b,c]
          => Prod k (Prod k a b) c `k` Prod k a (Prod k b c)
  rassocP = (exl . exl) &&& first  exr
            <+ okProd @k    @b @c
            <+ inOpL' @(Prod k) @(Ok k) @a @b @c
  {-# MINIMAL exl, exr, ((&&&) | ((***), dup)) #-}
#ifdef DefaultCat
  default exl :: A.Arrow k => (a :* b) `k` a
  exl = arr exl
  default exr :: A.Arrow k => (a :* b) `k` b
  exr = arr exr
  default (&&&) :: A.Arrow k => a `k` c -> a `k` d -> a `k` (c :* d)
  (&&&) = (A.&&&)
  -- OOPS. We can't give two default definitions for (&&&).
#endif

-- TODO: find some techniques for prettifying type operators.

-- type ProdOk k ok = (ProductCat k, ok ~ Ok k)

instance ProductCat (->) where
  type Prod (->) = (:*)
  exl     = fst
  exr     = snd
  (&&&)   = (A.&&&)
  (***)   = (A.***)
  first   = A.first
  second  = A.second
  lassocP = \ (a,(b,c)) -> ((a,b),c)
  rassocP = \ ((a,b),c) -> (a,(b,c))

-- | Apply to both parts of a product
twiceP :: (ProductCat k, Oks k [a,c]) 
       => (a `k` c) -> Prod k a a `k` (Prod k c c)
twiceP f = f *** f

-- | Operate on left-associated form
inLassocP :: forall k a b c a' b' c'.
             -- (ProductCat k, Ok6 k a b c a' b' c') 
             -- Needs :set -fconstraint-solver-iterations=5 or greater:
             (ProductCat k, Oks k [a,b,c,a',b',c'])
          => Prod k (Prod k a b) c `k` Prod k (Prod k a' b') c'
          -> Prod k a (Prod k b c) `k` (Prod k a' (Prod k b' c'))
inLassocP = rassocP <~ lassocP
              <+ (inOpLR @(Prod k) @(Ok k) @a  @b  @c ***
                  inOpLR @(Prod k) @(Ok k) @a' @b' @c')

-- | Operate on right-associated form
inRassocP :: forall a b c a' b' c' k.
--              (ProductCat k, Ok6 k a b c a' b' c') 
             (ProductCat k, Oks k [a,b,c,a',b',c'])
          => Prod k a (Prod k b c) `k` (Prod k a' (Prod k b' c'))
          -> Prod k (Prod k a b) c `k` Prod k (Prod k a' b') c'
inRassocP = lassocP <~ rassocP
              <+ (inOpLR @(Prod k) @(Ok k) @a  @b  @c ***
                  inOpLR @(Prod k) @(Ok k) @a' @b' @c')

transposeP :: forall k a b c d. (ProductCat k, Oks k [a,b,c,d])
           => Prod k (Prod k a b) (Prod k c d) `k` Prod k (Prod k a c) (Prod k b d)
transposeP = (exl.exl &&& exl.exr) &&& (exr.exl &&& exr.exr)
  <+ okProd @k @(Prod k a b) @(Prod k c d)
  <+ okProd @k @c @d
  <+ okProd @k @a @b
  <+ okProd @k @b @d
  <+ okProd @k @a @c

-- | Inverse to '(&&&)'
unfork :: forall k a c d. (ProductCat k, Oks k [a,c,d]) 
       => (a `k` Prod k c d) -> (a `k` c, a `k` d)
unfork f = (exl . f, exr . f)  <+ okProd @k @c @d

instance Monad m => ProductCat (Kleisli m) where
  type Prod (Kleisli m) = (:*)
  exl   = arr exl
  exr   = arr exr
  dup   = arr dup
  (&&&) = inNew2 forkK
  (***) = inNew2 crossK

-- Underlies '(&&&)' on Kleisli arrows
forkK :: Applicative m => (a -> m c) -> (a -> m d) -> (a -> m (c :* d))
(f `forkK` g) a = liftA2 (,) (f a) (g a)

-- Underlies '(***)' on Kleisli arrows
crossK :: Applicative m => (a -> m c) -> (b -> m d) -> (a :* b -> m (c :* d))
(f `crossK` g) (a,b) = liftA2 (,) (f a) (g b)

{--------------------------------------------------------------------
    Coproducts
--------------------------------------------------------------------}

okCoprod :: forall k a b. OpCon (Coprod k) (Ok k)
         => Ok k a && Ok k b |- Ok k (Coprod k a b)
okCoprod = inOp

infixr 2 +++, |||

-- | Category with coproduct.
class (OpCon (Coprod k) (Ok k), Category k) => CoproductCat k where
  type Coprod k :: u -> u -> u
  -- type Coprod k = (:+)
  inl :: Oks k [a,b] => a `k` Coprod k a b
  inr :: Oks k [a,b] => b `k` Coprod k a b
  jam :: Oks k '[a] => Coprod k a a `k` a
  jam = id ||| id
  swapS :: forall a b. Oks k [a,b] => Coprod k a b `k` Coprod k b a
  swapS = inr ||| inl
          <+ okCoprod @k @b @a
  (+++) :: forall a b c d. Oks k [a,b,c,d] 
        => (c `k` a) -> (d `k` b) -> (Coprod k c d `k` Coprod k a b)
  f +++ g = inl . f ||| inr . g
            <+ okCoprod @k @a @b
  (|||) :: forall a c d. Oks k [a,c,d] 
        => (c `k` a) -> (d `k` a) -> (Coprod k c d `k` a)
#ifndef DefaultCat
  f ||| g = jam . (f +++ g)
          <+ okCoprod @k @a @a
          <+ okCoprod @k @c @d
#endif
  left  :: forall a a' b. Oks k [a,b,a'] 
        => (a `k` a') -> (Coprod k a b `k` Coprod k a' b)
  left  = (+++ id)
  right :: forall a b b'. Oks k [a,b,b'] 
        => (b `k` b') -> (Coprod k a b `k` Coprod k a b')
  right = (id +++)
  lassocS :: forall a b c. Oks k [a,b,c]
          => Coprod k a (Coprod k b c) `k` Coprod k (Coprod k a b) c
  lassocS = inl.inl ||| (inl.inr ||| inr)
            <+ inOpL' @(Coprod k) @(Ok k) @a @b @c
            <+ okCoprod @k    @b @c
  rassocS :: forall a b c. Oks k [a,b,c]
          => Coprod k (Coprod k a b) c `k` Coprod k a (Coprod k b c)
  rassocS = (inl ||| inr.inl) ||| inr.inr
            <+ inOpR' @(Coprod k) @(Ok k) @a @b @c
            <+ okCoprod @k @a @b
#ifdef DefaultCat
  default inl :: A.ArrowChoice k => a `k` Coprod k a b
  inl = arr inl
  default inr :: A.ArrowChoice k => b `k` Coprod k a b
  inr = arr inr
  default (|||) :: A.ArrowChoice k => (a `k` c) -> (b `k` c) -> (Coprod k a b `k` c)
  (|||) = (A.|||)
  -- OOPS. We can't give two default definitions for (|||).
#endif
  {-# MINIMAL inl, inr, ((|||) | ((+++), jam)) #-}

-- type CoprodOk k ok = (CoproductCat k, ok ~ Ok k)

instance CoproductCat (->) where
  type Coprod (->) = (:+)
  inl   = Left
  inr   = Right
  (|||) = (A.|||)
  (+++) = (A.+++)
  left  = A.left
  right = A.right


-- | Operate on left-associated form
inLassocS :: forall k a b c a' b' c'.
             -- (CoproductCat k, Ok6 k a b c a' b' c') 
             (CoproductCat k, Oks k [a,b,c,a',b',c'])
          => Coprod k (Coprod k a b) c `k` Coprod k (Coprod k a' b') c'
          -> Coprod k a (Coprod k b c) `k` (Coprod k a' (Coprod k b' c'))
inLassocS = rassocS <~ lassocS
            <+ (inOpLR @(Coprod k) @(Ok k) @a  @b  @c ***
                inOpLR @(Coprod k) @(Ok k) @a' @b' @c')

-- | Operate on right-associated form
inRassocS :: forall a b c a' b' c' k.
             -- (CoproductCat k, Ok6 k a b c a' b' c') 
             (CoproductCat k, Oks k [a,b,c,a',b',c'])
          => Coprod k a (Coprod k b c) `k` (Coprod k a' (Coprod k b' c'))
          -> Coprod k (Coprod k a b) c `k` Coprod k (Coprod k a' b') c'
inRassocS = lassocS <~ rassocS
            <+ (inOpLR @(Coprod k) @(Ok k) @a  @b  @c ***
                inOpLR @(Coprod k) @(Ok k) @a' @b' @c')

transposeS :: forall k a b c d. (CoproductCat k, Oks k [a,b,c,d])
           => Coprod k (Coprod k a b) (Coprod k c d) `k` Coprod k (Coprod k a c) (Coprod k b d)
transposeS = (inl.inl ||| inr.inl) ||| (inl.inr ||| inr.inr)
  <+ okCoprod @k @(Coprod k a c) @(Coprod k b d)
  <+ okCoprod @k @c @d
  <+ okCoprod @k @a @b
  <+ okCoprod @k @b @d
  <+ okCoprod @k @a @c

-- | Inverse to '(|||)'
unjoin :: forall k a c d. (CoproductCat k, Oks k [a,c,d]) 
       => (Coprod k c d `k` a) -> (c `k` a, d `k` a)
unjoin f = (f . inl, f . inr)  <+ okCoprod @k @c @d

{--------------------------------------------------------------------
    Distributive
--------------------------------------------------------------------}

class (ProductCat k, CoproductCat k) => DistribCat k where
  distl :: forall a u v. Oks k [a,u,v]
        => Prod k a (Coprod k u v) `k` Coprod k (Prod k a u) (Prod k a v)
  distr :: forall u v b. Oks k [u,v,b]
        => Prod k (Coprod k u v) b `k` Coprod k (Prod k u b) (Prod k v b)
  distl = (swapP +++ swapP) . distr . swapP
    <+ okProd   @k @(Coprod k u v) @a
    <+ okCoprod @k @(Prod k u a) @(Prod k v a)
    <+ okProd   @k @u @a
    <+ okProd   @k @v @a
    <+ okCoprod @k @(Prod k a u) @(Prod k a v)
    <+ okProd   @k @a @u
    <+ okProd   @k @a @v
    <+ okProd   @k @a @(Coprod k u v)
    <+ okCoprod @k @u @v
  distr = (swapP +++ swapP) . distl . swapP
    <+ okProd   @k @b @(Coprod k u v)
    <+ okCoprod @k @(Prod k b u) @(Prod k b v)
    <+ okProd   @k @b @u
    <+ okProd   @k @b @v
    <+ okCoprod @k @(Prod k u b) @(Prod k v b)
    <+ okProd   @k @u @b
    <+ okProd   @k @v @b
    <+ okProd   @k @(Coprod k u v) @b
    <+ okCoprod @k @u @v
  {-# MINIMAL distl | distr #-}

-- | Inverse to 'distl': @(a * u) + (a * v) --> a * (u + v)@
undistl :: forall k a u v. (ProductCat k, CoproductCat k, Oks k [a,u,v])
        => Coprod k (Prod k a u) (Prod k a v) `k` Prod k a (Coprod k u v)
undistl = (exl ||| exl) &&& (exr +++ exr)
  <+ okCoprod @k @(Prod k a u) @(Prod k a v)
  <+ okProd   @k @a @u
  <+ okProd   @k @a @v
  <+ okCoprod @k @u @v

-- | Inverse to 'distr': @(u * b) + (v * b) --> (u + v) * b@
undistr :: forall k u v b. (ProductCat k, CoproductCat k, Oks k [u,v,b])
        => Coprod k (Prod k u b) (Prod k v b) `k` Prod k (Coprod k u v) b
undistr = (exl +++ exl) &&& (exr ||| exr)
  <+ okCoprod @k @(Prod k u b) @(Prod k v b)
  <+ okCoprod @k @u @v
  <+ okProd   @k @u @b
  <+ okProd   @k @v @b

{--------------------------------------------------------------------
    Exponentials
--------------------------------------------------------------------}

okExp :: forall k a b. OpCon (Exp k) (Ok k)
      => Ok k a && Ok k b |- Ok k (Exp k a b)
okExp = inOp

class (OpCon (Exp k) (Ok k), ProductCat k) => ClosedCat k where
  type Exp k :: u -> u -> u
  apply   :: forall a b. Oks k [a,b] => Prod k (Exp k a b) a `k` b
  apply = uncurry id
          <+ okExp @k @a @b
  curry   :: Oks k [a,b,c] => (Prod k a b `k` c) -> (a `k` Exp k b c)
  uncurry :: forall a b c. Oks k [a,b,c]
          => (a `k` Exp k b c)  -> (Prod k a b `k` c)
  uncurry g = apply . first g
              <+ okProd @k @(Exp k b c) @b
              <+ okProd @k @a @b
              <+ okExp @k @b @c
  {-# MINIMAL curry, (apply | uncurry) #-}

--   apply   :: (Oks k [a,b], p ~ Prod k, e ~ Exp k) => ((a `e` b) `p` a) `k` b

instance ClosedCat (->) where
  type Exp (->) = (->)
  apply   = P.uncurry ($)
  curry   = P.curry
  uncurry = P.uncurry

#if 1
applyK   ::            Kleisli m (Kleisli m a b :* a) b
curryK   :: Monad m => Kleisli m (a :* b) c -> Kleisli m a (Kleisli m b c)
uncurryK :: Monad m => Kleisli m a (Kleisli m b c) -> Kleisli m (a :* b) c

applyK   = pack (apply . first unpack)
curryK   = inNew $ \ h -> return . pack . curry h
uncurryK = inNew $ \ f -> \ (a,b) -> f a >>= ($ b) . unpack

instance Monad m => ClosedCat (Kleisli m) where
  type Exp (Kleisli m) = Kleisli m
  apply   = applyK
  curry   = curryK
  uncurry = uncurryK
#else
instance Monad m => ClosedCat (Kleisli m) where
  type Exp (Kleisli m) = Kleisli m
  apply   = pack (apply . first unpack)
  curry   = inNew $ \ h -> return . pack . curry h
  uncurry = inNew $ \ f -> \ (a,b) -> f a >>= ($ b) . unpack
#endif

class (Category k, Ok k (Unit k)) => TerminalCat k where
  type Unit k :: u
  it :: Ok k a => a `k` Unit k

instance TerminalCat (->) where
  type Unit (->) = ()
  it = const ()

instance Monad m => TerminalCat (Kleisli m) where
  type Unit (Kleisli m) = ()
  it = arr it

-- -- | Categories with constant arrows (generalized elements)
-- class ConstCat k where
--   konst :: forall a b. Oks k [a,b] => b -> (a `k` b)

-- instance ConstCat (->) where konst = const

-- instance Monad m => ConstCat (Kleisli m) where konst b = arr (const b)

-- class ApplyToCat k where
--   applyTo :: Oks k [a,b] => a -> ((a -> b) `k` b)

-- Do I want `Exp k a b` in place of `a -> b`?
-- LMap seems to want ->.

-- class ClosedCat k => ApplyToCat k where
--   applyTo :: Oks k [a,b] => a -> (Exp k a b `k` b)

#if 0

class Category k => UnsafeArr k where
  unsafeArr :: Oks k [a,b] => (a -> b) -> a `k` b

instance UnsafeArr (->) where
  unsafeArr = A.arr

instance Monad m => UnsafeArr (Kleisli m) where
  unsafeArr = A.arr
  
#endif

constFun :: forall k p a b. (ClosedCat k, Oks k [p,a,b])
         => (a `k` b) -> (p `k` Exp k a b)
constFun f = curry (f . exr)
             <+ okProd @k @p @a

--        f        :: a `k` b
--        f . exl  :: Prod k p a `k` b
-- curry (f . exl) :: p `k` (Exp k a b)

-- Combine with currying:

constFun2 :: forall k p a b c. (ClosedCat k, Oks k [p,a,b,c])
          => (Prod k a b `k` c) -> (p `k` (Exp k a (Exp k b c)))
constFun2 = constFun . curry
            <+ okExp @k @b @c

unitFun :: forall k a b. (ClosedCat k, TerminalCat k, Oks k [a,b])
        => (a `k` b) -> (Unit k `k` (Exp k a b))
unitFun = constFun

unUnitFun :: forall k p a. (ClosedCat k, TerminalCat k, Oks k [p,a]) =>
             (Unit k `k` Exp k p a) -> (p `k` a)
unUnitFun g = uncurry g . (it &&& id)
              <+ okProd @k @(Unit k) @p

{--------------------------------------------------------------------
    Constant arrows
--------------------------------------------------------------------}

#if 0
  
class TerminalCat k => ConstCat k where
  const :: Oks k [a,b] => b -> (a `k` b)
  const b = unitArrow b . it
  unitArrow  :: Ok k b => b -> Unit k `k` b
  unitArrow = const
  {-# MINIMAL const | unitArrow #-}

#elif 0

-- Alternatively, make `b` a parameter to `ConstCat`:

class (TerminalCat k, Ok k b) => ConstCat k b where
  unitArrow  :: b -> Unit k `k` b
  const :: Ok k a => b -> (a `k` b)
  const b = unitArrow b . it
  unitArrow = const
  {-# MINIMAL unitArrow | const #-}

#elif 0

-- Associated type for the codomain

class (TerminalCat k, Ok k (ConstObj k b)) => ConstCat k b where
  type ConstObj k b
  type ConstObj k b = b
  unitArrow  :: b -> (Unit k `k` ConstObj k b)
  const :: Ok k a => b -> (a `k` ConstObj k b)
  const b = unitArrow b . it
  unitArrow = const
  {-# MINIMAL unitArrow | const #-}

#else

-- Drop ConstObj for now

type ConstObj k b = b

class (TerminalCat k, Ok k (ConstObj k b)) => ConstCat k b where
--   type ConstObj k b
--   type ConstObj k b = b
  unitArrow  :: b -> (Unit k `k` ConstObj k b)
  const :: Ok k a => b -> (a `k` ConstObj k b)
  const b = unitArrow b . it
  unitArrow = const
  {-# MINIMAL unitArrow | const #-}

#endif

instance ConstCat (->) b where const = const

instance Monad m => ConstCat (Kleisli m) b where const b = arr (const b)

-- For prims, use constFun instead.

-- Note that `ConstCat` is *not* poly-kinded. Since the codomain `b` is an
-- argument to `unitArrow` and `const`, `k :: * -> * -> *`. I'm uneasy
-- about this kind restriction, which would preclude some useful categories,
-- including linear maps and entailment. Revisit this issue later.

{--------------------------------------------------------------------
    Class aggregates
--------------------------------------------------------------------}

-- | Bi-cartesion (cartesian & co-cartesian) closed categories. Also lumps in
-- terminal and distributive, though should probably be moved out.
type BiCCC k = (ClosedCat k, CoproductCat k, TerminalCat k, DistribCat k)

-- -- | 'BiCCC' with constant arrows.
-- type BiCCCC k p = (BiCCC k, ConstCat k p {-, RepCat k, LoopCat k, DelayCat k-})


{--------------------------------------------------------------------
    Some categories
--------------------------------------------------------------------}

-- Exactly one arrow for each pair of objects.
data U2 (a :: *) (b :: *) = U2

-- Is there a standard name and/or generalization?
-- Seems to be called "indiscrete" or "chaotic"

instance Category U2 where
  id = U2
  U2 . U2 = U2

instance ProductCat U2 where
  type Prod U2 = (:*)
  exl = U2
  exr = U2
  U2 &&& U2 = U2

instance CoproductCat U2 where
  type Coprod U2 = (:+)
  inl = U2
  inr = U2
  U2 ||| U2 = U2

instance ClosedCat U2 where
  type Exp U2 = (->)
  apply = U2
  curry U2 = U2
  uncurry U2 = U2

instance TerminalCat U2 where
  type Unit U2 = () -- ??
  it = U2

-- instance ConstCat U2 where konst = const U2

{--------------------------------------------------------------------
    Natural transformations
--------------------------------------------------------------------}

-- ↠, \twoheadrightarrow

data a --> b = NT (forall (t :: *). a t -> b t)

-- instance Newtype (a --> b) where
--   -- Illegal polymorphic type: forall t. a t -> b t
--   type O (a --> b) = forall t. a t -> b t
--   pack h = NT h
--   unpack (NT h) = h

instance Category (-->) where
  id = NT id
  NT g . NT f = NT (g . f)

instance ProductCat (-->) where
  type Prod (-->) = (:*:)
  exl = NT (\ (a :*: _) -> a)
  exr = NT (\ (_ :*: b) -> b)
  NT f &&& NT g = NT (pack . (f &&& g))

instance CoproductCat (-->) where
  type Coprod (-->) = (:+:)
  inl = NT L1
  inr = NT R1
  NT a ||| NT b = NT ((a ||| b) . unpack)

instance ClosedCat (-->) where
  type Exp (-->) = (+->)
  apply = NT (\ (ab :*: a) -> unpack ab a)
  curry   (NT f) = NT (\ a -> pack (\ b -> f (a :*: b)))
  uncurry (NT g) = NT (\ (a :*: b) -> unpack (g a) b)

-- With constraint element types

data NTC con a b = NTC (forall (t :: *). con t => a t -> b t)

instance Category (NTC con) where
  id = NTC id
  NTC g . NTC f = NTC (g . f)

instance ProductCat (NTC con) where
  type Prod (NTC con) = (:*:)
  exl = NTC (\ (a :*: _) -> a)
  exr = NTC (\ (_ :*: b) -> b)
  NTC f &&& NTC g = NTC (pack . (f &&& g))

instance CoproductCat (NTC con) where
  type Coprod (NTC con) = (:+:)
  inl = NTC L1
  inr = NTC R1
  NTC a ||| NTC b = NTC ((a ||| b) . unpack)

instance ClosedCat (NTC con) where
  type Exp (NTC con) = (+->)
  apply = NTC (\ (ab :*: a) -> unpack ab a)
  curry   (NTC f) = NTC (\ a -> pack (\ b -> f (a :*: b)))
  uncurry (NTC g) = NTC (\ (a :*: b) -> unpack (g a) b)

-- An unquantified version

data UT (t :: *) a b = UT { unUT :: a t -> b t }

instance Newtype (UT t a b) where
  type O (UT t a b) = a t -> b t
  pack = UT
  unpack = unUT

instance Category (UT t) where
  id = UT id
  UT g . UT f = UT (g . f)

instance ProductCat (UT t) where
  type Prod (UT t) = (:*:)
  exl = UT (\ (a :*: _) -> a)
  exr = UT (\ (_ :*: b) -> b)
  UT f &&& UT g = UT (pack . (f &&& g))

instance CoproductCat (UT t) where
  type Coprod (UT t) = (:+:)
  inl = UT L1
  inr = UT R1
  UT a ||| UT b = UT ((a ||| b) . unpack)

instance ClosedCat (UT t) where
  type Exp (UT t) = (+->)
  apply = UT (\ (ab :*: a) -> unpack ab a)
  curry   (UT f) = UT (\ a -> pack (\ b -> f (a :*: b)))
  uncurry (UT g) = UT (\ (a :*: b) -> unpack (g a) b)

-- With constraints

data UTC con (t :: *) a b = UTC (con t => a t -> b t)

instance Category (UTC con t) where
  id = UTC id
  UTC g . UTC f = UTC (g . f)

instance ProductCat (UTC con t) where
  type Prod (UTC con t) = (:*:)
  exl = UTC (\ (a :*: _) -> a)
  exr = UTC (\ (_ :*: b) -> b)
  UTC f &&& UTC g = UTC (pack . (f &&& g))

instance CoproductCat (UTC con t) where
  type Coprod (UTC con t) = (:+:)
  inl = UTC L1
  inr = UTC R1
  UTC a ||| UTC b = UTC ((a ||| b) . unpack)

instance ClosedCat (UTC con t) where
  type Exp (UTC con t) = (+->)
  apply = UTC (\ (ab :*: a) -> unpack ab a)
  curry   (UTC f) = UTC (\ a -> pack (\ b -> f (a :*: b)))
  uncurry (UTC g) = UTC (\ (a :*: b) -> unpack (g a) b)

{--------------------------------------------------------------------
    Add constraints to a category
--------------------------------------------------------------------}

data Constrained (con :: u -> Constraint) (k :: u -> u -> *) a b =
  Constrained (a `k` b)

instance (OpCon op con, OpCon op con') => OpCon op (con &+& con') where
  inOp :: forall a b. (con &+& con') a && (con &+& con') b |- (con &+& con') (a `op` b)
  inOp = Sub $ Dict <+ inOp @op @con @a @b <+ inOp @op @con' @a @b

instance Category k => Category (Constrained con k) where
  type Ok (Constrained con k) = Ok k &+& con
  id = Constrained id
  Constrained g . Constrained f = Constrained (g . f)

instance (ProductCat k, OpCon (Prod k) con) => ProductCat (Constrained con k) where
  type Prod (Constrained con k) = Prod k
  exl = Constrained exl
  exr = Constrained exr
  Constrained f &&& Constrained g = Constrained (f &&& g)

instance (CoproductCat k, OpCon (Coprod k) con) => CoproductCat (Constrained con k) where
  type Coprod (Constrained con k) = Coprod k
  inl = Constrained inl
  inr = Constrained inr
  Constrained a ||| Constrained b = Constrained (a ||| b)

instance (ClosedCat k, OpCon (Prod k) con, OpCon (Exp k) con) => ClosedCat (Constrained con k) where
  type Exp (Constrained con k) = Exp k
  apply = Constrained apply
  curry   (Constrained f) = Constrained (curry f)
  uncurry (Constrained g) = Constrained (uncurry g)

{--------------------------------------------------------------------
    Entailment
--------------------------------------------------------------------}

-- Copied from Data.Constraint:

-- instance Category (|-) where
--   id  = refl
--   (.) = trans

instance Category (|-) where
  id = Sub Dict
  g . f = Sub $ Dict <+ g <+ f

#if 0
instance ProductCat (|-) where
  type Prod (|-) = (&&)
  exl = weaken1 . unconj
  exr = weaken2 . unconj
  dup = conj . contract
  f &&& g = conj . (f K.&&& g)
  f *** g = conj . (f K.*** g) . unconj
#else
instance ProductCat (|-) where
  type Prod (|-) = (&&)
  exl = Sub Dict
  exr = Sub Dict
  dup = Sub Dict
  f &&& g = Sub $ Dict <+ f <+ g
  f *** g = Sub $ Dict <+ f <+ g
#endif

#if 0

-- infixr 1 :==>
-- type family (:==>) (a :: Constraint) :: Constraint where
--   a && b :==> c = a |- b :==> c

-- infixr 1 :==>
-- type family a :==> b where
--   (a && b) :==> c = a :==> b :==> c -- UndecidableInstances
--   a :==> b = Entails' a b

-- class Entails' a b where entails' :: a |- b

infixr 1 |--

-- data (|--) :: Constraint -> Constraint -> * where
--   Entails :: Entails' a b => a |-- b
--   AndEnt  :: Entails' (a && b) c => a |-- b :==> c

data (|--) :: Constraint -> Constraint -> * where
  Entails :: (a |- b) -> (a |-- b)
  AndEnt  :: (a |-- b |--* c) -> (a && b |-- c)

class a |--* b where entails' :: a |-- b

instance Category (|--) where
  id = Entails id
  Entails bc . Entails ab = Entails (bc . ab)

modusPonens :: forall a b. (a |--* b) && a |-- b
modusPonens =
  Entails (Sub (case entails' :: a |-- b of
                  Entails (Sub Dict :: a |- b) -> Dict
                  AndEnt abc -> undefined))  -- working here

-- modusPonens :: forall a b. (a :==> b) && a |- b
-- modusPonens = Sub (case entails' :: a |- b of Sub Dict -> Dict) -- works

-- instance ClosedCat (|--) where
--   type Exp (|-) = (|--*)
--   apply :: forall a b. (a |--* b) && a |-- b
--   apply = modusPonens
-- --   apply = Sub (case entails :: a |- b of Sub Dict -> Dict)
-- --   curry :: (a && b |- c) -> (a |- b :==> c)
-- --   curry (Sub Dict) = Sub Dict

#elif 0
infixr 1 :==>
class a :==> b where entails :: a |- b

foo :: forall a b. (a :==> b) && a => Dict b
foo | Sub Dict <- (entails :: a |- b) = Dict     -- works
-- foo = case entails :: a |- b of Sub Dict -> Dict -- works

foo' :: forall a b. (a :==> b) && a |- b
-- foo' = Sub (foo @a @b) -- works
-- foo' | Sub Dict <- (entails :: a |- b) = Sub Dict -- nope
foo' = Sub (case entails :: a |- b of Sub Dict -> Dict) -- works
-- foo' = case entails :: a |- b of Sub Dict -> Sub Dict -- nope

modusPonens :: forall a b. (a :==> b) && a |- b
modusPonens = Sub (case entails :: a |- b of Sub Dict -> Dict) -- works

-- instance ClosedCat (|-) where
--   type Exp (|-) = (:==>)
--   apply :: forall a b. (a :==> b) && a |- b
--   apply = Sub (case entails :: a |- b of Sub Dict -> Dict)
--   curry :: (a && b |- c) -> (a |- b :==> c)
--   curry (Sub Dict) = Sub Dict

-- f :: a && b |- c
-- Sub Dict :: a && b |- c
-- Dict :: (a,b) => c
  
--   apply = modusPonens

--   apply = Sub Dict --  <+ (entails :: a |- b)

--   apply = Sub Dict <+ (entails :: a |- b)

--   curry   :: (a && b |- c) -> (a |- b :==> c)
--   curry abc = Sub Dict 

--   curry   :: (a && b |- c) -> (a |- Exp (|-) b c)


--   apply   :: Oks k [a,b]   => Prod k (Exp k a b) a `k` b
--   curry   :: Oks k [a,b,c] => (Prod k a b `k` c) -> (a `k` Exp k b c)
--   uncurry :: forall a b c. Oks k [a,b,c]
--           => (a `k` Exp k b c)  -> (Prod k a b `k` c)

#elif 0

data (|--) :: Constraint -> Constraint -> * where
  Entails  ::      (a      |-  b) -> (a |-- b)
  CurryEnt :: a => (a && b |-- c) -> (b |-- c)

-- -- Equivalently,
-- data b |-- c =
--     Entails (b |- c)
--   | forall a. a => CurryEnt (a && b |- c) 

entails :: (b |-- c) -> (b |- c)
entails (Entails  bc ) = bc
entails (CurryEnt abc) = Sub (Dict <+ entails abc)

-- entails (CurryEnt abc) = Sub Dict <+ entails abc  -- could not deduce b

-- entails (CurryEnt (Sub Dict)) = undefined  -- could not deduce b

instance Category (|--) where
  id = Entails id
  g . f = Entails (entails g . entails f)

instance ProductCat (|--) where
  type Prod (|--) = (&&)
  exl = Entails exl
  exr = Entails exr
  f &&& g = Entails (entails f &&& entails g)

class HasEntails b c where entailIt :: b |-- c

instance ClosedCat (|--) where
  type Exp (|--) = HasEntails
  apply :: HasEntails a b && a |-- b
  apply = CurryEnt (\ abc -> ...)

a holds
abc :: a && b |-- c
entails abc :: a && b |- c

need :: x


#elif 0

closeCon :: a => (a && b |- c) -> (b |- c)
closeCon abc = Sub (Dict <+ abc)

class Entails a b where entails :: a |- b

instance ClosedCat (|-) where
  type Exp (|-) = Entails
  apply :: forall a b. Entails a b && a |- b
  apply = Sub (Dict <+ (entails :: a |- b))
  curry :: forall a b c. (a && b |- c) -> (a |- Entails b c)
  curry = undefined

#endif

{--------------------------------------------------------------------
    Memo tries
--------------------------------------------------------------------}

instance Category (:->:) where
  type Ok (:->:) = HasTrie
  id = idTrie
  (.) = (@.@)

instance ProductCat (:->:) where
  type Prod (:->:) = (:*)
  exl   = trie exl
  exr   = trie exr
  (&&&) = inTrie2 (&&&)

instance CoproductCat (:->:) where
  type Coprod (:->:) = (:+)
  inl   = trie inl
  inr   = trie inr
  (|||) = inTrie2 (|||)

instance OpCon (:*) HasTrie where inOp = Sub Dict
instance OpCon (:+) HasTrie where inOp = Sub Dict

#if 0
instance OpCon (:->:) HasTrie where inOp = Sub Dict

instance ClosedCat (:->:) where
  type Exp (:->:) = (:->:)
  apply :: forall a b. Ok (:->:) [a,b] => Exp (:->:) a b :* a :->: b
  apply = trie (apply . first untrie)
    <+ inOp @(Exp (:->:)) @(Ok (:->:)) @a @b
  curry = unpack
  uncurry = pack
  -- apply = (pack.trie) (\ (Memod t, a) -> untrie t a)
#else

-- instance ClosedCat (:->:) where
--   type Exp (:->:) = (->)
--   apply :: forall a b. C2 HasTrie a b => (a -> b) :* a :->: b

#endif

-- -- Idea: Use (->) for Exp (:->:)

-- curry :: ((a :* b) :->: c) -> (a :-> (b -> c))
-- uncurry :: (a :-> (b -> c)) -> ((a :* b) :->: c)

#if 1

{--------------------------------------------------------------------
    Optional memoization
--------------------------------------------------------------------}

-- Some operations we can't or don't want to memoize, e.g., apply, exl, exr,
-- inl, inr.

infixr 1 :->?
data a :->? b = Fun (a -> b) | Trie (a :->: b)

untrie' :: HasTrie a => (a :->? b) -> (a -> b)
untrie' (Fun  f) = f
untrie' (Trie t) = untrie t

trie' :: HasTrie a => (a -> b) -> (a :->? b)
trie' = Trie . trie

-- | Apply a unary function inside of a trie
inTrie' :: (HasTrie a, HasTrie c)
        => ((a  ->  b) -> (c  ->  d))
        -> ((a :->? b) -> (c :->? d))
inTrie' = trie' <~ untrie'

-- | Apply a binary function inside of a trie
inTrie2' :: (HasTrie a, HasTrie c, HasTrie e) 
         => ((a  ->  b) -> (c  ->  d) -> (e  ->  f))
         -> ((a :->? b) -> (c :->? d) -> (e :->? f))
inTrie2' = inTrie' <~ untrie'

instance Category (:->?) where
  type Ok (:->?) = HasTrie
  id = Fun id
  (.) = inTrie2' (.)

--   Fun g . Fun f = Fun (g . f)
--   g . f = trie' (untrie' g . untrie' f)

instance ProductCat (:->?) where
  type Prod (:->?) = (:*)
  exl = Fun exl
  exr = Fun exr
  (&&&) = inTrie2' (&&&)

--   f &&& g = trie' (untrie' f &&& untrie' g)

-- instance ClosedCat (:->?) where
--   type Exp (:->?) = (->)
--   apply = Fun apply
--   curry f = Fun (curry (untrie' f))
--   uncurry g = Fun (uncurry (untrie' g))

-- * No instance for `(OpCon (->) HasTrie)`
--     arising from the superclasses of an instance declaration

-- TODO: revisit

--   apply :: C2 HasTrie a b => (a -> b) :* a :->? b
--   curry :: C3 HasTrie a b c => (a :* b :->? c) -> (a :->? (b -> c))
--   uncurry :: C3 HasTrie a b c => (a :->? (b -> c)) -> (a :* b :->? c)

#endif

{--------------------------------------------------------------------
    Functors
--------------------------------------------------------------------}

-- A functor maps arrows in one category to arrows in another, systematically
-- transforming the domain and codomain.

infixr 8 %

-- From <https://hackage.haskell.org/package/data-category>. Changes:
-- 
-- *  Rename ftag from to f
-- *  Remove `f` argument from `(%)`
-- *  Generalized object kinds from * to u and v

#if 0

-- | Functors map objects and arrows.
class (Category (FDom f), Category (FCod f)) => FunctorC f where
  type DomObj f
  type CodObj f
  type FDom f :: DomObj f -> DomObj f -> *
  type FCod f :: CodObj f -> CodObj f -> *
  type OkF f (a :: DomObj f) (b :: DomObj f) :: Constraint
  type OkF f a b = () 
  -- | @%@ maps objects.
  type f % (a :: DomObj f) :: CodObj f
  -- | @fmapC@ maps arrows.
  fmapC :: OkF f a b => FDom f a b -> FCod f (f % a) (f % b)
  -- Laws:
  -- fmapC id == id
  -- fmapC (q . p) == fmapC q . fmapC p

class (ProductCat (FDom f), ProductCat (FCod f), FunctorC f)
   => CartesianFunctorC f where
  distribProd :: forall a b. () |- f % Prod (FDom f) a b ~ Prod (FCod f) (f % a) (f % b)
  -- Laws:
  -- f % Prod (FDom f) a b ~ Prod (FCod f) (f % a) (f % b) 
  -- fmapC exl == exl
  -- fmapC exr == exr
  -- fmapC (q &&& p) = fmapC q &&& fmapC p

-- I'd like to express the object structure as a superclass constraint, but it's
-- universally quantified over types. Noodling.

-- Haskell-style functor

instance Functor f => FunctorC f (->) (->) where
  type f % a = f a
  fmapC = fmap

#else

-- | Functors map objects and arrows.
class (Category k, Category k'{-, OkTarget f k k'-})
   => FunctorC f (k :: u -> u -> *) (k' :: v -> v -> *) {-| f -> k k'-} where
#if 0
  type OkF f :: u -> Constraint
  type OkF f = Yes1
#elif 0
  type OkF f (a :: u) :: Constraint
  type OkF f a = () 
#elif 0
  type OkF f (a :: u) (b :: u) :: Constraint
  type OkF f a b = () 
#endif
  -- | @%@ maps objects.
  type f % (a :: u) :: v
  -- | @fmapC@ maps arrows.
  -- fmapC :: OkF f a b => (a `k` b) -> ((f % a) `k'` (f % b))
  fmapC :: -- OkF f a b
           (Oks k [a,b], Oks k' [f % a, f % b])
        => (a `k` b) -> ((f % a) `k'` (f % b))
  -- Laws:
  -- fmapC id == id
  -- fmapC (q . p) == fmapC q . fmapC p

-- class OkTarget f (cat :: u -> u -> *) (cat' :: v -> v -> *) where
--   okTarget :: forall a. Ok cat a |- Ok cat' (f % a)

-- (<+) :: a => (b => r) -> (a |- b) -> r

-- okTarg :: 

id' :: (Category k, Ok k a) => a `k` a
id' = id
{-# NOINLINE [1] id' #-}

comp' :: (Category k, Oks k [a,b,c]) => (b `k` c) -> (a `k` b) -> (a `k` c)
comp' = (.)
{-# NOINLINE [1] comp' #-}

-- fmapC

-- fmapComp :: forall h k k' a b c.
--             (b `k` c) -> (a `k` b) -> [(h % a) `k'` (h % c)]
-- fmapComp g f = [ fmapC (g . f)
--                , fmapC g . fmapC f
--                ]

fmapComp :: forall k k' a b c h.
            (FunctorC h k k', Oks k [a,b,c], Oks k' [h % a,h % b,h % c])
         => (b `k` c) -> (a `k` b) -> [(h % a) `k'` (h % c)]
fmapComp g f = [ fmapC @h (g . f)
               , fmapC @h g . fmapC @h f
               ]

-- g :: b `k` c
-- f :: a `k` b
-- g . f :: a `k` c
-- fmapC (g . f) :: (h % a) `k'` (h %c)

{-# RULES

"fmapC id" fmapC id' = id'

-- "fmapC (g . f)" forall f g. fmapC (g `comp'` f) = fmapC g `comp'` fmapC f

--     • Could not deduce: (f0 % b) ~ (f % b)
--       from the context: (FunctorC f k2 k',
--                          Oks k2 '[a, b],
--                          Oks k' '[f % a, f % b],
--                          Category k2,
--                          Oks k2 '[a, b1, b])
--         bound by the RULE "fmapC (g . f)"
--         at /Users/conal/Haskell/concat/src/ConCat/Category.hs:1251:1-73
--       Expected type: k' (f0 % b1) (f % b)
--         Actual type: k' (f0 % b1) (f0 % b)
--       NB: ‘%’ is a type function, and may not be injective
--       The type variable ‘f0’ is ambiguous
--     • In the first argument of ‘comp'’, namely ‘fmapC g’
--       In the expression: fmapC g `comp'` fmapC f
--       When checking the transformation rule "fmapC (g . f)"
-- 
--     • Could not deduce: (f1 % a) ~ (f % a)
--       from the context: (FunctorC f k2 k',
--                          Oks k2 '[a, b],
--                          Oks k' '[f % a, f % b],
--                          Category k2,
--                          Oks k2 '[a, b1, b])
--         bound by the RULE "fmapC (g . f)"
--         at /Users/conal/Haskell/concat/src/ConCat/Category.hs:1251:1-73
--       Expected type: k' (f % a) (f0 % b1)
--         Actual type: k' (f1 % a) (f1 % b1)
--       NB: ‘%’ is a type function, and may not be injective
--       The type variable ‘f1’ is ambiguous
--     • In the second argument of ‘comp'’, namely ‘fmapC f’
--       In the expression: fmapC g `comp'` fmapC f
--       When checking the transformation rule "fmapC (g . f)"

-- "fmapC exl" fmapC exl = exl

--     • Could not deduce: (f % Prod k1 b b1) ~ Prod k' (f % b) b0
--       from the context: (FunctorC f k1 k',
--                          Oks k1 '[Prod k1 b b1, b],
--                          Oks k' '[f % Prod k1 b b1, f % b],
--                          ProductCat k1,
--                          Oks k1 '[b, b1])
--         bound by the RULE "fmapC exl"
--         at /Users/conal/Haskell/concat/src/ConCat/Category.hs:1253:1-27
--       Expected type: k' (f % Prod k1 b b1) (f % b)
--         Actual type: k' (Prod k' (f % b) b0) (f % b)
--       The type variable ‘b0’ is ambiguous
--     • In the expression: exl
--       When checking the transformation rule "fmapC exl"

 #-}

-- If I used the class methods in the rules, I'd get

-- src/ConCat/Category.hs:1241:1: warning: [-Winline-rule-shadowing] …
--     Rule "fmapC id" may never fire
--       because rule "Class op id" for ‘id’ might fire first
--     Probable fix: add phase [n] or [~n] to the competing rule

#if 0
  
-- Experiment: FunctorC *without* associated type family

class OkTarget {-(h :: *)-} (k :: u -> u -> *) (k' :: u -> u -> *) where
  okTarget :: forall a. Ok k a |- Ok k' a -- (h % a)

-- | Functors map objects and arrows.
class (Category k, Category k', OkTarget k k')
   => FunctorC' h (k :: u -> u -> *) (k' :: v -> v -> *) {-| h -> k k'-} where
  fmapC' :: Oks k [a,b] => h -> (a `k` b) -> (a `k'` b)
  -- Laws:
  -- fmapC h id == id
  -- fmapC h (q . p) == fmapC h q . fmapC h p

-- fmapId :: forall h k k' a. (FunctorC' h k k', Ok k a) => a `k'` a
-- fmapId = id' <+ okTarget @k @k' @a

-- fmapComp' :: forall k k' a b c h.
--              (FunctorC' h k k', Ok k a, Ok k b, Ok k c)
--           => h -> (b `k` c) -> (a `k` b) -> [a `k'` c]
-- fmapComp' h g f = [ fmapC' h (g . f)
--                   , fmapC' h g . fmapC' h f
--                   ]
-- --   -- <+ okTarget ...

-- ^^ Compiler stack overflow.

-- compF :: forall h k k' a b c.
--             (FunctorC' h k k', Oks k [a,b,c])
--          => (b `k` c) -> (a `k` b) -> (a `k'` c)
-- g `compF` f = fmapC' @h @k @k' g . fmapC' @h @k @k' f
--   -- <+ okTarget @h @k @k' @a

{-# RULES

-- "fmapC' id" forall h. fmapC' h id' = id'
-- "fmapC' (g . f)" forall h f g. fmapC' h (g . f) = fmapC' h g . fmapC' h f
-- "fmapC' exl" forall h. fmapC' h exl = exl

-- The second and third rules fail to type-check

 #-}

-- fmapComp' :: forall k k' a b c h.
--              (FunctorC' h k k', Oks k [a,b,c], Oks k' [a,b,c])
--           => (b `k` c) -> (a `k` b) -> [a `k'` c]
-- fmapComp' g f = [ fmapC' @h (g . f)
--                 , fmapC' @h g . fmapC' @h f
--                 ]


class (ProductCat cat, ProductCat cat', FunctorC f cat cat')
   => CartesianFunctorC f cat cat' where
  distribProd :: forall a b. () |- f % Prod cat a b ~ Prod cat' (f % a) (f % b)
  -- Laws:
  -- f % Prod cat a b ~ Prod cat' (f % a) (f % b) 
  -- fmapC exl == exl
  -- fmapC exr == exr
  -- fmapC (q &&& p) = fmapC q &&& fmapC p

#endif

-- I'd like to express the object structure as a superclass constraint, but it's
-- universally quantified over types. Noodling.

-- Haskell-style functor

data HFunctor (f :: * -> *)

instance Functor f => FunctorC (HFunctor f) (->) (->) where
  type HFunctor f % a = f a
  fmapC = fmap

-- instance OkTarget (HFunctor f) (->) (->) where
--   okTarget = Sub Dict

-- TODO: Does this instance overlap with others I'll want, or do the two (->)s
-- suffice to distinguish?

-- | Add a constraint
data Constrain con

instance Category k => FunctorC (Constrain con) k (Constrained con k) where
  type Constrain con % a = a
  fmapC = Constrained

#endif

{--------------------------------------------------------------------
    Uncurrying --- move elsewhere
--------------------------------------------------------------------}

-- | Repeatedly uncurried version of a -> b
class Uncurriable a b where
  type UncDom a b
  type UncRan a b
  type UncDom a b = a
  type UncRan a b = b
  uncurries :: (a -> b) -> (UncDom a b -> UncRan a b)
  default uncurries :: (a -> b) -> (a -> b)
  uncurries = id

instance Uncurriable (a :* b) c => Uncurriable a (b -> c) where
  type UncDom a (b -> c) = UncDom (a :* b) c
  type UncRan a (b -> c) = UncRan (a :* b) c
  uncurries = uncurries . uncurry

instance Uncurriable a ()
instance Uncurriable a Bool
instance Uncurriable a Int
instance Uncurriable a Float
instance Uncurriable a Double
instance Uncurriable a (c :* d)
instance Uncurriable a (c :+ d)

{--------------------------------------------------------------------
    Other category subclasses, perhaps to move elsewhere
--------------------------------------------------------------------}

-- I don't think I want the general Kleisli instances for the rest.
-- For instance, for circuits, type BoolOf (:>) = Source Bool.

-- #define KleisliInstances

-- Adapted from Circat.Classes

class (ProductCat k, Ok k (BoolOf k)) => BoolCat k where
  type BoolOf k
  notC :: BoolOf k `k` BoolOf k
  andC, orC, xorC :: Prod k (BoolOf k) (BoolOf k) `k` BoolOf k

--     • Potential superclass cycle for ‘BoolCat’
--         one of whose superclass constraints is headed by a type family:
--           ‘Ok k bool’
--       Use UndecidableSuperClasses to accept this
--     • In the class declaration for ‘BoolCat’

instance BoolCat (->) where
  type BoolOf (->) = Bool
  notC = not
  andC = P.uncurry (&&)
  orC  = P.uncurry (||)
  xorC = P.uncurry (/=)

#ifdef KleisliInstances
instance Monad m => BoolCat (Kleisli m) where
  type BoolOf (Kleisli m) = Bool
  notC = arr notC
  andC = arr andC
  orC  = arr orC
  xorC = arr xorC
#endif

class Num a => NumCat k a where
  negateC :: a `k` a
  addC, subC, mulC :: Prod k a a `k` a
  powIC :: Prod k a Int `k` a

instance Num a => NumCat (->) a where
  negateC = negate
  addC    = uncurry (+)
  subC    = uncurry (-)
  mulC    = uncurry (*)
  powIC   = uncurry (^)

#ifdef Kleisli
instance (Monad m, Num a) => NumCat (Kleisli m) a where
  negateC = arr negateC
  addC    = arr addC
  subC    = arr subC
  mulC    = arr mulC
  powIC   = arr powIC
#endif

class Fractional a => FractionalCat k a where
  recipC :: a `k` a
  divideC :: Prod k a a `k` a

instance Fractional a => FractionalCat (->) a where
  recipC = recip
  divideC = uncurry (/)

#ifdef Kleisli
instance (Monad m, Fractional a) => FractionalCat (Kleisli m) a where
  recipC  = arr recipC
  divideC = arr divideC
#endif

-- HACK: generalize/replace/...
class Floating a => FloatingCat k a where
  expC, cosC, sinC :: a `k` a

instance Floating a => FloatingCat (->) a where
  expC = exp
  cosC = cos
  sinC = sin

#ifdef Kleisli
instance (Monad m, Floating a) => FloatingCat (Kleisli m) a where
  expC = arr expC
  cosC = arr cosC
  sinC = arr sinC
#endif

-- Stand-in for fromIntegral, avoiding the intermediate Integer in the Prelude
-- definition.
class (Integral a, Num b) => FromIntegralCat k a b where
  fromIntegralC :: a `k` b

instance (Integral a, Num b) => FromIntegralCat (->) a b where
  fromIntegralC = fromIntegral

#ifdef Kleisli
instance (Monad m, Integral a, Num b) => FromIntegralCat (Kleisli m) a b where
  fromIntegralC = arr fromIntegral
#endif

okTT :: forall k a. OpCon (Prod k) (Ok k) => Ok k a |- Ok k (Prod k a a)
okTT = okProd @k @a @a . dup

class (BoolCat k, Ok k a, Eq a) => EqCat k a where
  equal, notEqual :: Prod k a a `k` BoolOf k
  notEqual = notC . equal    <+ okTT @k @a
  equal    = notC . notEqual <+ okTT @k @a
  {-# MINIMAL equal | notEqual #-}

instance Eq a => EqCat (->) a where
  equal    = uncurry (==)
  notEqual = uncurry (/=)

#ifdef Kleisli
instance (Monad m, Eq a) => EqCat (Kleisli m) a where
  equal    = arr equal
  notEqual = arr notEqual
#endif

class (EqCat k a, Ord a) => OrdCat k a where
  lessThan, greaterThan, lessThanOrEqual, greaterThanOrEqual :: Prod k a a `k` BoolOf k
  greaterThan        = lessThan . swapP    <+ okTT @k @a
  lessThan           = greaterThan . swapP <+ okTT @k @a
  lessThanOrEqual    = notC . greaterThan  <+ okTT @k @a
  greaterThanOrEqual = notC . lessThan     <+ okTT @k @a
  {-# MINIMAL lessThan | greaterThan #-}

instance Ord a => OrdCat (->) a where
  lessThan           = uncurry (<)
  greaterThan        = uncurry (>)
  lessThanOrEqual    = uncurry (<=)
  greaterThanOrEqual = uncurry (>=)

#ifdef Kleisli
instance (Monad m, Ord a) => OrdCat (Kleisli m) a where
  lessThan           = arr lessThan
  greaterThan        = arr greaterThan
  lessThanOrEqual    = arr lessThanOrEqual
  greaterThanOrEqual = arr greaterThanOrEqual
#endif

class Ok k a => BottomCat k a where
  bottomC :: Unit k `k` a

instance BottomCat (->) a where bottomC = error "bottomC for (->) evaluated"

type IfT k a = Prod k (BoolOf k) (Prod k a a) `k` a

class (BoolCat k, Ok k a) => IfCat k a where
  ifC :: IfT k a

instance IfCat (->) a where
  ifC (i,(t,e)) = if i then t else e

#ifdef Kleisli
instance Monad m => IfCat (Kleisli m) a where
  ifC = arr ifC
#endif

unitIf :: forall k. (TerminalCat k, BoolCat k) => IfT k (Unit k)
unitIf = it <+ (inOpR @(Prod k) @(Ok k) @(BoolOf k) @(Unit k) @(Unit k))

okIf :: forall k a. BoolCat k => Ok k a |- Ok k (Prod k (BoolOf k) (Prod k a a)) && Ok k (Prod k a a)
okIf = inOpR' @(Prod k) @(Ok k) @(BoolOf k) @a @a . Sub Dict

prodIf :: forall k a b. (IfCat k a, IfCat k b) => IfT k (Prod k a b)
prodIf = (ifC . second (twiceP exl)) &&& (ifC . second (twiceP exr))
           <+ okIf @k @(Prod k a b)
           <+ okProd @k @a @b
           <+ okIf @k @a
           <+ okIf @k @b

#if 0

   prodIf
== \ (c,((a,b),(a',b'))) -> (ifC (c,(a,a')), ifC (c,(b,b')))
== (\ (c,((a,b),(a',b'))) -> ifC (c,(a,a'))) &&& ...
== (ifC . (\ (c,((a,b),(a',b'))) -> (c,(a,a')))) &&& ...
== (ifC . second (\ ((a,b),(a',b')) -> (a,a'))) &&& ...
== (ifC . second (twiceP exl)) &&& (ifC . second (twiceP exr))

#endif

-- funIf :: forall k a b. (ClosedCat k, IfCat k b) => IfT k (Exp k a b)
-- funIf = curry (ifC . (exl . exl &&& (half exl &&& half exr)))
--  where
--    half :: (u `k` Exp k a b) -> (Prod k (Prod k _bool u) a `k` b)
--    half h = apply . first (h . exr)

funIf :: forall k a b. (ClosedCat k, Ok k a, IfCat k b) => IfT k (Exp k a b)
funIf = curry (ifC . (exl . exl &&& (apply . first (exl . exr) &&& apply . first (exr . exr))))
           <+ okProd @k @(Prod k (BoolOf k) (Prod k (Exp k a b) (Exp k a b))) @a
           <+ okIf @k @(Exp k a b)
           <+ okProd @k @(Exp k a b) @a
           <+ okExp @k @a @b
           <+ okIf @k @b

#if 0

   funIf
== \ (c,(f,f')) -> \ a -> ifC (c,(f a,f' a))
== curry (\ ((c,(f,f')),a) -> ifC (c,(f a,f' a)))
== curry (ifC . \ ((c,(f,f')),a) -> (c,(f a,f' a)))
== curry (ifC . (exl.exl &&& \ ((c,(f,f')),a) -> (f a,f' a)))
== curry (ifC . (exl.exl &&& ((\ ((c,(f,f')),a) -> f a) &&& (\ ((c,(f,f')),a) -> f' a))))
== curry (ifC . (exl.exl &&& (apply (first (exl.exr)) &&& (apply (first (exl.exr))))))

#endif

repIf :: forall k a. (RepCat k, ProductCat k, Ok k a, HasRep a, IfCat k (Rep a))
      => IfT k a
repIf = abstC . ifC . second (twiceP reprC)
        <+ okProd @k @(BoolOf k) @(Prod k (Rep a) (Rep a))
        <+ okProd @k @(Rep a) @(Rep a)
        <+ okProd @k @(BoolOf k) @(Prod k a a)
        <+ okProd @k @a @a

#if 0
   repIf
== \ (c,(a,a')) -> abstC (ifC (c,(reprC a,reprC a')))
== \ (c,(a,a')) -> abstC (ifC (c,(twiceP reprC (a,a'))))
== \ (c,(a,a')) -> abstC (ifC (second (twiceP reprC) (c,((a,a')))))
== abstC . ifC . second (twiceP reprC)
#endif

class UnknownCat k a b where
  unknownC :: a `k` b

instance UnknownCat (->) a b where
  unknownC = error "unknown"


class RepCat k where
  reprC :: HasRep a => a `k` Rep a
  abstC :: HasRep a => Rep a `k` a

instance RepCat (->) where
  reprC = repr
  abstC = abst
