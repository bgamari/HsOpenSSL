{- -*- haskell -*- -}

#include "HsOpenSSL.h"

-- |Message verification using asymmetric cipher and message digest
-- algorithm. This is an opposite of "OpenSSL.EVP.Sign".

module OpenSSL.EVP.Verify
    ( VerifyStatus(..)
    , verify
    , verifyBS
    , verifyLBS
    )
    where

import           Control.Monad
import           Data.ByteString as B
import           Data.ByteString.Base
import qualified Data.ByteString.Char8 as B8
import qualified Data.ByteString.Lazy.Char8 as L8
import           Data.Typeable
import           Foreign
import           Foreign.C
import           OpenSSL.EVP.Digest
import           OpenSSL.EVP.PKey
import           OpenSSL.Utils

-- |@'VerifyStatus'@ represents a result of verification.
data VerifyStatus = VerifySuccess
                  | VerifyFailure
                    deriving (Show, Eq, Typeable)


foreign import ccall unsafe "EVP_VerifyFinal"
        _VerifyFinal :: Ptr EVP_MD_CTX -> Ptr CChar -> CUInt -> Ptr EVP_PKEY -> IO Int


verifyFinalBS :: DigestCtx -> String -> PKey -> IO VerifyStatus
verifyFinalBS ctx sig pkey
    = withDigestCtxPtr ctx $ \ ctxPtr ->
      withCStringLen sig $ \ (buf, len) ->
      withPKeyPtr pkey $ \ pkeyPtr ->
      _VerifyFinal ctxPtr buf (fromIntegral len) pkeyPtr >>= interpret
    where
      interpret :: Int -> IO VerifyStatus
      interpret 1 = return VerifySuccess
      interpret 0 = return VerifyFailure
      interpret _ = raiseOpenSSLError

-- |@'verify'@ verifies a signature and a stream of data. The string
-- must not contain any letters which aren't in the range of U+0000 -
-- U+00FF.
verify :: Digest          -- ^ message digest algorithm to use
       -> String          -- ^ message signature
       -> PKey            -- ^ public key to verify the signature
       -> String          -- ^ input string to verify
       -> IO VerifyStatus -- ^ the result of verification
verify md sig pkey input
    = verifyLBS md sig pkey (L8.pack input)

-- |@'verifyBS'@ verifies a signature and a chunk of data.
verifyBS :: Digest          -- ^ message digest algorithm to use
         -> String          -- ^ message signature
         -> PKey            -- ^ public key to verify the signature
         -> ByteString      -- ^ input string to verify
         -> IO VerifyStatus -- ^ the result of verification
verifyBS md sig pkey input
    = do ctx <- digestStrictly md input
         verifyFinalBS ctx sig pkey

-- |@'verifyLBS'@ verifies a signature of a stream of data.
verifyLBS :: Digest          -- ^ message digest algorithm to use
          -> String          -- ^ message signature
          -> PKey            -- ^ public key to verify the signature
          -> LazyByteString  -- ^ input string to verify
          -> IO VerifyStatus -- ^ the result of verification
verifyLBS md sig pkey input
    = do ctx <- digestLazily md input
         verifyFinalBS ctx sig pkey