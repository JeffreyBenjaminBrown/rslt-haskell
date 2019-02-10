{-# LANGUAGE ScopedTypeVariables #-}
module Test.Qseq.TProgram where

import           Data.Either
import           Data.Map (Map)
import qualified Data.Map       as M
import           Data.Set (Set)
import qualified Data.Set       as S
import           Test.HUnit hiding (Test, test)

import Qseq.Query
import Qseq.MkLeaf
import Data.Graph
import Qseq.QTypes


test_module_Program = TestList [
  TestLabel "test_runProgram" test_runProgram
  , TestLabel "test_runNestedQuants" test_runNestedQuants
  ]

test_runNestedQuants = TestCase $ do
  let [a,b,c,x,y] = ["a","b","c","x","y"]
      [a0,b0,c0,x0,y0] = ["a0","b0","c0","x0","y0"]
      [a1,b1,c1,x1,y1] = ["a1","b1","c1","x1","y1"]

  assertBool ( "every c for which all of c's children "
               ++ "which are also 3's children are < 10" ) $
    let d = mkGraph [ (1, [  4,40     ] )
                    , (2, [  2,20     ] )
                    , (3, [  2,3,30   ] ) ]
        res = runProgram d
                [ ( "all", QFind $ mkFindReturn' $ graphNodes d )
                , ( "children", QQuant $ ForSome a0 "all"
                                $ QFind $ findChildren $ Right a0 )
                , ( "children of 3", QFind $ findChildren $ Left 3)
                , ( lastKey
                  , QQuant $ ForSome a1 "all"
                    $ QJunct $ QAnd
                    [ QFind $ mkFindReturn $ Right a1
                    , QVTest $ mkVTestCompare (<) (Right a1) $ Left 10
                    , ( -- this query is varTestlike
                        QQuant $ ForAll "c of a1" "children"
                        [ -- restrict to children of a1
                          QVTest $ mkVTestIO' (a1,a0) ("c of a1","children")
                        ]
                        $ QQuant $ ForAll "c of 3" "children of 3" []
                        $ QVTest ( mkVTestCompare (/=) (Right "c of a1")
                                   $ Right "c of 3" ) )
                    ] ) ]
        lastKey = "under 10 and its children don't overlap those of 3"
    in M.lookup lastKey (fromRight (error "donkeys") res)
       == Just ( M.fromList [ (1, S.singleton $ M.singleton a1 1)
                            , (4, S.singleton $ M.singleton a1 4) ] )

test_runProgram = TestCase $ do
  let [a,b,c,e,f,g,h,x,y,z] = ["a","b","c","e","f","g","h","x","y","z"]
      [a1,b1,c1,e1,f1,g1,h1,x1,y1,z1] =
        ["a1","b1","c1","e1","f1","g1","h1","x1","y1","z1"]
      [a2,b2,c2,e2,f2,g2,h2,x2,y2,z2] =
        ["a2","b2","c2","e2","f2","g2","h2","x2","y2","z2"]
      d = mkGraph [ (0, [1,2        ] )
                  , (3, [  2,3,4    ] )
                  , (10,[11, 23     ] ) ]

  assertBool "1" $ runProgram d [ (a, QFind $ findParents $ Left 2) ]
    == Right ( M.singleton a ( M.fromList [ (0, S.singleton M.empty)
                                          , (3, S.singleton M.empty) ] )
             :: Possible Int )

  assertBool "2" $ runProgram d
    [ ( b, ( QJunct $ QAnd [ QFind $ findChildren $ Left 3
                             , QTest $ mkTest (/=) $ Left 2 ] ) ) ]
    == Right (M.singleton b ( M.fromList [ (3, S.singleton M.empty)
                                           , (4, S.singleton M.empty) ] ) )

  assertBool "3" $ runProgram d
    [ ( a, QFind $ findParents $ Left 2)
    , ( b, ( QQuant $ ForSome a a $
               QJunct $ QAnd
               [ QFind $ findChildren $ Right a
               , QTest $ mkTest (/=) $ Right a
               , QTest $ mkTest (/=) $ Left 2 ] ) ) ]
    == Right ( M.fromList
               [ ( a, M.fromList [ (0, S.singleton M.empty)
                                 , (3, S.singleton M.empty) ] )
               , ( b, M.fromList [ (1, S.singleton $ M.singleton a 0)
                                 , (4, S.singleton $ M.singleton a 3)
                                 ] ) ] )

  let d = mkGraph [ (0, [1,2,3] )
                  , (1, [11,12] )
                  , (2, [   12,13] )
                  , (3, [] ) ]

  assertBool "4" $ runProgram d
    [ (a, QFind $ findChildren $ Left 0)
    , (b, ( QQuant $ ForSome a a
              ( QQuant $ ForSome a2 a
                (QJunct $ QAnd
                 [ QVTest $ mkVTestCompare (<) (Right a) (Right a2)
                 , QFind $ findChildren $ Right a
                 , QFind $ findChildren $ Right a2 ] ) ) ) ) ]
    == Right
    ( M.fromList
      [ ( a, M.fromList [ ( 1, S.singleton M.empty)
                        , ( 2, S.singleton M.empty)
                        , ( 3, S.singleton M.empty) ] )
      , ( b, M.fromList [ ( 12, S.singleton $ M.fromList [(a,1),(a2,2)] ) ] )
      ] :: Possible Int )
