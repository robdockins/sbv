{-# LANGUAGE FlexibleInstances    #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE Rank2Types           #-}
{-# LANGUAGE ScopedTypeVariables  #-}
{-# LANGUAGE OverloadedStrings    #-}

-----------------------------------------------------------------------------
-- |
-- Module      :  Data.SBV.RegExp
-- Copyright   :  (c) Levent Erkok
-- License     :  BSD3
-- Maintainer  :  erkokl@gmail.com
-- Stability   :  experimental
--
-- A collection of regular-expression related utilities. The recommended
-- workflow is to import this module qualified as the names of the functions
-- are specificly chosen to be common identifiers. Also, it is recommended
-- you use the @OverloadedStrings@ extension to allow literal strings to be
-- used as symbolic-strings and regular-expressions when working with
-- this module.
-----------------------------------------------------------------------------

module Data.SBV.RegExp (
        -- * Regular expressions
        RegExp(..)
        -- * Matching
        , RegExpMatchable(..)
        -- * Constructing regular expressions
        -- ** Literals
        , exactly
        -- ** A class of characters
        , oneOf
        -- ** Spaces
        , newline, whiteSpace, whiteSpaceNoNewLine
        -- ** Separators
        , tab, punctuation
        -- ** Digits
        , digit, octDigit, hexDigit
        -- ** Numbers
        , decimal, octal, hexadecimal
        -- ** Identifiers
        , identifier
        ) where

import Data.SBV.Core.Data
import Data.SBV.Core.Model () -- instances only

-- Only for testing
import Prelude hiding  (length)
import Data.SBV.String (length, charToStr)
import Data.SBV.Char   (isSpace)

-- For doctest use only
--
-- $setup
-- >>> import Data.SBV.Provers.Prover (prove, sat)
-- >>> import Data.SBV.Utils.Boolean  ((<=>), (==>), bAny)
-- >>> import Data.SBV.Core.Model
-- >>> :set -XOverloadedStrings
-- >>> :set -XScopedTypeVariables

-- | Matchable class. Things we can match against a 'RegExp'.
-- TODO: Currently SBV does *not* optimize this call if @s@ is concrete, but
-- rather directly defers down to the solver. We might want to perform the
-- operation on the Haskell side for performance reasons, should this become
-- important.
--
-- For instance, you can generate valid-looking phone numbers like this:
--
-- >>> :set -XOverloadedStrings
-- >>> let dig09 = Range '0' '9'
-- >>> let dig19 = Range '1' '9'
-- >>> let pre   = dig19 * Loop 2 2 dig09
-- >>> let post  = dig19 * Loop 3 3 dig09
-- >>> let phone = pre * "-" * post
-- >>> sat $ \s -> (s :: SString) `match` phone
-- Satisfiable. Model:
--   s0 = "222-2248" :: String
class RegExpMatchable a where
   -- | @`match` s r@ checks whether @s@ is in the language generated by @r@.
   match :: a -> RegExp -> SBool

-- | Matching a character simply means the singleton string matches the regex.
instance RegExpMatchable SChar where
   match = match . charToStr

-- | Matching symbolic strings.
instance RegExpMatchable SString where
   -- >>> prove $ \s -> match s "hello" <=> s .== "hello"
   -- Q.E.D.
   -- >>> prove $ \s -> match s (Loop 2 5 "xyz") ==> length s .>= 6
   -- Q.E.D.
   -- >>> prove $ \s -> match s (Loop 2 5 "xyz") ==> length s .<= 15
   -- Q.E.D.
   -- >>> prove $ \s -> match s (Loop 2 5 "xyz") ==> length s .>= 7
   -- Falsifiable. Counter-example:
   --   s0 = "xyzxyz" :: String
   match s r = lift1 (StrInRe r) opt s
     where -- TODO: Replace this with a function that concretely evaluates the string against the
           -- reg-exp, possible future work. But probably there isn't enough ROI.
           opt :: Maybe (String -> Bool)
           opt = Nothing

-- | A literal regular-expression, matching the given string exactly. Note that
-- with 'OverloadedStrings' extension, you can simply use a Haskell
-- string to mean the same thing, so this function is rarely needed.
--
-- >>> prove $ \(s :: SString) -> s `match` exactly "LITERAL" <=> s .== "LITERAL"
-- Q.E.D.
exactly :: String -> RegExp
exactly = Literal

-- | Helper to define a character class.
--
-- >>> prove $ \(c :: SChar) -> c `match` oneOf "ABCD" <=> bAny (c .==) (map literal "ABCD")
-- Q.E.D.
oneOf :: String -> RegExp
oneOf = foldr (\char re -> exactly [char] + re) None

-- | Recognize a newline. Also includes carriage-return and form-feed.
--
-- >>> prove $ \c -> c `match` newline ==> isSpace c
-- Q.E.D.
newline :: RegExp
newline = oneOf "\n\r\f"

-- | Recognize a tab.
--
-- >>> prove $ \c -> c `match` tab ==> c .== literal '\t'
-- Q.E.D.
tab :: RegExp
tab = oneOf "\t"

-- | Recognize white space.
--
-- >>> prove $ \c -> c `match` whiteSpace ==> isSpace c
-- Q.E.D.
whiteSpace :: RegExp
whiteSpace = newline + tab + oneOf "\v\160 "

whiteSpaceNoNewLine :: a
whiteSpaceNoNewLine = error "whiteSpaceNoNewLine"

punctuation         :: a
punctuation         = error "punctuation"

digit               :: a
digit               = error "digit"

octDigit            :: a
octDigit            = error "octDigit"

hexDigit            :: a
hexDigit            = error "hexDigit"

decimal             :: a
decimal             = error "decimal"

octal               :: a
octal               = error "octal"

hexadecimal         :: a
hexadecimal         = error "hexadecimal"

identifier          :: a
identifier          = error "identifier"

-- | Lift a unary operator over strings.
lift1 :: forall a b. (SymWord a, SymWord b) => StrOp -> Maybe (a -> b) -> SBV a -> SBV b
lift1 w mbOp a
  | Just cv <- concEval1 mbOp a
  = cv
  | True
  = SBV $ SVal k $ Right $ cache r
  where k = kindOf (undefined :: b)
        r st = do swa <- sbvToSW st a
                  newExpr st k (SBVApp (StrOp w) [swa])

-- | Concrete evaluation for unary ops
concEval1 :: (SymWord a, SymWord b) => Maybe (a -> b) -> SBV a -> Maybe (SBV b)
concEval1 mbOp a = literal <$> (mbOp <*> unliteral a)

-- | Quiet GHC about testing only functions
__unused :: a
__unused = undefined length isSpace