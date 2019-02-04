{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE LambdaCase #-}

module Rslt.Edit where

import           Prelude hiding (lookup)
import           Data.Either
import qualified Data.List      as L
import           Data.Maybe
import           Data.Map (Map)
import qualified Data.Map       as M
import           Data.Set (Set)
import qualified Data.Set       as S

import Rslt.Index
import Rslt.Lookup
import Rslt.RTypes
import Rslt.RValid
import Util


-- | = Edit + search

-- | `lookupInsert r ei` returns the `Addr` containing ei, if present.
-- If not, it inserts ei, and then returns the `Addr` containing it.
-- Since it might modify the `Rslt`, it also returns that.
lookupInsert :: Rslt -> Expr -> Either String (Rslt, Addr)
lookupInsert r ei = do
  let (mra :: Maybe Addr) = either (const Nothing) Just
                            $ lookup r ei
  case mra of
    Just a -> Right (r, a)
    Nothing -> do

    lookupInsert_rootNotFound r ei


-- | `lookupInsert_rootNotFound` is like `lookupInsert`,
-- for the case that the root `RefExpr` has been determined not to be present,
-- but the others still might be.
lookupInsert_rootNotFound :: Rslt -> Expr -> Either String (Rslt, Addr)
lookupInsert_rootNotFound r (ExprAddr a) =
  Left $ "lookupInsert: Addr " ++ show a ++ "not found.\n"

lookupInsert_rootNotFound r (Word w) = do
  a <- nextAddr r
  r <- insertAt a (Word' w) r
  Right (r,a)

lookupInsert_rootNotFound r (Tplt js) = do
  (r,as) <- prefixLeft "lookupInsert_rootNotFound"
            $ lookupInsert_list r js
  a <- nextAddr r
  r <- insertAt a (Tplt' $ as) r
  Right (r, a)

lookupInsert_rootNotFound r (Rel ms t) = do
  (r,ta)  <- prefixLeft "lookupInsert_rootNotFound"
            $ lookupInsert r t
  (r,mas) <- prefixLeft "lookupInsert_rootNotFound"
             $ lookupInsert_list r ms
  a <- nextAddr r
  r <- insertAt a (Rel' mas ta) r
  Right (r,a)

lookupInsert_rootNotFound r (Par ps s) = do
  let (ss, is) = unzip ps
  (r,as) <- prefixLeft "lookupInsert_rootNotFound"
            $ lookupInsert_list r is
  a <- nextAddr r
  r <- insertAt a (Par' (zip ss as) s) r
  Right (r,a)


lookupInsert_list :: Rslt -> [Expr] -> Either String (Rslt, [Addr])
lookupInsert_list r is = do
  let ((er, as) :: (Either String Rslt, [Addr])) =
        L.mapAccumL f (Right r) is where
        f :: Either String Rslt -> Expr -> (Either String Rslt, Addr)
        f (Left s) ei = (Left s, error "irrelevant")
        f (Right r) ei = case lookupInsert r ei of
          Left s -> (Left s, error "irrelevant")
          Right (r,a) -> (Right r, a)
  r <- prefixLeft "lookupInsert_list" er
  Right $ (r, as)


-- | = Pure editing

replace :: RefExpr -> Addr -> Rslt -> Either String Rslt
replace e oldAddr r = do
  let pel = prefixLeft "replace"
  newAddr <- pel $ nextAddr r
  _       <- pel $ validRefExpr r e
  r       <- pel $ insertAt newAddr e r
  r       <- pel $ _substitute newAddr oldAddr r
  id      $  pel $ deleteUnused oldAddr r

_substitute :: Addr -> Addr -> Rslt -> Either String Rslt
_substitute new old r = do
  (roles :: Set (Role, Addr)) <- prefixLeft "_substitute"
                                 $ isIn r old
  let f :: Either String Rslt -> (Role, Addr) -> Either String Rslt
      f e@(Left _) _ = e
      f (Right r) (role,host) = replaceInRole role new host r
  S.foldl f (Right r) roles

_replaceInRefExpr :: Rslt -> Role -> Addr -> RefExpr -> Either String RefExpr
_replaceInRefExpr r spot new host = do
  let pel = prefixLeft "_replaceInRefExpr"
  pel $ refExprAt r new

  case spot of
    RoleTplt -> case host of
      Rel' as _ -> do
        if variety r new == Right (TpltCtr, length as)
          then Right $ Rel' as new
          else Left $ "_replaceInRefExpr: RefExpr at " ++ show new
                ++ " is not a valid Tplt in " ++ show host ++ ".\n"
      _ -> Left $ "_replaceInRefExpr: nothing plays the role of Tplt in "
                ++ show host ++ ".\n"

    RoleMember k -> do
      case host of

        Rel' as a -> do
          as' <- pel $ replaceNth new k as
          Right $ Rel' as' a

        Tplt' as -> do
          as' <- pel $ replaceNth new k as
          Right $ Tplt' as'

        Par' sas s -> do
          let (ss,as) = unzip sas
          as' <- pel $ replaceNth new k as
          Right $ Par' (zip ss as') s

        _ -> Left $ "_replaceInRefExpr: RefExpr " ++ show host
             ++ " has no members.\n"

replaceInRole :: Role -> Addr -> Addr -> Rslt -> Either String Rslt
replaceInRole spot new host r = do
  let pel = prefixLeft "replaceInRole"
  _                          <- pel $ refExprAt r new
  oldHostRefExpr             <- pel $ refExprAt r host
  (hostHas :: Map Role Addr) <- pel $ has r host
  (old :: Addr) <- let err = Left $ "replaceInRole: RefExpr at " ++ show host
                             ++ " includes no position " ++ show spot ++ "\n."
    in maybe err Right $ M.lookup spot hostHas

  (newHostRefExpr :: RefExpr) <-
    pel $ _replaceInRefExpr r spot new oldHostRefExpr
  (newIsAlreadyIn :: Set (Role,Addr)) <- pel $ isIn r new

  Right $ r {
      _refExprAt = M.insert host newHostRefExpr $ _refExprAt r
    , _addrOf = let f = case newHostRefExpr of
                          Par' _ _ -> id
                          _        -> M.insert newHostRefExpr host
                in f $ M.delete oldHostRefExpr $ _addrOf r

    , _has    = M.adjust (M.insert spot new) host $ _has r

    , _isIn   =   M.filter (not . null)
      -- PITFALL: delete before inserting. Otherwise, replacing something
      -- with itself is not the identity operation.
                . M.insert new (S.insert (spot, host) newIsAlreadyIn)
      -- PITFALL: We can't adjust the value at new; it might not exist.
                . M.adjust (S.delete (spot, host)) old
                $ _isIn r
    }

insert :: RefExpr -> Rslt -> Either String Rslt
insert e r = do
  a <- prefixLeft "insert" $ nextAddr r
  insertAt a e r

insertAt :: Addr -> RefExpr -> Rslt -> Either String Rslt
insertAt a e r = do
  prefixLeft "insertAt" $ validRefExpr r e
  let errMsg = "insertAt: Addr " ++ show a ++ " already occupied.\n"
      in either Right (const $ Left errMsg)
         $ refExprAt r a
  Right $ _insert a e r

-- | PITFALL: Unsafe. Checks neither that the RefExpr is valid, nor that
-- the Addr collides with nothing already present.
_insert :: Addr -> RefExpr -> Rslt -> Rslt
_insert a e r = Rslt {
    _refExprAt = M.insert a e $ _refExprAt r
  , _addrOf = M.insert e a $ _addrOf r
  , _variety = M.insert a (refExprVariety e) $ _variety r
  , _has = let
      (positions :: Map Role Addr) = M.fromList $ refExprPositions e
      in if null positions then _has r
         else M.insert a positions $ _has r
  , _isIn = invertAndAddPositions (_isIn r) (a, refExprPositions e)
  }

-- | PITFALL: One could put the Rslt into an invalid state by running this
-- on an RefExpr that appears in other RefExprs. This only deletes mentions in
-- which it is the container or "the thing", but not the contained.
_deleteInternalMentionsOf :: Addr -> Rslt -> Either String Rslt
_deleteInternalMentionsOf a r = do
  (aHas       ::           Map Role Addr) <-
    prefixLeft "_deleteInternalMentionsOf" $ has r a
  let (_has2  :: Map Addr (Map Role Addr)) = M.delete a $ _has r
      (_isIn1 :: Map Addr (Set (Role, Addr))) = _isIn r
      (_isIn2 :: Map Addr (Set (Role, Addr))) =
        M.filter (not . null)
        $ M.foldlWithKey f _isIn1 aHas
        where
          f :: Map Addr (Set (Role, Addr)) -> Role -> Addr
            -> Map Addr (Set (Role, Addr))
          f ii rl ad = M.adjust (S.delete (rl,a)) ad ii

  _addrOf2 <- do
    e <- prefixLeft "_deleteInternalMentionsOf" $ refExprAt r a
    Right $ M.delete e $ _addrOf r

  Right $ Rslt {
    _has  = _has2
    , _isIn = _isIn2
    , _variety = M.delete a $ _variety r
    , _refExprAt = M.delete a $ _refExprAt r
    , _addrOf = _addrOf2
    }

deleteUnused :: Addr -> Rslt -> Either String Rslt
deleteUnused a r = do
  users <- prefixLeft "deleteUnused: " $ isIn r a
  if null users
    then _deleteInternalMentionsOf a r
    else Left $ "deleteUnused: Addr " ++ show a
         ++ " is used in other RefExprs.\n"