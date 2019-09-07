{-# LANGUAGE ScopedTypeVariables #-}

module Hode.Test.TPTree where

import qualified Test.HUnit      as T
import           Test.HUnit hiding (Test, test)

import           Lens.Micro
import qualified Data.List.PointedList as P

import           Hode.Util.PTree
import           Hode.Util.Direction


test_module_pTree :: T.Test
test_module_pTree = TestList [
    TestLabel "test_porestLeaf"     test_porestLeaf
  , TestLabel "test_focusedSubtree" test_focusedSubtree
  , TestLabel "test_focusedChild"   test_focusedChild
  , TestLabel "test_parentOfFocusedSubtree" test_parentOfFocusedSubtree
  , TestLabel "test_moveFocus_inPTree" test_moveFocus_inPTree
  , TestLabel "test_moveFocus_inPorest" test_moveFocus_inPorest
  , TestLabel "test_pListLenses" test_pListLenses
  ]

test_pListLenses :: T.Test
test_pListLenses = TestCase $ do
  let toPList = maybe (error "impossible: P.fromList fails only on []") id
                . P.fromList
      l  = [1..3 :: Int]
      l' = [4..6 :: Int]
      pl  = toPList l
      pl' = toPList l'
  assertBool "get"         $  pl ^. getPList        == l
  assertBool "set"         $ (pl &  setPList .~ l') == pl'
  assertBool "fail to set" $ (pl &  setPList .~ []) == pl

test_moveFocus_inPorest :: T.Test
test_moveFocus_inPorest = TestCase $ do
  let -- In these names, u=up, d=down, and otherwise n=next is implicit
    pList :: [a] -> P.PointedList a
    pList = maybe (error "impossible unless given [].") id . P.fromList
    nip   = nextIfPossible
    f     = pTreeLeaf (1 :: Int)
    t     = f { _pTreeHasFocus = True }
    _f_nt = nip $ pList [f,t]
    _t_nf =       pList [t,f]

  assertBool "1" $ moveFocusInPorest DirNext _t_nf
                                          == _f_nt
  assertBool "2" $ moveFocusInPorest DirNext _f_nt
                                          == _f_nt
  assertBool "1" $ moveFocusInPorest DirPrev _t_nf
                                          == _t_nf
  assertBool "2" $ moveFocusInPorest DirPrev _f_nt
                                          == _t_nf

test_moveFocus_inPTree :: T.Test
test_moveFocus_inPTree = TestCase $ do
  let -- In these names, u=up, d=down, and otherwise n=next is implicit
    f          = pTreeLeaf (1 :: Int)
    t          = f { _pTreeHasFocus = True }
    f_dt       = f { _pMTrees =                    P.fromList [t] }
    t_df       = t { _pMTrees =                    P.fromList [f] }
    f_df_t     = f { _pMTrees = nextIfPossible <$> P.fromList [f,t] }
    f_dt_f     = f { _pMTrees =                    P.fromList [t,f] }
    f_dt_df_uf = f { _pMTrees =                    P.fromList [t_df,f] }
    f_df_dt_uf = f { _pMTrees =                    P.fromList [f_dt,f] }

  assertBool "Next"             $ moveFocusInPTree DirNext f_dt_f == f_df_t
  assertBool "Next maxed out 1" $ moveFocusInPTree DirNext f_df_t == f_df_t

  assertBool "Prev maxed out 1" $ moveFocusInPTree DirPrev f_dt_f == f_dt_f
  assertBool "Prev"             $ moveFocusInPTree DirPrev f_df_t == f_dt_f

  assertBool "Down maxed out 1" $ moveFocusInPTree DirDown f_dt == f_dt
  assertBool "Down"             $ moveFocusInPTree DirDown t_df == f_dt
  assertBool "Down from middle" $ moveFocusInPTree DirDown f_dt_df_uf
                                                        == f_df_dt_uf

  assertBool "Up maxed out 1"   $ moveFocusInPTree DirUp t    == t
  assertBool "Up maxed out 2"   $ moveFocusInPTree DirUp f    == t
  assertBool "Up maxed out 3"   $ moveFocusInPTree DirUp t_df == t_df
  assertBool "Up"               $ moveFocusInPTree DirUp f_dt == t_df
  assertBool "Up from bottom of 3 layers"
                                $ moveFocusInPTree DirUp f_df_dt_uf
                                                      == f_dt_df_uf

test_porestLeaf :: T.Test
test_porestLeaf = TestCase $ do
  assertBool "1" $ Just (porestLeaf 1) ==
    ( P.fromList [ PTree { _pTreeLabel = 1 :: Int
                         , _pTreeHasFocus = False
                         , _pMTrees = Nothing } ] )

test_parentOfFocusedSubtree :: T.Test
test_parentOfFocusedSubtree = TestCase $ do
  let f  = pTreeLeaf (1 :: Int)
      t  = f { _pTreeHasFocus = True }
      ft = f { _pMTrees = Just $ P.singleton t }
      ff = f { _pMTrees = Just $ P.singleton f }
      tf = t { _pMTrees = Just $ P.singleton f }

  assertBool "s1" $ (setParentOfFocusedSubtree .~ f) t  == t
  assertBool "s2" $ (setParentOfFocusedSubtree .~ t) f  == f
  assertBool "s3" $ (setParentOfFocusedSubtree .~ t) tf == tf
  assertBool "s4" $ (setParentOfFocusedSubtree .~ t) ft == t

  assertBool "g1" $ (t  ^. getParentOfFocusedSubtree) == Nothing
  assertBool "g2" $ (f  ^. getParentOfFocusedSubtree) == Nothing
  assertBool "g3" $ (ft ^. getParentOfFocusedSubtree) == Just ft
  assertBool "g4" $ (ff ^. getParentOfFocusedSubtree) == Nothing
  assertBool "g4" $ (tf ^. getParentOfFocusedSubtree) == Nothing

test_consUnder_andFocus :: T.Test
test_consUnder_andFocus = TestCase $ do
  let f    = pTreeLeaf (1 :: Int)
      t    = f { _pTreeHasFocus = True }
      f_t  = f { _pMTrees = P.fromList   [t] }
      f_ft = f { _pMTrees = P.fromList [f,t] }
  assertBool "1" $ consUnder_andFocus t f   == f_t
  assertBool "2" $ consUnder_andFocus t t   == f_t
  assertBool "3" $ consUnder_andFocus f t   == f_t
  assertBool "4" $ consUnder_andFocus t f_t == f_ft

test_focusedSubtree :: T.Test
test_focusedSubtree = TestCase $ do
  let f  = pTreeLeaf (1 :: Int)
      t  = f { _pTreeHasFocus = True }
      ft = f { _pMTrees = Just $ P.singleton t }
      ff = f { _pMTrees = Just $ P.singleton f }
      tf = t { _pMTrees = Just $ P.singleton f }

  assertBool "s1" $ (f & setFocusedSubtree . pTreeLabel %~ (+1))
    == f
  assertBool "s2" $ (setFocusedSubtree . pTreeLabel %~ (+1)) t
    == (pTreeLabel .~ 2) t
  assertBool "s3" $ (setFocusedSubtree . pTreeLabel %~ (+1)) tf
    == (pTreeLabel .~ 2) tf
  assertBool "s4" $ (setFocusedSubtree . pTreeLabel %~ (+1)) ft
    == (pMTrees . _Just . P.focus . pTreeLabel .~ 2) ft

  assertBool "1" $ f  ^. getFocusedSubtree == Nothing
  assertBool "2" $ t  ^. getFocusedSubtree == Just t
  assertBool "3" $ ft ^. getFocusedSubtree == Just t
  assertBool "4" $ ff ^. getFocusedSubtree == Nothing
  assertBool "5" $ tf ^. getFocusedSubtree == Just tf

test_focusedChild :: T.Test -- :: PTree a -> Maybe (PTree a)
test_focusedChild = TestCase $ do
  let f       = pTreeLeaf (1 :: Int)
      t       = f { _pTreeHasFocus = True }
      f_t     = f { _pMTrees = P.fromList [t] }
      t_f     = t { _pMTrees = P.fromList [f] }
      f_ft_tf = f { _pMTrees = P.fromList [f_t,t_f] }

  assertBool "1" $ f       ^. getFocusedChild == Nothing
  assertBool "2" $ t       ^. getFocusedChild == Nothing
  assertBool "3" $ f_t     ^. getFocusedChild == Just t
  assertBool "3" $ t_f     ^. getFocusedChild == Nothing
  assertBool "4" $ f_ft_tf ^. getFocusedChild == Just t_f