{-# LANGUAGE ScopedTypeVariables #-}

module Test.TSubst where

import           Data.Map (Map)
import qualified Data.Map       as M
import           Data.Set (Set)
import qualified Data.Set       as S
import Test.HUnit

import Graph
import Query
import Subst
import Types
import Util

import Test.TGraph
import Test.TQuery
import Test.TUtil


testModuleSubst = TestList
  [ TestLabel "testReconcile2" testReconcile2
  , TestLabel "testReconcile1ToMany" testReconcile1ToMany
  , TestLabel "testReconcile2sets" testReconcile2sets
  , TestLabel "testReconcile" testReconcile
  , TestLabel "testReconcileCondEltsAtElt" testReconcileCondEltsAtElt
  , TestLabel "testReconcileCondElts" testReconcileCondElts
  , TestLabel "testVarSubsts" testVarSubsts
  , TestLabel "testVarToCondElts" testVarToCondElts
  , TestLabel "testSubstToCondElts" testSubstToCondElts
  , TestLabel "testSetSubstToCondElts" testSetSubstToCondElts
  , TestLabel "testRecordDependencies" testRecordDependencies
  ]

testRecordDependencies = TestCase $ do
  let x     = Var "x" $ S.empty
      aOf_x = Var "a" $ S.singleton x
      a     = Var "a" $ S.empty
      b     = Var "b" $ S.empty
      c     = Var "b" $ S.empty
      s = S.fromList  [ M.fromList [ (a,1)      , (b,1)  ]
                      , M.fromList [ (a,2)      , (b,2)  ] ]
      t = S.fromList  [ M.fromList [ (a,11)     , (c,11) ]
                      , M.fromList [ (a,12)     , (c,12) ] ]
      s' = S.fromList [ M.fromList [ (aOf_x,1)  , (b,1)  ]
                      , M.fromList [ (aOf_x,2)  , (b,2)  ] ]
      t' = S.fromList [ M.fromList [ (aOf_x,11) , (c,11) ]
                      , M.fromList [ (aOf_x,12) , (c,12) ] ]
  assertBool "1" $             M.fromList [ (5,s'), (6,t') ] ==
    recordDependencies aOf_x ( M.fromList [ (5,s),  (6,t ) ] )

testSetSubstToCondElts = TestCase $ do
  let [a,b,c,x,y] = map (\s -> Var s S.empty) ["a","b","c","x","y"]
      s = M.fromList [ (a,1), (b,2) ]
      t = M.fromList [ (a,1), (b,3) ]
      u = M.fromList [ (a,1), (b,3)
                     , (a,2), (b,3), (c,4) ]
  assertBool "1" $ setSubstToCondElts a (S.fromList [s, t,u,M.empty])
    == ( M.fromList
         [ (1, S.fromList [ M.singleton b 2
                          , M.singleton b 3 ] )
         , (2, S.singleton $ M.fromList [ (b,3), (c,4) ] ) ] )

testSubstToCondElts = TestCase $ do
  let [a,b,c,x,y] = map (\s -> Var s S.empty) ["a","b","c","x","y"]
      s = M.fromList [ (a,1), (b,2) ]
  assertBool "2" $ substToCondElts c s == Nothing
  assertBool "1" $ substToCondElts b s ==
    (Just $ M.singleton 2 $ S.singleton $ M.singleton a 1)

testVarToCondElts = TestCase $ do
  let [a,b,c,x,y] = map (\s -> Var s S.empty) ["a","b","c","x","y"]
      vf_a    = Var "a" (S.empty)
      s_b1c1 = M.fromList [ (b,1), (c,1) ]
      s_b2   = M.fromList [ (b,2)        ]
      (ra :: Possible) = M.fromList [
        ( a, M.fromList [ (1, S.singleton mempty)
                        , (5, S.singleton $ M.singleton x 23) ] ) ]
  assertBool "0" $   varToCondElts ra M.empty vf_a == ((M.!) ra a)
  assertBool "0.1" $ varToCondElts ra s_b1c1  vf_a == ((M.!) ra a)
    -- the Subst s_b1c1 is ignored because the dets in the Var are empty

  let (r :: Possible) = M.fromList
          [ ( a, M.fromList
              [ (1, S.singleton $ error "never used")
              , (2, error "doesn't matter") ] )
          , ( b, M.fromList
              [ (1, S.fromList [ M.fromList [(a, 2), (x,0)       ]
                               , M.fromList [(a, 3), (x,1)       ]
                               , M.fromList [(a, 4), (x,1)       ] ] )
              , (2, S.fromList [ M.fromList [(a,2)               ]
                               , M.fromList [(a,3) , (x,1)       ] ] ) ] )
          , ( c, M.fromList
              [ (1, S.fromList [ M.fromList [(a, 2),       (y,3) ]
                               , M.fromList [(a, 2),       (y,4) ]
                               , M.fromList [(a, 3), (x,2)       ]
                               , M.fromList [(a, 4),       (y,2) ] ] )
              , (2, error "never used, doesn't matter") ] ) ]
      aOf_b  = Var "a" (S.fromList [b   ])
      aOf_bc = Var "a" (S.fromList [b, c])

  assertBool "1" $ varToCondElts r s_b2 aOf_b
    == M.fromList [ (2, S.singleton M.empty)
                  , (3, S.singleton $ M.singleton x 1 ) ]
  assertBool "2" $ varToCondElts r s_b1c1 aOf_bc
    == M.fromList [ (2, S.fromList [ M.fromList [(x,0), (y,3)]
                                   , M.fromList [(x,0), (y,4)] ] )
                  , (4, S.fromList [ M.fromList [(x,1), (y,2)] ] ) ]

testVarSubsts = TestCase $ do
  let [a,b,c,x,y] = map (\s -> Var s S.empty) ["a","b","c","x","y"]
      aOf_x  = Var "a" (S.fromList [x   ])
      aOf_xy = Var "a" (S.fromList [x, y])

      xCondElts = M.fromList -- x could be 1 or 2, if ...
        [ (1, S.fromList [ M.fromList [ (a, 1) ] ] )
        , (2, S.fromList [ M.fromList [ (a, 2), (b, 2) ] ] ) ]
      yCondElts = M.fromList -- y could be 3 or 4, if ...
        [ (3, S.fromList [ M.fromList [ (a, 1) ] ] )
        , (4, S.fromList [ M.fromList [         (b, 2), (c, 2) ]
                         , M.fromList [ (a, 2),         (c, 3) ]
                         , M.fromList [         (b, 3), (c, 3) ] ] ) ]
      r = M.fromList [ (x, xCondElts)
                     , (y, yCondElts) ]
      xySubst xVal yVal = M.fromList [ (x, xVal), (y, yVal) ]

  assertBool "0" $ varSubsts r (xySubst 1 4) aOf_x
    == S.fromList [ M.fromList [ (a, 1) ] ]
  assertBool "1" $ varSubsts r (xySubst 1 3) aOf_xy
    == S.fromList [ M.fromList [ (a, 1) ] ]
  assertBool "2" $ varSubsts r (xySubst 2 3) aOf_xy
    == S.empty
  assertBool "3" $ varSubsts r (xySubst 1 4) aOf_xy
    == S.fromList [ M.fromList [ (a, 1), (b, 2), (c, 2) ]
                  , M.fromList [ (a, 1), (b, 3), (c, 3) ] ]

testReconcileCondElts = TestCase $ do
  let [a,b,c,x] = map (flip Var S.empty) ["a","b","c","x"]
      ce, cf :: CondElts
      ce = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 1) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (b, 1) ] ] )
                      , (3, S.fromList [ M.empty ] ) ]
      cf = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 2) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (c, 3) ] ] ) ]
  assertBool "1" $ reconcileCondElts (S.fromList [ce,cf])
    == Just ( M.fromList
              [ (1, S.singleton $ M.fromList [ (a, 2), (b, 2) ] )
              , (2, S.singleton $ M.fromList [ (a,1), (b,1), (c,3) ] ) ] )

testReconcileCondEltsAtElt = TestCase $ do
  let [a,b,c,x] = map (flip Var S.empty) ["a","b","c","x"]
      ce, cf :: CondElts
      ce = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 1) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (b, 1) ] ] ) ]
      cf = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 2) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (c, 3) ] ] ) ]
  assertBool "1" $ reconcileCondEltsAtElt 1 (S.fromList [ce,cf])
    == Just ( M.fromList
              [ (1, S.singleton $ M.fromList [ (a, 2), (b, 2) ] ) ] )
  assertBool "1" $ reconcileCondEltsAtElt 2 (S.fromList [ce,cf])
    == Just ( M.fromList
              [ (2, S.singleton
                  $ M.fromList [ (a,1), (b,1), (c,3) ] ) ] )

testReconcile = TestCase $ do
  let [x,y,z] = map (\s -> Var s S.empty) ["x","y","z"]
      x1    = S.singleton ( M.singleton x 1 )
      x1_x2 = S.fromList  [ M.singleton x 1
                          , M.singleton x 2 ]
      x1_x3 = S.fromList  [ M.singleton x 1
                          , M.singleton x 3 ]
  assertBool "1" $ reconcile (S.fromList [x1_x2, x1_x3]) == x1
  let x1y1 = S.singleton ( M.fromList [(x,1), (y,2)]        )
      y2z3 = S.singleton ( M.fromList [(x,1),        (z,3)] )
  assertBool "2" $ reconcile (S.fromList [x1, x1y1]) == x1y1
  assertBool "3" $ reconcile (S.fromList [x1, x1y1, y2z3]) ==
    S.singleton ( M.fromList [(x,1), (y,2), (z,3)] )
  assertBool "3" $ reconcile (S.fromList [x1, x1y1, y2z3, S.empty]) ==
                                                          S.empty

testReconcile2sets = TestCase $ do
  let x1 = M.singleton        (Var "x" $ S.empty) 1
      y1 = M.singleton        (Var "y" $ S.empty) 1
      y2 = M.singleton        (Var "y" $ S.empty) 2
      z2 = M.singleton        (Var "z" $ S.empty) 2
      x1y2 = M.fromList [ (   (Var "x" $ S.empty), 1)
                        , (   (Var "y" $ S.empty), 2) ]
      x1z2 = M.fromList [ (   (Var "x" $ S.empty), 1)
                        , (   (Var "z" $ S.empty), 2) ]
      x1y1z2 = M.fromList [ ( (Var "x" $ S.empty), 1)
                          , ( (Var "y" $ S.empty), 1)
                          , ( (Var "z" $ S.empty), 2) ]
      x1y2z2 = M.fromList [ ( (Var "x" $ S.empty), 1)
                          , ( (Var "y" $ S.empty), 2)
                          , ( (Var "z" $ S.empty),2) ]
      ss = S.singleton
      sf = S.fromList
  assertBool "0" $ reconcile2sets S.empty (sf [x1y2, x1z2])
                               == S.empty
  assertBool "0.1" $ reconcile2sets (ss x1) S.empty
                                         == S.empty
  assertBool "1" $ reconcile2sets (ss x1) (sf [x1y2, x1z2])
                                        == sf [x1y2, x1z2]
  assertBool "2" $ reconcile2sets (sf [x1,z2]) (sf [x1y2, x1z2])
                                             == sf [x1y2, x1z2, x1y2z2]
  assertBool "3" $ reconcile2sets (ss y1) (sf [x1y2, x1z2]) == ss x1y1z2

testReconcile1ToMany = TestCase $ do
  let x1   = M.singleton  (Var "x" $ S.empty) 1
      y1   = M.singleton  (Var "y" $ S.empty) 1
      y2   = M.singleton  (Var "y" $ S.empty) 2
      x1y2 = M.fromList [ (Var "x" $ S.empty, 1)
                        , (Var "y" $ S.empty, 2)]
  assertBool "1" $ reconcile1ToMany x1y2 (S.fromList [x1, y1, y2] )
                     == S.singleton x1y2
  assertBool "2" $ reconcile1ToMany x1y2 (S.singleton M.empty)
                     == S.singleton x1y2
  assertBool "3" $ reconcile1ToMany x1y2 S.empty
                     == S.empty

testReconcile2 = TestCase $ do
  let x1 = M.singleton (Var "x" $ S.empty) 1
      y1 = M.singleton (Var "y" $ S.empty) 1
      y2 = M.singleton (Var "y" $ S.empty) 2
      x1y2 = M.fromList [ ( (Var "x" $ S.empty) ,1)
                        , ( (Var "y" $ S.empty) ,2) ]
  assertBool "0" $ reconcile2 M.empty M.empty == Just M.empty
  assertBool "1" $ reconcile2 M.empty x1      == Just x1
  assertBool "2" $ reconcile2 x1y2    M.empty == Just x1y2
  assertBool "3" $ reconcile2 x1      y2      == Just x1y2
  assertBool "4" $ reconcile2 y2      x1y2    == Just x1y2
  assertBool "5" $ reconcile2 y1      x1y2    == Nothing