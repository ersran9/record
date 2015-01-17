module Record where

import BasePrelude
import Language.Haskell.TH
import Language.Haskell.TH.Quote
import qualified Record.Types as Types
import qualified Record.Lens as Lens
import qualified Record.Parser as Parser
import qualified Data.Text as T


record :: QuasiQuoter
record =
  QuasiQuoter
    (const $ fail "Expression context is not supported")
    (const $ fail "Pattern context is not supported")
    type'
    (const $ fail "Declaration context is not supported")
  where
    type' =
      join . fmap (either fail return . renderRecordType) .
      either (fail . showString "Parser failure: ") return .
      Parser.run Parser.recordQQ . fromString

lens :: QuasiQuoter
lens =
  undefined

renderRecordType :: Parser.RecordType -> Either String Type
renderRecordType l =
  checkRepeatedLabels >> getRecordTypeName >>= constructType
  where
    checkRepeatedLabels =
      maybe (return ()) (Left . showString "Repeated labels: " . show) $
      mfilter (not . null) . Just $ 
      map (fst . head) $
      filter ((> 1) . length) $
      groupWith fst l
    getRecordTypeName =
      maybe (Left (showString "Record arity " . shows arity . shows " is not supported" $ ""))
            (Right) $
      recordTypeNameByArity arity
      where
        arity = length l
    constructType n =
      foldl (\a (l, t) -> AppT <$> (AppT <$> a <*> pure (textLitT l)) <*> (renderType t))
            (pure (ConT n))
            (sortWith fst l)
      where
        textLitT =
          LitT . StrTyLit . T.unpack

recordTypeNameByArity :: Int -> Maybe Name
recordTypeNameByArity =
  \case
    1 -> Just ''Types.Record1
    2 -> Just ''Types.Record2
    3 -> Just ''Types.Record3
    _ -> Nothing

renderType :: Parser.Type -> Either String Type
renderType =
  \case
    Parser.AppType a b  -> AppT <$> renderType a <*> renderType b
    Parser.VarType n    -> Right $ VarT (mkName (T.unpack n))
    Parser.ConType n    -> Right $ ConT (mkName (T.unpack n))
    Parser.TupleType a  -> Right $ TupleT a
    Parser.ArrowType    -> Right $ ArrowT
    Parser.ListType     -> Right $ ListT
    Parser.RecordType a -> renderRecordType a



