# 命題の等価性

[前の章](DPair.md)で、どうすれば依存対と依存レコードを使って、実行時にのみ知られている値にパターン照合することでその値から*型*を計算することができるのか、を学びました。
ここからは、どのようにして型としての値の間の関係……または*契約*……を記述することができるのか、どのようにすればこれらの型の値を契約を充足する証明として使えるのか、を見ていきます。

```idris
module Tutorial.Eq

import Data.Either
import Data.HList
import Data.Vect
import Data.String

%default total
```

## 型としての等価性

2つのCSVファイルの内容を結合したい場面を想像してください。
この両方のファイルには、依存対についてお話ししたときに見たそれぞれのスキーマとともに、
表としてディスクに格納されています。

```idris
data ColType = I64 | Str | Boolean | Float

Schema : Type
Schema = List ColType

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

Row : Schema -> Type
Row = HList . map IdrisType

record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

concatTables1 : Table -> Table -> Maybe Table
```

どうにかして2つのスキーマが同値であることを検証できなければ、2つの行のベクタを結合することで`concatTables1`を実装することはできません。「それなら」とあなたが言うのが聞こえます。「大した問題ではありません。`ColType`に`Eq`を実装するだけです。」やってみましょう。

```idris
Eq ColType where
  I64     == I64     = True
  Str     == Str     = True
  Boolean == Boolean = True
  Float   == Float   = True
  _       == _       = False

concatTables1 (MkTable s1 m rs1) (MkTable s2 n rs2) = case s1 == s2 of
  True  => ?what_now
  False => Nothing
```

どういうわけか動かないようです。
虫食い`what_new`の文脈を調べると、Idrisはまだs1とs2が異なると考えています。
それを脇目に`True`の場合で兎にも角にも`Vect.(++)`を呼び出したならば、Idrisは型エラーで応じます。

```repl
Tutorial.Relations> :t what_now
   m : Nat
   s1 : List ColType
   rs1 : Vect m (HList (map IdrisType s1))
   n : Nat
   s2 : List ColType
   rs2 : Vect n (HList (map IdrisType s2))
------------------------------
what_now : Maybe Table
```

問題は、たとえ`(==)`が`True`を返したとしても、
Idrisにとって2つの値を統合する根拠がないことです。
なぜなら`(==)`の結果には型が`Bool`であること以外の情報を持たないからです。
*私達*はこれが`True`なら2つの値は同値だろうと考えますが、Idrisは説得を受けません。
実際、以下の`Eq ColType`の実装は型検査器の知る限りでは全く問題ないでしょう。

```repl
Eq ColType where
  _       == _       = True
```

なのでIdrisが私達を信用しないことは正しいのです。
`(==)`の実装を調べてひとりでに`True`の結果が意味するところを解明してくれることを期待するかもしれませんが、
これは一般的にうまくいくものではありません。
なぜならほとんどの場合確認すべき計算経路の数はあまりにも多過ぎるからです。
結果として、Idrisは関数を統合時に評価することができますが、
関数の結果から関数の引数についての情報を遡って解析してはくれません。

### 等しいスキーマのための型

上で記述した問題は[単独型](DPair.md#erased-existentials)の利点についてお話しした際に見たことと似ています。
つまり型が充分に精密でないのです。
今から行っていくことは、異なる用例で同じことの繰り返しをすることです。
値の間の契約を指標化されたデータ型に符号化するのです。

```idris
data SameSchema : (s1 : Schema) -> (s2 : Schema) -> Type where
  Same : SameSchema s s
```

まず、`SameSchema`が型`Schema`の2つの値で指標付けられた型族である点に着目してください。
でも唯一の構築子が`s1`と`s2`の値に制限を課していることにも注意してください。
2つの指標は同値である*必要*があります。

なぜこれが便利なのでしょうか？
それでは、2つのスキーマの等価性を確認する関数を想像してください。
この関数は型`SameSchema s1 s2`の値を返そうとします。

```idris
sameSchema : (s1, s2 : Schema) -> Maybe (SameSchema s1 s2)
```

そうしてこの関数を使えば`concatTables`を実装できます。

```idris
concatTables : Table -> Table -> Maybe Table
concatTables (MkTable s1 m rs1) (MkTable s2 n rs2) = case sameSchema s1 s2 of
  Just Same => Just $ MkTable s1 _ (rs1 ++ rs2)
  Nothing   => Nothing
```

動きました！何が起こっているのでしょうか？
では、関係している型を調べましょう。

```idris
concatTables2 : Table -> Table -> Maybe Table
concatTables2 (MkTable s1 m rs1) (MkTable s2 n rs2) = case sameSchema s1 s2 of
  Just Same => ?almost_there
  Nothing   => Nothing
```

REPLで、以下の`almost_there`の文脈が得られます。

```repl
Tutorial.Relations> :t almost_there
   m : Nat
   s2 : List ColType
   rs1 : Vect m (HList (map IdrisType s2))
   n : Nat
   rs2 : Vect n (HList (map IdrisType s2))
   s1 : List ColType
------------------------------
almost_there : Maybe Table
```

ほら、`rs1`と`rs2`の型が統合されていますね？
`sameSchema s1 s2`の結果として来た値`Same`は、
`s1`と`s2`が実は同値であることの*目撃者*なのです。
なぜならこれが`Same`の定義で指定したことだからです。

残っているのは`sameSchema`を実装することだけです。
このためには、型`ColType`の2つの値が同値である場合に指定するための別のデータ型を書いていきます。

```idris
data SameColType : (c1, c2 : ColType) -> Type where
  SameCT : SameColType c1 c1
```

これでいくつかの便利関数を定義できます。
まず2つの行の型が同値であるかどうかを調べるものです。

```idris
sameColType : (c1, c2 : ColType) -> Maybe (SameColType c1 c2)
sameColType I64     I64     = Just SameCT
sameColType Str     Str     = Just SameCT
sameColType Boolean Boolean = Just SameCT
sameColType Float   Float   = Just SameCT
sameColType _ _             = Nothing
```

これにはIdrisも説得されます。
なぜならそれぞれのパターン照合で照合した値に応じて返却型が調整されるからです。
例えば最初の行で出力型は`Maybe (SameColType I64 I64)`ですが、
これはREPLで虫食いを入れて型を確認することで簡単に手元で確かめられます。

もう2つのユーティリティが必要になります。
nilとconsの場合のための型`SameSchema`の値を作る関数です。
実装がどれほど取るに足らないものか見てください。
それでもそのような小さな証明を手早く書かなくてはならないことはしばしばです（時節でなぜ*証明*と呼んでいるのかを説明します）。
そうしてこれらの証明を、私達が既に言うまでもないこととしているがIdrisにとってはそうでない事実について、型検査器を説得するのに使います。

```idris
sameNil : SameSchema [] []
sameNil = Same

sameCons :  SameColType c1 c2
         -> SameSchema s1 s2
         -> SameSchema (c1 :: s1) (c2 :: s2)
sameCons SameCT Same = Same
```

いつも通り、`sameCons`の右側を虫食いで置き換えてREPLで型と文脈を確認することで、何が起こっているのかを理解する助けになります。
左側の値`SameCT`と`Same`の存在はIdrisに`c1`と`c2`及び`s1`と`s2`を統合することを強制します。
そこから`c1 :: s1`と`c2 :: s2`の統合が直ちに従います。
これらを以って遂に`sameSchema`を実装することができます。

```idris
sameSchema []        []        = Just sameNil
sameSchema (x :: xs) (y :: ys) =
  [| sameCons (sameColType x y) (sameSchema xs ys) |]
sameSchema (x :: xs) []        = Nothing
sameSchema []        (x :: xs) = Nothing
```

ここで記述したことはインターフェース`Eq`や`(==)`演算子によりもたらされるものよりずっと強力な等価性の形式です。
型水準指標を統合しようとする際に型検査器によって受け付けられる値の等価性なのです。
これは*命題等値性*とも呼ばれています。
以降で見ていきますが、型と数学的な*命題*として、
これらの型の値をこれらの命題が持つ*証明*として、見ることができるのです。

### 型`Equal`

命題の等値性は基礎的な概念なので、*Prelude*はこのための汎用的なデータ型を既に輸出しています。
それが`Equal`で、その唯一のデータ型は`Refl`です。
加えて命題の等値性を表す組込み演算子もあり、`Equal`に脱糖されます。
それが`(=)`です。
この演算子はときに混乱に繋がることもありますが、
それは等号が*定義の等値性*にも使われているからです。
定義の等値性とは関数の実装で左側と右側が等しいものとして定義する記述です。
定義の方の等値性ではなく命題の方に曖昧回避したいときは前者に演算子`(===)`を使うこともできます。

`concatTables`の別実装は以下です。

```idris
eqColType : (c1,c2 : ColType) -> Maybe (c1 = c2)
eqColType I64     I64     = Just Refl
eqColType Str     Str     = Just Refl
eqColType Boolean Boolean = Just Refl
eqColType Float   Float   = Just Refl
eqColType _ _             = Nothing

eqCons :  {0 c1,c2 : a}
       -> {0 s1,s2 : List a}
       -> c1 = c2 -> s1 = s2 ->  c1 :: s1 = c2 :: s2
eqCons Refl Refl = Refl

eqSchema : (s1,s2 : Schema) -> Maybe (s1 = s2)
eqSchema []        []        = Just Refl
eqSchema (x :: xs) (y :: ys) = [| eqCons (eqColType x y) (eqSchema xs ys) |]
eqSchema (x :: xs) []        = Nothing
eqSchema []        (x :: xs) = Nothing

concatTables3 : Table -> Table -> Maybe Table
concatTables3 (MkTable s1 m rs1) (MkTable s2 n rs2) = case eqSchema s1 s2 of
  Just Refl => Just $ MkTable _ _ (rs1 ++ rs2)
  Nothing   => Nothing
```

### 演習 その1

以下の演習ではいくつかの等値性の証明におけるとても基本的な性質を実装していくことになります。
実装は物凄く簡素なので、関数の型は自力で思い付かなくてはいけません。

補足：用語「反射的」「対称的」「推移的」が意味することが思い出せなければ、
[こちら](https://en.wikipedia.org/wiki/Equivalence_relation)で同値関係について軽く読んでください。

1. `SameColType`が反射関係の1つであることを示してください。

2. `SameColType`が対称関係の1つであることを示してください。

3. `SameColType`が推移関係の1つであることを示してください。

4. 任意の型`a`について、`f`を型`ColType -> a`の関数であるとします。
   型`SameColType c1 c2`の値から`f c1`と`f c2`が等しいことを示してください。

`(=)`について上の性質は*Prelude*で関数`sym`、`trans`、`cong`として手に入ります。
反射性はデータ構築子`Refl`そのものから来ています。

5. 2つの自然数が同値か検証する関数を実装してください。
   実装では`cong`を使ってみてください。

6. 演習5の関数を使い、同数の行があれば2つの`Table`を縫合してください。

   ヒント：`Vect.zipWith`を使ってください。
   このために自前の関数`appRows`を実装する必要があるでしょう。
   なぜなら`HList.(++)`を使うときは、
   型が統合されることを、Idrisがひとりでに解明しないためです。

   ```idris
   appRows : {ts1 : _} -> Row ts1 -> Row ts2 -> Row (ts1 ++ ts2)
   ```

あとで*書き換え規則*の使い方を学び、
`appRows`のような自前の関数を書く必要があるところを回避したり、
`(++)`を`zipWith`で直接使ったりしていきます。

## 証明としてのプログラム

数学者*Haskell Curry*と論理学者*William Alvin Howard*による有名な考察はある結論を導きだしました。
それは充分に豊かな型システムを備えるプログラム言語における*型*を数学的な命題として、
そしてこの型の*値*を計算する全域なプログラムを命題が満たす証明として、それぞれ見ることができるということです。
これは[Curry-Howard同型写像](https://en.wikipedia.org/wiki/Curry%E2%80%93Howard_correspondence)としても知られています。

例えば、以下は1足す1が2に等しいことの単純な証明です。

```idris
onePlusOne : the Nat 1 + 1 = 2
onePlusOne = Refl
```

Idrisは統合によりこれを解くため上の証明は取るに足らないものです。
しかし既に演習でいくつかのより興味深いことを記しました。
例えば`SameColType`の対称性と推移性は次の通り。

```idris
sctSymmetric : SameColType c1 c2 -> SameColType c2 c1
sctSymmetric SameCT = SameCT

sctTransitive : SameColType c1 c2 -> SameColType c2 c3 -> SameColType c1 c3
sctTransitive SameCT SameCT = SameCT
```

なお、型だけでは証明ではありません。
例えば1足す1が3だと記すことは自由です。

```idris
onePlusOneWrong : the Nat 1 + 1 = 3
```

しかしこれを証明上全域に実装するとなると手こずることでしょう。
これを「型`the Nat 1 + 1 = 3`は*非現住*である」と言います。
その意味はこの型の値は1つもないということです。

### 証明がテストを置き換えるとき

コンパイル時の証明のいくつかの多様な用例を見ていきます。
とても直感的なものとしては、関数についての性質を証明することにより、その関数がそうあるべきように振る舞うことを示すことです。
例えば以下はリストにおける`map`がリスト中の要素数を変えないという命題です。

```idris
mapListLength : (f : a -> b) -> (as : List a) -> length as = length (map f as)
```

これは全称量化された表明として読まれます。
つまり`a`から`b`への全ての関数`f`と型`a`の値を持つ全てのリスト`as`について、
`map f as`の長さは元のリストの長さと同じです。

`mapListLength`は`as`におけるパターン照合により実装できます。
`Nil`の場合は些細なものです。
Idrisはこれを統合により解きます。
入力リスト (`Nil`)
の値を知っており、`map`もまた入力におけるパターン照合により実装されているため、結果も同じように`Nil`になることが直ちに従います。

```idris
mapListLength f []        = Refl
```

`cons`の場合はより込み入っているため、一歩ずつ進めていきます。
まず、尾鰭上で写す長さが、再帰により同じままであることを証明することができますね。


```repl
mapListLength f (x :: xs) = case mapListLength f xs of
  prf => ?mll1
```

ここで型と文脈を調べてみましょう。

```repl
 0 b : Type
 0 a : Type
   xs : List a
   f : a -> b
   x : a
   prf : length xs = length (map f xs)
------------------------------
mll1 : S (length xs) = S (length (map f xs))
```

というわけで、型`length xs = length (map f xs)`の証明があり、
`map`の実装からIdrisは実際に求めているものが型`S (length xs) = S (length (map f
xs))`の結果であると結論付けています。
*Prelude*の関数*cong*はまさにこのためにあります。
（"cong"は*congruence*の略語です。）
そうして以下のように簡潔に*cons*の場合を実装することができます。

```idris
mapListLength f (x :: xs) = cong S $ mapListLength f xs
```

ここで達成できたことをしばし噛み締めましょう。
この関数が決してリストの長さに影響を与えないことの、数学的な意味での*証明*です。
もはや検証のために単体テストやそれに類するプログラムは必要ないのです。

続ける前に重要な点に注意してください。
case式中で再帰呼び出しからの結果に*変数*を使いました。

```repl
mapListLength f (x :: xs) = case mapListLength f xs of
  prf => cong S prf
```

ここでは2つの長さを統合したいとはしていません。
なぜなら`cong`の呼び出しに区別が必要だったからです。
したがって、もし2つの変数を統合するために型`x = y`の証明が必要であれば、
パターン照合中で`Refl`データ構築子を使ってください。
他方でもしそのような証明においてさらに計算を走らせる必要があれば、
変数を使い左側と右側が区別されたままにしておいてください。

以下は前の章からの別の例です。
列の型を解析し印字することが正しく行われることを示したいとします。
構文解析器についての証明を書くことは一般にとても難しくなりえますが、
以下では単なるパターン照合により完了します。

```idris
showColType : ColType -> String
showColType I64      = "i64"
showColType Str      = "str"
showColType Boolean  = "boolean"
showColType Float    = "float"

readColType : String -> Maybe ColType
readColType "i64"      = Just I64
readColType "str"      = Just Str
readColType "boolean"  = Just Boolean
readColType "float"    = Just Float
readColType s          = Nothing

showReadColType : (c : ColType) -> readColType (showColType c) = Just c
showReadColType I64     = Refl
showReadColType Str     = Refl
showReadColType Boolean = Refl
showReadColType Float   = Refl
```

こうした単純な証明は、手軽ではあれど、
いかなる間抜けな誤りも犯していないことの強力な保証をもたらしてくれます。

今まで見てきた例はとても簡単に実装できました。
一般にはこの限りではなく、プログラムについての興味深い事柄を証明するためには、追加でいくつかの技法について学ばねばならないでしょう。
しかしながらIdrisを証明支援ではなく汎用用途のプログラミング言語として使っている時も、
コードのいくつかの側面でこのような強力な保証が必要かどうかを選ぶことは自由なのです。

### 注意喚起の補足：関数型での小文字の識別子

上で行ったように証明の型を書き下す際、以下の罠に嵌らないよう細心の注意を払わねばなりません。
一般にIdrisは関数型中の小文字の識別子を型変数（消去される暗黙引数）として扱います。
例えば以下では`Maybe`に同値関手則を証明しようとしています。

```idris
mapMaybeId1 : (ma : Maybe a) -> map Prelude.id ma = ma
mapMaybeId1 Nothing  = Refl
mapMaybeId1 (Just x) = ?mapMaybeId1_rhs
```

`Just`の場合を実装することは叶わないでしょう。
なぜならIdrisは`id`を暗黙引数として扱うからです。
`mapMaybeId1_rhs`の文脈を調べれば簡単にわかります。

```repl
Tutorial.Relations> :t mapMaybeId1_rhs
 0 a : Type
 0 id : a -> a
   x : a
------------------------------
mapMaybeId1_rhs : Just (id x) = Just x
```

見ての通り`id`は型`a -> a`の消去引数です。
そして実際にこのモジュールを型検査するとき、Idrisは引数`id`が既存の関数に影を落としていると警告を上げます。

```repl
Warning: We are about to implicitly bind the following lowercase names.
You may be unintentionally shadowing the associated global definitions:
  id is shadowing Prelude.Basics.id
```

同じことは`map`には当て嵌まりません。
明示的に`map`に引数を渡しているため、Idrisはこれを暗黙引数としてではなく関数名として扱います。

ここではいくつかの選択肢があります。
例えば大文字の識別子を使うことができます。
こうすれば決して暗黙引数として扱われることがないからです。

```idris
Id : a -> a
Id = id

mapMaybeId2 : (ma : Maybe a) -> map Id ma = ma
mapMaybeId2 Nothing  = Refl
mapMaybeId2 (Just x) = Refl
```

代替として……そしてこれがこの場合を制御するより好ましい方法です……`id`に名前空間の一部を前置することができます。
こうすれば直ちに問題が解決します。

```idris
mapMaybeId : (ma : Maybe a) -> map Prelude.id ma = ma
mapMaybeId Nothing  = Refl
mapMaybeId (Just x) = Refl
```

補足：エディタで（例えば[idris2-lsp
plugin](https://github.com/idris-community/idris2-lsp)を使うことによって）意味論的彩色を有効にしていれば、`mapMaybeId1`中の`map`と`id`が異なって彩色されていることに気付くことでしょう。
`map`は関数名に、`id`は束縛変数になっています。

### 演習 その2

これらの演習では小さな関数のいくつかの単純な性質を証明していきます。
証明を書くときは、Idrisが次に何を期待しているのか調べるために、虫食いを使うことがずっと重要になります。
暗中模索する前に与えられた道具を使いましょう。

1. `Either e`への`map id`が値を変更せずに返すことを証明してください。

2. リストへの`map id`が変更されていないリストを返すことを証明してください。

3. 核酸塩基の鎖（[前の章](DPair.md#use-case-nucleic-acids)を見てください）を2度相補すると元の鎖になることを証明してください。

   ヒント: 最初にこれを単一の塩基に証明してから、
   塩基配列の実装で*Prelude*の`cong2`を使いましょう。

4. 関数`replaceVect`を実装してください。

   ```idris
   replaceVect : (ix : Fin n) -> a -> Vect n a -> Vect n a
   ```

   それでは、`replaceAt`を使ってベクタ中の要素を置き換えたあとに、
   `index`を使って同じ要素にアクセスすると、
   ちょうど追加した値を返すことを証明してください。

5. 関数`insertVect`を実装してください。

   ```idris
   insertVect : (ix : Fin (S n)) -> a -> Vect n a -> Vect (S n) a
   ```

   演習4と似た証明を使ってこれが正しく振る舞うことを示してください。

補足：関数`replaceVect`と`insertVect`は`Data.Vect`でそれぞれ`replaceAt`と`insertAt`として手に入ります。

## 虚空の中へ

以前の関数`onePlusOneWrong`を覚えていますか。
これは全き誤りの表明でした。
1足す1は3に等しくありませんから。
ときどき正にこのことを表したいことがあります。
ある表明が偽であり満たされないということです。
Idrisでの証明の表明においてこれが何を意味するのかしばし考えてください。
そのような表明（あるいは命題）は型で、その表明の証明はこの型の値や式になっています。
そのような型はいわゆる*現住*です。
表明が真でなければ与えられた型の値は1つもありえません。
このとき与えられた型は*非現住*であると言います。
それでもなお非現住型の値を何とかして掴み取るならば、
それは論理的な矛盾であって、この矛盾からどんなことも従います。
（[ex falso
quodlibet](https://en.wikipedia.org/wiki/Principle_of_explosion)を思い出してください。）

というわけでこれが命題を満たさないことを表現する方法です。
もし命題を満たす*としたら*、矛盾になってしまうことを表明するのです。
Idrisで矛盾を表現する最も自然な方法は型`Void`の値を返すことです。

```idris
onePlusOneWrongProvably : the Nat 1 + 1 = 3 -> Void
onePlusOneWrongProvably Refl impossible
```

これは与えられた型の証明上全域な実装になっていますね。
型は`1 + 1 = 3`から`Void`への関数です。
これをパターン照合により実装し、たった1つの構築子が照合されますが、
これにより不可能な場合になってしまいます。

矛盾した表明を使って他の表明を証明することもできます。
例えば以下は、2つのリストの長さが同じでなければ、
2つのリストが同じになることもありえないということの証明です。

```idris
notSameLength1 : (List.length as = length bs -> Void) -> as = bs -> Void
notSameLength1 f prf = f (cong length prf)
```

こう書くのは億劫ですしとても読みづらいです。
なのでpreludeに関数`Not`があり、同じことをより自然に表すことができます。

```idris
notSameLength : Not (List.length as = length bs) -> Not (as = bs)
notSameLength f prf = f (cong length prf)
```

実はこれは`cong`の待遇の特殊版にすぎません。
つまり、`a = b`から`f a = f b`が従うのであれば、`not (f a = f b)`から`not (a = b)`が従います。

```idris
contraCong : {0 f : _} -> Not (f a = f b) -> Not (a = b)
contraCong fun = fun . cong f
```

### インターフェース`Uninhabited`

*Prelude*には非現住型のためのインターフェースがあります。
`Uninhabited`とその唯一の関数`uninhabited`です。
REPLでこのインターフェースのドキュメントを眺めてみましょう。
すると既にちょっとした数の実装が使えることがわかります。
その多くがデータ型`Equal`に関わっています。

`Uninhabited`を使えば、例えば空のスキーマが空でないスキーマと等しくないことを表せます。

```idris
Uninhabited (SameSchema [] (h :: t)) where
  uninhabited Same impossible

Uninhabited (SameSchema (h :: t) []) where
  uninhabited Same impossible
```

関連して知っておかねばならない関数があります。`absurd`です。
これは`uninhabited`を`void`と繋げるものです。

```repl
Tutorial.Eq> :printdef absurd
Prelude.absurd : Uninhabited t => t -> a
absurd h = void (uninhabited h)
```

### 決定可能等値性

`sameColType`を実装したとき、2つの行の型が確かに同じであるという証明を
得て、そこから2つのスキーマが同値かどうかが調べられました。型は偽陽性
の発生がないことを保証します。つまり型`SameSchema s1 s2`の値を生成すれ
ば`s1`と`s2`が確かに同値であるという証明があるのです。しかし
`sameColType`とそれを使う`sameSchema`は、2つの値が同値であっても
`Nothing`を返すことによって、それでも理論的には偽陰性を生じる可能性が
あるのです。例えば`sameColType`を常に`Nothing`を返すようなやり方で実装
できてしまいます。これは型としては合致しますが間違いなく望んでいるもの
ではないでしょう。なのでここでより強い保証を得るために行いたいことが出
てきます。2つのスキーマが同じであるという証明を返すか、2つのスキーマ
が同じでないという証明を返すかのどちらかをしたいのです。（`Not a`が`a
-> Void`の別の形であることを思い出してください。）

命題を満たすか矛盾になるかする性質を*決定可能性質*と呼びます。そして
*Prelude*はデータ型`Dec prop`を輸出しており、この区別を内蔵化します。

以下はこれを`ColType`に符号化する方法です。

```idris
decSameColType :  (c1,c2 : ColType) -> Dec (SameColType c1 c2)
decSameColType I64 I64         = Yes SameCT
decSameColType I64 Str         = No $ \case SameCT impossible
decSameColType I64 Boolean     = No $ \case SameCT impossible
decSameColType I64 Float       = No $ \case SameCT impossible

decSameColType Str I64         = No $ \case SameCT impossible
decSameColType Str Str         = Yes SameCT
decSameColType Str Boolean     = No $ \case SameCT impossible
decSameColType Str Float       = No $ \case SameCT impossible

decSameColType Boolean I64     = No $ \case SameCT impossible
decSameColType Boolean Str     = No $ \case SameCT impossible
decSameColType Boolean Boolean = Yes SameCT
decSameColType Boolean Float   = No $ \case SameCT impossible

decSameColType Float I64       = No $ \case SameCT impossible
decSameColType Float Str       = No $ \case SameCT impossible
decSameColType Float Boolean   = No $ \case SameCT impossible
decSameColType Float Float     = Yes SameCT
```

まず、単一引数ラムダで直接パターン照合を使えている点に注目してください。
これはしばしば*ラムダcase*形式と呼ばれるもので、Haskellプログラミング言語の拡張に因んでいます。
パターン照合で`SameCT`構築子を使うとIdrisはインスタンス`Float`を`I64`を統合するよう迫られます。
これは可能ではないためcase全体が不可能になります。

ただこれはかなり実装するのが億劫です。Idrisを説得するために場合を漏ら
さなかったわけですが、全ての可能な構築子の対を明示的に扱う方法などあり
ません。しかしここから*遥かに*強力な保証を得ています。もはや偽陽性*も*
偽陰性も生み出すことはなく、したがって`decSameColType`は証明上正しいの
です。

同じことをスキーマに対して行うにはいくつかの便利関数が必要で、その型は虫食いを置くことで調べられます。

```idris
decSameSchema' :  (s1, s2 : Schema) -> Dec (SameSchema s1 s2)
decSameSchema' []        []        = Yes Same
decSameSchema' []        (y :: ys) = No ?decss1
decSameSchema' (x :: xs) []        = No ?decss2
decSameSchema' (x :: xs) (y :: ys) = case decSameColType x y of
  Yes SameCT => case decSameSchema' xs ys of
    Yes Same => Yes Same
    No  contra => No $ \prf => ?decss3
  No  contra => No $ \prf => ?decss4
```

最初の2つの場合はそれほど難しくありません。`decss1`の型は`SameSchema
[] (y :: ys) -> Void`で、これはREPLで簡単に確かめられます。しかしそれ
は単に`uninhabited`であって、`SameSchema [] (y :: ys)`に特殊化されてお
り、既にもっと前で実装したことなのです。同じことが`decss2`にも言えます。

他2つの場合はこれより難しいので既にできる限り書き入れました。
もし先頭か尾鰭のいずれかが証明上独立しているときは`No`を返したいことがわかっています。
`No`は関数を満たしているので、既にラムダを加えてあり、返る値についてのみ虫食いにしています。
以下はその型と……そしてより重要な……`decss3`の文脈です。

```repl
Tutorial.Relations> :t decss3
   y : ColType
   xs : List ColType
   ys : List ColType
   x : ColType
   contra : SameSchema xs ys -> Void
   prf : SameSchema (y :: xs) (y :: ys)
------------------------------
decss3 : Void
```

`contra`と`prf`の型はここで必要なものです。`xs`と`ys`が相異なるもので
あれば`y :: xs`と`y :: ys`もまた相異なるものでなくてはなりません。これ
は`x :: xs`が`y :: ys`と同じであれば、`xs`と`ys`もまた同じであるという
表明の待遇になっています。したがってラムダを実装することで、*cons*構築
子が[*単射*](https://en.wikipedia.org/wiki/Injective_function)であるこ
とを証明せねばなりません。

```idris
consInjective :  SameSchema (c1 :: cs1) (c2 :: cs2)
              -> (SameColType c1 c2, SameSchema cs1 cs2)
consInjective Same = (SameCT, Same)
```

これで`prf`を`consInjective`に渡し型`SameSchema xs ys`の値を取り出すことができます。
そしてこれを`contra`に渡せば型`Void`の望んだ値を得ることになります。
これらの観察とユーティリティを以ってこれで`decSameSchema`を実装できます。

```idris
decSameSchema :  (s1, s2 : Schema) -> Dec (SameSchema s1 s2)
decSameSchema []        []        = Yes Same
decSameSchema []        (y :: ys) = No absurd
decSameSchema (x :: xs) []        = No absurd
decSameSchema (x :: xs) (y :: ys) = case decSameColType x y of
  Yes SameCT => case decSameSchema xs ys of
    Yes Same   => Yes Same
    No  contra => No $ contra . snd . consInjective
  No  contra => No $ contra . fst . consInjective
```

命題的等値性のための決定過程を実装できる型用に、モジュール
`Decidable.Equality`により輸出されている`DecEq`と呼ばれるインターフェー
スがあります。2つの値が等しいかどうかを調べるためにこれを実装すること
ができます。

### 演習 その3

1. 空でない`Void`のベクタが1つとしてありえないことを対応する非現住の実装
   を書くことにより示してください。

2. 演習1を全ての非現住要素型に一般化してください。

3. `a = b`を満たしえなければ`b = a`もまた満たしえないことを示してください。

4. `a = b`を満たしており、且つ`b = c`を満たしえないならば、`a = c`もまた
   満たしえないことを示してください。

5. `Crud i a`に`Uninhabited`を実装してください。可能な限り一般的になるよ
   うにしてみてください。

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

6. `DecEq`を`ColType`に実装してください。

7. 演習6のような実装はデータ構築子の数の関係に伴いその平方のパターン照合
   が必要になるため書くのが面倒です。以下はこれをより堪えられるようにする
   秘訣です。

   1. 関数`ctNat`を実装してください。この関数は型`ColType`の全ての値に一意の
      自然数を割り当てます。

   2. `ctNat`が単射であることを証明してください。ヒント：`ColType`の値でパター
      ン照合する必要があるでしょうが、網羅性検査器を満足させるには4つの照合
      で充分でしょう。

   3. `ColType`への`DecEq`の実装では、両方の行の型を`ctNat`に適用した結果に
      `decEq`を使ってください。そうすればたった2行のコードに削減されます。

   あとで`with`規則についてお話しします。これは依存パターン照合の特殊
   な形式であり、関数の引数に計算を行うことによりそれら引数の形状につ
   いて知ることができるようになります。これにより、ここで見たのと似た
   技法を使って`DecEq`を実装するのに、`n`個のデータ構築子のある任意の
   直和型に対してたった`n`個のパターン照合が必要になるようにできます。

## 書き換え規則

命題の等値性の最重要の用例の1つに、Idrisが自動的には統合できない既存の
型を置き換えたり*書き換え*たりすることがあります。例えば以下は何ら問題
はありません。Idrisは`0 + n`が`n`に等しいことを知っています。なぜなら
自然数における`plus`は最初の引数でのパターン照合により実装されているか
らです。したがって2つのベクタの長さはちょうどうまく統合されるのです。

```idris
leftZero :  List (Vect n Nat)
         -> List (Vect (0 + n) Nat)
         -> List (Vect n Nat)
leftZero = (++)
```

しかし下の例は簡単には実装できません（やってみてください！）。なぜなら
Idrisは自力で2つの長さを統合するものだと調べられないからです。

```idris
rightZero' :  List (Vect n Nat)
           -> List (Vect (n + 0) Nat)
           -> List (Vect n Nat)
```

Idrisが算数の法則について知っていることはどれほど少ないかということを、
もしかすると初めて気付いたかもしれません。Idrisが値を統合できるのは以
下の場合です。

* 計算中の全ての値はコンパイル時に知られている
* 関数の実装で使われているパターン照合から、ある式が他の式から直接従っている

式`n + 0`では全ての値は知られておらず（`n`は変数）、`(+)`は最初の引数
でパターン照合することにより実装されています。ここで最初の引数について
分かることは何もないのです。

しかしIdrisに教えることができます。2式が等価であることを証明できれば一
方の式を他方に置き換えることができ、したがって2つは改めて統合されるの
です。以下は補題とその証明で、全ての自然数`n`について`n + 0`が`n`に等
しいとするものです。

```idris
addZeroRight : (n : Nat) -> n + 0 = n
addZeroRight 0     = Refl
addZeroRight (S k) = cong S $ addZeroRight k
```

基底の場合が自明であるところに注目してください。
残っている変数が1つもないため、Idrisは直ちに`0 + 0 = 0`を解明できるのです。
再帰の場合では、`cong S`を虫食いに置き換えて型と文脈を眺めると、どのように処理されるのかが分かりやすいかもしれません。

*Prelude*は条件中の1変数を別のものに置換するための関数`replace`を輸出
 しています。以下の例を見る前にまずその型を調べて確かめてください。

```idris
replaceVect : Vect (n + 0) a -> Vect n a
replaceVect as = replace {p = \k => Vect k a} (addZeroRight n) as
```

見てわかるように`x = y`という証明に基づいて、型`p x`の値を型`p y`の値
で*置き換え*ています。ただし`p`は何らかの型`t`から`Type`への関数で、
`x`と`y`は型`t`の値です。`replaceVect`の例では`t`は`Nat`に等しく、
`x`は`n + 0`に等しく、`y`は`n`に等しく、そして`p`は`\k => Vect k a`に
等しいものです。

直接`replace`を使うのはあまり便利ではありません。それはIdrisが`p`の値
を自力で推論できないことがよくあるからです。そのときはもちろん
`replaceVect`中で明示的に型を与えなくてはなりません。したがってIdrisは
*書き換え規則*のような特別な構文を提供しています。この構文は
`replace`の呼び出しを全ての詳細が記入されたものに脱糖してくれるもので
す。以下は書き換え規則を使った`replaceVect`の実装です。

```idris
rewriteVect : Vect (n + 0) a -> Vect n a
rewriteVect as = rewrite sym (addZeroRight n) in as
```

混乱の元の1つとして*rewrite*が等値性の証明をあべこべに使うということで
す。つまり`y = x`が与えられているとき`p x`を`p y`に置き換えるのです。
だから上の実装では`sym`を呼び出す必要があったんですね。

### 用例：ベクタを反転する

書き換え規則はよく興味深い型水準計算を行う際に必要になります。例えば既
に`Vect`を操作する関数の多くの興味深い例を見てきましたが、これらは関係
するベクタの厳密な長さを把握し続けられるものでした。しかしもっともな理
由があってここまでのお話では1つの鍵となる機能が欠けていました。関数
`reverse`です。以下は考えられる実装で、リストに`reverse`を実装したやり
かたになっています。


```repl
revOnto' : Vect m a -> Vect n a -> Vect (m + n) a
revOnto' xs []        = xs
revOnto' xs (x :: ys) = revOnto' (x :: xs) ys


reverseVect' : Vect n a -> Vect n a
reverseVect' = revOnto' []
```

お分かりかもしれませんが、これは`revOnto'`の2つの節の長さの指標が統合しないためコンパイルされません。

*nil*の場合は上で既に見た場合です。ここでは`n`がゼロですが、それは2つ
 目のベクタが空であり、Idrisを再び`m + 0 = m`だと説得せねばなりません。

```idris
revOnto : Vect m a -> Vect n a -> Vect (m + n) a
revOnto xs [] = rewrite addZeroRight m in xs
```

2つ目の場合はより複雑です。ここでIdrisは`S (m + len)`と`m + S len`を統
合するのに失敗しています。ただし`len`は2つ目のベクタの尾鰭である`ys`の
長さです。モジュール`Data.Nat`は自然数における算術操作についての多くの
証明を提供しており、その1つが`plusSuccRightSucc`です。以下がその型です。

```repl
Tutorial.Eq> :t plusSuccRightSucc
Data.Nat.plusSuccRightSucc :  (left : Nat)
                           -> (right : Nat)
                           -> S (left + right) = left + S right
```

ここでは`S (m + len)`を`m + S
len`で置き換えたいので、引数が入れ替わったバージョンが必要です。しかしもう1つ障害物があります。`plusSuccRightSucc`を`ys`の長さ付きで呼び出す必要があるのですが、この`ys`は`revOnto`の暗黙の関数引数として与えられていないのです。したがって`n`（2つ目のベクタの長さ）でパターン照合する必要がありますが、これは尾鰭の長さを変数に束縛するためです。覚えておいてほしいのは、使われている構築子が別の消去されていない引数での照合に従うときにのみ、消去された引数でパターン照合することができるということです（この場合`ys`がそれにあたります）。以下は2つ目の場合の実装です。

```idris
revOnto {n = S len} xs (x :: ys) =
  rewrite sym (plusSuccRightSucc m len) in revOnto (x :: xs) ys
```

私自身の経験からこれは最初のうち相当に混乱するものだと知っています。も
しIdrisを証明支援ではなく汎用目的プログラミング言語として使うのであれ
ば惧らくそこまで頻繁に書き換え規則を使わなければいけないことはないでしょ
う。それでもそうしたものが存在すると知っておくことは大事です。複雑な等
値性をIdrisに教えることができるからです。

### 消去についての補足

`Unit`、`Equal`、`SameSchema`といった単一値データ型は実行に関係しませ
ん。というのもこれらの型の値は常に同値であるためです。したがって常にこ
れらの値でパターン照合することが可能でありつつ、消去される関数引数とし
て使うことができます。例えば`replace`の型を見れば等値性の証明が消去引
数であることに気付きます。これによりそのような値を生み出す任意の複雑な
計算がコンパイルされたIdrisプログラムを低速にしてしまうのではないかと
恐れることなく、そのような計算を走らせることができるのです。

### 演習パート4

1. 自力で`plusSuccRightSucc`を実装してください。

2. `minus n n`がゼロに等しいことを全ての自然数`n`について証明してください。

3. `minus n 0`が`n`に等しいことを全ての自然数`n`について証明してください。

4. `n * 1 = n`と`1 * n = n`を全ての自然数`n`について証明してください。

5. 自然数の和が可換であることを証明してください。

6. ベクタの`map`の末尾再帰版を実装してください。

7. 以下の命題を証明してください。

   ```idris
   mapAppend :  (f : a -> b)
             -> (xs : List a)
             -> (ys : List a)
             -> map f (xs ++ ys) = map f xs ++ map f ys
   ```

8. 演習7の証明を使ってもう一度2つの`Table`を縫合する関数を実装してくださ
   い。今回は`Data.HList.(++)`に加えて自前の関数`appRows`の代わりに書き換
   え規則も使ってください。

## まとめ

*命題としての型、証明としての値*という概念は証明上正しいプログラムを書
 く上でとても強力な道具です。したがってもう少し時間を掛けて値の間の契
 約を記述するデータ型と,その契約を満たす証明としてのこれらの型の値を定
 義していきましょう。これにより必要な関数の前後条件を記述でき、したがっ
 て`Maybe`や他の失敗型を返す必要が減ります。なぜなら制限された入力とな
 るため関数が最早失敗することがなくなるからです。

[次の章](./Predicates.md)

<!-- vi: filetype=idris2:syntax=markdown
-->
