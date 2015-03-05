module Record.Preprocessor where

import Record.Prelude
import Record.Preprocessor.Model
import qualified Record.Preprocessor.Parsing as Parsing
import qualified Record.Preprocessor.Rendering as Rendering
import qualified Record.Preprocessor.HSE as HSE


process :: String -> String -> Either Error String
process name code =
  flip runReaderT name $ do
    asts <- parseUnleveledASTs code
    levels <- reifyUnleveledASTLevels asts
    undefined

type Error =
  (CursorOffset, String)
  
type Process =
  ReaderT String (Either Error)


parseUnleveledASTs :: String -> Process [DecontextedAST UnleveledAST]
parseUnleveledASTs code =
  ReaderT $ \name -> Parsing.run (Parsing.total (many (Parsing.decontextedAST Parsing.unleveledAST))) name code

-- |
-- Detect levels of all top-level record splices.
reifyUnleveledASTLevels :: [DecontextedAST UnleveledAST] -> Process [Level]
reifyUnleveledASTLevels l =
  case HSE.reifyLevels HSE.Mode_Module $ foldMap (Rendering.decontextedAST (const "Ѣ")) l of
    HSE.ParseOk a -> return a
    HSE.ParseFailed l m -> lift $ Left (correctOffset $ HSE.srcLocToCursorOffset l, m)
  where
    correctOffset o =
      stringCursorOffset $
      foldMap (Rendering.decontextedAST Rendering.unleveledAST) $
      catMaybes $
      flip evalState mempty $ forM l $ \ast -> do
        modify $ (<> ((stringCursorOffset . Rendering.decontextedAST (const "Ѣ")) ast))
        o' <- get
        if o' < o
          then return $ Just ast
          else return $ Nothing
      where
        stringCursorOffset =
          (\(CursorOffset l c) -> CursorOffset (pred l) (pred c)) .
          either (error . showString "Unexpected cursor offset parsing error: " . show) id .
          Parsing.run Parsing.cursorOffsetAtEnd ""
      
reifyExpASTLevels :: ExpAST UnleveledAST -> Process [Level]
reifyExpASTLevels =
  \case
    ExpAST_Record strict (RecordExpBody_Named sections) ->
      fmap concat . mapM reifyUnleveledASTLevels . catMaybes . map snd $ sections
