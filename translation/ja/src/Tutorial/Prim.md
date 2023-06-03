# 原始型

これまで押さえてきた話題ではほとんど一度もIdrisの原始型についてお話ししてきませんでした。空気のようにそこにあって、いくつかの計算で使いましたが、その仕組みや出自について本当に説明しませんでしたし、それらについて何ができ何ができないかを詳しく示しませんでした。

```idris
module Tutorial.Prim

import Data.Bits
import Data.String

%default total
```

## 原始型はどのように実装されているのか

### バックエンドについての短い補足

[Wikipedia](https://en.wikipedia.org/wiki/Compiler)によると、コンパイ
ラは「あるプログラミング言語（ソース言語）で書かれたコンピュータのコー
ドを別の言語（対象言語）に翻訳するコンピュータプログラム」です。Idris
コンパイラはまさしくその通りです。Idrisで書かれたプログラムをChez
Schemeで書かれたプログラムに翻訳するプログラムですから。このSchemeコー
ドはそれからChez Schemeインタプリタによって構文解析され解釈されます。
このインタプリタはコンパイルされたIdrisプログラムを走らせるのに使うコ
ンピュータ上にインストールしなければなりません。

しかしそれは氷山の一角です。Idris 2は当初より様々なコード生成器（いわ
ゆる*バックエンド*）に対応するよう設計されており、このバックエンドのお
陰で様々なプラットフォームを対象とするIdrisコードを書くことができ、
Idrisをインストールするといくつかの追加のバックエンド付属して使えるよ
うになっています。使うバックエンドを`--cg`コマンドライン引数（`cg`は
*コード生成器*を表しています）を使って指定することができます。例えば以
下の通り。

```sh
idris2 --cg racket
```

以下は標準的なIdrisのインストールで手に入るバックエンドの非網羅的な一
覧です（コマンドライン引数で使われる名前は括弧内に与えられています）：

* Racket Scheme (`racket`): これはSchemeプログラミング言語の別のフレーバー
  であり、オペレーティングシステムでChez Schemeが使えないときに便利かも
  しれません。
* Node.js (`node`): これはIdrisプログラムをJavaScriptに変換します。
* ブラウザ (`javascript`): ブラウザの上で走るWebアプリケーションをIdris
  で書くことができるようにする別のJavaScriptバックエンドです。
* RefC (`refc`): IdrisをCのコードにコンパイルするバックエンドで、そこか
  ら更にCコンパイラによってコンパイルされます。

少なくともJavaScriptバックエンドについてはこのIdrisの手引きの別の部で
もう少し詳細に押さえる予定です。というのも私自身かなり頻繁に使うからで
す。

Idrisプロジェクトによって公式に対応していない外部のバックエンドもいく
つかあります。その中にはIdrisコードをJavaやPythonにコンパイルするバッ
クエンドもあります。外部バックエンドの一覧は[Idris
Wiki](https://github.com/idris-lang/Idris2/wiki/1-%5BLanguage%5D-External-backends)
で見ることができます。

### Idrisの原始型

*原始データ型*はIdrisコンパイラに*原始関数*と共に組込まれている型です。
原始関数は原始型に関する計算を行うために使われます。したがって原始型や
原始関数の定義は*Prelude*のソースコードには見付かりません。

以下に再びIdrisの原始型の一覧を示します：

* 符号付き、固定精度整数：
  * `Int8`: 範囲 [-128,127] 中の整数
  * `Int16`: 範囲 [-32768,32767] 中の整数
  * `Int32`: 範囲 [-2147483648,2147483647] 中の整数
  * `Int64`: 範囲 [-9223372036854775808,9223372036854775807] 中の整数
* 符号なし、固定精度整数：
  * `Bits8`: 範囲 [0,255] 中の整数
  * `Bits16`: 範囲 [0,65535] 中の整数
  * `Bits32`: 範囲 [0,4294967295] 中の整数
  * `Bits64`: 範囲 [0,18446744073709551615] 中の整数
* `Integer`: 符号あり、任意精度整数。
* `Double`: 倍精度（64bit）浮動小数点数。
* `Char`: Unicode文字。
* `String`: Unicode文字の並び。
* `%World`: 現在の世界の状態の象徴的な表現。これについてはどのように
  `IO`が実装されているかを示した際に学びました。ほとんどの場合、手元のコー
  ドでこの型の値を扱うことはないでしょう。
* `Int`: これは特別です。固定精度で、符号付きの整数ですが、ビットの大
   きさは使っているバックエンドと（恐らく）プラットフォームに依存しま
   す。例えば既定のChez Schemeバックエンドを使っているなら、`Int`は64
   ビット符号付き整数ですが、JavaScriptバックエンドでは効率上の理由か
   ら32ビット符号付き整数です。したがって`Int`についてくるのはかなり少
   ない保証であり、可能な限り上に挙げた充分に指定された整数型のうち1つ
   を使うべきです。

コンパイラのソースコードのどこに原始型と原始関数が定義されているかを知
るとわかりやすいかもしれません。このソースコードは[Idrisプロジェク
ト](https://github.com/idris-lang/Idris2)の`src`フォルダに見付かり、原
始型はデータ型`Core.TT.Constant`の定数構築子です。

### 原始関数

原始型を操作する全ての計算は2種類の原始関数に基づいています。一方はコ
ンパイラに組込まれているもの（後述）で、もう一方はプログラマが異邦関数
インターフェース（FFI）を介して定義したものです。これについては別の章
でお話しするつもりです。

組み込みの原始関数はコンパイラに知られている関数で、その定義は
*Prelude*には見付けられません。これらの関数は原始型用に使える中核の機
能を定義します。大抵の場合直接呼び出すことはないですが（とはいえほとん
どの場合そうしても完全に問題ありません）、普通は*Prelude*や*base*ライ
ブラリが輸出する関数とインターフェースを介して呼び出されます。

例えば2つの8ビット符号無し整数を加える原始関数は`prim__add_Bits8`です。
REPLで型と挙動を調べられます。

```repl
Tutorial.Prim> :t prim__add_Bits8
prim__add_Bits8 : Bits8 -> Bits8 -> Bits8
Tutorial.Prim> prim__add_Bits8 12 100
112
```

`Bits8`にインターフェース`Num`を実装するソースコードを見ると、和演算子は内部的には単に`prim__add_Bits8`を呼び出しているだけだとわかるでしょう。同じことがほとんどの原始インターフェース実装中の他の関数にも言えます。例えば`%World`を除く全ての原始型には原始比較関数が付属しています。`Bits8`には`prim__eq_Bits8`、`prim__gt_Bits8`、`prim__lt_Bits8`、`prim__gte_Bits8`、`prim__lte_Bits8`といった具合です。なお、これらの関数は`Bool`（Idrisでの原始型では*ありません*）ではなく`Int`を返します。したがってこれらの関数は`Eq`や`Comp`といったインターフェースの対応する演算子の実装ほどには使うのに安全でも便利でもありません。他方で`Bool`への変換を介さないために効率が重大なコード（真面目なプロファイリングの後にのみ問題を特定できる）では僅かに良いかもしれません。

原始型に関しては、原始型はコンパイラのソースのデータ型
(`Core.TT.PrimFn`) 中の構築子として挙げられています。そのほとんどを以
下の節で見ていきます。

### 原始型であることの帰結

原始関数と原始型はコンパイラにとってほとんどの点で不透明です。これらは
それぞれのバックエンドで個別に定義し実装されなくてはならず、したがって
コンパイラは原始型の値の内部構造についても原始関数の内部の仕組みについ
ても何も知らないのです。例えば以下の再帰関数について、*私達*は再帰呼び
出し中の引数が基底の場合に（使っているバックエンドにバグがない限り）収
束することを知っていますが、コンパイラはそうではありません。

```idris
covering
replicateBits8' : Bits8 -> a -> List a
replicateBits8' 0 _ = []
replicateBits8' n v = v :: replicateBits8' (n - 1) v
```

こうした場合単に*covering*関数として済ますか、`assert_smaller`を使って
全域性検査器を説得するか（こちらが好ましい方法です）の2択です。

```idris
replicateBits8 : Bits8 -> a -> List a
replicateBits8 0 _ = []
replicateBits8 n v = v :: replicateBits8 (assert_smaller n $ n - 1) v
```

以前`assert_smaller`を使う危険性を示したので、新しい関数引数が確かに基
底の場合との関係としてより小さいものであることを確かめるのに特に注意が
必要です。

Idrisは原始型と関連する関数の内部の仕組みを何もしりませんが、そうはいっ
てもコンパイル時に知っている値が与えられているときはこれらの関数のほと
んどは評価の最中に簡約します。例えば`Bits8`についての以下の等式が満た
されることの自明な証明を行えます。

```idris
zeroBits8 : the Bits8 0 = 255 + 1
zeroBits8 = Refl
```

原始型の内部構造についても原始関数の実装についても何の手掛かりもないた
めに、Idrisはそのような関数や値の*一般的な*性質については何も証明の助
けになりません。以下はこれを実演する例です。リストの長さによって指標付
けられたデータ型の中にリストを包みたいとします。

```idris
data LenList : (n : Nat) -> Type -> Type where
  MkLenList : (as : List a) -> LenList (length as) a
```

2つの`LenList`を結合するとき、長さの指標は加算されます。それがリストの
結合がリストの長さに影響するところです。このことが正しいことを安全に
Idrisに教えられます。

```idris
0 concatLen : (xs,ys : List a) -> length xs + length ys = length (xs ++ ys)
concatLen []        ys = Refl
concatLen (x :: xs) ys = cong S $ concatLen xs ys
```

上の補題があれば`LenList`の結合を実装できます。

```idris
(++) : LenList m a -> LenList n a -> LenList (m + n) a
MkLenList xs ++ MkLenList ys =
  rewrite concatLen xs ys in MkLenList (xs ++ ys)
```

同じことは文字列についてはできません。文字列を長さと対にすることが便利
であるような利用法（例えば構文解析中に文字列が厳密に短かくなっていき、
したがって結局は全体が消費されることを確かめたいなど）がありますが、
Idrisはこうしたことを正しくするための助けには入れません。以下の補題を
安全な方法で実装する方法はなく、故に証明することもできません。

```idris
0 concatLenStr : (a,b : String) -> length a + length b = length (a ++ b)
```

<!-- markdownlint-disable MD026 -->
### 信じてくれ！
<!-- markdownlint-enable MD026 -->

`concatLenStr`を実装するには全ての安全性を抛ち、型強制という10トン破砕
球を使わねばなりません。それが`believe_me`です。この原始関数があれば自
由にあらゆる型の値を別のあらゆる型の値に強制することができます。言わず
もがな、何をしているのかを*本当に*分かっているときにのみ安全です。

```idris
concatLenStr a b = believe_me $ Refl {x = length a + length b}
```

`{x = length a + length b}`にある変数`x`への明示的な代入は必要です。
なぜならそうでないとIdrisは*未解決の虫食い*について不平を言うからです。
`Refl`構築子中の変数`x`の型を推論できないのです。
何にせよ結果を`believe_me`に渡しているので、ここではどんな型を`x`に代入することもできますが、等式の両端のうち1つを代入するのが意図を明確にする上で良い習慣であると考えます。

原始型の複雑度が高くなればなるほど、それが満たすほとんどの基礎的な性質
さえ推定するのが危険になります。例えば浮動小数点数の加算が結合的である
という思い違いを起こすかもしれません。

```idris
0 doubleAddAssoc : (x,y,z : Double) -> x + (y + z) = (x + y) + z
doubleAddAssoc x y z = believe_me $ Refl {x = x + (y + z)}
```

ああ、そのことだが。あれは嘘だ。で、嘘をつくと`Void`へまっしぐら。

```idris
Tiny : Double
Tiny = 0.0000000000000001

One : Double
One = 1.0

wrong : (0 _ : 1.0000000000000002 = 1.0) -> Void
wrong Refl impossible

boom : Void
boom = wrong (doubleAddAssoc One Tiny Tiny)
```

上のコードで起こっていることは次の通りです。`doubleAddAssoc`を呼び出す
と`One + (Tiny + Tiny)`が`(One + Tiny) + Tiny`に等しいという証明を返し
ます。しかし`One + (Tiny + Tiny)`は`1.0000000000000002`に等しいのです
が、`(One + Tiny) + Tiny`は`1.0`に等しいのです。したがって（誤った）証
明を`wrong`に渡せてしまい、正しい型ではあるので、そこから`Void`の証明
に至ったというわけです。

## 文字列を取り回す

*base*のモジュール`Data.String`は文字列を取り回す関数を豊富に取り揃え
ています。これら全てはコンパイラに組込まれている以下の原始的な操作を土
台としています。

* `prim__strLength`: 文字列長を返す。
* `prim__strHead`: 文字列から最初の文字を取り出す。
* `prim__strTail`: 文字列から最初の文字を除く。
* `prim__strCons`: 文字を文字列に前置する。
* `prim__strAppend`: 2つの文字列を結合する。
* `prim__strIndex`: 文字列から与えられた位置での文字を取り出す。
* `prim__strSubstr`: 与えられた位置間の部分文字列を取り出す。

言わずもがなですが、これらの関数全てが全域というわけではありません。し
たがってIdrisは不当な呼び出しがコンパイル時に簡約されないことを確かめ
ます。そうしなければコンパイラがクラッシュするからです。しかしもし対応
するプログラムをコンパイルし走らせることで部分的な原始関数の評価を強制
すれば、このプログラムはエラーと共にクラッシュします。

```repl
Tutorial.Prim> prim__strTail ""
prim__strTail ""
Tutorial.Prim> :exec putStrLn (prim__strTail "")
Exception in substring: 1 and 0 are not valid start/end indices for ""
```

`prim__strTail ""`はREPLでは簡約されず、一方で同じ式をコンパイルしてプ
ログラムを実行すると実行時例外になることに注目してください。しかし
`prim__strTail`の妥当な呼び出しは正常に簡約されます。

```idris
tailExample : prim__strTail "foo" = "oo"
tailExample = Refl
```

### 詰め込んだり荷解きしたり

文字列を取り回す上で最重要の関数のうち2つは`unpack`と`pack`です。これ
らは文字列を文字のリストに変換したりその逆をしたりします。これにより文
字のリスト上を巡回したり畳み込んだりすることにより多くの文字列操作を便
利に実装できます。これは最も効率のよいことであるとは限りませんが、とて
も大量のテキストを扱う予定があるのでなければそれなりに効率良く動きます。

### 文字列内挿

Idrisでは丸括弧で包むことで任意の文字列式を文字列表記内に含められます。
開括弧はバックスラッシュでエスケープされていなくてはなりません。
例えば以下です。

```idris
interpEx1 : Bits64 -> Bits64 -> String
interpEx1 x y = "\{show x} + \{show y} = \{show $ x + y}"
```

これは異なる型の値から複雑な文字列を組み合わせるおに大変便利な方法です。
加えてインターフェース`Interpolation`もあります。
これにより最初に文字列に変換することなく内挿される文字列で値を使えます。

```idris
data Element = H | He | C | N | O | F | Ne

Formula : Type
Formula = List (Element,Nat)

Interpolation Element where
  interpolate H  = "H"
  interpolate He = "He"
  interpolate C  = "C"
  interpolate N  = "N"
  interpolate O  = "O"
  interpolate F  = "F"
  interpolate Ne = "Ne"

Interpolation (Element,Nat) where
  interpolate (_, 0) = ""
  interpolate (x, 1) = "\{x}"
  interpolate (x, k) = "\{x}\{show k}"

Interpolation Formula where
  interpolate = foldMap interpolate

ethanol : String
ethanol = "The formulat of ethanol is: \{[(C,2),(H,6),(O, the Nat 1)]}"
```

### 素地や複数行の文字列表記

文字列表記では引用符やバックスラッシュや改行文字のような特定の文字をエ
スケープせねばなりません。例えば次の通りです。

```idris
escapeExample : String
escapeExample = "A quote: \". \nThis is on a new line.\nA backslash: \\"
```

Idrisでは素地文字列表記を入力することができます。この表記では引用符文
字を同数のハッシュ文字で前後を包むことにより引用符やバックスラッシュを
エスケープする必要はありません。

```idris
rawExample : String
rawExample = #"A quote: ". A blackslash: \"#

rawExample2 : String
rawExample2 = ##"A quote: ". A blackslash: \"##
```

素地文字列表記でも文字列内挿を使うことはできますが、
開中括弧には、バックスラッシュと、
文字列表記の開始終了に使われるのと同数のハッシュが前置されていなくてはなりません。

```idris
rawInterpolExample : String
rawInterpolExample = ##"An interpolated "string": \##{rawExample}"##
```

最後にIdrisでは複数行文字列を簡便に書くことができます。
素地複数行文字列表記が欲しい場合は前後にハッシュを付けることができ、
文字列内挿と組み合わせることもできます。
複数行表記は3つの引用符文字で開閉されます。
閉3引用符を字下げすることで全体の複数行表記を字下げすることができます。
字下げに使われた空白は結果の文字列には表れません。
例えば以下です。

```idris
multiline1 : String
multiline1 = """
  And I raise my head and stare
  Into the eyes of a stranger
  I've always known that the mirror never lies
  People always turn away
  From the eyes of a stranger
  Afraid to see what hides behind the stare
  """

multiline2 : String
multiline2 = #"""
  An example for a simple expression:
  "foo" ++ "bar".
  This is reduced to "\#{"foo" ++ "bar"}".
  """#
```

ぜひREPLで例にある文字列を見て、
使用した構文と内挿や素地文字列表記の効果を比べてみてください。

### 演習 その1

これらの演習では文字列を取り込んで変換する沢山の便利関数を実装することになります。
ここでは期待される型を与えていません。
なぜなら自力で思い付くこととしているからです。

1. 文字列用の`map`、`filter`、`mapMaybe`に似た関数を実装してください。
   これらの出力型は常に文字列です。

2. 文字列用の`foldl`、`foldMap`に似た関数を実装してください。

3. 文字列用の`traverse`に似た関数を実装してください。
   出力型は包まれた文字列になります。

4. 文字列に束縛演算子を実装してください。
   出力型もまた文字列になります。

## 整数

本章の始めに一覧になっていたように、
Idrisは任意精度符号付き整数型である`Integer`と共に、
さまざまな固定精度の符号付きないし符号無し整数型を提供しています。
これら全ては以下の原始関数から来ています。
（っこでは`Bits8`を例に取ります。）

* `prim__add_Bits8`: 整数の加算。
* `prim__sub_Bits8`: 整数の減算。
* `prim__mul_Bits8`: 整数の乗算。
* `prim__div_Bits8`: 整数の除算。
* `prim__mod_Bits8`: 剰余関数。
* `prim__shl_Bits8`: ビットの左シフト。
* `prim__shr_Bits8`: ビットの右シフト。
* `prim__and_Bits8`: ビットの*and*。
* `prim__or_Bits8`: ビットの*or*。
* `prim__xor_Bits8`: ビットの*xor*。

よくあるのは、インターフェース`Num`由来の演算子を通じて加算や乗算のための関数を、
インターフェース`Neg`を通じて減算のための関数を、
そしてインターフェース`Integral`を通じて除算（`div`と`mod`）のための関数を、
それぞれ使うというものです。
ビット演算はインターフェース`Data.Bits.Bits`と`Data.Bits.FiniteBits`インターフェースを通じて使うことができます。

全ての整数型について、数値演算用の以下の法則が満たされているとされます。
（`x`、`y`、`z`は同じ原始整数型の任意の値です。）

* `x + y = y + x`: 加算は可換です。
* `x + (y + z) = (x + y) + z`: 加算は結合的です。
* `x + 0 = x`: ゼロは加算の中立要素です。
* `x - x = x + (-x) = 0`: `-x`は`x`の加法的逆数です。
* `x * y = y * x`: 乗算は可換です。
* `x * (y * z) = (x * y) * z`: 乗算は結合的です。
* `x * 1 = x`: 1は乗算の中立要素です。
* `x * (y + z) = x * y + x * z`: 分配法則を満たします。
* ``y * (x `div` y) + (x `mod` y) = x``（ただし`y /= 0`）

注意していただきたいのは、公式に対応されているバックエンドでは`mod`の計算に*ユークリッドモジュロ*が使われているという点です。
`y /= 0`のとき、``x `mod` y``は常に`abs y`より厳密に小さい非負値であり、
上に与えられた法則が満たされるのです。
`x`や`y`が負数であれば他の多くの言語でどうなっているかはさまざまですが、
もっともな説明がこちらの[記事](https://www.microsoft.com/en-us/research/publication/division-and-modulus-for-computer-scientists/)にあります。

### 符号無し整数

符号無し固定精度整数型（`Bits8`、`Bits16`、`Bits32`、`Bits64`）には全ての整数インターフェース（`Num`、`Neg`、`Integral`）と2つのビット演算用のインターフェース（`Bits`と`FiniteBits`）が付属しています。
`div`と`mod`以外の全ての関数は全域です。
オーバーフローは剰余`2^bitwise`を計算することによって取り扱われます。
例えば`Bits8`については全ての操作で結果を256を法とするよう計算されます。

```repl
Main> the Bits8 255 + 1
0
Main> the Bits8 255 + 255
254
Main> the Bits8 128 * 2 + 7
7
Main> the Bits8 12 - 13
255
```

### 符号付き整数

符号無し整数型と同様、符号付き固定精度整数型（`Int8`、`Int16`、`Int32`、`Int64`）には全ての整数インターフェースと2つのビット演算用インターフェース（`Bits`と`FiniteBits`）が付属しています。
オーバーフローは剰余`2^bitwise`を計算しそれでも結果が範囲外であれば小さいほうの境界（負数）を加えることで取り扱われます。
例えば`Int8`については、全ての操作は結果を256の剰余で取り、結果がそれでも範囲外なら128を引きます。

```repl
Main> the Int8 2 * 127
-2
Main> the Int8 3 * 127
125
```

### ビット演算

モジュール`Data.Bits`は整数型に対してビット演算を行うインターフェースを輸出しています。
ビット計算が初めての読者にその概念を説明するために、符号無し8ビット数 (`Bits8`) について数例お見せしようと思います。
なお、これについては符号付きの場合よりも遥かに符号無し整数型の場合のほうが把握が簡単です。
符号付きのものは数の*符号*についての情報をビット様式に含めなくてはならず、Idrisにおける符号付き整数は[2の補数](https://en.wikipedia.org/wiki/Two%27s_complement)を使っているものとされます。
2の補数についてはここでは詳細に踏み込みません。

符号なし8ビット2進数は内部的に8つのビット（値は0か1）の並びによって表され、
それぞれが2の累乗に対応します。
例えば数23 (= 16 + 4 + 2 + 1) は`0001 0111`として表されます。

```repl
2進数での23：   0  0  0  1    0  1  1  1

ビット数：      7  6  5  4    3  2  1  0
10進値：      128 64 32 16    8  4  2  1
```

関数`testBit`を使って与えられた位置にあるビットが点いているかどうかを確かめられます。

```repl
Tutorial.Prim> testBit (the Bits8 23) 0
True
Tutorial.Prim> testBit (the Bits8 23) 1
True
Tutorial.Prim> testBit (the Bits8 23) 3
False
```

同様に、関数`setBit`と`clearBit`を使って特定の位置のビットを点けたり消したりできます。

```repl
Tutorial.Prim> setBit (the Bits8 23) 3
31
Tutorial.Prim> clearBit (the Bits8 23) 2
19
```

整数値に真偽値演算をするためには関数`xor`（ビットの*排他的論理和*）と同様に
演算子`(.&.)`（ビットの*論理積*）や`(.|.)`（ビットの*論理和*）もあります。
例えば`x .&. y`の各ビット集合はちょうど`x`と`y`両方のビットが点いているところが点きます。
一方で`x .|. y`は`x`ないし`y`（あるいは両方）が点いている全てのビットが点きます。
そして``x `xor` y``は2つの値のうちちょうど1つが点いているビットが点きます。

```repl
23を2進数で：          0  0  0  1    0  1  1  1
11を2進数で：          0  0  0  0    1  0  1  1

23 .&. 11を2進数で：   0  0  0  0    0  0  1  1
23 .|. 11を2進数で：   0  0  0  1    1  1  1  1
23 `xor` 11を2進数で： 0  0  0  1    1  1  0  0
```

そして以下はREPLでの例です。

```repl
Tutorial.Prim> the Bits8 23 .&. 11
3
Tutorial.Prim> the Bits8 23 .|. 11
31
Tutorial.Prim> the Bits8 23 `xor` 11
28
```

最後に、関数`shiftR`と`shiftL`を使うことにより、全てのビットを特定の数だけそれぞれ左右にシフトすることができます（溢れたビットは単に捨てられます）。
したがって左シフトは2の累乗による乗算として、
右シフトは2の累乗による除算として、それぞれ見ることができます。

```repl
22 in binary:            0  0  0  1    0  1  1  0

22 `shiftL` 2 in binary: 0  1  0  1    1  0  0  0
22 `shiftR` 1 in binary: 0  0  0  0    1  0  1  1
```

そしてREPLで次のようにします。

```repl
Tutorial.Prim> the Bits8 22 `shiftL` 2
88
Tutorial.Prim> the Bits8 22 `shiftR` 1
11
```

ビット演算は専門的なコードやある程度高い効率性のアプリケーションでよく使われます。
プログラマとしてはそれらの存在と仕組みを知っておかねばなりません。

### 整数表記

ここまで所与の型用に整数表記が使えるようにするために常に`Num`の実装が必要でした。
しかし実は`Integer`を問題の型に変換する関数を実装しさえすればよいのです。
最後の節で見ていくように、そのような関数は妥当な表記として許される値を制限しさえできます。

例えば化学分子の電荷を表現するデータ型を定義したいとします。
そのような値は正にも負にもなりえ、（理論上）ほぼ任意の大きさを取りえます。

```idris
record Charge where
  constructor MkCharge
  value : Integer
```

電荷を加算することは理に適っていますが、乗算はそうではありません。
したがって`Monoid`の実装を持ちますが、`Num`は持ちません。
それでもコンパイル時に定数の電荷を使う際に整数表記の便宜を得たいのです。
以下はこれをする方法です。

```idris
fromInteger : Integer -> Charge
fromInteger = MkCharge

Semigroup Charge where
  x <+> y = MkCharge $ x.value + y.value

Monoid Charge where
  neutral = 0
```

#### 別の基数

よく知られた10進表記に加えて、2進、8進、16進表現の整数表記を使うこともできます。
これらは2進、8進、16進それぞれについて、
ゼロと続く`b`、`o`、`x`で前置されていなくてはなりません。

```repl
Tutorial.Prim> 0b1101
13
Tutorial.Prim> 0o773
507
Tutorial.Prim> 0xffa2
65442
```

### 演習 その2

1. 整数値用の梱包レコードを定義し`(<+>)`が`(.&.)`に対応するように`Monoid`を実装してください。

   手掛かり：インターフェース`Bits`で手に入る関数を眺めて、
   中立の要素として相応しい値を見付けてください。

2. 整数値用の梱包レコードを定義し`(<+>)`が`(.|.)`に対応するように`Monoid`を実装してください。

3. ビット演算を使って次の関数を実装してください。
   この関数は型が`Bits64`の与えられた値が偶数かどうかを検査します。

4. 型`Bits64`の値を2進表現の文字列へ変換してください。

5. 型`Bits64`の値を16進数表現の文字列へ変換してください。

   手掛かり：`shiftR`と`(.&. 15)`を使い、
   後続する4ビットの集まりにアクセスしてください。

## 精錬された原始型

何らかの文脈ではある型の全ての値を許したくないことはよくあります。
例えば任意のUTF-8文字（いくつかは印字可能ですらありません）の並びとしての`String`はほとんどの場合一般化されすぎています。
したがって大抵は不正な値を早めに排除することが勧められます。
これは値と消去される妥当性の証明と対にすることでできます。

流麗な述語の書き方を学んできましたが、
これにより関数が全域であることを証明することができ、
そこから……理想的な場合では……他の関連する述語を導出することもできます。
しかしながら、述語を原始型に定義するとき、
述語を操れるだけの原始的な公理（ほぼ`believe_me`を使って実装されます）の集合を思い付かない限り、こうしたことはそれ単体ではそこそこの悪夢です。

### 用例：ASCII文字列

文字列のエンコーディングは難しい話題なので、多くの低水準な処理では最初のうちはほとんどの文字を排除するのは理に適っています。
したがって、ここでのアプリケーションで受け付ける文字列はASCII文字からのみ構成されることにしたいと思います。

```idris
isAsciiChar : Char -> Bool
isAsciiChar c = ord c <= 127

isAsciiString : String -> Bool
isAsciiString = all isAsciiChar . unpack
```

これで文字列値を検証の消去される証明と対にすることで*精錬*できます。

```idris
record Ascii where
  constructor MkAscii
  value : String
  0 prf : isAsciiString value === True
```

これで、実行時ないしコンパイル時に最初に包まれる文字列を検証することなく型`Ascii`の値を作ることが*不可能*になりました。
これによって最早コンパイル時に型`Ascii`の値に安全に文字列を包むことはかなり簡単です。

```idris
hello : Ascii
hello = MkAscii "Hello World!" Refl
```

そしてさらに、安全性の快適さを犠牲にすることなく、これに文字列表記を使うこともまた遥かにより便利にすることでしょう。
そうするためと言って、インターフェース`FromString`を使うことはできません。
というのはその関数`fromString`は*いかなる*文字列をも変換できるようにしなければならず、不正なものでさえそうなのです。
しかしながら実は文字列表記に対応するには`FromString`の実装は必要ではなく、
これはちょうど整数表記に対応するために`Num`の実装が必要ではないようなものです。
本当に必要なことは`fromString`という名前の関数なのです。
さて、文字列表記が脱糖されると`fromString`の呼出しとその引数として文字列値が与えられたものに変換されます。
例えば表記`"Hello"`は`fromString "Hello"`に脱糖されます。
これは型検査と（自動）暗黙値を埋める前に起こります。
したがって妥当性の証明としての消去される自動暗黙引数を持つ自前の`fromString`関数を定義することは全くもって大丈夫なのです。

```idris
fromString : (s : String) -> {auto 0 prf : isAsciiString s === True} -> Ascii
fromString s = MkAscii s prf
```

これを使えば直接型`Ascii`の値であるようなものにについて（妥当な）文字列表記を使うことができます。

```idris
hello2 : Ascii
hello2 = "Hello World!"
```

不明な源からの文字列から型`Ascii`の値を実行時に作るためには、何らかの類の失敗型を返す精錬関数を使うことができます。

```idris
test : (b : Bool) -> Dec (b === True)
test True  = Yes Refl
test False = No absurd

ascii : String -> Maybe Ascii
ascii x = case test (isAsciiString x) of
  Yes prf   => Just $ MkAscii x prf
  No contra => Nothing
```

#### 真偽値証明の欠点

多くの用途で、上でASCII文字列について記述したことを使えば大きく前進で
きます。しかし、この手法の欠点の1つは手に証明を手にしていてもいかなる
計算も安全には行えないということです。

例えば2つのASCII文字列を結合するのは全くもって大丈夫だと知っているでしょうが、
このことをIdrisに説得するためには`believe_me`を使わねばならないでしょう。
なぜなら以下の補題を証明することが決してできないからです。

```idris
0 allAppend :  (f : Char -> Bool)
            -> (s1,s2 : String)
            -> (p1 : all f (unpack s1) === True)
            -> (p2 : all f (unpack s2) === True)
            -> all f (unpack (s1 ++ s2)) === True
allAppend f s1 s2 p1 p2 = believe_me $ Refl {x = True}

namespace Ascii
  export
  (++) : Ascii -> Ascii -> Ascii
  MkAscii s1 p1 ++ MkAscii s2 p2 =
    MkAscii (s1 ++ s2) (allAppend isAsciiChar s1 s2 p1 p2)
```

同じことが与えられた文字列から部分文字列を取り出す全ての操作について言えます。
それぞれの規則について`believe_me`を使って実装せねばなりません。
したがって精錬された原始型を便利に扱うための理に適った公理の集合を見付けることはしばしば挑戦的となり、
そのような公理が必要であるかすらも直面している用例に大きく依存するのです。

### 用例：消毒済みHTML

登録済みの利用者の間で科学的な議論をするための単純なWebアプリケーションを書いているとします。
話を単純にするためにここでは書式化されていない入力テキストのみを考えます。
利用者はテキストフィールドに任意のテキストを書くことができ、エンターを打つと文言が他の全ての登録済み利用者に表示されます。

ここで利用者が以下の文言を入力することにしたとしましょう。

```html
<script>alert("Hello World!")</script>
```

おっと、（かなり）まずいことになるところでした。
尚もこれが起こることを防ぐ対策を講じなければ、
Webページ中に全く意図しないJavaScriptプログラムが埋め込まれるかもしれません！
ここで記述したことは[クロスサイトスクリプティング](https://en.wikipedia.org/wiki/Cross-site_scripting)と呼ばれるセキュリティ脆弱性でよく知られています。
Webページの利用者にテキストフィールドへ悪意のあるJavaScriptコードを入力することを許すことで、ページのHTML構造にそれが含まれてしまい、他の利用者に表示されたときに実行されてしまうのです。

確かなことにしたいのは、これがwebページで起こりえないようにすることです。
この攻撃から身を守るために、例えば`'<'`や`'>'`のような文字（これでは充分ではないかもしれません！）を全く許さないようにすることもできますが、もしこの会話サービスがプログラマーを対象しているならば、度を越した制限となるでしょう。
代替案は特定の文字をページに描画する前にエスケープすることです。

```idris
escape : String -> String
escape = concat . map esc . unpack
  where esc : Char -> String
        esc '<'  = "&lt;"
        esc '>'  = "&gt;"
        esc '"'  = "&quot;"
        esc '&'  = "&amp;"
        esc '\'' = "&apos;"
        esc c    = singleton c
```

ここでやりたいことは文字列とその文字列が適切にエスケープされているという証明と共に保管することです。
これは存在量化の別の形式です。
「ここに文字列があり、ある別の文字列が存在する。
後者の文字列を`escape`に渡すと今ある前者の文字列に至る。」
以下はこれを符号化する方法です。

```idris
record Escaped where
  constructor MkEscaped
  value    : String
  0 origin : String
  0 prf    : escape origin === value
```

これでwebページに出所不明の文字列を埋め込むときはいつでも、型`Escaped`の値を要求し、最早クロスサイトスクリプティング攻撃に対して脆弱でないことの大変強力な保証が得られました。
もっといいことに、コンパイル時に知られている文字列表記を、最初にエスケープする必要なく、安全に埋め込むこともできています。

```idris
namespace Escaped
  export
  fromString : (s : String) -> {auto 0 prf : escape s === s} -> Escaped
  fromString s = MkEscaped s s prf

escaped : Escaped
escaped = "Hello World!"
```

### 演習 その3

この大部の演習では原始型における述語を扱う小さなライブラリを構築していきます。
以下の目標を念頭に置きたいと思います。

* 述語を組み合わせるのに命題論理につきものの操作を使いたいです。
  つまり、否定、連言（論理の*and*）、そして宣言（論理*or*）です。
* 全ての述語は実行時に消去されるべきです。
  原始的な数について何らかの証明をするとき、莫大な検証のための証明を持ち回ることがないようにしたいです。
* 述語における計算は実行時に現れないようにするべきです。
  （ただし`decide`は例外です。後述します。）
* 述語における再帰計算は、`decide`の実装で使われているときは、末尾再帰であるべきです。
  これを達成するのは大変かもしれません。
  所与の問題について末尾再帰の解法を見付けられなければ、代わりに最も自然に感じる方法を使ってください。

効率性についての補足。
述語について計算を走らせられるようにするために、できるときはいつでも、そしてできるだけ早く、原始値を代数型データ型に変換したいです。
符号無し整数は`cast`を使って`Nat`に変換されるでしょうし、文字列は`unpack`を使って`List Char`に変換されるでしょう。
これによりほとんどの時間を`Nat`と`List`における証明の作業に割くことができ、そのような証明は`believe_me`やその他のズルに訴えることなく実装できます。
しかしながら、原始型が代数的データ型に優越する1点は、効率性が遥かによいことがよくあるということです。
とりわけ整数型と`Nat`を比較する際は致命的です。
自然数における操作はしばしば`O(n)`時間計算量です。
ただし`n`は対象の自然数の数です。
例えば多くの操作は高速な定数時間 (`O(1)`) で走ります。
幸運なことにIdrisコンパイラは対応する`Integer`の操作を実行時に使うことで自然数における多くの関数を最適化します。
これには、コンパイル時には自然数について何かしらの証明を適切に導出できつつ、実行時には速い整数の操作を享受できるという利点があります。
しかしながら、`Nat`における操作は*コンパイル時に*`O(n)`時間計算量で走るのです。
したがって、大きな自然数を扱う証明は劇的にコンパイラを低速にさせます。
この回避方法はこの節の演習の末尾で議論します。

前置きはこのくらいにして始めましょう！
始めるにあたって、以下のユーティリティが与えられています。

```idris
-- `Dec`のようですが、消去された証明を持ちます。
-- 構築子`Yes0`と`No0`はコンパイラによって定数`0`と`1`に変換されます！
data Dec0 : (prop : Type) -> Type where
  Yes0 : (0 prf : prop) -> Dec0 prop
  No0  : (0 contra : prop -> Void) -> Dec0 prop

-- 1つ以上の引数を持つインターフェース（この例では`a`と`p`）について、
-- 時に1つの引数が他方を知ることによって決定できることがあります。
-- 例えば`p`が何であるかを知っているとき、
-- `a`が何であるかもほぼ確実に知っています。
-- したがって`Decidable`における証明検索が`p`に基づくことを、
-- 垂直棒の後に`p`を挙げること、つまり`| p`によって指定しています。
-- これは述語についての章で見たように`[search p]`で
-- データ型の検索引数を指定するようなものです。
-- ここで見たように単一の検索引数を指定することにより劇的に型推論の助けになります。
interface Decidable (0 a : Type) (0 p : a -> Type) | p where
  decide : (v : a) -> Dec0 (p v)

-- しばしばIdrisの型推論を助けるために`p`を明示的に渡す必要があります。
-- そのような場合、`decide {p = pred}`の代わりに
-- `decideOn pred`を使うとより便利です。
decideOn : (0 p : a -> Type) -> Decidable a p => (v : a) -> Dec0 (p v)
decideOn _ = decide

-- 真偽値関数を使ってのみ合理的に実装される原始的な述語もあります。
-- このユーティリティはそのような証明の決定可能性を補助します。
test0 : (b : Bool) -> Dec0 (b === True)
test0 True  = Yes0 Refl
test0 False = No0 absurd
```

またコンパイル時に決定可能な計算を走らせもしたいのです。
これは帰納型に直接証明検索を走らせるより遥かに効率的なことがよくあります。
したがって`Dec0`の値が実際には`Yes0`であることをを証言する述語と2つの補助関数を作り出します。

```idris
data IsYes0 : (d : Dec0 prop) -> Type where
  ItIsYes0 : IsYes0 (Yes0 prf)

0 fromYes0 : (d : Dec0 prop) -> (0 prf : IsYes0 d) => prop
fromYes0 (Yes0 x) = x
fromYes0 (No0 contra) impossible

0 safeDecideOn :  (0 p : a -> Type)
               -> Decidable a p
               => (v : a)
               -> (0 prf : IsYes0 (decideOn p v))
               => p v
safeDecideOn p v = fromYes0 $ decideOn p v
```

最後に、ほとんどの原始型を精錬しようとしているため、時には自分達が何をしているのかがわかっているのだとIdrisを説得する大型ハンマーが必要になります。

```idris
-- `decideOn p v`が`Yes0`を返すことを確信しているときにだけ使ってくださいね。
0 unsafeDecideOn : (0 p : a -> Type) -> Decidable a p => (v : a) -> p v
unsafeDecideOn p v = case decideOn p v of
  Yes0 prf => prf
  No0  _   =>
    assert_total $ idris_crash "Unexpected refinement failure in `unsafeRefineOn`"
```

1. 透過性の証明から始めます。
   `Decidable`を`Equal v`に実装してください。

   手掛かり：制約としてはモジュール`Decidable.Equality`の`DecEq`を使い、必ず`v`が実行時に使えるようにしてください。

2. 次のように述語を否定できるようにしたいです。

   ```idris
   data Neg : (p : a -> Type) -> a -> Type where
     IsNot : {0 p : a -> Type} -> (contra : p v -> Void) -> Neg p v
   ```

   相応しい制約を使って`Neg p`に`Decidable`を実装してください。

3. 述語の連言を記述したいです。

   ```idris
   data (&&) : (p,q : a -> Type) -> a -> Type where
     Both : {0 p,q : a -> Type} -> (prf1 : p v) -> (prf2 : q v) -> (&&) p q v
   ```

   相応しい制約を使って`(p && q)`に`Decidable`を実装してください。

4. 2つの述語の選言（論理的な*or*）用の`(||)`という名前のデータ型を作り出し、相応しい制約を使って`Decidable`を実装してください。

5. 以下の命題を実装することによって[ド・モルガンの法則](https://en.wikipedia.org/wiki/De_Morgan%27s_laws)を証明してください。

   ```idris
   negOr : Neg (p || q) v -> (Neg p && Neg q) v

   andNeg : (Neg p && Neg q) v -> Neg (p || q) v

   orNeg : (Neg p || Neg q) v -> Neg (p && q) v
   ```

   ド・モルガンの最後の含意は型付けて証明するのが難しいのですが、それは型`p v`と`q v`の値を作り出す方法が必要なところ、両方ともは存在しないと判明するからです。
   以下はこれを符号化する方法です（数量子0で註釈していますが、これは消去された対偶にアクセスするのに必要です）。

   ```idris
   0 negAnd :  Decidable a p
            => Decidable a q
            => Neg (p && q) v
            -> (Neg p || Neg q) v
   ```

   `negAnd`を実装する際は消去された（暗黙の）引数に自由にアクセスできることを思い出してください。
   なぜできるかというと`negAnd`自体は消去された文脈でのみ使われているからです。

ここまででいくつかの述語を抽象的に記述したり結合したりする道具を実装しました。
これでいくつかの例を作り出すときが来ました。
最初の用例として自然数の妥当な範囲を制限することに焦点を当てます。
このためには以下のデータ型を使います。

```idris
-- Proof that m <= n
data (<=) : (m,n : Nat) -> Type where
  ZLTE : 0 <= n
  SLTE : m <= n -> S m <= S n
```

これは`Data.Nat.LTE`と似ていますが、筆者はしばしば演算子の記法がよりすっきりしているように思われます。
また以下の別称を定義して使うこともできます。

```repl
(>=) : (m,n : Nat) -> Type
m >= n = n <= m

(<) : (m,n : Nat) -> Type
m < n = S m <= n

(>) : (m,n : Nat) -> Type
m > n = n < m

LessThan : (m,n : Nat) -> Type
LessThan m = (< m)

To : (m,n : Nat) -> Type
To m = (<= m)

GreaterThan : (m,n : Nat) -> Type
GreaterThan m = (> m)

From : (m,n : Nat) -> Type
From m = (>= m)

FromTo : (lower,upper : Nat) -> Nat -> Type
FromTo l u = From l && To u

Between : (lower,upper : Nat) -> Nat -> Type
Between l u = GreaterThan l && LessThan u
```

6. `m`と`n`にパターン照合して型`m <= n`の値を作り出すのは`m`が大きな数のときにかなり非効率になります。
   これは`m`回分の計算が必要になるからです。
   しかし消去される文脈である限りは型`m <= n`の値を保つ必要はありません。
   そのような値がより効率的な計算から従うことだけを示せばよいのです。
   そうした計算は自然数の`compare`です。
   これは*Prelude*で引数へのパターン照合で実装されているものの、たとえとても大きな数であっても定数時間で走る整数の比較にコンパイラが最適化します。
   自然数用の`Prelude.(<=)`は`compare`を活用して実装されているので、こちらも効率的に走ります。

   したがって以下の2つの補題を証明する必要があります（これらの宣言で`Prelude.(<=)`と`Prim.(<=)`を混同しないようにしてください。）。

   ```idris
   0 fromLTE : (n1,n2 : Nat) -> (n1 <= n2) === True -> n1 <= n2

   0 toLTE : (n1,n2 : Nat) -> n1 <= n2 -> (n1 <= n2) === True
   ```

   どれも数量子0が付いていますが、それは単に上でお話しした別の案の計算と同じくらい非効率だからです。したがって実行時に全く使われないことに関して絶対の確信を得たいのです。

   それでは`test0`、`fromLTE`、`toLTE`を活用して`Decidable Nat (<= n)`を実装してください。同様にして`Decidable Nat (m <=)`を実装してください。これは両方の種類の述語に必要だからです。

   補足：これで`n`が実行時に使えるようになっていることとこれが正にそうなっていることを確実にする方法を明らかにしたことでしょう。

7. `(<=)`が反射率と推移律を満たすことを対応する命題を宣言して実装することによって証明してください。推移律の証明は型`(<=)`のいくつかの値を連鎖させるのに必要になるかもしれないので、これの別称となる短い演算子も定義するのは理に適っています。

8. `n > 0`から`IsSucc n`が従うことを、またの逆を証明してください。

9. `Base64`用の安全な除算と剰余関数を宣言して実装してください。これには割る数が自然数に変換したとき厳密に正であることの消去される証明を要求します。剰余関数の場合、結果が法とする数より厳密に小さいことの消去される証明を持ち回る精錬された値を返してください。

   ```idris
   safeMod :  (x,y : Bits64)
           -> (0 prf : cast y > 0)
           => Subset Bits64 (\v => cast v < cast y)
   ```

10. これまでに定義した述語と補助関数を使って型`Bits64`の値を底が`b`の数字の文字列に変換していきます。ここで`2 <= b && b <=
    16`です。そうするために以下の定義の骨組を実装してください。

    ```idris
    -- この関数には`assert_total`と`idris_crash`の助けがいくらか要ります。
    digit : (v : Bits64) -> (0 prf : cast v < 16) => Char

    record Base where
      constructor MkBase
      value : Bits64
      0 prf : FromTo 2 16 (cast value)

    base : Bits64 -> Maybe Base

    namespace Base
      public export
      fromInteger : (v : Integer) -> {auto 0 _ : IsJust (base $ cast v)} -> Base
    ```

    最後に実装で`safeDiv`と`safeMod`を使って`digits`を実装してください。
    これは挑戦的な難易度かもしれません。
    というのも型検査器を満たすために証明を手作業で変形する必要があるためです。
    再帰の過程では`assert_smaller`も必要になることでしょう。

    ```idris
    digits : Bits64 -> Base -> String
    ```

ここからは文字列に焦点を移します。受け付ける文字列を制限する最も分かりやすい2つの方法は文字集合を制限することと長さを限定することです。より応用的な精錬では文字列が特定のパターンや正規表現に照合することを要求するかもしれません。そうした場合は真偽値検査を付けたりパターンのそれぞれの部分を表現する独自データ型を使ったりすることになりそうですが、こうした話題はここでは触れません。

11. 以下の関数名で、文字における有用な述語を実装してください。

    手掛かり：`cast`を使って文字を自然数に変換し、`(=)`と`InRange`を使って文字の範囲を指定し、そして`(||)`を使って文字の範囲を結合してください。

    ```idris
    -- 文字 <= 127
    IsAscii : Char -> Type

    -- 文字 <= 255
    IsLatin : Char -> Type

    -- 文字は ['A','Z'] の範囲内
    IsUpper : Char -> Type

    -- 文字は ['a','z'] の範囲内
    IsLower : Char -> Type

    -- 大小文字
    IsAlpha : Char -> Type

    -- ['0','9'] の範囲にある文字
    IsDigit : Char -> Type

    -- 数字かアルファベットにある文字
    IsAlphaNum : Char -> Type

    -- 範囲 [0,31] または [127,159] の文字
    IsControl : Char -> Type

    -- 制御文字ではないASCII文字
    IsPlainAscii : Char -> Type

    -- 制御文字ではないラテン文字
    IsPlainLatin : Char -> Type
    ```

12. 原始型における述語へ向けてのこのより組立方式の手法の利点は、述語における計算を安全に走らせて`Nat`や`List`のような帰納型についての既存の証明からの強力な保証を得られることです。以下はそのような計算と変換の例であり、全て誤魔化すことなく実装できています。

    ```idris
    0 plainToAscii : IsPlainAscii c -> IsAscii c

    0 digitToAlphaNum : IsDigit c -> IsAlphaNum c

    0 alphaToAlphaNum : IsAlpha c -> IsAlphaNum c

    0 lowerToAlpha : IsLower c -> IsAlpha c

    0 upperToAlpha : IsUpper c -> IsAlpha c

    0 lowerToAlphaNum : IsLower c -> IsAlphaNum c

    0 upperToAlphaNum : IsUpper c -> IsAlphaNum c
    ```

    以下 (`asciiToLatin`) はもっと注意が要ります。`(<=)`が推移的であることを思い出しましょう。ところが推移律の証明の呼び出しでは`%search`を使った直接的な証明検索を適用することは決してできません。なぜなら検索深度が小さすぎるからです。検索深度を増すことはできますが、代わりに`safeDecideOn`を使うのが遥かに効率的です。

    ```idris
    0 asciiToLatin : IsAscii c -> IsLatin c

    0 plainAsciiToPlainLatin : IsPlainAscii c -> IsPlainLatin c
    ```

文字列における述語に完全に集中する前に、まずはリストを押さえなければなりません。というのもよく文字列を文字のリストとして扱うことになるからです。

13. `Head`に`Decidable`を実装してください：

    ```idris
    data Head : (p : a -> Type) -> List a -> Type where
      AtHead : {0 p : a -> Type} -> (0 prf : p v) -> Head p (v :: vs)
    ```

14. `Length`に`Decidable`を実装してください：

    ```idris
    data Length : (p : Nat -> Type) -> List a -> Type where
      HasLength :  {0 p : Nat -> Type}
                -> (0 prf : p (List.length vs))
                -> Length p vs
    ```

15. 以下の述語は値のリストの中にある全ての値が与えられた述語を満足するという証明です。これを使って文字列中の妥当な文字集合を制限していきます。

    ```idris
    data All : (p : a -> Type) -> (as : List a) -> Type where
      Nil  : All p []
      (::) :  {0 p : a -> Type}
           -> (0 h : p v)
           -> (0 t : All p vs)
           -> All p (v :: vs)
    ```

    `All`に`Decidable`を実装してください。

    真の挑戦として、`decide`の実装を末尾再帰にしてみてください。これはJavaScriptバックエンドにおける現実世界のアプリケーションでは重要になってきます。そのようなアプリケーションでは実行時にスタックオーバーフローすることなく何千もの文字からなる文字列を精錬したいことがあるかもしれません。末尾再帰の実装を引き出すためには、`SnocList`中の全ての要素について述語が満たされていることを証言する`AllSnoc`データ型が追加で必要になるでしょう。

16. ついにここまで辿り着きました。Idrisの識別子はアルファベット文字の並びで、下線文字 (`_`)
    で区切られていてもよいものです。加えて全ての識別子は文字始まりでなければなりません。この仕様があるとき、述語`IdentChar`を実装してください。この述語から識別子用の新しい梱包型を定義することができます。

    ```idris
    0 IdentChars : List Char -> Type

    record Identifier where
      constructor MkIdentifier
      value : String
      0 prf : IdentChars (unpack value)
    ```

    実行時に出所不明な文字列を変換するためのファクトリーメソッド`identifier`を実装してください。

    ```idris
    identifier : String -> Maybe Identifier
    ```

    加えて、`Identifier`用に`fromString`を実装し、以下が妥当な識別子であることを検証してください。

    ```idris
    testIdent : Identifier
    testIdent = "fooBar_123"
    ```

結びの言葉：原始型について物事を証明することは挑戦的になりえます。どんな公理を使うか決めるときもそうですし、実行時とコンパイル時とで効率良く動作するようにしようとするときもそうです。筆者はこうした問題に対処するためのライブラリの作成を試みています。まだ未完ですが[こちら](https://github.com/stefan-hoeck/idris2-prim)から垣間見ることができます。

<!-- vi: filetype=idris2:syntax=markdown
-->
