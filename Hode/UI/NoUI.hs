-- | = Functions from an `Rslt` and a parsed `String`,
-- to search, insert, show.
-- Theoretically, one could maintain an Rslt using GHCI with just these,
-- without ever using the TUI.

{-# LANGUAGE ScopedTypeVariables #-}

module Hode.UI.NoUI (
    nShowRslt      -- ^ Rslt -> [String]
  , nShowRsltIO    -- ^ Rslt -> IO ()

  , nInsert        -- ^ Rslt -> String -> Either String (Rslt, Addr)
  , nInsert'       -- ^ Rslt -> String -> Either String Rslt
  , nInserts       -- ^ Foldable f =>
                   --   Rslt -> f String -> Either String Rslt

  , nFind          -- ^ Rslt -> String -> Either String [(Addr, Expr)]
  , nFindStrings   -- ^ Rslt -> String -> Either String [(Addr, String)]
  , nFindStringsIO -- ^ Rslt -> String -> IO ()

  , module Internal
  ) where

import           Control.Monad (foldM)
import qualified Data.Map       as M
import qualified Data.Set as S

import Hode.Rslt.Edit
import Hode.Rslt.RLookup
import Hode.Rslt.RTypes
import Hode.Rslt.Show
import Hode.Util.Misc
import Hode.UI.NoUI.Internal as Internal


nShowRslt :: Rslt -> [String]
nShowRslt r = let
  m = _addrToRefExpr r
  showPair k = let val = flip M.lookup m k
               in show k ++ ": " ++ show val
  in fmap showPair $ M.keys m

nShowRsltIO :: Rslt -> IO ()
nShowRsltIO = mapM_ putStrLn . nShowRslt

nInsert :: Rslt -> String -> Either String (Rslt, Addr)
nInsert r s = prefixLeft "nInsert: " $
              nExpr r s >>= exprToAddrInsert r

nInsert' :: Rslt -> String -> Either String Rslt
nInsert' r s = fst <$> nInsert r s

nInserts :: Foldable f
         => Rslt -> f String -> Either String Rslt
nInserts r ss = foldM nInsert' r ss

nFind :: Rslt -> String -> Either String [(Addr, Expr)]
nFind r s = do as <- S.toList <$> nFindAddrs r s
               es <- ifLefts $ map (addrToExpr r) as
               Right $ zip as es

nFindStrings :: Rslt -> String -> Either String [(Addr, String)]
nFindStrings r s = do
  (as,es) :: ([Addr],[Expr]) <- unzip <$> nFind r s
  ss <- ifLefts $ map (eShow r) es
  Right $ zip as ss

nFindStringsIO :: Rslt -> String -> IO ()
nFindStringsIO r q = case nFindStrings r q
  of Left err -> putStrLn err
     Right ss -> let f (a,s) = show a ++ ": " ++ s
                 in mapM_ putStrLn $ map f ss
