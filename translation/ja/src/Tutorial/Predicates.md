# 前提条件と証明検索

[前の章](Eq.md)で命題の等価性を学びました。これにより2つの値が等価であ
ることを証明することができるようになりました。等価性は値間の関係であり、
指標付けられたデータ型を使って指標の自由度を制限して唯一のデータ構築子
に狭めることでこの関係を符号化しました。このようにして符号化できるよう
な別の関係や契約が存在します。これらによって関数引数として受け付ける値
や関数から返される値を制限することができます。

```idris
module Tutorial.Predicates

import Data.Either
import Data.List1
import Data.String
import Data.Vect
import Data.HList
import Decidable.Equality

import Text.CSV
import System.File

%default total
```

## 前提条件

しばしば与えられた型の値を操作する関数を実装するとき、問題の関数に関し
て全ての値が妥当とは考えられないことがあります。例えばゼロ除算を許さな
いことはよくありますが、それは一般的な場合で結果が未定義であるためです。
関数引数に*前提条件*を置くという概念はかなり頻繁に発生するものであり、
これをするためのいくつかの方法があります。

リストや他の容器型に取り組む際にとてもよくある操作は並びの中の最初の値
を取り出すことです。この関数はしかし、一般的な場合には動きません。なぜ
ならリストから値を取り出すためにはリストが空であってはならないからです。
以下はこれを符号化し実装するいくつかの方法であり、それぞれに利点と欠点
があります。

* 結果を失敗型に包む、`Maybe`や何らかの自前のエラー型`e`を伴う`Either e`
  といったもの。こうすると直ちに関数が結果を返せないことがあるかもしれ
  ないということが明確になります。不明な源からの未検証の入力を扱う自然な
  方法です。この手法の短所は*nil*の場合が不可能だと*知っている*状況でさ
  え、`Maybe`の染みが付いた結果を運ぶことになる点です。例えばリスト引数
  の値をコンパイル時に知っていたり、既に空でないことを確かめられるような
  やり方（例えばその前のパターン照合からなど）で入力値を*精錬*した後であっ
  たりなどの経緯でこの状況になります。

* 空でないリスト用の新しいデータ型を定義し、これを関数引数として使うもの。
  これはモジュール`Data.List1`で採られた手法です。これにより純粋な値（こ
  こでは「失敗型に包まれていない」の意）を返すことができますが、それは関
  数は決して失敗する可能性がないためです。しかし既に`List`に実装した便利
  関数やインターフェースの多くを再実装する負担が付いてきます。よくあるデー
  タ型については妥当な選択肢になりえますが、稀な用例向けにはしばしば面倒
  になります。

* 指標を使って関心のある性質を把握するもの。これは型族`List01`で採った手
  法です。このデータ型については本手引きのこれまでの例や演習でいくつか見
  てきました。これはまたベクタでも採られている手法であり、指標として厳密
  な長さを使うことでさらに表現力を増すものです。こうすると多くの関数を一
  度だけ実装すればよくなり型水準でより良い精度が得られます。一方で、型で
  変化を把握することになり、より複雑な関数型になり、計算の出力が実行時ま
  で知られないために時々存在量化された梱包を返すようになる、という負担も
  付いてきます。

* 実行時例外と共に失敗するもの。これは多くのプログラミング言語（Haskell
  でさえそう）でよく用いられる解決策です。しかしIdrisではこれを避けよう
  とします。なぜなら自身のコードも使い手のコードも全域性が壊れるからです。
  幸運にも一般的には強力な型システムを使ってこの状況を避けられます。

* 入力値が正しい種類や形状であることの証人として使える型を追加の（消去可
  能な）引数として取るもの。これは本章で深堀りしてお話しする解決策です。
  既存の機能の多くを複製することなく値への制限があることを言いたいときに
  極めて強力な方法です。

Idrisで上に挙げた解決策が全てかどうかには議論の余地があるものの、最後
の選択肢に至り述語（いわゆる*前提条件*）で関数引数を精錬することがしば
しばでしょう。なぜなら関数が実行時*及び*コンパイル時に使いやすくなるか
らです。

### 例：非空リスト

命題的等値性のための指標付けられたデータ型を実装したやり方を思い出して
ください。構築子で指標の妥当な値を制限したのでした。同じことが非空リス
ト用の述語にも行えます。

```idris
data NotNil : (as : List a) -> Type where
  IsNotNil : NotNil (h :: t)
```

これは単一値データ型なので、常に消去された関数引数として使うことができ、
それでいてパターン照合することができます。これで安全で純粋な`head`関数
を実装できます。

```idris
head1 : (as : List a) -> (0 _ : NotNil as) -> a
head1 (h :: _) _ = h
head1 [] IsNotNil impossible
```

値`IsNotNil`がどのように指標の*目撃者*となっているかという点に注目して
ください。この指標はリスト引数に対応しており当然非空です。なぜなら型で
指定していることだからです。`head1`の実装の中の不可能の場合はここでは
厳密には必要ではありません。上では完全のために与えられています。

`NotNil`はリストにおける*述語*と呼びます。なぜなら指標で許される値を制
限するからです。追加の（消去されうる）述語を関数の引数リストに加えるこ
とにより関数の前提条件を表現できるのです。

1つ目の実に粋な点は、コンパイル時にリスト引数が確かに非空であれば
`head1`を安全に使うことができる有り様にあります。

```idris
headEx1 : Nat
headEx1 = head1 [1,2,3] IsNotNil
```

`IsNotNil`の証明を手動で渡さねばならないのは少し面倒です。その痒みを掻
く前にまず、値が実行時まで知られていないリストの扱い方について話しましょ
う。そのような場合、実行時のリストの値を調べることによって述語の値をプ
ログラミング的に生成しようとしなければなりません。最も単純な場合では証
明を`Maybe`に包むことができますが、述語が*決定可能*であることを示せれ
ば、`Dec`を返すことによりさらに強力な保証が得られます。

```idris
Uninhabited (NotNil []) where
  uninhabited IsNotNil impossible

nonEmpty : (as : List a) -> Dec (NotNil as)
nonEmpty (x :: xs) = Yes IsNotNil
nonEmpty []        = No uninhabited
```

これを携えれば関数`headMaybe`を実装できます。この関数は出所不明なリス
トに使うことができます。

```idris
headMaybe1 : List a -> Maybe a
headMaybe1 as = case nonEmpty as of
  Yes prf => Just $ head1 as prf
  No  _   => Nothing
```

もちろん`headMaybe`のような自明な関数についてはリスト引数に直接パター
ン照合することで実装するのが理に適っています。しかしすぐ後でよりつくる
のが面倒な値の述語の例を見ていきます。

### 自動暗黙子

手動で非空であることの証明を`head1`に渡さねばならないことは、コンパイ
ル時に用いる上でこの関数を不必要に冗長にしています。Idrisでは暗黙関数
引数を定義することができ、この値は*証明検索*と呼ばれる技術を活用してひ
とりでに組み合わせられます。これは型推論と混同すべきではなく、そちらは
周囲の文脈から値や型を推論する意味でした。違いを説明するにはいくつかの
例を見るのが一番です。

最初に以下のベクタ用の`replicate`の実装を眺めてみましょう。

```idris
replicate' : {n : _} -> a -> Vect n a
replicate' {n = 0}   _ = []
replicate' {n = S _} v = v :: replicate' v
```

関数`replicate`は消去されていない暗黙引数を取ります。この引数の*値*は
周囲の文脈から導出できなくてはなりません。例えば以下の例では直ちに
`n`が3であることが明らかですが、それは欲しいベクタの長さがそれだからで
す。

```idris
replicateEx1 : Vect 3 Nat
replicateEx1 = replicate' 12
```

次の例では`n`の値はコンパイル時に知られていませんが、消去されていない
暗黙子として使うことができるので、これもまた`replicate`にそのまま渡す
ことができます。

```idris
replicateEx2 : {n : _} -> Vect n Nat
replicateEx2 = replicate' 12
```

しかし以下の例では`n`の値は推論することはできません。中間結果のベクタ
が直ちに不明な長さのリストに変換されているからです。Idrisは`n`にあらゆ
る値を挿入してみることはできるものの、そうすることは決してありません。
なぜならこれが欲しい長さであると確かめることができないからです。したがっ
て長さを明示的に渡さねばなりません。

```idris
replicateEx3 : List Nat
replicateEx3 = toList $ replicate' {n = 17} 12
```

`n`の値がこれらの例で推論されねばならなかったことに注目してください。
つまりその値が周囲の文脈に姿を現すようにしなければならなかったというこ
とです。自動暗黙引数では違った動作をします。以下は`head`の例ですが、今
回は自動暗黙子を使っています。

```idris
head : (as : List a) -> {auto 0 prf : NotNil as} -> a
head (x :: _) = x
head [] impossible
```

暗黙引数`prf`の数量子の前の`auto`キーワードに注目してください。これが
意味するところは、周囲の文脈で目に触れることなく、この値をIdrisに自力
で構築してもらいたいということです。そうするためにはIdrisはコンパイル
時にリスト引数`as`の構造を知っていなければなりません。それからそのよう
な値をデータ型の構築子から構築しようとします。もし成功したらこの値は所
望された引数として自動的に埋められます。そうでなければIdrisは型エラー
と共に失敗します。

これを実際に見てみましょう。

```idris
headEx3 : Nat
headEx3 = Predicates.head [1,2,3]
```

以下の例はエラーとなり失敗します。

```idris
failing "Can't find an implementation\nfor NotNil []."
  errHead : Nat
  errHead = Predicates.head []
```

待った！「Can't find an implementation for...」だって？これはインター
フェースの実装が欠けているときのエラー文言じゃないか。その通り、そして
本章の末尾でインターフェースの解決が証明検索に過ぎないことをお見せしま
す。既にお見せしてきたことは、毎度毎度長ったらしく`{auto prf :
t} ->`と書くことは面倒かもしれないということです。したがってIdrisでは
代わりに制約付き関数用の同じ構文を使うことができるのです。`(prf : t)
=>`、さらに制約の名前を付ける必要がなければ`t =>`でさえ構いません。そ
こからはいつも通り、（もしあれば）名前によって、関数の本体で制約を扱え
ます。以下は`head`の別実装です。

```idris
head' : (as : List a) -> (0 _ : NotNil as) => a
head' (x :: _) = x
head' [] impossible
```

証明検索中にIdrisは現在の関数の文脈の中で必要とされている型の値を探す
こともします。これにより`headMaybe`を実装するのに手動で`NotNil`の証明
を渡す必要はなくなります。

```idris
headMaybe : List a -> Maybe a
headMaybe as = case nonEmpty as of
  -- `prf` is available during proof seach
  Yes prf => Just $ Predicates.head as
  No  _   => Nothing
```

まとめるとこうなります。述語があれば関数が引数として受け付ける値を制限
することができます。実行時にそのような*証拠*を関数引数でのパターン照合
により構築する必要があります。こうした操作は一般には失敗しうるものです。
コンパイル時に*証明検索*と呼ばれる技術を使ってIdrisにこれらの値を構築
してみてもらうことができます。これにより関数を安全にしつつ、それと同時
に使うのに便利になります。

### 演習 その1

これらの演習では関数引数として受け付ける値に制約を課すために自動暗黙子
を活用した関数を複数実装せねばなりません。結果は*純粋*でなければなりま
せん。つまり`Maybe`のような失敗型に包まれていてはなりません。

1. リストに`tail`を実装してください。

2. `concat1`と`foldMap1`をリストに実装してください。これらは`concat`や
   `foldMap`と同じように動作しますが、要素型への`Semigroup`制約のみを取り
   ます。

3. リスト中の最大と最小の要素を返す関数を実装してください。

4. 厳密に正の自然数のための述語を定義し、それを使って安全で証明上全域な自
   然数における除算関数を実装してください。

5. 非空の`Maybe`のための述語を定義し、安全に`Just`の中に保管されてている
   値を取り出してください。この述語が決定可能であることを対応する変換関数
   を実装することによって示してください。

6. `Left`と`Right`から安全に値を取り出す関数を相応しい述語を使って定義し
   実装してください。再びこれらの述語が決定可能であることを示してください。

これらの演習で実装した熟語は既に*base*ライブラリから手に入ります。
`Data.List.NonEmpty`、`Data.Maybe.IsJust`、`Data.Either.IsLeft`、
`Data.Either.IsRight`、`Data.Nat.IsSucc`がそれです。

## 値間契約

これまで見てきた述語は値の型は単一のものに制限されていました。しかし相
異なる型を持ちうる複数の値の間の契約を記述する述語を定義することもでき
ます。

### `Elem`述語

混成リストから与えられた型の値を取り出したいとします。

```idris
get' : (0 t : Type) -> HList ts -> t
```

これは一般にはうまくいきません。これを実装できたとすると直ちにvoidの証
明が得られてしまいます。

```idris
voidAgain : Void
voidAgain = get' Void []
```

問題点は明らかです。値を取り出したい型は混成リストの指標の要素でなけれ
ばなりません。以下はとある述語で、これがあればこの要件を表現することが
できます。

```idris
data Elem : (elem : a) -> (as : List a) -> Type where
  Here  : Elem x (x :: xs)
  There : Elem x xs -> Elem x (y :: xs)
```

これは2つの値、すなわち型`a`と`a`のリストの値、の間の契約を記述する述
語です。この契約の値は値がリストの要素であることの証拠です。これが再帰
的に定義されていることに注目してください。探している値がリストの先頭に
ある場合は`Here`構築子で扱われ、要素とリストの先頭とで同じ変数 (`x`)
が使われます。値がリスト中のより深くにある場合は`There`構築子によって
扱われます。これは以下のように読むことができます。もし`x`が`xs`の要素
であれば、あらゆる`y`の値について、`x`もまた`y :: xs`の要素です。この
契約の感覚を掴むためにいくつかの例を書き下しましょう。

```idris
MyList : List Nat
MyList = [1,3,7,8,4,12]

oneElemMyList : Elem 1 MyList
oneElemMyList = Here

sevenElemMyList : Elem 7 MyList
sevenElemMyList = There $ There Here
```

ここで`Elem`は値のリストを指標で探り入れる単なる別の方法です。リストの
長さで制限された`Fin`指標を使う代わりに、値が特定の位置で見付けられる
ことの証明を使います。

`Elem`述語を使うことで混成リストの望んだ型から値を取り出すことができます。

```idris
get : (0 t : Type) -> HList ts -> (prf : Elem t ts) => t
```

大事なのは自動暗黙子がこの場合には消してはならないということに注意する
ことです。もはやこれが単一値データ型ではなく、混成リストの中のどれほど
深いところに値が格納されているのかを解明するために、この値でパターン照
合できなくてはならないのです。

```idris
get t (v :: vs) {prf = Here}    = v
get t (v :: vs) {prf = There p} = get t vs
get _ [] impossible
```

右側で穴開きを使い、`Elem`述語の値に基づいてIdrisが推論した値の文脈と
型を見つつ、自力で`get`を実装するとわかりやすいかもしれません。

ちょっとREPLで動かしてみましょう。

```repl
Tutorial.Predicates> get Nat ["foo", Just "bar", S Z]
1
Tutorial.Predicates> get Nat ["foo", Just "bar"]
Error: Can't find an implementation for Elem Nat [String, Maybe String].

(Interactive):1:1--1:28
 1 | get Nat ["foo", Just "bar"]
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

この例で*証明検索*が実際のところ意味するところが分かり始めます。値
`v`と値のリスト`vs`が与えられると、Idrisは`v`が`vs`の要素である証明を
見付けようとします。さて、話を進める前に証明検索が銀の弾丸ではないこと
に注意してください。検索アルゴリズムには合理的に制限された*探索深度*が
あり、この制限を超過すると探索が失敗します。例えば以下です。

```idris
Tps : List Type
Tps = List.replicate 50 Nat ++ [Maybe String]

hlist : HList Tps
hlist = [ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        , Nothing ]
```

そしてREPLで次のようにします。

```repl
Tutorial.Predicates> get (Maybe String) hlist
Error: Can't find an implementation for Elem (Maybe String) [Nat,...
```

見ての通りIdrisは`Maybe String`が`Tps`の要素であるという証明を見付ける
ことに失敗します。検索深度は`%auto_implicit_depth`命令で増加させること
ができ、ソースファイルの以降ないし異なる値が設定されるまでは保たれます。
既定値は25に設定されています。これを大きすぎる値に設定することは、劇的
にコンパイル時間を増加させかねないので、一般にはお勧めできません。

```idris
%auto_implicit_depth 100
aMaybe : Maybe String
aMaybe = get _ hlist

%auto_implicit_depth 25
```

### 用例：より良いスキーマ

[依存和型](DPair.md)についての章でCSVファイル用のスキーマを導入しまし
た。これは使う上であまりよくありませんでした。なぜなら特定の列にアクセ
スするために自然数を使わねばならなかったからです。さらに悪いことにこの
小さなライブラリの利用者も同じことをしなければならないのです。それぞれ
の列に名前を定義したり名前で列にアクセスする方法がありませんでした。こ
れを変えていくつもりです。以下はこの用例を符号化したものです。

```idris
data ColType = I64 | Str | Boolean | Float

IdrisType : ColType -> Type
IdrisType I64     = Int64
IdrisType Str     = String
IdrisType Boolean = Bool
IdrisType Float   = Double

record Column where
  constructor MkColumn
  name : String
  type : ColType

infixr 8 :>

(:>) : String -> ColType -> Column
(:>) = MkColumn

Schema : Type
Schema = List Column

Show ColType where
  show I64     = "I64"
  show Str     = "Str"
  show Boolean = "Boolean"
  show Float   = "Float"

Show Column where
  show (MkColumn n ct) = "\{n}:\{show ct}"

showSchema : Schema -> String
showSchema = concat . intersperse "," . map show
```

見ての通り、スキーマ中で列の型と名前を対にしました。以下は会社の従業員
の情報を保管するCSVファイル用のスキーマの例です。

```idris
EmployeeSchema : Schema
EmployeeSchema = [ "firstName"  :> Str
                 , "lastName"   :> Str
                 , "email"      :> Str
                 , "age"        :> I64
                 , "salary"     :> Float
                 , "management" :> Boolean
                 ]
```

そのようなスキーマは当然ここでも利用者の入力から読み取れますが、構文解
析器を実装するのは本章の後半まで待つことにします。この新しいスキーマを
`HList`と直接使うと型推論の問題が生じるので、手早く自前の行の型を書き
ました。スキーマ上に指標付けられた混成リストです。

```idris
data Row : Schema -> Type where
  Nil  : Row []

  (::) :  {0 name : String}
       -> {0 type : ColType}
       -> (v : IdrisType type)
       -> Row ss
       -> Row (name :> type :: ss)
```

*cons*の処方では消去された暗黙引数を明示的に列挙しています。これは良い
習慣です。というのもそうしないと使い手のコードでこのようなデータ構築子
を使うときに、Idrisがよく陰に隠されている旨の警告を出すからです。

これで従業員を表現するCSVの行の型別称を定義できます。

```idris
0 Employee : Type
Employee = Row EmployeeSchema

hock : Employee
hock = [ "Stefan", "Höck", "hock@foo.com", 46, 5443.2, False ]
```

なお、`Employee`にゼロ数量子を与えました。つまり、この関数を使うのは必
ずコンパイル時にのみ許されており、実行時には決して使えません。これはア
プリケーションを構築する際に型水準関数とその別称を実行可能物に確実に漏
れ出させないようにするための安全な方法です。ゼロ数量子の関数と値は型処
方や他の消去される値の計算時に使うことができますが、実行時関連の計算で
はできません。

さて、行の中の値に与えられた名前に基づいてアクセスしたいと思っています。
このためには自前の述語を書きます。この述語は与えられた名前を持つ列がス
キーマの一部であることの証拠として供されます。ここで、以下は注意すべき
重要な点です。この述語では与えられた名前を持つ列の*型*用の指標を含めま
す。こうする必要があるのですが、その理由は名前で列にアクセスする際に返
却型を調べる方法が必要だからです。しかし証明検索中はこの型はIdrisによっ
て列の名前と問題のスキーマに基づいて導出されなければなりません（さもな
いと返却型が前もって知られていない限り証明検索が失敗します）。したがっ
て、この型を検索判定基準の一覧に含められないことをIdrisに教える*必要*
があります。でないと証明検索を走らせる前に（型推論を使って）文脈から列
の型を推論しようとします。これは`[search name schema]`のように、検索で
使う指標を列挙することによって行うことができます。

```idris
data InSchema :  (name    : String)
              -> (schema  : Schema)
              -> (colType : ColType)
              -> Type where
  [search name schema]
  IsHere  : InSchema n (n :> t :: ss) t
  IsThere : InSchema n ss t -> InSchema n (fld :: ss) t

Uninhabited (InSchema n [] c) where
  uninhabited IsHere impossible
  uninhabited (IsThere _) impossible
```

これを使うことで、列の名前に基づいて与えられた列にある値にアクセスする準備が整いました。

```idris
getAt :  {0 ss : Schema}
      -> (name : String)
      -> (row  : Row ss)
      -> (prf  : InSchema name ss c)
      => IdrisType c
getAt name (v :: vs) {prf = IsHere}    = v
getAt name (_ :: vs) {prf = IsThere p} = getAt name vs
```

以下はこれをコンパイル時に使う方法の一例です。どれほどのことをIdrisが
してくれているかに注目してください。まず、`firstName`、`lastName`、
`age`が確かに`Employee`スキーマ中の妥当な名前であるという証明を考え付
いています。これらの証明から自動的に`getAt`の呼び出しによる返却型を解
明し、列から対応する値を抽出します。この全てが証明上全域で型安全なやり
方で行われるのです。

```idris
shoeck : String
shoeck =  getAt "firstName" hock
       ++ " "
       ++ getAt "lastName" hock
       ++ ": "
       ++ show (getAt "age" hock)
       ++ " years old."
```

実行時に列の名前を指定するためには、列の名前と問題のスキーマを比較する
ことによって型`InSchema`の値を計算する方法が必要です。命題上等しくある
ために2つの文字列値を比較せねばならないため、ここでは`String`用の
`DecEq`実装を使います（Idrisは全ての原始型用に`DecEq`実装を提供してい
ます）。同時に列の型を取り出し、（依存対として）これと`InSchema`証明と
を対にしています。

```idris
inSchema : (ss : Schema) -> (n : String) -> Maybe (c ** InSchema n ss c)
inSchema []                    _ = Nothing
inSchema (MkColumn cn t :: xs) n = case decEq cn n of
  Yes Refl   => Just (t ** IsHere)
  No  contra => case inSchema xs n of
    Just (t ** prf) => Just $ (t ** IsThere prf)
    Nothing         => Nothing
```

本章の終わりには、CSVコマンドラインアプリケーションで列の中の全ての値
を列挙するために`InSchema`を使っていきます。

### 演習 その2

1. `InSchema`が決定可能であることを、`inSchema`の出力型を`Dec (c **
   InSchema n ss c)`に変えることで示してください。

2. 与えられた列名に基づいてフィールドを変更する関数を宣言し実装してください。

3. 1つ目のリストが2つ目のリスト中の要素をこの順で含んでいるという証拠とし
   て使われる述語を定義し、この述語を使って複数列を行から一度に抽出するの
   に使ってください。

   例えば`[2,4,5]`には`[1,2,3,4,5,6]`から正しい順序で要素を含んでいますが、
   `[4,2,5]`はそうではありません。

4. 演習3を元に新しい述語を定義することによって機能を向上させてください。
   この述語はリスト中の全ての文字列がスキーマ中の列名に（任意の順序で）対
   応するという証拠です。これを使って行から複数列を任意の順序で一度に取り
   出してください。

   手掛かり：必ず結果のスキーマを指標として含めてください。ただし名前
   のリストと入力スキーマのみに基づいて検索してください。

## 用例：柔軟なエラー制御

大き目のアプリケーションを書いているときに繰り返されるパターンとして、
独自の失敗型を持つプログラムのそれぞれの部品を、より大きな作用付き計算
に組み合わせることがあります。これについては例えばCSVファイルを取り扱
うコマンドラインツールを実装したときに見ました。そこではデータをファイ
ルについて読み書きし、列の型とスキーマを構文解析し、行と列の指標とコマ
ンドラインの命令を構文解析しました。これら全ての操作は潜在的な失敗が付
き物であり、アプリケーションをなす異なる部品において実装されることがあ
ります。これらの異なる失敗型を統一するためにそれぞれを内蔵化する自前の
直和型を書き、この直和型用の単一の制御子を書きました。この手法はそのと
きは良かったのですが、充分な規模拡大にはなりませんし、柔軟性の観点から
は欠けているところがありました。したがってここでは違う手法を試していき
ます。先に進む前に手短かに潜在的な失敗を伴ういくつかの関数といくつかの
自前のエラー型を実装します。

```idris
record NoNat where
  constructor MkNoNat
  str : String

readNat' : String -> Either NoNat Nat
readNat' s = maybeToEither (MkNoNat s) $ parsePositive s

record NoColType where
  constructor MkNoColType
  str : String

readColType' : String -> Either NoColType ColType
readColType' "I64"     = Right I64
readColType' "Str"     = Right Str
readColType' "Boolean" = Right Boolean
readColType' "Float"   = Right Float
readColType' s         = Left $ MkNoColType s
```

ところが`Fin n`を構文解析したいとなるとこの時点でどう失敗しうるかにつ
いて2通りあることになります。1つは問題の文字列が自然数を表現していない
とき（`NoNat`エラーに繋がります）、もう1つは範囲外であるとき
（`OutOfBounds`エラーに繋がります）です。どうにかしてこれら2つの可能性
を返却型に符号化せねばなりません。例えば`Either`をエラー型として使うこ
とはできます。

```idris
record OutOfBounds where
  constructor MkOutOfBounds
  size  : Nat
  index : Nat

readFin' : {n : _} -> String -> Either (Either NoNat OutOfBounds) (Fin n)
readFin' s = do
  ix <- mapFst Left (readNat' s)
  maybeToEither (Right $ MkOutOfBounds n ix) $ natToFin ix n
```

これは非常に見辛いです。自前の直和型は僅かにマシかもしれませんが、それ
でも`readNat'`を呼び出すときに`mapFst`を使う必要があるでしょうし、全て
の取り得るエラーの組み合わせについて直和型を書くこともまたとても速やか
に面倒なことになるでしょう。ここで追い求めていたものは一般化された直和
型です。型のリスト（取り得る選択肢）によって指標付けられちょうど1つの
問題の型の単一値を保有する型なのです。以下は最初の素朴な試みです。

```idris
data Sum : List Type -> Type where
  MkSum : (val : t) -> Sum ts
```

しかし決定的な情報が欠けています。それは、`t`が`ts`の要素なのか、そし
て実際に*どの*型なのかをまだ確証していないことです。実際これは消去され
た存在量化子の別の場合であり、実行時に`t`について何かを知る術は1つもあ
りません。しなければならないことは値を証明と対にすることで、その証明は
型`t`が`ts`の要素であることについてのものです。このために再び`Elem`を
使うこともできるでしょうが、リスト中にある型の数にアクセスする必要があ
る用例もあります。したがってリストの代わりにベクタを指標として使います。
以下は`Elem`に似ていつつもベクタ用の述語です。

```idris
data Has :  (v : a) -> (vs  : Vect n a) -> Type where
  Z : Has v (v :: vs)
  S : Has v vs -> Has v (w :: vs)

Uninhabited (Has v []) where
  uninhabited Z impossible
  uninhabited (S _) impossible
```

型`Has v vs`の値は`v`が`vs`の要素であることの証拠です。これを使えば今
や指標付けられた直和型（*開合併型*とも呼ばれます）を実装できます。

```idris
data Union : Vect n Type -> Type where
  U : (ix : Has t ts) -> (val : t) -> Union ts

Uninhabited (Union []) where
  uninhabited (U ix _) = absurd ix
```

`HList`と`Union`の間の違いに注目してください。`HList`は*生成された直積
型*です。指標にそれぞれの型の値を保有しています。`Union`は*生成された
直和型*です。単一値のみを持ち、指標に挙げられている型でなればなりませ
ん。これがあれば今や遥かに柔軟なエラー型を定義できます。

```idris
0 Err : Vect n Type -> Type -> Type
Err ts t = Either (Union ts) t
```

`Err ts a`を返す関数はある計算を記述しています。その計算とは`ts`で挙げ
られたエラーのうちの1つで失敗しうるというものです。最初にいくつかの便
利関数が必要です。

```idris
inject : (prf : Has t ts) => (v : t) -> Union ts
inject v = U prf v

fail : Has t ts => (err : t) -> Err ts a
fail err = Left $ inject err

failMaybe : Has t ts => (err : Lazy t) -> Maybe a -> Err ts a
failMaybe err = maybeToEither (inject err)
```

次に以前書いた構文解析器のより柔軟なバージョンを書くことができます。

```idris
readNat : Has NoNat ts => String -> Err ts Nat
readNat s = failMaybe (MkNoNat s) $ parsePositive s

readColType : Has NoColType ts => String -> Err ts ColType
readColType "I64"     = Right I64
readColType "Str"     = Right Str
readColType "Boolean" = Right Boolean
readColType "Float"   = Right Float
readColType s         = fail $ MkNoColType s
```

`readFin`を実装する前に、複数のエラー型が存在していなければならないこ
とを指定する早道を導入します。

```idris
0 Errs : List Type -> Vect n Type -> Type
Errs []        _  = ()
Errs (x :: xs) ts = (Has x ts, Errs xs ts)
```

関数`Errs`は制約のタプルを返します。これは全ての列挙された型が型のベク
タにあることの証拠として使えます。Idrisは自動的にタプルから証明を必要
に応じて取り出します。


```idris
readFin : {n : _} -> Errs [NoNat, OutOfBounds] ts => String -> Err ts (Fin n)
readFin s = do
  S ix <- readNat s | Z => fail (MkOutOfBounds n Z)
  failMaybe (MkOutOfBounds n (S ix)) $ natToFin ix n
```

最後の例として以下はスキーマとCSVの行のための構文解析器です。

```idris
fromCSV : String -> List String
fromCSV = forget . split (',' ==)

record InvalidColumn where
  constructor MkInvalidColumn
  str : String

readColumn : Errs [InvalidColumn, NoColType] ts => String -> Err ts Column
readColumn s = case forget $ split (':' ==) s of
  [n,ct] => MkColumn n <$> readColType ct
  _      => fail $ MkInvalidColumn s

readSchema : Errs [InvalidColumn, NoColType] ts => String -> Err ts Schema
readSchema = traverse readColumn . fromCSV

data RowError : Type where
  InvalidField  : (row, col : Nat) -> (ct : ColType) -> String -> RowError
  UnexpectedEOI : (row, col : Nat) -> RowError
  ExpectedEOI   : (row, col : Nat) -> RowError

decodeField :  Has RowError ts
            => (row,col : Nat)
            -> (c : ColType)
            -> String
            -> Err ts (IdrisType c)
decodeField row col c s =
  let err = InvalidField row col c s
   in case c of
        I64     => failMaybe err $ read s
        Str     => failMaybe err $ read s
        Boolean => failMaybe err $ read s
        Float   => failMaybe err $ read s

decodeRow :  Has RowError ts
          => {s : _}
          -> (row : Nat)
          -> (str : String)
          -> Err ts (Row s)
decodeRow row = go 1 s . fromCSV
  where go : Nat -> (cs : Schema) -> List String -> Err ts (Row cs)
        go k []       []                    = Right []
        go k []       (_ :: _)              = fail $ ExpectedEOI row k
        go k (_ :: _) []                    = fail $ UnexpectedEOI row k
        go k (MkColumn n c :: cs) (s :: ss) =
          [| decodeField row k c s :: go (S k) cs ss |]
```

以下はREPLセッションの一例です。ここでは`readSchema`を試しました。
`:let`命令を使って変数`ts`を定義し、より便利にしています。型
`InvalidColumn`と`NoColType`がエラーのリスト中にある限り、エラー型の順
番には何ら重要性はないことに注意してください。

```repl
Tutorial.Predicates> :let ts = the (Vect 3 _) [NoColType,NoNat,InvalidColumn]
Tutorial.Predicates> readSchema {ts} "foo:bar"
Left (U Z (MkNoColType "bar"))
Tutorial.Predicates> readSchema {ts} "foo:Float"
Right [MkColumn "foo" Float]
Tutorial.Predicates> readSchema {ts} "foo Float"
Left (U (S (S Z)) (MkInvalidColumn "foo Float"))
```

### エラー制御

エラー制御にはいくつかの技法があり、それら全てがその時々で役に立ちます。
例えば何らかのエラーを個別かつ早めに扱いつつ、他のものはアプリケーショ
ンのもっと後で対処したいことがあるかもしれません。あるいはそれらを一挙
に扱いたいかもしれません。ここでは両方の手法を見ていきます。

まず単一のエラーを個別に扱うためには、合併を二者択一の可能性に*分割*す
る必要があります。ここでの二者とは、問題のエラー型または新しい合併の値
のことで、後者は他のエラー型を持ちます。このためには新しい述語が必要で
あり、この述語はベクタ中に値があることだけではなく、その値を削除する結
果についても符号化するものです。

```idris
data Rem : (v : a) -> (vs : Vect (S n) a) -> (rem : Vect n a) -> Type where
  [search v vs]
  RZ : Rem v (v :: rem) rem
  RS : Rem v vs rem -> Rem v (w :: vs) (w :: rem)
```

繰り返しますが関数の返却型では指標 (`rem`) のうち1つを使いたいので、証
明検索中では他の指標のみを使います。以下は開合併から値を分離する関数で
す。

```idris
split : (prf : Rem t ts rem) => Union ts -> Either t (Union rem)
split {prf = RZ}   (U Z     val) = Left val
split {prf = RZ}   (U (S x) val) = Right (U x val)
split {prf = RS p} (U Z     val) = Right (U Z val)
split {prf = RS p} (U (S x) val) = case split {prf = p} (U x val) of
  Left vt        => Left vt
  Right (U ix y) => Right $ U (S ix) y
```

これは型`t`の値を合併から取り出そうとするものです。もしうまくいけば結
果は`Left`に包まれ、そうでなければ`Right`の中に入れた新しい合併が返さ
れます。ただしこの合併については取り得る型のリストから`t`は削除されて
います。

これがあれば単一エラー用の制御子を実装できます。エラー制御はしばしば作
用付きの文脈で置こるため（文言をコンソールに印字したりエラーをログファ
イルに書き込んだりしたいかもしれません）、アプリカティブ作用型を使って
中のエラーを扱います。

```idris
handle :  Applicative f
       => Rem t ts rem
       => (h : t -> f a)
       -> Err ts a
       -> f (Err rem a)
handle h (Left x)  = case split x of
  Left v    => Right <$> h v
  Right err => pure $ Left err
handle _ (Right x) = pure $ Right x
```

全てのエラーを一度に扱うためにはエラーのベクタによって指標付けられた制
御子型を使うことができ、出力型を変数に取ります。

```idris
namespace Handler
  public export
  data Handler : (ts : Vect n Type) -> (a : Type) -> Type where
    Nil  : Handler [] a
    (::) : (t -> a) -> Handler ts a -> Handler (t :: ts) a

extract : Handler ts a -> Has t ts -> t -> a
extract (f :: _)  Z     val = f val
extract (_ :: fs) (S y) val = extract fs y val
extract []        ix    _   = absurd ix

handleAll : Applicative f => Handler ts (f a) -> Err ts a -> f a
handleAll _ (Right v)       = pure v
handleAll h (Left $ U ix v) = extract h ix v
```

以下では、自前のエラー制御用のインターフェースを定義することによって一
度に全てのエラーを扱う追加の方法を見ていきます。

### 演習 その3

1. `Union`用の以下の便利関数を実装してください。

   ```idris
   project : (0 t : Type) -> (prf : Has t ts) => Union ts -> Maybe t

   project1 : Union [t] -> t

   safe : Err [] a -> a
   ```
2. 開合併をより大きな可能性の集合に組込む以下の2関数を実装してください。
   `extend`中の消去されない暗黙子に注意してください！

   ```idris
   weaken : Union ts -> Union (ts ++ ss)

   extend : {m : _} -> {0 pre : Vect m _} -> Union ts -> Union (pre ++ ts)
   ```

3. `Union ts`を`Union ss`中に組込む汎用的な方法を見付けて、以下ができるよ
   うにしてください。

   ```idris
   embedTest :  Err [NoNat,NoColType] a
             -> Err [FileError, NoColType, OutOfBounds, NoNat] a
   embedTest = mapFst embed
   ```

4. 制御子に問題のエラーを`f (Err rem a)`へ変換させるようにすることで、
   `handle`をより強力にしてください。

## インターフェースの真実

さて、遂にここまで来ました。インターフェースについての真実です。内部的
にはインターフェースは単なるレコードデータ型で、インターフェースのメン
バーに対応するフィールドを持ちます。インターフェースの実装はそのような
レコードの*値*であり、証明検索の最中に値が入手できるよう`%hint`プラグ
マ（後述）で註釈付けられています。とどのつまり制約付き関数は単なる1つ
以上の自動暗黙引数を持つ関数なのです。例えば以下はリスト中の要素を見つ
け出す同じ関数で、一方は既に見た構文の制約付き関数であり、もう一方は自
動暗黙引数を持つものです。Idrisによって生成されるコードは両方とも同じ
です。

```idris
isElem1 : Eq a => a -> List a -> Bool
isElem1 v []        = False
isElem1 v (x :: xs) = x == v || isElem1 v xs

isElem2 : {auto _ : Eq a} -> a -> List a -> Bool
isElem2 v []        = False
isElem2 v (x :: xs) = x == v || isElem2 v xs
```

ただのレコードであるために、インターフェースを通常の関数引数として見做
しパターン照合で解剖することもできます。

```idris
eq : Eq a -> a -> a -> Bool
eq (MkEq feq fneq) = feq
```

### 手動インターフェース定義

ここでは証明検索が通常のインターフェース定義および実装を使うのと同じ振
舞いを実現する方法を実演していきます。新しいエラー制御ツールを使った
CSVの例を終わらせたいので、いくつかのエラー制御子を実装していきます。
最初にインターフェースは単なるレコードです。

```idris
record Print a where
  constructor MkPrint
  print' : a -> String
```

制約付き関数中のレコードにアクセスするためには`%search`キーワードを使
います。このキーワードは証明検索によって所望の型（この場合`Print a`）
の値を出そうとします。

```idris
print : Print a => a -> String
print = print' %search
```

代替案として名前付き制約を使うこともでき、直接その名前を介してアクセスできます。

```idris
print2 : (impl : Print a) => a -> String
print2 = print' impl
```

更に別の代替案として、自動暗黙子用の構文を使うこともできます。

```idris
print3 : {auto impl : Print a} -> a -> String
print3 = print' impl
```

3バージョン全ての`print`は実行時にはちょうど同じ振舞いをします。ですか
ら`{auto x : Foo}`と書くときは単に`(x : Foo) =>`とも書くことができます
し、逆もまた然りです。

インターフェース実装は単に与えられたレコード型の値ですが、証明検索中で
使えるようにするには、`%hint`プラグマで註釈付けられている必要がありま
す。

```idris
%hint
noNatPrint : Print NoNat
noNatPrint = MkPrint $ \e => "Not a natural number: \{e.str}"

%hint
noColTypePrint : Print NoColType
noColTypePrint = MkPrint $ \e => "Not a column type: \{e.str}"

%hint
outOfBoundsPrint : Print OutOfBounds
outOfBoundsPrint = MkPrint $ \e => "Index is out of bounds: \{show e.index}"

%hint
rowErrorPrint : Print RowError
rowErrorPrint = MkPrint $
  \case InvalidField r c ct s =>
          "Not a \{show ct} in row \{show r}, column \{show c}. \{s}"
        UnexpectedEOI r c =>
          "Unexpected end of input in row \{show r}, column \{show c}."
        ExpectedEOI r c =>
          "Expected end of input in row \{show r}, column \{show c}."
```

合併やエラー用の`Print`の実装を書くこともできます。このためには最初に
合併の指標中の全ての型に`Print`の実装が付いて来ていることの証明を思い
付くことになります。

```idris
0 All : (f : a -> Type) -> Vect n a -> Type
All f []        = ()
All f (x :: xs) = (f x, All f xs)

unionPrintImpl : All Print ts => Union ts -> String
unionPrintImpl (U Z val)     = print val
unionPrintImpl (U (S x) val) = unionPrintImpl $ U x val

%hint
unionPrint : All Print ts => Print (Union ts)
unionPrint = MkPrint unionPrintImpl
```

このようにインターフェースを定義することは利点になりえます。というのも
魔法のような要素は遥かに少なく、フィールドの型と値に関してより微に入る
制御できるからです。また、こうした魔法全てが証明手掛かりから来ているこ
とにも注目です。この手掛かりは「インターフェース実装」に註釈付けられる
ものです。これらは対応する値と関数を証明検索中に使えるようにするもので
す。

#### CSVの命令を構文解析する

本章の締め括りとして、前節の柔軟なエラー制御手法を使い、CSVの命令の構
文解析器を再実装します。元の構文解析器より冗長でなくなるとは限らないも
のの、この手法はエラーの制御とエラー文言の印字をアプリケーションの残り
の部分から分離します。失敗の可能性を持つ関数は異なる文脈で再利用ができ
ますが、それはエラー文言用に使うプリティープリンターもまた再利用できる
ためです。

最初に以前の章にあったいくつかのものを繰り返し書きます。列中の全ての値
を印字する新しい命令を忍ばせました。

```idris
record Table where
  constructor MkTable
  schema : Schema
  size   : Nat
  rows   : Vect size (Row schema)

data Command : (t : Table) -> Type where
  PrintSchema :  Command t
  PrintSize   :  Command t
  New         :  (newSchema : Schema) -> Command t
  Prepend     :  Row (schema t) -> Command t
  Get         :  Fin (size t) -> Command t
  Delete      :  Fin (size t) -> Command t
  Col         :  (name : String)
              -> (tpe  : ColType)
              -> (prf  : InSchema name t.schema tpe)
              -> Command t
  Quit        : Command t

applyCommand : (t : Table) -> Command t -> Table
applyCommand t                 PrintSchema = t
applyCommand t                 PrintSize   = t
applyCommand _                 (New ts)    = MkTable ts _ []
applyCommand (MkTable ts n rs) (Prepend r) = MkTable ts _ $ r :: rs
applyCommand t                 (Get x)     = t
applyCommand t                 Quit        = t
applyCommand t                 (Col _ _ _) = t
applyCommand (MkTable ts n rs) (Delete x)  = case n of
  S k => MkTable ts k (deleteAt x rs)
  Z   => absurd x
```

次に、以下は再実装された命令の構文解析器です。全体としては7つの異なる
原因で失敗しうるものですが、少なくともそのうちのいくつかはより大きなア
プリケーションの他の部分でも使うことができる可能性があります。

```idris
record UnknownCommand where
  constructor MkUnknownCommand
  str : String

%hint
unknownCommandPrint : Print UnknownCommand
unknownCommandPrint = MkPrint $ \v => "Unknown command: \{v.str}"

record NoColName where
  constructor MkNoColName
  str : String

%hint
noColNamePrint : Print NoColName
noColNamePrint = MkPrint $ \v => "Unknown column: \{v.str}"

0 CmdErrs : Vect 7 Type
CmdErrs = [ InvalidColumn
          , NoColName
          , NoColType
          , NoNat
          , OutOfBounds
          , RowError
          , UnknownCommand ]

readCommand : (t : Table) -> String -> Err CmdErrs (Command t)
readCommand _                "schema"  = Right PrintSchema
readCommand _                "size"    = Right PrintSize
readCommand _                "quit"    = Right Quit
readCommand (MkTable ts n _) s         = case words s of
  ["new",    str] => New     <$> readSchema str
  "add" ::   ss   => Prepend <$> decodeRow 1 (unwords ss)
  ["get",    str] => Get     <$> readFin str
  ["delete", str] => Delete  <$> readFin str
  ["column", str] => case inSchema ts str of
    Just (ct ** prf) => Right $ Col str ct prf
    Nothing          => fail $ MkNoColName str
  _               => fail $ MkUnknownCommand s
```

`readFin`や`readSchema`といった関数を直接呼び出せているところに注目し
てください。これは必要なエラー型が起こりうるエラーのリストの一部にある
からです。

本節のまとめとして、以下は命令の結果を印字する機能とアプリケーションの
メインループです。このほとんどは以前の章からの繰り返しですが、単一の
`print`の呼び出しで全てのエラーを一度に扱えていることに着目してくださ
い。

```idris
encodeField : (t : ColType) -> IdrisType t -> String
encodeField I64     x     = show x
encodeField Str     x     = show x
encodeField Boolean True  = "t"
encodeField Boolean False = "f"
encodeField Float   x     = show x

encodeRow : (s : Schema) -> Row s -> String
encodeRow s = concat . intersperse "," . go s
  where go : (s' : Schema) -> Row s' -> Vect (length s') String
        go []        []        = []
        go (MkColumn _ c :: cs) (v :: vs) = encodeField c v :: go cs vs

encodeCol :  (name : String)
          -> (c    : ColType)
          -> InSchema name s c
          => Vect n (Row s)
          -> String
encodeCol name c = unlines . toList . map (\r => encodeField c $ getAt name r)

result :  (t : Table) -> Command t -> String
result t PrintSchema   = "Current schema: \{showSchema t.schema}"
result t PrintSize     = "Current size: \{show t.size}"
result _ (New ts)      = "Created table. Schema: \{showSchema ts}"
result t (Prepend r)   = "Row prepended: \{encodeRow t.schema r}"
result _ (Delete x)    = "Deleted row: \{show $ FS x}."
result _ Quit          = "Goodbye."
result t (Col n c prf) = "Column \{n}:\n\{encodeCol n c t.rows}"
result t (Get x)       =
  "Row \{show $ FS x}: \{encodeRow t.schema (index x t.rows)}"

covering
runProg : Table -> IO ()
runProg t = do
  putStr "Enter a command: "
  str <- getLine
  case readCommand t str of
    Left err   => putStrLn (print err) >> runProg t
    Right Quit => putStrLn (result t Quit)
    Right cmd  => putStrLn (result t cmd) >>
                  runProg (applyCommand t cmd)

covering
main : IO ()
main = runProg $ MkTable [] _ []
```

以下はREPLセッションの例です。

```repl
Tutorial.Predicates> :exec main
Enter a command: new name:Str,age:Int64,salary:Float
Not a column type: Int64
Enter a command: new name:Str,age:I64,salary:Float
Created table. Schema: name:Str,age:I64,salary:Float
Enter a command: add John Doe,44,3500
Row prepended: "John Doe",44,3500.0
Enter a command: add Jane Doe,50,4000
Row prepended: "Jane Doe",50,4000.0
Enter a command: get 1
Row 1: "Jane Doe",50,4000.0
Enter a command: column salary
Column salary:
4000.0
3500.0

Enter a command: quit
Goodbye.
```

## まとめ

述語のお陰で型の間の契約を記述し、妥当な関数引数として受け付ける値を精
錬することができます。述語を自動暗黙引数として使うことにより、関数を安
全で、且つ実行時*と*コンパイル時に使うのに便利なものにしてくれます。自
動暗黙引数とは、関数引数の構造について充分な情報があればIdrisが自力で
構築しようとするものでした。

<!-- vi: filetype=idris2
-->
