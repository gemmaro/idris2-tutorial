# 依存和型

ここまでの依存的に型付いたプログラミングの例では、
ベクタの長さのような型指標はコンパイル時に分かっていたり、
コンパイル時に知られている値から計算できるものでした。
しかし現実のアプリケーションではそのような情報が実行時まで入手できないことがよくあり、
利用者や周囲の世界の状態によって下される決定に依る値となります。
例えばファイルの内容を複数行の文章のベクタとして保管するとき、
一般的にこのベクタの長さはファイルが記憶領域に読み込まれるまで知られていません。
結果として取り扱う値の型が実行時にのみ知られている他の値に依存することとなり、
これらの型は依存する値へのパターン照合によってのみ行えることはよくあります。
こうした依存関係を表現するためには[依存和型](https://en.wikipedia.org/wiki/Dependent_type#%CE%A3_type)と呼ばれるものが必要です。
依存対と、それを一般化した依存レコードがそれです。

```idris
module Tutorial.DPair

import Control.Monad.State

import Data.DPair
import Data.Either
import Data.HList
import Data.List
import Data.List1
import Data.Singleton
import Data.String
import Data.Vect

import Text.CSV

%default total
```

## 依存対

既にベクタの長さ指標がどれほど便利なのかについての幾つかの例を見てきました。
これがあれば関数のできることとできないことを型でより精密に表現できました。
例えばベクタにおける`map`や`traverse`操作は厳密に同じ長さのベクタを返します。
型がこれが正しいことを保証しており、したがって以下の関数は完全に安全で証明上全域です。

```idris
parseAndDrop : Vect (3 + n) String -> Maybe (Vect n Nat)
parseAndDrop = map (drop 3) . traverse parsePositive
```

`traverse parsePositive`の引数は型が`Vect (3 + n) String`なので、
その結果は型が`Maybe (Vect (3 + n) Nat)`となります。
したがってこれを`drop 3`での呼び出しに使うのは安全です。
なお、これ自体はコンパイル時に知られていることです。
つまり、最初の引数が少なくとも3引数のベクタであるという前提条件を
長さの指標に折り込んだため、ここから結果の長さを導出することができたのです。

### 未知の長さのベクタ

しかしこれはいつも可能とは限りません。
`List`に定義され`Data.List`から輸出されている以下の関数について考えてください。

```repl
Tutorial.Relations> :t takeWhile
Data.List.takeWhile : (a -> Bool) -> List a -> List a
```

これはリスト引数から与えられた条件が`True`を返すような最長の前部分を取得するものです。
この場合、この前部分がどこまで長くなるかはリストの要素と前提条件に依存しています。
そのような関数をベクタについて書くことができるでしょうか？
試してみましょう。

```idris
takeWhile' : (a -> Bool) -> Vect n a -> Vect m a
```

さあ、これを実装してみてください。
長く試すことはありません。
というのは証明上全域な方法ではできないからです。
疑問に思うのは、ここで何が問題なのかということです。
これを理解するには`takeWhile'`の型が約束していることに気付かねばなりません。
「あらゆる型`a`の値を操作する述語と、
この型の値を持つあらゆるベクタと、
全ての長さ`m`について、
型`a`の値を持つ長さ`m`のベクタをあげます。」
3引数全てが[*全称量化され*](https://en.wikipedia.org/wiki/Universal_quantification)ているということです。
つまり関数の呼び出し手が、述語、入力ベクタ、ベクタの持つ値の型、
そして*出力ベクタの長さ*を自由に選ぶのです。
信じていませんか？
こちらを見てください。

```idris
-- 困ったことになっているようです。`Void`の非空なベクタがあります……
voids : Vect 7 Void
voids = takeWhile' (const True) []

-- ……上から直ちに`Void`の証明に従います。
proofOfVoid : Void
proofOfVoid = head voids
```

`takeWhile'`を呼び出す時に`m`の値を自由に決められたことがわかりますか？
`takeWhile'`に空ベクタ（型`Void`の値を持つ唯一の既にあるベクタ）を渡し、
関数の型は同じ型の値を持つ非空ベクタを何とかして返すと約束します。
そこから自由に最初のものを抽出できるのです。

幸いにもIdrisはこれを許しません。
`takeWhile'`をズルする（例えば全域性検査器を切って永久にループさせるなど）ことなく実装することは決してできません。
そこで、どうやって`takeWhile'`の結果を型で表現すればよいのか、という疑問が残ります。
この答えは「*依存対*を使うべし」になります。
ベクタにその長さに合致する値が対になったものです。

```idris
record AnyVect a where
  constructor MkAnyVect
  length : Nat
  vect   : Vect length a
```

これは述語論理における[*存在量化*](https://en.wikipedia.org/wiki/Existential_quantification)に対応します。
つまり、ある自然数があって、それは今持っているベクタの長さに対応する、というものです。
着目していただきたいのは、
`AnyVect a`の外側からは最早包まれたベクタの長さが型水準では見えず、
それでも実行時にそのベクタを調べれば何らかのことがわかる、ということです。
これは実際のベクタと共に包まれているためです。
`takeWhile`を型`AnyVect a`の値を返すように実装できます。

```idris
takeWhile : (a -> Bool) -> Vect n a -> AnyVect a
takeWhile f []        = MkAnyVect 0 []
takeWhile f (x :: xs) = case f x of
  False => MkAnyVect 0 []
  True  => let MkAnyVect n ys = takeWhile f xs in MkAnyVect (S n) (x :: ys)
```

これは証明上全域にはたらきますが、
それはこの関数の呼び出し手が今や結果のベクタの長さを自力で選ぶことができないからです。
関数`takeWhile`がこの長さを決めてベクタと一緒に返し、
型検査器は2つの値を対にするときに誤ちを犯していないことを立証します。
実際、長さはIdrisが自動的に推論できるので、
望むなら下線文字で置き換えることができます。

```idris
takeWhile2 : (a -> Bool) -> Vect n a -> AnyVect a
takeWhile2 f []        = MkAnyVect _ []
takeWhile2 f (x :: xs) = case f x of
  False => MkAnyVect 0 []
  True  => let MkAnyVect _ ys = takeWhile2 f xs in MkAnyVect _ (x :: ys)
```

まとめると、汎化関数型の引数は全称量化されており、
それらの値はその関数の呼び出し側で決められます。
依存レコード型があれば存在量化された値を記述できます。
呼び出し手はそのような値を自由に選ぶことはできません。
そうした値は関数の結果の一部として返されるのです。

なお、Idrisでは全称量化について明示的にさせることができます。
`takeWhile'`の型は以下のようにも書くことができます。

```idris
takeWhile'' : forall a, n, m . (a -> Bool) -> Vect n a -> Vect m a
```

全称量化された引数はIdrisにより暗黙消去引数に脱糖されます。
上記は、以前に見たことがあるような以下の関数型の、より冗長でない版です。

```idris
takeWhile''' :  {0 a : _}
             -> {0 n : _}
             -> {0 m : _}
             -> (a -> Bool)
             -> Vect n a
             -> Vect m a
```

Idrisでは全称量化について明示的にしたいかどうか決めるのは自由です。
時々型水準で起こっていることを理解する助けになります。
他の言語、例えば[PureScript](https://www.purescript.org/)はよりこれについて厳格になっています。
そこでは全称量化された引数への明示的な註記は[必須](https://github.com/purescript/documentation/blob/master/language/Differences-from-Haskell.md#explicit-forall)です。

### 依存対の本質

ここで起こっていることを理解するには時間と経験がいるかもしれません。
少なくとも筆者の場合はIdrisとの多くの対話を経てようやく依存対とは何かわかりました。
何らかの型の*値*を、最初の値から計算された型の2つ目の値と対にしたものです。
例えば自然数`n`（値）が長さ`n`（2つ目の値で、最初の値に*依存*する型のもの）のベクタと対になります。
これは依存対のあるプログラミングのごく基本的な概念なので、
*Prelude*から一般的な依存対型が提供されています。
以下はその実装です。
（プライム記号を付けて曖昧回避しました。）

```idris
record DPair' (a : Type) (p : a -> Type) where
  constructor MkDPair'
  fst : a
  snd : p fst
```

ここで起こっていることを理解するのは不可欠です。
2つの引数、型`a`と関数`p`があり、後者は型`a`の*値*から*型*を計算します。
まずある値 (`fst`) があり、それから2つ目の値 (`snd`) の*型*を計算するのに使われるのです。
例えば以下は`DPair`として表現された`AnyVect a`です。

```idris
AnyVect' : (a : Type) -> Type
AnyVect' a = DPair Nat (\n => Vect n a)
```

なお、`\n => Vect n a`は`Nat`から`Type`への関数です。
Idrisは依存対を表現する特別な構文を提供していますが、
それは依存対が第一級型を持つプログラミング言語で重要な建築資材だからです。

```idris
AnyVect'' : (a : Type) -> Type
AnyVect'' a = (n : Nat ** Vect n a)
```

REPLで調べると`AnyVect''`の右側は`AnyVect'`の右側に脱糖されることがわかります。

```repl
Tutorial.Relations> (n : Nat ** Vect n Int)
DPair Nat (\n => Vect n Int)
```

Idrisは`n`が型`Nat`でなければいけないことを推論できるため、
この情報を省くことができます。
（それでも全体の式を括弧内に置くことは必要です。）

```idris
AnyVect3 : (a : Type) -> Type
AnyVect3 a = (n ** Vect n a)
```

これにより自然数`n`と長さ`n`のベクタを対にすることができましたが、
それはちょうど`AnyVect`でしたことと同じです。
したがって`takeWhile`を、
自前の型`AnyVect`の代わりに`DPair`を返すように書き換えられます。
なお、通常の対のように、依存対を作ったりパターン照合したりするのに
同じ構文`(x ** y)`を使うことができます。

```idris
takeWhile3 : (a -> Bool) -> Vect m a -> (n ** Vect n a)
takeWhile3 f []        = (_ ** [])
takeWhile3 f (x :: xs) = case f x of
  False => (_ ** [])
  True  => let (_  ** ys) = takeWhile3 f xs in (_ ** x :: ys)
```

ちょうど通常の対のように、依存対の構文を使って依存3対やそれ以上のものを定義できます。

```idris
AnyMatrix : (a : Type) -> Type
AnyMatrix a = (m ** n ** Vect m (Vect n a))
```

### 消去された存在子

時々、指標値を指標付けられた型の値へのパターン照合で決定することができることがあります。
例えばベクタへのパターン照合により長さの指標を知ることができます。
このような場合には厳密には実行時に指標を持ち回る必要はなく、
最初の引数が数量子ゼロの特別版の依存対を書くことができます。
*base*のモジュール`Data.DPair`はこの用途でデータ型`Exists`を輸出しています。

例として以下は型`Exists`の値を返す版の`takeWhile`です。

```idris
takeWhileExists : (a -> Bool) -> Vect m a -> Exists (\n => Vect n a)
takeWhileExists f []        = Evidence _ []
takeWhileExists f (x :: xs) = case f x of
  True  => let Evidence _ ys = takeWhileExists f xs
            in Evidence _ (x :: ys)
  False => takeWhileExists f xs
```

消去された値を復元するには*base*のモジュール`Data.Singleton`にあるデータ型`Singleton`が便利かもしれません。
これは保有する*値*を引数に取るものです。

```idris
true : Singleton True
true = Val True
```

これは*単独*型と呼ばれます。
ちょうど1つの値に対応する型です。
固定値`true`以外の値を返すことは型エラーであり、Idrisはこのことを知っています。

```idris
true' : Singleton True
true' = Val _
```

これを使えば（消去された！）ベクタの長さを何もないところから引っ張り出すのに使えます。

```idris
vectLength : Vect n a -> Singleton n
vectLength []        = Val 0
vectLength (x :: xs) = let Val k = vectLength xs in Val (S k)
```

この関数は`Data.Vect.length`よりも遥かに強い保証が付いてきます。
後者は単に*どんな*自然数も返すと言っていますが、
`vectLength`は型検査のために厳密に`n`を返さ*ねばなりません*。
実演として以下はよく型付けされたいんちきな`length`の実装です。

```idris
bogusLength : Vect n a -> Nat
bogusLength = const 0
```

手元で簡単に確かめられますが、
これは`vectLength`の妥当な実装として受け付けられないでしょう。

（`Data.Vect.length`ではなく）`vectLength`の助けを借りて、
消去された存在子を適切な依存対に変換できます。

```idris
toDPair : Exists (\n => Vect n a) -> (m ** Vect m a)
toDPair (Evidence _ as) = let Val m = vectLength as in (m ** as)
```

ここでも簡単な演習として、
`length`を使って`toDPair`を実装してみましょう。
どのようにIdrisが`length`の結果と実際のベクタの長さを統合するのに失敗するかに注目してください。

### 演習 その1

1. `Data.List.filter`と似たようにベクタを篩に掛ける関数を宣言して実装してください。

2. `Data.List.mapMaybe`と似たようにベクタの値の上で部分関数を写す関数を宣言し実装してください。

3. `Data.List.dropWhile`に似たベクタ用の関数を宣言し実装してください。
   `Data.DPair.Exists`を返却型に使ってください。

4. 適切な依存対を返すようにして演習3を反復してください。
   実装には演習3の関数を使ってください。

## 用例：核酸

核酸であるRNAとDNAについての計算を走らせる、小さく単純化したライブラリを作ってみたいと思います。
これらの核酸は5つの核酸塩基から構築されるもので、そのうち3つは両方の種類の核酸で使われ、2つはそれぞれの酸の種類に特有のものです。
必ず妥当な塩基のみが核酸鎖にあるようにしたいです。
以下は取り得るコードの1つです。

```idris
data BaseType = DNABase | RNABase

data Nucleobase : BaseType -> Type where
  Adenine  : Nucleobase b
  Cytosine : Nucleobase b
  Guanine  : Nucleobase b
  Thymine  : Nucleobase DNABase
  Uracile  : Nucleobase RNABase

NucleicAcid : BaseType -> Type
NucleicAcid = List . Nucleobase

RNA : Type
RNA = NucleicAcid RNABase

DNA : Type
DNA = NucleicAcid DNABase

encodeBase : Nucleobase b -> Char
encodeBase Adenine  = 'A'
encodeBase Cytosine = 'C'
encodeBase Guanine  = 'G'
encodeBase Thymine  = 'T'
encodeBase Uracile  = 'U'

encode : NucleicAcid b -> String
encode = pack . map encodeBase
```

`Uracile`をDNA鎖で使うと型エラーになります。

```idris
failing "Mismatch between: RNABase and DNABase."
  errDNA : DNA
  errDNA = [Uracile, Adenine]
```

なお、核酸塩基`Adenine`、`Cytosine`、`Guanine`用に変数を使いました。
これらはここでも全称量化されており、
使い手のコードが自由にここの値を選びます。
これによりこれらの塩基をDNA*及び*RNAで使うことができます。

```idris
dna1 : DNA
dna1 = [Adenine, Cytosine, Guanine]

rna1 : RNA
rna1 = [Adenine, Cytosine, Guanine]
```

`Thymine`と`Uracile`についてはより強い制限があります。
`Thymine`はDNAでしか許されていない一方で、
`Uracile`はRNA鎖で使うように制限されています。
DNAとRNA鎖の構文解析器を書いてみましょう。

```idris
readAnyBase : Char -> Maybe (Nucleobase b)
readAnyBase 'A' = Just Adenine
readAnyBase 'C' = Just Cytosine
readAnyBase 'G' = Just Guanine
readAnyBase _   = Nothing

readRNABase : Char -> Maybe (Nucleobase RNABase)
readRNABase 'U' = Just Uracile
readRNABase c   = readAnyBase c

readDNABase : Char -> Maybe (Nucleobase DNABase)
readDNABase 'T' = Just Thymine
readDNABase c   = readAnyBase c

readRNA : String -> Maybe RNA
readRNA = traverse readRNABase . unpack

readDNA : String -> Maybe DNA
readDNA = traverse readDNABase . unpack
```

ここでも両方の鎖の種類に登場する塩基の場合は、
全称量化された`readAnyBase`を使うところでは自由に塩基の種類を選ぶことができます。
しかし`Thymine`や`Uracile`の値は決して得られません。

これで核酸塩基の並びにおける単純な計算を幾つか実装することができます。
例えば鎖の補完を出すことができます。

```idris
complementRNA' : RNA -> RNA
complementRNA' = map calc
  where calc : Nucleobase RNABase -> Nucleobase RNABase
        calc Guanine  = Cytosine
        calc Cytosine = Guanine
        calc Adenine  = Uracile
        calc Uracile  = Adenine

complementDNA' : DNA -> DNA
complementDNA' = map calc
  where calc : Nucleobase DNABase -> Nucleobase DNABase
        calc Guanine  = Cytosine
        calc Cytosine = Guanine
        calc Adenine  = Thymine
        calc Thymine  = Adenine
```

ああ、コードの重複が！
ここではそこまで悪くありませんが、
山のような塩基のごく一部に特別なものを含むものがある状況を想像してください。
もちろん、もっとうまくできますよね？
不幸にも以下は動きません。

```idris
complementBase' : Nucleobase b -> Nucleobase b
complementBase' Adenine  = ?what_now
complementBase' Cytosine = Guanine
complementBase' Guanine  = Cytosine
complementBase' Thymine  = Adenine
complementBase' Uracile  = Adenine
```

ほぼうまくいきますが、`Adenine`の場合は例外です。
思い出してほしいのですが、変数`b`は全称量化されており、
関数の*呼び出し手*が`b`が何であるかを決められるのです。
したがって単に`Thymine`を返すことはできません。
呼び出し手が`Nucleobase RNABase`を代わりに望んでいるかもしれないため、
Idrisは型エラーを応答するのです。
これを遣り過ごす一案は追加で（明示的ないし暗黙的に）塩基の種類を表す消去される引数を取ることです。

```idris
complementBase : (b : BaseType) -> Nucleobase b -> Nucleobase b
complementBase DNABase Adenine  = Thymine
complementBase RNABase Adenine  = Uracile
complementBase _       Cytosine = Guanine
complementBase _       Guanine  = Cytosine
complementBase _       Thymine  = Adenine
complementBase _       Uracile  = Adenine
```

これもまた依存*関数*型の一例です。
（[*依存積型*](https://en.wikipedia.org/wiki/Dependent_type#%CE%A0_type)とも呼ばれます。）
入出力型が両方とも最初の引数の*値*に*依存*しています。
これを使えばどんな核酸塩基の補完も計算できます。

```idris
complement : (b : BaseType) -> NucleicAcid b -> NucleicAcid b
complement b = map (complementBase b)
```

さて、ここで興味深い用例があります。
利用者の入力から塩基配列を読んで2つの文字列を受け付けます。
最初のものは利用者がDNAないしRNAのどちらの鎖を入力しようとしているかで、2つ目は並びそのものです。
そのような関数の型はどうあるべきでしょうか。
副作用を伴う計算を記述しているので何か`IO`が絡むものになりそうです。
利用者の入力はほとんどいつでも検証されて翻訳される必要があるので、何か間違っていればこの場合のためのエラー型が必要です。
最終的に利用者はRNAないしDNA鎖の何れかを入力したいので、この区別もまたコードで表すべきです。

もちろんそのような用例のための自前の直和型を書くことはいつでもできます。

```idris
data Result : Type where
  UnknownBaseType : String -> Result
  InvalidSequence : String -> Result
  GotDNA          : DNA -> Result
  GotRNA          : RNA -> Result
```

これには全てのありうる出力が単一のデータ型に落とし込まれています。
しかしながら柔軟性の点からは今一つです。
手始めに、エラーを制御して、単にRNAないしDNA鎖を抽出したいのだとしても、
さらに別のデータ型が必要です。

```idris
data RNAOrDNA = ItsRNA RNA | ItsDNA DNA
```

これも方法の1つではありますが、多くの選択肢がある結果については、
早急に面倒なことになりえます。
それに、なぜ既にこうしたことを扱う道具を手中にしているのに、
自前のデータ型を出すことがあるでしょうか。

以下は依存対でこれを落とし込むやり方です。

```idris
namespace InputError
  public export
  data InputError : Type where
    UnknownBaseType : String -> InputError
    InvalidSequence : String -> InputError

readAcid : (b : BaseType) -> String -> Either InputError (NucleicAcid b)
readAcid b str =
  let err = InvalidSequence str
   in case b of
        DNABase => maybeToEither err $ readDNA str
        RNABase => maybeToEither err $ readRNA str

getNucleicAcid : IO (Either InputError (b ** NucleicAcid b))
getNucleicAcid = do
  baseString <- getLine
  case baseString of
    "DNA" => map (MkDPair _) . readAcid DNABase <$> getLine
    "RNA" => map (MkDPair _) . readAcid RNABase <$> getLine
    _     => pure $ Left (UnknownBaseType baseString)
```

核酸塩基の型と塩基配列とを対にしている点に注目してください。
さて、DNAからRNAに転写する関数を実装することを考え、
利用者の入力から対応するRNA配列へと塩基配列を変換したいとします。
以下はこれを行う方法です。

```idris
transcribeBase : Nucleobase DNABase -> Nucleobase RNABase
transcribeBase Adenine  = Uracile
transcribeBase Cytosine = Guanine
transcribeBase Guanine  = Cytosine
transcribeBase Thymine  = Adenine

transcribe : DNA -> RNA
transcribe = map transcribeBase

printRNA : RNA -> IO ()
printRNA = putStrLn . encode

transcribeProg : IO ()
transcribeProg = do
  Right (b ** seq) <- getNucleicAcid
    | Left (InvalidSequence str) => putStrLn $ "Invalid sequence: " ++ str
    | Left (UnknownBaseType str) => putStrLn $ "Unknown base type: " ++ str
  case b of
    DNABase => printRNA $ transcribe seq
    RNABase => printRNA seq
```

依存対の最初の値にパターン照合することで、2つ目の値がRNAないしDNA配列のどちらになるかを判定できます。
最初の場合だとまず配列を転写する必要がありますが、2つ目の場合では直接`printRNA`を呼び出せます。

より興味深い筋書きでは、RNA配列を対応する蛋白質配列に*翻訳*することでしょう。
それでもこの例は単純化した現実世界の筋書きをどのように扱うかを示しています。
データは異なるやり方でコード化されるかもしれず、異なる源から来るかもしれないということです。
精緻な型を使うことで最初に値を正しい書式に変換することを強制されます。
そうすることに失敗するとコンパイル時の例外に繋がりますが、実行時のエラーにはなりませんし、プログラムが静かにいんちきな計算を走らせるような更に悪いことにもなりません。

### 依存型対直和型

`AnyVect a`でお見せしたような依存レコードは依存対の一般化です。
任意の数のフィールドを持つことができ、中に格納されている値を使って他の値の型を計算できます。
核酸塩基の例のような大変単純な場合には、`DPair`、自前の依存レコード、ましてや直和型のどれを使おうとも、あまり問題になりません。
実際、3つのコード化手法には等しく表現力があります。

```idris
Acid1 : Type
Acid1 = (b ** NucleicAcid b)

record Acid2 where
  constructor MkAcid2
  baseType : BaseType
  sequence : NucleicAcid baseType

data Acid3 : Type where
  SomeRNA : RNA -> Acid3
  SomeDNA : DNA -> Acid3
```

これらの符号化の間の損失のない変換を書くことは詰まらないことで、それぞれの符号化があれば1回のパターン照合で、現時点でRNAないしDNAどちらの配列があるのかを決めることができます。
しかしながら依存型は1つ以上の値に依存することができ、演習で見ていくことになります。
そのような場合、直和型と依存対はすぐに手に余るようになり、依存レコードとしてのコードにした方が良くなります。

### 演習 その2

依存対と依存レコードの技能を研ぎ澄ましましょう！
演習2から7では、関数が依存対ないしレコードのどちらを返すべきか、関数が追加の引数を必要とすべきかどうか、何にパターン照合できるのか、そして他のどのユーティリティ関数が必要なのか、について自分で決めなくてはいけません。

1. 核酸塩基の3つのエンコーディングが*同形*（意味：同じ構造をしている）であることを、損失のない変換関数を書くことで証明してください。
   `Acid1`から`Acid2`へのものとその逆、および`Acid1`と`Acid3`についても同様です。

2. 塩基配列は2つに1つの方向で符号化できます。
   これが[*センス*と*アンチセンス*](https://en.wikipedia.org/wiki/Sense_(molecular_biology))です。
   新しいデータ型を宣言し、塩基配列のセンスを記述し、
   そしてこれを型`Nucleobase`と型`DNA`および`RNA`への追加の引数として加えてください。

3. `complement`と`transcribe`の型を精錬し、
   *センス*の変化を反映するようにしてください。
   `transcribe`の場合はアンチセンスDNA鎖はセンスRNA鎖に変換されます。

4. 塩基配列と共に塩基の種類とセンスを格納する依存レコードを定義してください。

5. `readRNA`と`readDNA`を調整し、
   配列の*センス*が入力文字列から読まれるようにしてください。
   センス鎖は "5´-CGGTAG-3´" のように符号化されます。
   アンチセンス鎖は "3´-CGGTAG-5´" のように符号化されます。

6. `encode` を調整し、出力にセンスが含まれるようにしてください。

7. `getNucleicAcid`と`transcribeProg`を向上させ、
   センスと塩基の種類が配列と共に格納され、
   `transcribeProg`が常に*センス*RNA鎖を印字するようにしてください。
   （必要に応じて予め転写します。）

8. 骨折りの成果を喜びましょう。プログラムをREPLで試してください。

補足：ここでも依存レコードを使う代わりに、
4つの構築子からなる直和型を使ってそれぞれの配列の型を符号化することができます。
しかしながら構築子の数はそれぞれの型水準指標の値の数の*積*に対応する分だけ必要です。
したがってこの数は急増する可能性があり、
このような場合には直和型の符号化は長いパターン照合ブロックに繋がりかねません。

## 用例：スキーマ付きCSVファイル

この節では以前CSV構文解析器に取り組んだことに基づいた発展例を見ていきます。
小さなコマンドラインプログラムがほしいとします。
このプログラムでは、
利用者が構文解析してメモリに読み込むCSVの表にスキーマを指定することができます。
始める前に以下が最終的なプログラムを走らせたREPLセッションです。
これを演習で完成させていきます。

```repl
Solutions.DPair> :exec main
Enter a command: load resources/example
Table loaded. Schema: str,str,fin2023,str?,boolean?
Enter a command: get 3
Row 3:

str   | str    | fin2023 | str? | boolean?
------------------------------------------
Floor | Jansen | 1981    |      | t

Enter a command: add Mikael,Stanne,1974,,
Row prepended:

str    | str    | fin2023 | str? | boolean?
-------------------------------------------
Mikael | Stanne | 1974    |      |

Enter a command: get 1
Row 1:

str    | str    | fin2023 | str? | boolean?
-------------------------------------------
Mikael | Stanne | 1974    |      |

Enter a command: delete 1
Deleted row: 1.
Enter a command: get 1
Row 1:

str | str     | fin2023 | str? | boolean?
-----------------------------------------
Rob | Halford | 1951    |      |

Enter a command: quit
Goodbye.
```

この例は書籍[Type-Driven Development with
Idris](https://www.manning.com/books/type-driven-development-with-idris)にある例で使われたプログラムに着想を得ました。

ここで幾つかの点に集中したいと思います。

* 純粋性：メインプログラムのループは例外であれ、
  実装で使われている全ての関数は純粋です。
  この文脈での意味は「`IO`のような副作用を伴ういかなるモナドも走らせない」です。
* 早期に失敗する：コマンドパーサは例外であれ、
  表を更新したりクエリを制御したりする全ての関数が型付けされ、
  失敗することのないような方法で実装されます。

しばしばこれらの2つの指針を固守するよう忠告しますが、
それは関数の大多数を実装しやすく、また検査しやすくするためです。

ライブラリの利用者が作業する表のスキーマ（列の順番と型）を指定できるようにするため、
この情報は実行されるまで知られていません。
現在の表の大きさについても同じことが言えます。
したがって両方の値を依存レコード中のフィールドとして保管することになります。

### スキーマを符号化する

表のスキーマを実行時に調べる必要があります。
理論上は可能ですが、ここではIdrisの型を直接操作するのは感心しません。
その代わり閉じた自前のデータ型を使い、認識できる列の型を記述します。
最初の試みでは幾つかのIdrisの原始型のみ対応します。

```idris
data ColType = I64 | Str | Boolean | Float

Schema : Type
Schema = List ColType
```

次に`Schema`をIdrisの型のリストに変換する方法が必要です。
それからこのリストを使って表中の行に対応する混成リストの指標として使うことになります。

```idris
IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

Row : Schema -> Type
Row = HList . map IdrisType
```

これで表の内容を行のベクタとして格納する依存レコードとして表を記述することができます。
表の行を安全に索引し、また追加する新しい行を解析するため、
現在のスキーマと表の大きさは実行時に既知でなくてはなりません。

```idris
record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)
```

最後に現在の表を操作する命令を記述する指標付けられたデータ型を定義します。
現在の表を命令の指標として使うことにより、
アクセスしたり行を削除したりするためのインデックスが範囲内にあり、
新しい行が現在のスキーマに適合することを確かめられます。
これは2つ目の設計原理を守る上で必要です。
つまり、表における全ての関数は失敗の可能性なく実行されなくてはならない、ということです。

```idris
data Command : (t : Table) -> Type where
  PrintSchema : Command t
  PrintSize   : Command t
  New         : (newSchema : Schema) -> Command t
  Prepend     : Row (schema t) -> Command t
  Get         : Fin (size t) -> Command t
  Delete      : Fin (size t) -> Command t
  Quit        : Command t
```

これで主なアプリケーションのはたらきを実装できます。
利用者がどの命令を入力したかがアプリケーションの現状態に影響します。
約束通り、これは失敗の危険なくできているため、
返り値の型を`Either`に包むことはありません。

```idris
applyCommand : (t : Table) -> Command t -> Table
applyCommand t                 PrintSchema = t
applyCommand t                 PrintSize   = t
applyCommand _                 (New ts)    = MkTable ts _ []
applyCommand (MkTable ts n rs) (Prepend r) = MkTable ts _ $ r :: rs
applyCommand t                 (Get x)     = t
applyCommand t                 Quit        = t
applyCommand (MkTable ts n rs) (Delete x)  = case n of
  S k => MkTable ts k (deleteAt x rs)
  Z   => absurd x
```

指標が常に範囲内にあるように（構築子`Get`と`Delete`）、
また新しい行が表の現在のスキーマに遵守しているように（構築子`Prepend`）、
`Command t`の構築子が型付けられていることを理解してください。

1つこれまでにまだ見たことのないであろう箇所は末行での`absurd`の呼び出しです。
これは`Uninhabited`インターフェースの導出された関数であり、
`Void`のような型や上の例での`Fin 0`といった値が1つも存在しえないことを記述します。
そこで関数`absurd`は単に別の爆発の原理の表明なのです。
まだこれがあまり飲み込めなくても心配ご無用。
`Void`とその使用について次章で見ていきます。

### 命令を解析する

利用者の入力の検証はアプリケーションを書くときの重要な話題です。
早期に起きたのであればアプリケーションの大部分を純粋（この文脈では、「失敗の可能性なしに」という意味です。）に保つことができます。
適切に行われればこの工程はプログラムで何かが間違う可能性の全てではなくともそのほとんどを符号化し制御しますが、これにより厳密に何が問題を生じているのかを利用者に伝える明白なエラー文言を出すことができます。
きっと自身で体験してきたはずですが、どうでもよくないコンピュータプログラムが助けにならない「エラーがありました」文言で終了することほど腹立たしいことはそうありません。

ですからこの重要な話題を細心の注意を持って扱うために、まず自前のエラー型を実装していきます。
これは小さなプログラムでは*厳密には*必須ではありませんが、ひとたびソフトウェアがより複雑になると、どこで何がおかしくなったのか把握するのに凄まじく助けになりえます。
何がおかしくなりえるのかを見付けだすためにはまず、どのように命令が入力されるのかを決める必要があります。
ここではそれぞれの命令について、1つのキーワードとオプションでキーワードから1つの空白文字を隔てて幾つかの引数を使います。
例えば：`"new i64,boolean,str,str"`は新しいスキーマで空の表を初期化します。
こうと決まれば、以下がおかしくなりえる事柄と印字したい文言の一覧です。

* いんちきな命令が入力された。
  入力の復唱と共にその命令を知らない旨の文言と知っている命令の一覧を出す。
* 不当なスキーマが入力された。
  この場合最初の不明な型の位置とそこで見付けた文字列を一覧にし、そして知っている型も列挙する。
* 不当ななCSV符号化がされた行が入力された。
  エラーのある位置、そこで出喰わした文字列、加えて期待される型を一覧にする。
  フィールドの数が少なすぎたり多すぎたりする場合は対応するエラー文言も印字する。
* インデックスが範囲外である。
  利用者が特定の行にアクセスしようとしたり削除しようとしたりするときに起こりえる。
  現在の行番号に加えて入力された値を印字する。
* 値がインデックスとして入力された自然数を表現していない。
  その値に応じたエラー文言を印字する。

把握すべきことが沢山ありますから、これを直和型に符号化しましょう。

```idris
data Error : Type where
  UnknownCommand : String -> Error
  UnknownType    : (pos : Nat) -> String -> Error
  InvalidField   : (pos : Nat) -> ColType -> String -> Error
  ExpectedEOI    : (pos : Nat) -> String -> Error
  UnexpectedEOI  : (pos : Nat) -> String -> Error
  OutOfBounds    : (size : Nat) -> (index : Nat) -> Error
  NoNat          : String -> Error
```

エラー文言を快適に構築するためにはIdrisの文字列内挿機能を使うのが一番です。
任意の文字列式を中括弧で囲んで文字列直値内に置くことができます。
ここで1つ目の中括弧はバックスラッシュでエスケープされている必要があります。
`"foo \{myExpr a b c}`のような感じです。
これを複数行文字列直値と併せていい感じにエラー文言を書式化できます。

```idris
showColType : ColType -> String
showColType I64      = "i64"
showColType Str      = "str"
showColType Boolean  = "boolean"
showColType Float    = "float"

showSchema : Schema -> String
showSchema = concat . intersperse "," . map showColType

allTypes : String
allTypes = concat
         . List.intersperse ", "
         . map showColType
         $ [I64,Str,Boolean,Float]

showError : Error -> String
showError (UnknownCommand x) = """
  Unknown command: \{x}.
  Known commands are: clear, schema, size, new, add, get, delete, quit.
  """

showError (UnknownType pos x) = """
  Unknown type at position \{show pos}: \{x}.
  Known types are: \{allTypes}.
  """

showError (InvalidField pos tpe x) = """
  Invalid value at position \{show pos}.
  Expected type: \{showColType tpe}.
  Value found: \{x}.
  """

showError (ExpectedEOI k x) = """
  Expected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (UnexpectedEOI k x) = """
  Unxpected end of input.
  Position: \{show k}
  Input: \{x}
  """

showError (OutOfBounds size index) = """
  Index out of bounds.
  Size of table: \{show size}
  Index: \{show index}
  Note: Indices start at 1.
  """

showError (NoNat x) = "Not a natural number: \{x}"
```

これでそれぞれの命令の構文解析器を書くことができます。
ベクタ指標、スキーマ、そしてCSVの行を解析する機能が必要です。
CSV書式を使って行を符号化したり復号化したりしているため、
スキーマについてもコンマ区切りの値のリストとして符号化するのが自然です。

```idris
zipWithIndex : Traversable t => t a -> t (Nat, a)
zipWithIndex = evalState 1 . traverse pairWithIndex
  where pairWithIndex : a -> State Nat (Nat,a)
        pairWithIndex v = (,v) <$> get <* modify S

fromCSV : String -> List String
fromCSV = forget . split (',' ==)

readColType : Nat -> String -> Either Error ColType
readColType _ "i64"      = Right I64
readColType _ "str"      = Right Str
readColType _ "boolean"  = Right Boolean
readColType _ "float"    = Right Float
readColType n s          = Left $ UnknownType n s

readSchema : String -> Either Error Schema
readSchema = traverse (uncurry readColType) . zipWithIndex . fromCSV
```

現在のスキーマに基づいてCSVの内容を復号する必要もあります。
スキーマのパターン照合により、型安全なやり方でそれができることに目を向けてください。
このスキーマは実行するまで知られていないものです。
エラー文言に期待される型を加えたいため、残念ながらCSVの解析部分を実装し直す必要があります（これはインターフェース`CSVLine`とエラー型`CSVError`では遥かに大変でしょう）。

```idris
decodeField : Nat -> (c : ColType) -> String -> Either Error (IdrisType c)
decodeField k c s =
  let err = InvalidField k c s
   in case c of
        I64     => maybeToEither err $ read s
        Str     => maybeToEither err $ read s
        Boolean => maybeToEither err $ read s
        Float   => maybeToEither err $ read s

decodeRow : {ts : _} -> String -> Either Error (Row ts)
decodeRow s = go 1 ts $ fromCSV s
  where go : Nat -> (cs : Schema) -> List String -> Either Error (Row cs)
        go k []       []         = Right []
        go k []       (_ :: _)   = Left $ ExpectedEOI k s
        go k (_ :: _) []         = Left $ UnexpectedEOI k s
        go k (c :: cs) (s :: ss) = [| decodeField k c s :: go (S k) cs ss |]
```

指標を暗黙の引数として渡すかどうかについての規則の決定版はありません。
以下に幾つかの観点を示します。

* 明示的引数でのパターン照合は構文的オーバーヘッドが比較的少ない。
* 引数がほとんどの場合に文脈から推論できる場合、
  使い手側のコードでいい感じに使えるように、関数に暗黙子として渡すことを検討する。
* ほとんどの場合でIdrisが推論できない値については（消去されうる）明示的引数を使う。

今欠けているのは現在の表の行にアクセスするインデックスを解析する方法だけです。
インデックスをゼロ始まりの代わりに1始まりにする変換を使いますが、
これはほとんどの非プログラマにとってより自然に感じるためです。

```idris
readFin : {n : _} -> String -> Either Error (Fin n)
readFin s = do
  S k <- maybeToEither (NoNat s) $ parsePositive {a = Nat} s
    | Z => Left $ OutOfBounds n Z
  maybeToEither (OutOfBounds n $ S k) $ natToFin k n
```

遂に利用者の命令のための構文解析器を実装することができます。
関数`Data.String.words`は文字列を空白文字で分割するのに使われます。
ほとんどの場合、命令名に加えて余剰の空白のない単一引数を期待します。
しかしCSVの行は余剰の空白文字があってもよいので、`Data.String.unwords`を分割された文字列に使います。

```idris
readCommand :  (t : Table) -> String -> Either Error (Command t)
readCommand _                "schema"  = Right PrintSchema
readCommand _                "size"    = Right PrintSize
readCommand _                "quit"    = Right Quit
readCommand (MkTable ts n _) s         = case words s of
  ["new",    str] => New     <$> readSchema str
  "add" ::   ss   => Prepend <$> decodeRow (unwords ss)
  ["get",    str] => Get     <$> readFin str
  ["delete", str] => Delete  <$> readFin str
  _               => Left $ UnknownCommand s
```

### アプリケーションを走らせる

残っていることは、
利用者に命令の結果を印字する関数を書き、
命令`"quit"`が入力されるまでアプリケーションを繰り返し走らせることだけです。

```idris
encodeField : (t : ColType) -> IdrisType t -> String
encodeField I64     x     = show x
encodeField Str     x     = show x
encodeField Boolean True  = "t"
encodeField Boolean False = "f"
encodeField Float   x     = show x

encodeRow : (ts : List ColType) -> Row ts -> String
encodeRow ts = concat . intersperse "," . go ts
  where go : (cs : List ColType) -> Row cs -> Vect (length cs) String
        go []        []        = []
        go (c :: cs) (v :: vs) = encodeField c v :: go cs vs

result :  (t : Table) -> Command t -> String
result t PrintSchema = "Current schema: \{showSchema t.schema}"
result t PrintSize   = "Current size: \{show t.size}"
result _ (New ts)    = "Created table. Schema: \{showSchema ts}"
result t (Prepend r) = "Row prepended: \{encodeRow t.schema r}"
result _ (Delete x)  = "Deleted row: \{show $ FS x}."
result _ Quit        = "Goodbye."
result t (Get x)     =
  "Row \{show $ FS x}: \{encodeRow t.schema (index x t.rows)}"

covering
runProg : Table -> IO ()
runProg t = do
  putStr "Enter a command: "
  str <- getLine
  case readCommand t str of
    Left err   => putStrLn (showError err) >> runProg t
    Right Quit => putStrLn (result t Quit)
    Right cmd  => putStrLn (result t cmd) >>
                  runProg (applyCommand t cmd)

covering
main : IO ()
main = runProg $ MkTable [] _ []
```

### 演習 その3

ここに示した挑戦問題は全て幾つかの対話的なやり方で表編集器の改善を行うものです。
問題の中には依存的に型付けられたプログラムを書くことを学ぶというより形式上の問題というべきものもあるので、気の赴くままに解いてください。
演習1から3は必須と考えてよいでしょう。

1. Idrisの型`Integer`と`Nat`をCSVの列に保管できるように対応してください。

2. CSVの列に`Fin n`への対応を加えてください。
   補足：動くようにするためには`n`への実行時のアクセスが必要です。

3. CSVの列にオプション型への対応を加えてください。
   欠落した値は空文字列で符号化されるでしょうから、
   入れ子のオプション型を許すのは無意味です。
   つまり、`Maybe Nat`のような型は許されますが、`Maybe (Maybe Nat)`は許されません。

   手掛かり：こうしたことを符号化するには幾つかの方法がありますが、その1つは`ColType`に真偽値指標を加えることです。

4. 表全体を印字する命令を加えてください。
   全ての列が適切に整列されていれば尚良しです。

5. 単純な問い合わせへの対応を加えてください。
   列の番号と値が与えられているとき、与えられた値に合致する項目の全行を一覧にします。

   これは挑戦的かもしれません。
   というのも型がとても興味深いものになるためです。

6. 表をディスクから読み出したり保存したりする対応を加えてください。
   表は2つのファイルに保存されます。
   1つはスキーマのためのもので、もう1つはCSVの内容のためのものです。

   補足：ファイルを証明上全域に読むことはかなり困難になりえるもので、
   日を改めての話題になるでしょう。
   現時点では単にbaseの`System.File`から輸出されている関数`readFile`を使ってください。
   この関数は部分的ですが、
   それは`/dev/urandom`や`/dev/zero`のような無限入力ストリームに使うと決して終了しないからです。
   ここで`assert_total`を使わ*ない*ことは大事です。
   現実世界のアプリケーションで`readFile`のような部分関数を使うことはセキュリティ上の危険を招く可能性が充分にあるため、
   最終的にはこれの対処をして何らかの方法で受け付ける入力の大きさを制限する必要があります。
   したがってこの部分性を可視化し、
   これにしたがって全ての下流の関数に註釈付けさせるのが一番なのです。

これらの追加点の実装は解法で見ることができます。
小さな例としての表はフォルダ`resources`で見付けられます。

補足：当然ながらここから山ほどのプロジェクトを追究できます。
例えば適切な問い合わせ言語を書いたり、
既存の行から新しい行を計算したり、
列中の値を累積したり、
表を結合したり縫合したり、
などです。
ここでは止めておきますが後の例でこれに立ち返ることがあるかもしれません。

## まとめ

依存対と依存レコードは実行時に値を調べて取り扱う型を定義するのに必要です。
これらの値へのパターン照合により型と他の値の取り得る形状についてわかりますが、
これにより数多くのプログラム中の潜在的なバグを減らすことができます。

[次章](Eq.md)ではデータ型の書き方について学びます。
ただしこのデータ型は、値の間で満たされている何らかの契約についての証明としてのものです。
これらにより、最終的に関数の引数と出力型に事前ないし事後の条件を定義することができます。

<!-- vi: filetype=idris2:syntax=markdown
-->
