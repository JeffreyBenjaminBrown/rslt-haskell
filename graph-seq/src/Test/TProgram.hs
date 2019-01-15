{-# LANGUAGE ScopedTypeVariables #-}
module Test.TProgram where

import           Data.Map (Map)
import qualified Data.Map       as M
import           Data.Set (Set)
import qualified Data.Set       as S
import           Test.HUnit hiding (Test)

import Graph
import Program
import Query
import Types


test_module_Program = TestList [
  TestLabel "test_runProgram" test_runProgram
  ]

test_runProgram = TestCase $ do
  let d = graph [ (0, [1,2        ] )
                , (3, [  2,3,4    ] )
                , (10,[11, 23     ] ) ]
  assertBool "1" $ runProgram d [ ("a", QFind $ findParents $ Left 2) ]
    == Right ( M.singleton "a" ( M.fromList [ (0,S.singleton M.empty)
                                            , (3,S.singleton M.empty) ] ) )
  assertBool "2" $ runProgram d
    [ ( "b", ( QAnd [ QFind $ findChildren $ Left 3
                    , QTest $ isNot_1 $ Left 2 ] ) ) ]
    == Right (M.singleton "b" ( M.fromList [ (3, S.singleton M.empty)
                                           , (4, S.singleton M.empty) ] ) )
  assertBool "3" $ runProgram d
    [ ( "a", QFind $ findParents $ Left 2)
    , ( "b", ( ForSome "a1" (Source "a") $
               QAnd [ QFind $ findChildren $ Right "a1"
                    , QTest $ isNot_1 $ Right "a1"
                    , QTest $ isNot_1 $ Left 2 ] ) ) ]
    == Right ( M.fromList
               [ ( "a", M.fromList [ (0, S.singleton M.empty)
                                   , (3, S.singleton M.empty) ] )
               , ( "b", M.fromList [ (1, S.singleton $ M.singleton "a1" 0)
                                   , (4, S.singleton $ M.singleton "a1" 3)
                                   ] ) ] )
