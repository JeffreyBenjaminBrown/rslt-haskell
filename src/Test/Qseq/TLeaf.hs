{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}
module Test.Qseq.TLeaf where

import           Data.Map (Map)
import qualified Data.Map       as M
import           Data.Set (Set)
import qualified Data.Set       as S
import           Test.HUnit hiding (Test, test)

import Qseq.Query.Valid
import Qseq.Query.MkLeaf
import Qseq.Query.RunLeaf
import Data.Graph
import Qseq.QTypes


test_modules_leaf = TestList [
    TestLabel "test_runVarTest_compare" test_runVarTest_compare
  , TestLabel "test_runVarTest_ioTest" test_runVarTest_ioTest
  , TestLabel "test_runFind" test_runFind
  , TestLabel "test_runTest" test_runTest
  ]

test_runTest = TestCase $ do
  -- I wrote tests for this function twice by accident. They are collected
  -- here, and probably redundant.
  let [a,b,c,x,y] = ["a","b","c","x","y"]
      g = graph [ (1, [11, 12    ] )
                , (2, [    12, 22] ) ]
      (a2 :: (Subst Int)) = M.singleton a 2
      (ce :: (CondElts Int)) = M.fromList [ (1, S.singleton $ M.singleton x 0)
                                    , (2, S.singleton $ M.empty) ]
  assertBool "1" $ runTest g a2 (mkTest (/=) $ Left 1) ce
    == Right ( M.singleton 2 (S.singleton M.empty) )
  assertBool "2" $ runTest g a2 (mkTest (/=) $ Right a) ce
    == Right ( M.singleton 1 ( S.singleton $ M.fromList [(a,2), (x,0)] ) )

  let (a,b,c) = ("a","b","c")
      g = graph [ (1, [2,3] )
                , (2, [1,3] ) ]
      s = M.fromList [(a, 1), (b, 2)]
  assertBool "1" $ runTest g s
    ( mkTest (>) (Left 1) )
    (  M.fromList [ (0, S.singleton $ M.singleton c 1)
                  , (2, S.singleton $ M.singleton c 1) ] )
    == Right ( M.fromList [ (0, S.singleton $ M.singleton c 1) ] )
  assertBool "2" $ runTest g s
    ( mkTest (<) (Right a) )
    (  M.fromList [ (0, S.singleton $ M.singleton c 1)
                  , (2, S.singleton $ M.singleton c 1) ] )
    == Right ( M.fromList
               [ (2, S.singleton $ M.fromList [ (a,1), (c,1) ] ) ] )

test_runFind = TestCase $ do
  let (a,b,c) = ("a","b","c")
      g = graph [ (1, [2,3] ) ]
      s = M.fromList [(a, 1), (b, 2)]
  assertBool "1" $ runFind g s (findChildren $ Left 1)  ==
    Right ( M.fromList [ (2, S.singleton M.empty)
                       , (3, S.singleton M.empty) ] )
  assertBool "2" $ runFind g s (findChildren $ Right a) ==
    Right ( M.fromList [ (2, S.singleton $ M.singleton a 1)
                       , (3, S.singleton $ M.singleton a 1) ] )
  assertBool "2" $ runFind g s (findChildren $ Right b) == Right M.empty

test_runVarTest_ioTest = TestCase $ do
  let g = graph [] :: Graph Int
      [a,b,c,x,y] = ["a","b","c","x","y"]
      (p :: Possible Int) = M.fromList
        [ (a, M.fromList [ ( 1, S.singleton M.empty)
                         , ( 2, S.singleton M.empty)] )
        , (b, M.fromList [ ( 1, S.fromList [ M.singleton a 1
                                           , M.singleton a 2 ] )
                         , ( 2, S.singleton M.empty)] ) ]
      go = runVarTest p g :: Subst Int -> VarTest Int (Graph Int)
                          -> Either String Bool

  assertBool "in progress" $ go (M.fromList [(a,1),(b,1)]) (mkVTestIO a b)
    == Right True
  assertBool "in progress" $ go (M.fromList [(a,1),(b,2)]) (mkVTestIO a b)
    == Right False
  assertBool "in progress" $ go (M.fromList [(a,3),(b,1)]) (mkVTestIO a b)
    == Right False

test_runVarTest_compare = TestCase $ do
  let a_lt_1 = mkVTestCompare (>) (Left 1)    $ Right "a"
      b_lt_1 = mkVTestCompare (>) (Left 1)    $ Right "b"
      a_gt_b = mkVTestCompare (>) (Right "a") $ Right "b"
      b_gt_a = mkVTestCompare (>) (Right "b") $ Right "a"
      subst = M.fromList [("a",0),("b",2)] :: Subst Int
      meh = error "whatever"
  assertBool "1" $ Right True  == runVarTest meh meh subst a_lt_1
  assertBool "2" $ Right False == runVarTest meh meh subst b_lt_1
  assertBool "3" $ Right False == runVarTest meh meh subst a_gt_b
  assertBool "4" $ Right True  == runVarTest meh meh subst b_gt_a