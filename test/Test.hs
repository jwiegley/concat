-- -*- flycheck-disabled-checkers: '(haskell-ghc haskell-stack-ghc); -*-

-- stack test
--
-- stack build && stack test >& ~/Haskell/concat/out/o1

{-# LANGUAGE CPP                 #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE TypeOperators       #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE ConstraintKinds     #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE TypeFamilies        #-}

{-# OPTIONS_GHC -Wall #-}

{-# OPTIONS -Wno-type-defaults #-}

{-# OPTIONS_GHC -Wno-missing-signatures #-}
{-# OPTIONS_GHC -Wno-unused-imports #-}
-- {-# OPTIONS_GHC -Wno-unused-binds   #-}
-- {-# OPTIONS_GHC -Wno-redundant-constraints #-}

-- To keep ghci happy, it appears that the plugin flag must be in the test module.
{-# OPTIONS_GHC -fplugin=ConCat.Plugin #-}

-- {-# OPTIONS_GHC -fplugin-opt=ConCat.Plugin:trace #-}
-- {-# OPTIONS_GHC -dverbose-core2core #-}

-- {-# OPTIONS_GHC -ddump-rule-rewrites #-}

-- Does this flag make any difference?
{-# OPTIONS_GHC -fexpose-all-unfoldings #-}

-- Tweak simpl-tick-factor from default of 100
{-# OPTIONS_GHC -fsimpl-tick-factor=2800 #-}
-- {-# OPTIONS_GHC -fsimpl-tick-factor=250 #-}
-- {-# OPTIONS_GHC -fsimpl-tick-factor=5  #-}

{-# OPTIONS_GHC -dsuppress-idinfo #-}
{-# OPTIONS_GHC -dsuppress-uniques #-}
{-# OPTIONS_GHC -dsuppress-module-prefixes #-}

----------------------------------------------------------------------
-- |
-- Module      :  Test
-- Copyright   :  (c) 2017 Conal Elliott
-- License     :  BSD3
--
-- Maintainer  :  conal@conal.net
-- Stability   :  experimental
-- 
-- Suite of automated tests
----------------------------------------------------------------------

module Main where

import Control.Arrow (second,runKleisli)
import Data.Tuple (swap)
import Data.Maybe
import Distribution.TestSuite
import GHC.Generics hiding (R,D)
import GHC.Exts (lazy,coerce)

import ConCat.Misc (Unop,Binop,(:*),PseudoFun(..),R,bottom,oops,Yes2,sqr,magSqr)
import ConCat.Rep
import ConCat.Standardize
import ConCat.Free.VectorSpace (V)
import ConCat.Free.LinearRow
import ConCat.Incremental
import ConCat.AD
import ConCat.Interval
import ConCat.Syntactic (Syn,render)
import ConCat.Circuit (GenBuses)
import qualified ConCat.RunCircuit as RC
import ConCat.GLSL (genGlsl,CAnim)
import ConCat.Image
import ConCat.RunCircuit (go,Okay,(:>))
import ConCat.AltCat ( ccc,reveal,Uncurriable(..),U2(..),(:**:)(..),Ok2
                     , reprC,abstC,mulC,amb,ambC,asKleisli, recipC )
import qualified ConCat.AltCat as A
import ConCat.Rebox () -- experiment
import ConCat.Orphans ()
import ConCat.GradientDescent

default (Int, Double)

main :: IO ()
main = sequence_
  [ putChar '\n' -- return ()

--   , test "recip-r" (recip :: Unop R)
--   , test "recipC-r" (recipC :: Unop R)

--   , test "foo" (\ ((x,y) :: R2) -> 1 * x + 0 + (-1) * y)

  , test "diag-plus-im" (\ t ((x,y) :: R2) -> x + sin t > y)
  , test "disk-sizing" (disk . cos)
--   , test "disk-sizing-p" (disk' . cos)
--   , test "diag-disk-turning" (\ t -> udisk `intersectR` rotate t xPos)
--   , test "sqr-sqr-anim" (\ t ((x,y) :: R2) -> sqr (sqr x) > y + sin t) -- Test reuse

--   , test "checker-sizing" (\ t -> uscale (sin t) checker)

--   , test "diag-plus-im" (\ t (x :: R,y) -> x + sin t > y)
--   , test "disk" disk
--   , test "diag-disk" (\ (x,y) -> disk (x,y) && x > y)
--   , test "sqr-sqr" (\ (x,y) -> sqr (sqr x) > y) -- Test reuse

--   , test "const2-0-der" (der (\ (_::R,_::R) -> 0 :: R))

--   , test "const2-0-uncurry-der" (der (uncurry (\ (_::R) (_::R) -> 0 :: R)))

--   , print (asKleisli (\ x -> let z = x `amb` x+1 in z*z) 5 :: [Int])

--   , print (asKleisli (\ x -> (x `amb` x+1) * (x `amb` x+1)) 5 :: [Int])

--   , test "min" (uncurry (min @Int))

--   , test "minmax" (\ (x :: Int, y :: Int) -> (min x y, max x y))

--   , test "minmax4" (\ w -> (min4 w :: Int, max4 w))

--   , print (unIF (ccc (sqr @Int)) (2,5))

--   , test "mul-iv" (unIF (ccc (uncurry ((*) @Int))))

--   , test "sqr-iv" (unIF (ccc (sqr @Int)))

--   , test "magSqr-iv" (unIF (ccc (magSqr @Int)))

--   , test "poly1" (\ x -> 1 + 3 * x + 5 * x^2 :: Double)

--   , test "poly1-iv" (ivFun (\ x -> 1 + 3 * x + 5 * x^2 :: Double))

--   , test "horner" (horner @Double [1,3,5])

--   , test "horner-iv" (ivFun (horner @Double [1,3,5]))

--   , test "poly1-der" (der (\ x -> 1 + 3 * x + 5 * x^2 :: Double))

--   , test "poly1-der-iv" (ivFun (der (\ x -> 1 + 3 * x + 5 * x^2 :: Double)))

--   , test "horner-der" (der (horner @Double [1,3,5])) -- times out

--   , test "horner-der-iv" (ivFun (der (horner @Double [1,3,5])))

--   , test "a3b" (\ (a,b) -> a + 3 * b :: Int)

--   , test "abc" (\ ((a,b),c) -> a + b * c :: Int)

--   , test "sqr-d" (der (\ x -> x * x :: R))

--   -- [[Oops --- ccc called!
--   , print (der (\ x -> x * x :: R) 1.0)

--   -- 2.0
--   , print (gradient (\ x -> x * x :: R) 1.0)

--   , print (take 10 gd1)

--   , test "sqr" (sqr @R)
--   , test "magSqr" (magSqr @R)

--   , test "sum-pp" (\ ((a,b),(c,d)) -> (a+c)+(b+d) :: R)

--   , test "magSqr3" (\ (a,b,c) -> sqr a + sqr b + sqr c :: R)

--   , test "sqr-ad" (andDer (ccc (sqr @R)))

--   , test "magSqr-d" (der (magSqr @R))

--   , test "magSqr-ad" (andDer (magSqr @R))

--   , print (minimize 1 cos 3)   -- (3.141592653589793,4)

--   , test "foo" (gradient cos :: R -> R)

--   , test "foo" (gradient (negateV . cos) :: R -> R)

--   , print (minimize 1 cos 5)  -- (3.141592653589793,6)
--   , print (maximize 1 cos 5)  -- (6.283185307179586,5)

--   -- 0.2: ((5.0e-324,5.0e-324),1460)
--   -- 0.4: ((0.0,0.0),2)
--   -- 0.5: ((0.0,0.0),2)
--   -- 0.6: ((0.0,0.0),465)
--   -- 0.7: ((0.0,0.0),816)
--   -- 0.8: ...
--   , print (minimize 0.5 (\ (a,b) -> sqr a + sqr b) (1,3))

--   , test "nothing" (\ () -> Nothing :: Maybe Int)

--   , test "magSqr-ad-inc" (inc (andDer (magSqr @R)))

--   , test "negate-ai" (andInc (negate :: Unop Int))

--   , test "xx" (\ x -> x * x :: R)

--   , test "xy" (\ (x,y) -> x * y :: R)

--   , test "xy-ad" (andDer (\ (x,y) -> x * y :: R))

--   , test "xy-ad-inc" (inc (andDer (\ (x,y) -> x * y :: R)))

--   , test "xy-i" (inc (\ (x,y) -> x * y :: R))

--   , test "xy-ai" (andInc (\ (x,y) -> x * y :: R))

--   , test "cond" (\ x -> if x > 0 then x else negate x :: Int)

--   , test "cond-fun" (\ x -> (if x > 0 then id else negate) x :: Int)

--   , test "sop1-ai" (andInc (\ (x,y,z) -> x * y + y * z + x * z :: R))

--   , test "sop1" (\ (x,y,z) -> x * y + y * z + x * z :: R)

--   , test "sop1-ai" (andInc (\ (x,y,z) -> x * y + y * z + x * z :: R))
--   , test "sop1-ad" (andDer (\ (x,y,z) -> x * y + y * z + x * z :: R))
--   , test "sop1-ad-ai" (andInc (andDer (\ (x,y,z) -> x * y + y * z + x * z :: R)))

--   , test "sop2-ad-ai" (andInc (andDer (\ (x,y,z) -> x * y + z :: R)))

--   , test "sop3-ad-ai" (andInc (andDer (\ (x::R,_y::R,_z::R) -> x)))

--   , test "sop4-d-ai" (andInc (der (\ (x::R,_y::R,_z::R) -> x)))

--   , test "sum4" (\ (a,b,c,d) -> (a+b)+(c+d) :: R)

--   , test "sum4-ai" (andInc (\ (a,b,c,d) -> (a+b)+(c+d) :: Int))

--   , test "sum4p-ai" (andInc (\ ((a,b),(c,d)) -> (a+b)+(c+d) :: Int))

--   , test "sum8" (\ ((a,b,c,d),(e,f,g,h)) -> ((a+b)+(c+d))+((e+f)+(g+h)) :: R)
--   , test "sum8-ai" (andInc (\ ((a,b,c,d),(e,f,g,h)) -> ((a+b)+(c+d))+((e+f)+(g+h)) :: R))

--   , test "magSqr"            (magSqr @R)
--   , test "magSqr-ai" (andInc (magSqr @R))
--   , test "magSqr-i"     (inc (magSqr @R))

--   , test "linear-compose-r-r-r" (uncurry ((A..) :: LComp R R R))
--   , test "linear-compose-r2-r-r" (uncurry ((A..) :: LComp R2 R R))
--   , test "linear-compose-r-r2-r" (uncurry ((A..) :: LComp R R2 R))
--   , test "linear-compose-r2-r2-r2" (uncurry ((A..) :: LComp R2 R2 R2))

--   , tst (Par1 @ Bool)
--   , tst (Par1 . Par1 @ Bool)
--   , tst (\ (x :: Bool) -> Par1 (Par1 x))
--   , tst (\ () -> Par1 True)

--   , tst (\ (Par1 b) -> b :: Bool)
--   , tst (\ (Par1 (Par1 b)) -> b :: Bool)

--   , tst ((\ (L w) -> w) :: LR R R -> (V R R :-* V R R) R)
--   , tst ((\ (L (Par1 (Par1 s))) -> s) :: LR R R -> R)

--   , tst (scale :: R -> L R R R)

--   , test "id-r"          (id :: Unop R)
--   , test "id-r2"         (id :: Unop R2)
--   , test "id-r3"         (id :: Unop R3)
--   , test "id-r4"         (id :: Unop R4)

--   , test "const-r-4"     (const 4 :: Unop R)
--   , test "const-r-34"    (const (3,4) :: R -> R2)
--   , test "const-r2-34"   (const (3,4) :: Unop R2)

--   , test "x-plus-four" (\ x -> x + 4 :: R)
--   , test "four-plus-x" (\ x -> 4 + x :: R)

--   , test "sin"         (sin @R)
--   , test "cos"         (cos @R)
--   , test "double"      (\ x -> x + x :: R) 

--   , test "sin-d1" (der (sin @R))
--   , test "sin-d2" (der (der (sin @R)))
--   , test "sin-d3" (der (der (der (sin @R))))
--   , test "sin-d4" (der (der (der (der (sin @R)))))

--   , tst (\ (p :: R2) -> (snd p, fst p))
--   , tst (\ ((x,y) :: R2) -> (y,x))
--   , tst (\ ((x,y) :: R2) -> (Par1 y,Par1 x))
--   , tst (\ ((x,y) :: R2) -> Par1 y :*: Par1 x) -- simple

--   , tst (\ (p :: Par1 R, q :: Par1 R) -> p :*: q)  -- complex

--   , tst (abstC :: Par1 R :* Par1 R -> (Par1 :*: Par1) R)

--   , test "mult"                     (uncurry ((*) @R))
--   , test "mult-d1"             (der (uncurry ((*) @R)))
--   , test "mult-d2"        (der (der (uncurry ((*) @R))))
--   , test "mult-d3"   (der (der (der (uncurry ((*) @R)))))

--   , test "square"      (\ x -> x * x :: R)

--   , test "cos-2x"      (\ x -> cos (2 * x) :: R)
--   , test "cos-2xx"     (\ x -> cos (2 * x * x) :: R)
--   , test "cos-xpy"     (\ (x,y) -> cos (x + y) :: R)

--   , test "cos-xy" (\ (x,y) -> cos (x * y) :: R)
--   , test "cos-xy-d1" (der (\ (x,y) -> cos (x * y) :: R))
--   , test "cos-xy-d2" (der (der (\ (x,y) -> cos (x * y) :: R)))

--   , test "cosSin-xy" (cosSinProd @R)
--   , test "cosSin-xy-d1" (der (cosSinProd @R))

--   , test "cosSin-xy-ad1" (andDer (\ (x,y) -> cosSin (x * y) :: R2))

--   , test "cosSin-xy-ad1-i" (inc (andDer (\ (x,y) -> cosSin (x * y) :: R2)))

--   , test "cosSin-xyz" (\ (x,y,z) -> cosSin (x * y + x * z + y * z) :: R2)
--   , test "cosSin-xyz-d1" (der (\ (x,y,z) -> cosSin (x * y + x * z + y * z) :: R2))

--   , test "three" three
--   , test "threep" three'
--   , test "addThree" addThree

  ]

{--------------------------------------------------------------------
    Testing utilities
--------------------------------------------------------------------}

type EC = Syn :**: (:>)

runU2 :: U2 a b -> IO ()
runU2 = print

type GO a b = (GenBuses a, Ok2 (:>) a b)

type GO' a b = (HasStandard a, HasStandard b, GO (Standard a) (Standard b))

runF :: (a -> b) -> IO ()
runF f = f `seq` return ()

runSyn :: Syn a b -> IO ()
runSyn syn = putStrLn ('\n' : render syn)

runEC :: GO a b => String -> EC a b -> IO ()
runEC nm (syn :**: circ) = runSyn syn >> runCirc nm circ

runCirc :: GO a b => String -> (a :> b) -> IO ()
runCirc nm circ = RC.run nm [] circ

runCircGlsl :: String -> CAnim -> IO ()
runCircGlsl nm circ = runCirc nm circ >> genGlsl nm circ

test :: Con a b => String -> (a -> b) -> IO ()
test nm _f = oops ("test called on " ++ nm)
{-# NOINLINE test #-}

tst :: Con a b => (a -> b) -> IO ()
tst = test "tst"
{-# NOINLINE tst #-}

type OkAnim a b = (a -> b) ~ (R -> R2 -> Bool)

-- ccc' :: (HasStandard a, HasStandard b) => (a -> b) -> (Standard a `k` Standard b)
-- ccc' = ccc . standardize

#if 0
type Con = Yes2
{-# RULES "ccc (->)" forall nm f. test nm f = runF (ccc f) #-}
#elif 0
type Con = Yes2
{-# RULES "U2" forall nm f. test nm f = runU2 (ccc f) #-}
#elif 0
type Con = Yes2
{-# RULES "Syn" forall nm f. test nm f = runSyn (ccc f) #-}
#elif 0
type Con a b = GO a b
{-# RULES "(:>)" forall nm f. test nm f = runCirc nm (ccc f) #-}
#elif 0
type Con = Uncurriable Syn
{-# RULES "Syn; uncurries" forall nm f. test nm f = runSyn (uncurries (ccc f)) #-}
#elif 0
type Con = Uncurriable Syn
{-# RULES "uncurries; Syn" forall nm f. test nm f = runSyn (ccc (uncurries f)) #-}
#elif 0
type Con = Uncurriable (->)
{-# RULES "(->); uncurries; Syn" forall nm f. test nm f = runSyn (ccc (uncurries (ccc f))) #-}
#elif 0
type Con a b = OkAnim a b
{-# RULES "GLSL" forall nm f. test nm f = genGlsl nm (ccc (uncurry f)) #-}
#elif 1
type Con a b = OkAnim a b
{-# RULES "Circuit and GLSL" forall nm f. test nm f = runCircGlsl nm (ccc (uncurry f)) #-}
#elif 0
type Con a b = GO a b
{-# RULES "EC" forall nm f. test nm f = runEC nm (ccc f) #-}
#elif 0
type Con a b = GO' a b
{-# RULES "EC" forall nm f. test nm f = runEC nm (ccc' f) #-}
#elif 0
type Con a b = GO a b
{-# RULES "(->); EC" forall nm f. test nm f = runEC nm (ccc (ccc f)) #-}
#elif 0
type Con a b = (GenBuses (UncDom a b), Uncurriable EC a b)
{-# RULES "uncurries ; EC" forall nm f. test nm f = runEC nm (uncurries (ccc f)) #-}
#elif 0
type Con a b = (GenBuses (UncDom a b), Uncurriable (->) a b)
{-# RULES "uncurries ; EC" forall nm f. test nm f = runEC nm (ccc (uncurries f)) #-}
#elif 0
type Con = Okay  -- rename
{-# RULES "(->); (:>)" forall nm f. test nm f = go nm (ccc f) #-}
#elif 0
type Con = Yes2
{-# RULES "L ; Syn" forall nm f. test nm f = runSyn (ccc (\ () -> lmap @R f)) #-}
#elif 0
type Con = Yes2
{-# RULES "(->) ; L ; Syn" forall nm f. test nm f = runSyn (ccc (\ () -> lmap @R (ccc f))) #-}
#elif 0
type Q a b = (V R a :-* V R b) R
type Con a b = (GenBuses (UncDom () (Q a b)), Uncurriable (:>) () (Q a b))
{-# RULES "L ; Syn+circuit" forall nm f.
    test nm f = runEC (nm++"-lmap") (ccc (\ () -> repr (lmap @R f))) #-}
#elif 0
type Con = Yes2
{-# RULES "andDer ; ccc" forall nm f. test nm f = runSyn (ccc (andDer f)) #-}
#elif 0
type Con = Yes2
{-# RULES "(->); D; Syn" forall nm f. test nm f = runSyn (ccc (andDer (ccc f))) #-}
#elif 0
type Con a b = (Ok2 (L R) a b, HasL (V R a))
{-# RULES "(->); D'; EC" forall nm f. test nm f = runSyn (ccc (ADFun.andDer (ccc f))) #-}
#elif 0
type Con a b = GO a b
{-# RULES "(->); D; (:>)" forall nm f. test nm f = runCirc (nm++"-ad") (ccc (andDer (ccc f))) #-}
#elif 0
type Con a b = GO a b
{-# RULES "(->); D; EC" forall nm f. test nm f = runEC (nm++"-ad") (ccc (andDer (ccc f))) #-}
#elif 0
type Con a b = GO a b
{-# RULES "(->); D; EC" forall nm f. test nm f = runEC (nm++"-d") (ccc (der (ccc f))) #-}
#elif 1
type Con a b = GO a b
{-# RULES "(->); D; EC" forall nm f. test nm f = runEC (nm++"-d2") (ccc (der (der (ccc f)))) #-}
#elif 0
type Con a b = (Ok2 (L R) a b, HasL (V R a), GO a b)
{-# RULES "(->); D'; EC" forall nm f. test nm f = runEC (nm++"-adf") (ccc (ADFun.andDer (ccc f))) #-}
#elif 0
type Con a b = (Ok2 (L R) a b, HasL (V R a), GO a b)
{-# RULES "(->); D; EC" forall nm f. test nm f = runEC (nm++"-derf") (ccc (ADFun.der (ccc f))) #-}
#else
 #OOPS#
#endif

{--------------------------------------------------------------------
    Ad hoc tests
--------------------------------------------------------------------}

#if 0

foo1 :: D R R
foo1 = ccc id

foo2, foo3 :: R -> R :* (R -> R)
foo2 = unD foo1
foo3 = unD (ccc id)

sampleD :: D a b -> a -> b
sampleD (D f) = fst . f

foo4 :: R -> R
foo4 = sampleD (ccc id)

#endif

double :: Num a => a -> a
double a = a + a
{-# INLINE double #-}

cosSin :: Floating a => a -> a :* a
cosSin a = (cos a, sin a)
{-# INLINE cosSin #-}

cosSinProd :: Floating a => a :* a -> a :* a
cosSinProd (x,y) = (cos z, sin z) where z = (x * y)

type R3 = (R,R,R)
type R4 = (R2,R2)

type LComp a b c = LR b c -> LR a b -> LR a c

#if 0

three :: R -> R3
three x = (x, x*x, x*x*x)

three' :: R -> (R3,R3)
three' x = (f 5, f 6)
 where
   f y = (x, x*x, x*y*x)

addThree :: R3 -> R
addThree (a,b,c) = a+b+c

par1 :: a -> Par1 a
par1 = Par1
{-# INLINE [0] par1 #-}

#endif

horner :: Num a => [a] -> a -> a

-- horner coeffs a = foldr (\ w z -> w + a * z) 0 coeffs

-- horner coeffs0 a = go coeffs0
--  where
--    go [] = a
--    go (c:cs) = c + a * go cs

-- This version inlines
horner []     _ = 0
horner (c:cs) a = c + a * horner cs a

type Region = R2 -> Bool
