{-# LANGUAGE ScopedTypeVariables #-}

module Test.Search.TSubst where

import           Data.Either
import           Data.Map (Map)
import qualified Data.Map       as M
import           Data.Set (Set)
import qualified Data.Set       as S
import Test.HUnit

import Search.Subst
import Search.Types


testModuleSubst = TestList
  [ TestLabel "testReconcile2" testReconcile2
  , TestLabel "testReconcile1ToMany" testReconcile1ToMany
  , TestLabel "testReconcile2sets" testReconcile2sets
  , TestLabel "testReconcile" testReconcile
  , TestLabel "testReconcileCondEltsAtElt" testReconcileCondEltsAtElt
  , TestLabel "testReconcileCondElts" testReconcileCondElts
  , TestLabel "testVarSubsts" testVarSubsts
  , TestLabel "testSubstToCondElts" testSubstToCondElts
  , TestLabel "testSetSubstToCondElts" testSetSubstToCondElts
  , TestLabel "test_drawVar" test_drawVar
  ]

test_drawVar = TestCase $ do
  let p = M.fromList [ ("a", M.fromList [ (1, error "meh") ] )
                     , ("b", M.fromList [ (2, error "meh")
                                        , (3, error "meh") ] ) ]
      s = M.singleton "x" 10 :: Subst Int
  assertBool "1" $ drawVar p s "b" "b1"
    == Right (S.fromList [ M.insert "b1" 2 s
                         , M.insert "b1" 3 s ] )
  assertBool "1" $ isLeft $ drawVar p s "b1" "b"

testSetSubstToCondElts = TestCase $ do
  let [a,b,c,x,y] = ["a","b","c","x","y"]
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
  let [a,b,c,x,y] = ["a","b","c","x","y"]
      s = M.fromList [ (a,1), (b,2) ]
  assertBool "2" $ substToCondElts c s == Nothing
  assertBool "1" $ substToCondElts b s ==
    (Just $ M.singleton 2 $ S.singleton $ M.singleton a 1)

testVarSubsts = TestCase $ do
  let [a,b,c,x,y] = ["a","b","c","x","y"]
      aOf_x  = "aOf_x" -- (a, S.fromList [x   ])
      aOf_xy = "aOf_xy" -- (a, S.fromList [x, y])
      xCondElts = M.fromList -- x could be 1 or 2, if ...
        [ (1, S.fromList [ M.fromList [ (a, 1) ] ] )
        , (2, S.fromList [ M.fromList [ (a, 2), (b, 2) ] ] )
        , (3, S.fromList [ M.fromList [ (a, 1) ,       (c, 3) ]
                         , M.fromList [         (b, 3)        ] ] ) ]
      yCondElts = M.fromList -- y could be 3 or 4, if ...
        [ (3, S.fromList [ M.fromList [ (a, 1) ] ] )
        , (4, S.fromList [ M.fromList [         (b, 2), (c, 2) ]
                         , M.fromList [ (a, 2),         (c, 3) ]
                         , M.fromList [         (b, 3), (c, 3) ] ] ) ]
      r = M.fromList [ (x, xCondElts)
                     , (y, yCondElts) ]
      xySubst xVal yVal = M.fromList [ (x, xVal), (y, yVal) ]

  assertBool "0" $ reconcileDetsAcrossVars r (xySubst 1 4) (S.singleton x)
    == Right ( S.fromList [ M.fromList [ (a, 1) ] ] ) -- y irrelevant in aOf_x
  assertBool "1" $ reconcileDetsAcrossVars r (xySubst 1 3) (S.fromList [x,y])
    == Right ( S.fromList [ M.fromList [ (a, 1) ] ] )
  assertBool "2" $ reconcileDetsAcrossVars r (xySubst 2 3) (S.fromList [x,y])
    == Right ( S.empty )
  assertBool "3" $ reconcileDetsAcrossVars r (xySubst 1 4) (S.fromList [x,y])
    == Right ( S.fromList [ M.fromList [ (a, 1), (b, 2), (c, 2) ]
                          , M.fromList [ (a, 1), (b, 3), (c, 3) ] ] )
  assertBool "3" $ reconcileDetsAcrossVars r (xySubst 3 4) (S.fromList [x,y])
    == Right ( S.fromList [ M.fromList [ (a, 1), (b, 3), (c, 3) ]
  -- TODO : are the next two answers redundant? Should I keep only the 1st?
  -- If we ever need to know whether a prior value of a led to this one,
  -- that way it would be available.
                          , M.fromList [ (a, 2), (b, 3), (c, 3) ]
                          , M.fromList [         (b, 3), (c, 3) ] ] )

testReconcileCondElts = TestCase $ do
  let [a,b,c,x] = ["a","b","c","x"]
      ce, cf :: CondElts Int
      ce = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 1) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (b, 1) ] ] )
                      , (3, S.fromList [ M.empty ] ) ]
      cf = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 2) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (c, 3) ] ] ) ]
  assertBool "1" $ reconcileCondElts (S.fromList [ce,cf])
    == M.fromList [ (1, S.singleton $ M.fromList [ (a,2), (b,2) ] )
                  , (2, S.singleton $ M.fromList [ (a,1), (b,1), (c,3) ] ) ]

testReconcileCondEltsAtElt = TestCase $ do
  let [a,b,c,x] = ["a","b","c","x"]
      ce, cf :: CondElts Int
      ce = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 1) ]
                                       , M.empty ] ) ]
      cf = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1)         ]
                                       , M.fromList [         (b, 2) ] ] ) ]

  assertBool "explanatory" $ reconcileCondEltsAtElt 1 (S.fromList [ce,cf])
    == Just ( M.singleton 1 $ S.fromList [ M.fromList [ (a,1), (b,1) ]
                                         , M.fromList [ (a,1) ]
                                         , M.fromList [ (b,2) ] ] )

  let ce = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 1) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (b, 1) ] ] ) ]
      cf = M.fromList [ (1, S.fromList [ M.fromList [ (a, 1), (b, 2) ]
                                       , M.fromList [ (a, 2), (b, 2) ] ] )
                      , (2, S.fromList [ M.fromList [ (a, 1), (c, 3) ] ] ) ]
  assertBool "2" $ reconcileCondEltsAtElt 1 (S.fromList [ce,cf])
    == Just ( M.fromList
              [ (1, S.singleton $ M.fromList [ (a, 2), (b, 2) ] ) ] )
  assertBool "1" $ reconcileCondEltsAtElt 2 (S.fromList [ce,cf])
    == Just ( M.fromList
              [ (2, S.singleton
                  $ M.fromList [ (a,1), (b,1), (c,3) ] ) ] )

testReconcile = TestCase $ do
  let [x,y,z] = ["x","y","z"]
      x1    = S.singleton ( M.singleton x 1 )
      x1_x2 = S.fromList  [ M.singleton x 1
                          , M.singleton x 2 ]
      x1_x3 = S.fromList  [ M.singleton x 1
                          , M.singleton x 3 ]
  assertBool "1" $ reconcile (S.fromList [x1_x2, x1_x3]) == x1

  let x1y2 = S.singleton ( M.fromList [(x,1), (y,2)]        )
      y2z3 = S.singleton ( M.fromList [(x,1),        (z,3)] )
  assertBool "2" $ reconcile (S.fromList [x1, x1y2]) == x1y2
  assertBool "3" $ reconcile (S.fromList [x1, x1y2, y2z3]) ==
    S.singleton ( M.fromList [(x,1), (y,2), (z,3)] )
  assertBool "3" $ reconcile (S.fromList [x1, x1y2, y2z3, S.empty]) ==
                                                          S.empty

testReconcile2sets = TestCase $ do
  let x1 = M.singleton        "x" 1
      y1 = M.singleton        "y" 1
      z2 = M.singleton        "z" 2
      x1y2 = M.fromList [ (   "x", 1)
                        , (   "y", 2) ]
      x1z2 = M.fromList [ (   "x", 1)
                        , (   "z", 2) ]
      x1y1z2 = M.fromList [ ( "x", 1)
                          , ( "y", 1)
                          , ( "z", 2) ]
      x1y2z2 = M.fromList [ ( "x", 1)
                          , ( "y", 2)
                          , ( "z", 2) ]
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
  let x1   = M.singleton  "x" 1
      y1   = M.singleton  "y" 1
      y2   = M.singleton  "y" 2
      x1y2 = M.fromList [ ("x", 1)
                        , ("y", 2) ]
  assertBool "1" $ reconcile1ToMany x1y2 (S.fromList [x1, y1, y2] )
                     == S.singleton x1y2
  assertBool "2" $ reconcile1ToMany x1y2 (S.singleton M.empty)
                     == S.singleton x1y2
  assertBool "3" $ reconcile1ToMany x1y2 S.empty
                     == S.empty

testReconcile2 = TestCase $ do
  let x1,y1,y2,x1y2 :: Subst Int
      x1 = M.singleton "x" 1
      y1 = M.singleton "y" 1
      y2 = M.singleton "y" 2
      x1y2 = M.fromList [ ("x" ,1)
                        , ("y" ,2) ]
  assertBool "0" $ reconcile2 M.empty M.empty == Just (M.empty :: Subst Int)
  assertBool "1" $ reconcile2 M.empty x1      == Just x1
  assertBool "2" $ reconcile2 x1y2    M.empty == Just x1y2
  assertBool "3" $ reconcile2 x1      y2      == Just x1y2
  assertBool "4" $ reconcile2 y2      x1y2    == Just x1y2
  assertBool "5" $ reconcile2 y1      x1y2    == Nothing