{-# LANGUAGE ScopedTypeVariables #-}

module Hode.Util.Parse where

import           Data.Char
import qualified Data.List as L
import           Data.Void (Void)
import           Text.Megaparsec
import           Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer as L


-- | = ordinary String functionsx

splitAfterFirstLexeme :: String -> (String, String)
splitAfterFirstLexeme s =
  let (h,t) = span (not . isSpace) $ L.dropWhile isSpace s
  in (h, L.dropWhile isSpace t)

hasMultipleWords :: String -> Bool
hasMultipleWords = (/=) "" . snd . splitAfterFirstLexeme


-- | = parsing via Megaparsec

type Parser = Parsec Void String

-- | space consumer
sc :: Parser ()
sc = L.space space1 lineCmnt blockCmnt
  where
    lineCmnt  = L.skipLineComment "//"
    blockCmnt = L.skipBlockComment "/*" "*/"

lexeme :: Parser a -> Parser a
lexeme = L.lexeme sc

symbol :: String -> Parser String
symbol = L.symbol sc

parens :: Parser a -> Parser a
parens = between (symbol "(") $ symbol ")"

integer :: Parser Integer
integer = lexeme L.decimal

filepath :: Parser String
filepath = lexeme $ some $ foldr1 (<|>)
  (alphaNumChar : map char ['.','/','_','-'])

identifier :: Parser String
identifier = lexeme $ some alphaNumChar

identifier_alphaLed :: Parser String
identifier_alphaLed = lexeme $ (:) <$> letterChar <*> many alphaNumChar
  -- `(:) :: Char -> String -> String, and
  -- `letterChar :: Parser Char`, so
  -- `(:) <$> letterChar :: Parser (String -> String)

phrase :: Parser String -- | does not accept the empty string
phrase = concat . L.intersperse " " <$> some identifier

nonPrefix :: Parser a -> Parser a
nonPrefix p = p <*
  ( -- This double-negative says it must be followed by whitespace,
    -- a quotation mark, or a paren. I would use "followed by",
    -- but I don't see it in Text.Megaparsec.
    -- TODO : This feels inelegant, like it works against the lexer.
    notFollowedBy $ satisfy $ \c -> not $ elem c "\n \"()" )
