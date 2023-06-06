# インターフェース

関数オーバーロード - つまり同名異実装な関数定義 - は多くのプログラミング言語で見られる概念です。
Idrisには関数のオーバーロードが備わっています。
つまり、同名の2つの関数は異なるモジュールや名前空間で定義でき、Idrisは型をもとに曖昧さを解消しようとします。
例はこちら。

```idris
module Tutorial.Interfaces

%default total

namespace Bool
  export
  size : Bool -> Integer
  size True  = 1
  size False = 0

namespace Integer
  export
  size : Integer -> Integer
  size = id

namespace List
  export
  size : List a -> Integer
  size = cast . length
```

ここでは`size`という名前の相異なる関数を名前空間で個別に定義しました。
これらの曖昧さを解消するにはそれぞれの名前空間を前置すればよいです。

```repl
Tutorial.Interfaces> :t Bool.size
Tutorial.Interfaces.Bool.size : Bool -> Integer
```

しかし、大抵は必要ありません。

```idris
mean : List Integer -> Integer
mean xs = sum xs `div` size xs
```

見ての通りIdrisは相異なる`size`関数の曖昧さを解消できていることがわかります。
`xs`は型`List Integer`であり、この型は`List a`にのみ統合できるので、`List
a`が引数の型である`List.size`が選ばれます。

## インターフェースの基本

関数オーバーロードは上述したようにいい感じに動くものの、こうした関数オーバーロードの形式だと沢山のコードの重複に繋がるような用例があります。

例として、関数`cmp`を考えてみましょう（*compare*を縮めたもので、既に*Prelude*から公開されています）。
この関数は型`String`の値の序列を表現するものとします。

```idris
cmp : String -> String -> Ordering
```

似たような関数は沢山の他のデータ型についても欲しいです。
これだけだったら関数オーバーロードでいいですが、`cmp`の機能性ははそれだけに留まりません。
この関数があれば`greaterThan`, `lessThan`, `minimum`, `maximum`やその他諸々の関数を導出できます。

```idris
lessThan' : String -> String -> Bool
lessThan' s1 s2 = LT == cmp s1 s2

greaterThan' : String -> String -> Bool
greaterThan' s1 s2 = GT == cmp s1 s2

minimum' : String -> String -> String
minimum' s1 s2 =
  case cmp s1 s2 of
    LT => s1
    _  => s2

maximum' : String -> String -> String
maximum' s1 s2 =
  case cmp s1 s2 of
    GT => s1
    _  => s2
```

これら全てを`cmp`関数を使って他の型について実装し直さなくてはなりません。
それにこれらの実装は、全てではないにしても、上に書いたものと同じになります。
そうなるとコードの重複が沢山出てきます。

1つの方法として高階関数を使うという手があります。
例えば、関数`minimumBy`を定義するとしましょう。
この関数は最初の引数に比較関数を取り、残りの2つの引数のうち、より小さいほうを返します。

```idris
minimumBy : (a -> a -> Ordering) -> a -> a -> a
minimumBy f a1 a2 =
  case f a1 a2 of
    LT => a1
    _  => a2
```

この解決策は高階関数があればコードの重複を減らせることの傍証になっています。
しかしながら、いつも比較関数を持ち回らなければいけないのは億劫です。
この例での比較関数のようなものをIdris自ら思い出せるようになってくれるといいですね。

インターフェースはまさにこの問題を解消するものです。
こちらが例です。

```idris
interface Comp a where
  comp : a -> a -> Ordering

implementation Comp Bits8 where
  comp = compare

implementation Comp Bits16 where
  comp = compare
```

上記のコードは*インターフェース*`Comp`を定義し、
型`a`の2つの値の序列を計算するための関数`comp`を提供しています。
これにさらにこのインターフェースについての型`Bits8`と`Bits16`のための2つの*実装*が続きます。
ただし`implementation`キーワードはあってもなくてもよいです。

`Bits8`と`Bits16`のための`comp`の実装では両方とも関数`compare`が使われています。
この関数は*Prelude*の似たようなインターフェースである`Ord`の一部です。

次に`comp`の型をREPLで見てみます。

```repl
Tutorial.Interfaces> :t comp
Tutorial.Interfaces.comp : Comp a => a -> a -> Ordering
```

`comp`の型処方の興味深い部分は最初の引数`Comp a =>`です。
ここで`Comp`は型変数`a`の*制約*です。
この処方は、「あらゆる型`a`、ただしインターフェース`Comp`の実装があるもの、については型`a`の2つの値を比較でき、それらの`Ordering`を返す」のようにに読めます。
`comp`をどんなもので呼び出そうとも、Idris自ら`Comp a`であるような型の値を思い付いてくれます。
そう、新しい矢印`=>`があればね。
もしIdrisがこれに失敗するなら、それは型エラーです。

これにて`comp`を関係する関数の実装に使えます。
やらなければいけないことは以下の導出される関数に`Comp`制約を前置することだけです。

```idris
lessThan : Comp a => a -> a -> Bool
lessThan s1 s2 = LT == comp s1 s2

greaterThan : Comp a => a -> a -> Bool
greaterThan s1 s2 = GT == comp s1 s2

minimum : Comp a => a -> a -> a
minimum s1 s2 =
  case comp s1 s2 of
    LT => s1
    _  => s2

maximum : Comp a => a -> a -> a
maximum s1 s2 =
  case comp s1 s2 of
    GT => s1
    _  => s2
```

`minimum`の定義は`minimumBy`と瓜二つですね。
強いて違うところを挙げるとすれば、`minimumBy`の場合は比較関数を明示的な引数として渡さねばならないところ、`minimum`は`Comp`の実装の一部で提供されているのでIdrisが代わりに渡してくれることです。

したがって以上のユーティリティ関数を一度定義してしまえば、インターフェース`Comp`の実装がある全ての型に適用できます。

### 演習 その1

1. 関数`anyLarger`を実装してください。
この関数は、値のリストが与えられた参照値より大きい要素を少なくとも1つ含んでいるときに限り`True`を返します。
インターフェース`Comp`を実装で使ってください。

2. 関数`allLarger`を実装してください。
この関数は、値のリストが与えられた参照値より大きい要素*のみ*を含んでいるときに限り`True`を返します。
ここで、自明な場合である空リストについては真になります。
インターフェース`Comp`を実装で使ってください。

3. 関数`maxElem`を実装してください。
この関数は`Comp`の実装を使って値のリストから最も大きい要素を抽出しようとします。
`minElem`も同様にしてください。
この関数は最も小さい要素を抽出しようとするものです。
出力の型を決めるときは、リストが空になる可能性があることを考慮しなくてはいけませんよ。

4. リストや文字列のような連結できる値のためのインターフェース`Concat`を定義してください。
リストと文字列向けの実装を提供してください。

5. `Concat`の実装が備わる値を持つリスト中の値を連結する関数`concatList`を実装してください。
リストが空になる可能性があることを出力の型に反映してくださいね。

## もっとインターフェース

先の節ではごく基本的なインターフェースを学びました。
便利な理由と定義して実装する方法についてです。
この節では少しだけ発展的な概念を学びます。
インターフェースを拡張すること、制約付きのインターフェース、既定実装です。

### インターフェースを拡張する

階層をなすインターフェースがあります。
例えば演習4で使った`Concat`インターフェースについては、`Empty`という名前の子インターフェースがあってもいいでしょう。
このインターフェースを満たすような型には、連結の際に何の効果も生じない値があります。
そのような場合、`Concat`の実装を`Empty`の実装の必要条件にできます。

```idris
interface Concat a where
  concat : a -> a -> a

implementation Concat String where
  concat = (++)

interface Concat a => Empty a where
  empty : a

implementation Empty String where
  empty = ""
```

`Concat a => Empty a`は「`Concat`の型`a`のための実装は、`a`に対して`Empty`の実装をするための必要条件である」のように読めます。
しかしこれは、インターフェース`Empty`の実装があるならば、常に`Concat`の実装が*なくてはならず*、
いつでも`Concat`にある関数を呼び出すことができる、という意味でもあるのです。

```idris
concatListE : Empty a => List a -> a
concatListE []        = empty
concatListE (x :: xs) = concat x (concatListE xs)
```

`concatListE`の型で`Empty`制約だけを使っているにも関わらず、実装で`empty`と`concat`の両方を呼び出せていますね。

### 制約付きの実装

ときに、ある汎化型のインターフェースを実装できるのが、
その型変数がこのインターフェースを実装しているときだけ、ということがあります。
たとえば、インターフェース`Comp`を`Maybe a`に実装するのが可能なのは、
型`a`自体が`Comp`を実装しているときだけです。
インターフェースの実装に制約を課すのは、制約付きの関数で使ったのと同じ文法でできます。

```idris
implementation Comp a => Comp (Maybe a) where
  comp Nothing  Nothing  = EQ
  comp (Just _) Nothing  = GT
  comp Nothing  (Just _) = LT
  comp (Just x) (Just y) = comp x y
```

文法がよく似てはいますが、これはインターフェースを拡張することとは同じではありません。
制約は*型変数*に課されていて、型全体ではないですね。
`Comp (Maybe a)`の実装の最後の行では2つの`Just`に格納された値を比較します。
これが可能となるのは、これらの値にも`Comp`の実装があるときだけです。
さあ、上記の実装から`Comp a`制約を消去してみましょう。
Idrisの型エラーを読み解くことは、修正するときに大事になります。

幸いにもIdrisはこれら全ての制約を代わりに解いてくれます。

```idris
maxTest : Maybe Bits8 -> Ordering
maxTest = comp (Just 12)
```

ここでIdrisは`Comp (Maybe Bits8)`の実装を見つけ出そうとします。
そのためには`Comp Bits8`用の実装が必要です。
さあさあ`maxInt`の型にある`Bits8`を`Bits64`に変えてみましょう。
どんなエラー文言をIdrisは出すでしょうか。

### 既定実装

ときどき、いくつかの関係する関数を1つのインターフェースに収めて、
そのインターフェースにある関数を使うことが*できながらも*、
プログラマがそれぞれの関数をもっとも効率的に動くように実装できるようにしたいことがあります。
たとえば、2つの値の等値性で比較するインターフェース`Equals`を考えましょう。
このインターフェースには2つの値が等しいとき`True`を返す関数`eq`と、
等しくないときに`True`を返す`neq`があります。
もちろん`neq`は`eq`を使って実装できますし、
ほとんどの場合で`Equals`を実装するときは`eq`のみを実装すればよいでしょう。
この場合、`neq`の実装を`Equals`の定義中に含めてしまうことができます。

```idris
interface Equals a where
  eq : a -> a -> Bool

  neq : a -> a -> Bool
  neq a1 a2 = not (eq a1 a2)
```

`Equals`の実装で`eq`のみ実装した場合は、
Idrisは上記の`neq`の既定実装を使うことになります。

```idris
Equals String where
  eq = (==)
```

他方で両方の関数に陽に実装を提供したければそれもできます。

```idris
Equals Bool where
  eq True True   = True
  eq False False = True
  eq _ _         = False

  neq True  False = True
  neq False True  = True
  neq _ _         = False
```

### 演習 その2

1. インターフェース`Equals`, `Comp`, `Concat`, `Empty`を対（2つ組タプル）に実装してください。
  実装では必要に応じて制約を課して構いません（関数の引数と同様に、複数の制約を連続して課すことができます。
  例えば`Comp a => Comp b => Comp (a,b)`です）。

2. 以下は2分木の実装です。
   インターフェース`Equals`と`Concat`をこの型に実装してください。

   ```idris
   data Tree : Type -> Type where
     Leaf : a -> Tree a
     Node : Tree a -> Tree a -> Tree a
   ```

## *Prelude*にあるインターフェース

Idrisの*Prelude*はインターフェースと実装をいくつか提供しています。
これらはほぼ全てのある程度以上のプログラムで便利です。
基本的なものをここで紹介します。
より発展的なものは後の章でお話ししましょう。

これらのインターフェースのほとんどは数学的な法則に関連します。
そして、実装はこれらの法則に従うことになっています。
法則についてもここで触れます。

### `Eq`

おそらく最も使われているインターフェースは`Eq`でしょう。
これは前述の例で使ったインターフェース`Equal`に対応します。
`eq`と`neq`の代わりに、`Eq`は2つの演算子`(==)`と`(/=)`を提供し、
2つの同じ型の値について等しいか異なるかを比べられます。
*Prelude*で定義されているほとんどのデータ型は`Eq`の実装付きですし、
プログラマが自前のデータ型を作るときも最初に実装するインターフェースでしょう。

#### `Eq`の法則

`Eq`の全ての実装について以下の法則を満たすようにしてください。

* `(==)`は*反射的*です。
`x == x = True`が全ての`x`について成り立ちます。
つまり、全ての値はそれ自身と等しいです。

* `(==)`は*対称的*です。
`x == y = y == x`が全ての`x`と`y`について成り立ちます。
つまり、`(==)`の引数の順序は重要ではありません。

* `(==)`は*推移的*です。
`x == y = True`と`y == z = True`から`x == z = True`が導かれます。

* `(/=)`は`(==)`の否定です。`x == y = not (x /= y)`が全ての`x`と`y`について成り立ちます。

理論上、Idrisにはこれらの法則を非原始型に対してコンパイル時に検証する能力があります。
しかしながら、実用上は`Eq`の実装には必要ありません。
そのような証明を書くというのはちょっとしたハマりどころだからです。

### `Ord`

*Prelude*版の`Comp`として`Ord`があります。
自前の`comp`と等価な`compare`に加え、比較演算子`(>=)`、`(>)`、`(<=)`、`(<)`やユーティリティ関数`max`と`min`を提供します。
`Comp`とは異なり、`Ord`は`Eq`を拡張します。
なので`Ord`制約がある場合は、常に演算子`(==)`および`(/=)`と関連する関数が使えます。

#### `Ord`の法則

`Ord`の全ての実装について以下の法則を満たすようにしてください。

* `(<=)`は*反射的*で*推移的*です。
* `(<=)`は*非対称的*です。
`x <= y = True`と`y <= x = True`から`x == y = True`が導かれます。
* `x <= y = y >= x`
* `x < y = not (y <= x)`
* `x > y = not (y >= x)`
* `compare x y = EQ` => `x == y = True`
* `compare x y == GT = x > y`
* `compare x y == LT = x < y`

### `Semigroup`と`Monoid`

`Semigroup`は例に出てきたインターフェース`Concat`のようなもので、
関数`concat`に対応する演算子`(<+>)`（*append*とも）を持ちます。

同様に`Monoid`は`Empty`に対応するもので、`empty`に対応する`neutral`があります。

これらは極めて重要なインターフェースで、
2つ以上のデータ型の値を単一の同じ型の値に結合するのに使えます。
前述の例にもありましたが数値型の和や積に留まらず、
連続するデータや連続する計算処理の結合にも使えます。

例として地理を扱うアプリケーションでの距離を表すデータ型を考えます。
単に`Double`を使うこともできますが、あまり型安全ではありません。
単一のフィールドを持つレコード型で`Double`型の値をくるむとよいでしょう。
値に明確な意味論が備わるためです。

```idris
record Distance where
  constructor MkDistance
  meters : Double
```

2つの距離を結合するのには自然な方法があります。
それらが持つ値を加算すればよいのです。
そこで直ちに`Semigroup`の実装が導かれます。

```idris
Semigroup Distance where
  x <+> y = MkDistance $ x.meters + y.meters
```

これも直ちに明らかなことですが、ゼロはこの操作での中立な要素です。
ゼロを加算しても値には何ら影響がありません。
こうして`Monoid`も実装できます。

```idris
Monoid Distance where
  neutral = MkDistance 0
```

#### `Semigroup`と`Monoid`の法則

`Semigroup`と`Monoid`の全ての実装について以下の法則を満たすようにしてください。

* `(<+>)`は結合的です。
  `x <+> (y <+> z) = (x <+> y) <+> z`は全ての`x`, `y`, `z`の値について成り立ちます。
* `neural`は`(<+>)`に関して*中立な要素*です。
  `neural <+> x = x <+> neural = x`が全ての`x`について成り立ちます。

### `Show`

`Show`インターフェースは主に不具合修正の用途で使われ、与えられた型の値を文字列として表示するためのものです。
その値を作るIdrisのコードに近付けることが多いです。
その場合は必要に応じて括弧内に引数を適切にくるむことがあります。
例えば以下の関数の出力がどうなるかREPLでやってみてください。

```idris
showExample : Maybe (Either String (List (Maybe Integer))) -> String
showExample = show
```

そしてREPLで次のようにします。

```repl
Tutorial.Interfaces> showExample (Just (Right [Just 12, Nothing]))
"Just (Right [Just 12, Nothing])"
```

`Show`のインスタンスを実装する方法は演習で学びましょう。

### オーバーロードされた直値

Idrisの直値、例えば整数直値 (`12001`)、文字列直値 (`"foo bar"`)、浮動小数点直値 (`12.112`)、そして文字直値
(`'$'`) はオーバーロードできます。
つまり、`String`ではない型の値を単なる文字列直値から作れるということです。
ちゃんとした仕組みは他の節まで待たなければいけませんが、大体はインターフェース`FromString`（文字列直値用）や`FromChar`（文字直値用）や`FromDouble`（浮動小数点直値用）を実装すれば充分でしょう。
整数直値については特殊なので次の節で詳述します。

`FromString`の用途はこうです。
アプリケーションを書いており、利用者が利用者名とパスワードで自身であることを同定できるものだとします。
はっきりと異なる意味論を持つものではあるのですが、いずれも文字からなる文字列なので、2つを混同してしまいがちです。
この場合、これら2つのために新しい型を用意することが望ましいです。
特にこれらを取り違えたりなんかするとセキュリティ上の問題になりますから。

例としてレコード型を3つ用意しました。

```idris
record UserName where
  constructor MkUserName
  name : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  name     : UserName
  password : Password
```

型`User`の値を作るには、試してみたいときであっても、逐一文字列を構築子でくるむ必要があります。

```idris
hock : User
hock = MkUser (MkUserName "hock") (MkPassword "not telling")
```

これは割りとまどろっこしく、型安全性を増すには割に合わなさすぎると考える人もいるでしょう（私はそうでもありませんが）。
幸いにも文字列直値の便利さをとても簡単に取り戻せます。

```idris
FromString UserName where
  fromString = MkUserName

FromString Password where
  fromString = MkPassword

hock2 : User
hock2 = MkUser "hock" "not telling"
```

### 数的インターフェース

*Prelude*はよくある代数操作を提供するインターフェースもいくつか公開しています。
以下はインターフェースと提供されている関数の網羅的な一覧です。

* `Num`
  * `(+)`: 加算
  * `(*)`: 乗算
  * `fromInteger`: オーバーロードされた整数直値

* `Neg`
  * `negate` : 正負反転
  * `(-)`: 減算

* `Integral`
  * `div`: 整数の除算
  * `mod` : 剰余演算

* `Fractional`
  * `(/)`: 除算
  * `recip` : 値の逆数を計算する

ここで次のことがわかります。
所与の型に整数直値を使うのにはインターフェース`Num`を実装する必要があります。
`-12`のような負数の整数直値を使うためにはインターフェース`Neg`も実装する必要があります。

### `Cast`

最後にこの節では`Cast`というインターフェースについて手短かに説明します。
ある型の値を他の型の値に関数`cast`で変換するというものです。
`Cast`が特別なのは、このインターフェースが*2つ*の型変数を引数に取るからです。
これまで見てきた他のインターフェースは型変数が1つしかありませんでした。

これまで`Cast`を主に標準ライブラリにある原始型の相互変換に使ってきました。
特に数値型です。
*Prelude*から公開されている実装を見てみると（例えば`:doc Cast`とREPLで呼び出します）、
原始型のほとんどの対に関して沢山の実装があることがわかるでしょう。

`Cast`は他の変換にも便利ですが（`Maybe`から`List`であったり、
`Either e`から`Maybe`であったり）、
*Prelude*と*base*はそうした変換を一環して提供してはいないようです。
例として`Cast`の実装として`SnocList`から`List`とその逆のものがありますが、
`Vect n`から`List`へ、あるいは`Vect n`から`List`への実装はありません。
そうした実装も可能ではあるのですが。

### 演習 その3

ここにある演習は自前のデータ型のためのインターフェースを流暢に実装できるようになることを意図しています。
Idrisのコードを書くときはしばしば必要になることですから。

`Eq`, `Ord`,
`Num`のようなインターフェースが便利な理由はすぐに分かりますが、一方で`Semigroup`と`Monoid`の便利さは最初は実感しにくいかもしれません。
したがって演習の中にはいくつかの異なるインスタンスについて実装するものがあります。

1. 複素数のためのレコード型`Complex`を定義してください。
   型`Double`の値2つを対にします。
   `Eq`、`Num`、`Neg`、`Fractional`を`Complex`に実装してください。

2. `Show`を`Complex`に実装してください。
   データ型`Prec`と関数`showPrec`を調べて、
   *Prelude*で`Either`や`Maybe`のインスタンスを実装するためにどのようにこれらが使われているのか見てみましょう。

   書いた実装が正しい挙動になっていることを確かめるために、
   REPLで型`Complex`の値を`Just`にくるんで`show`してみましょう。

3. 以下のオプショナルな値の梱包について考えてみましょう。

   ```idris
   record First a where
     constructor MkFirst
     value : Maybe a
   ```

   インターフェース`Eq`、`Ord`、`Show`、`FromString`、`FromChar`、`FromDouble`、`Num`、`Neg`、`Integral`、`Fractional`を`First a`に実装してください。
   これらは全て型変数`a`に対応する制約が必要になるでしょう。
   必要に応じて、以下のユーティリティ関数を実装して使ってください。

   ```idris
   pureFirst : a -> First a

   mapFirst : (a -> b) -> First a -> First b

   mapFirst2 : (a -> b -> c) -> First a -> First b -> First c
   ```

4. 同様にインターフェース`Semigroup`と`Monoid`を`First a`に実装してください。
   `(<+>)`は最初の非空な引数を返します。
   また、`neutral`は対応する中立要素です。
   これらの実装では型変数`a`に制約があってはいけません。

5. レコード`Last`についてもう一度問題3と4を解いてください。
   `Semigroup`の実装は最後の非空な値を返します。

   ```idris
   record Last a where
     constructor MkLast
     value : Maybe a
   ```

6. 関数`foldMap`は関数を順番に写して`Monoid`を返します。
   値のリストを巡回しつつ`(<+>)`で結果を積み重ねます。
   これはリストに格納された値を集積するとても強力な方法です。
   `foldMap`と`Last`でリストから最後の要素を（もしあれば）取り出してください。

   ここでの`foldMap`の型はより一般的で、リストのみが専門ではありません。
   `Maybe`や`Either`やその他のまだ見ぬ容器型に対しても動きます。
   後の節でインターフェース`Foldable`を学びましょう。

7. 真偽値の値のレコード梱包`Any`と`All`を考えます。

   ```idris
   record Any where
     constructor MkAny
     any : Bool

   record All where
     constructor MkAll
     all : Bool
   ```

   `Semigroup`と`Monoid`を`Any`に実装してください。
   ただし`(<+>)`の結果は、少なくとも1つの引数が`True`であるときにのみ`True`です。
   `neural`はもちろんこの操作において中立な要素になるようにしてくださいね。

   同様にして`Semigroup`と`Monoid`を`All`に実装してください。
   `(<+>)`の結果は、両方の引数が`True`のときにのみ`True`であるようにしてください。
   `neural`はもちろんこの操作において中立な要素になるようにしてくださいね。

8. 関数`anyElem`と`allElems`を、`foldMap`と`Any`ないし`All`を使って実装してください。

   ```idris
   -- 命題が少なくとも1つの要素について満たされているとき真
   anyElem : (a -> Bool) -> List a -> Bool

   -- 命題が全ての要素について満たされているとき真
   allElems : (a -> Bool) -> List a -> Bool
   ```

9. レコード梱包`Sum`と`Product`は主に数値型を保持するのに使われます。

   ```idris
   record Sum a where
     constructor MkSum
     value : a

   record Product a where
     constructor MkProduct
     value : a
   ```

   `Num a`の実装があるとして、`Semigroup (Sum a)`と`Monoid (Sum a)`を実装してください。
   ただし`(<+>)`は加算に対応します。

   同様に`Semigroup (Product a)`と`Monoid (Product a)`を実装してください。
   ただし`(<+>)`は乗算に対応します。

   `neutral`を実装する際は、数値型を扱うときに整数直値が使えることを思い出してください。

10. `sumList`と`productList`を実装してください。
    `foldMap`とともに演習9の梱包を使ってください。

    ```idris
    sumList : Num a => List a -> a

    productList : Num a => List a -> a
    ```

11. `foldMap`の強力さと多彩さを味わうために、演習6から10までを解いたあとに（もしくはREPLで`Solutions.Interfaces`を読み込んでもよいです）、以下をREPLで実行してください。
    これはなんとたった1回の巡回でリストの最初と最後の要素と全ての値の和と積を計算しています。

    ```repl
    > foldMap (\x => (pureFirst x, pureLast x, MkSum x, MkProduct x)) [3,7,4,12]
    (MkFirst (Just 3), (MkLast (Just 12), (MkSum 26, MkProduct 1008)))
    ```

   `Ord`の実装付きの型用に`Semigroup`の実装もあります。
   この実装は2つの値のうちより小さいかより大きいほうを返します。
   絶対的な最小値や最大値がある型の場合（例えば自然数の0や、`Bits8`の0と255）、これらは`Monoid`にまで拡張できます。

12. 以前の演習で、化学の元素を表現するデータ型を実装し、化学の体積を計算する関数を書きました。
    新しく原子の体積を表現する単一フィールドレコード型を定義して、インターフェース`Eq`, `Ord`, `Show`,
    `FromDouble`, `Semigroup`, `Monoid`をこの型に実装してください。

13. 演習12の新しいデータ型を使って原子の原子質量を算出し、
    分子式で与えられる分子の分子質量を計算してください。

   解決の糸口：相応しいユーティリティ関数があれば、ここでも`foldMap`が使えます。

最後の註釈：もし関数型プログラミングが初めてであれば、演習6から10の実装をREPLで確かめてみてください。
これら全ての関数を最小限の量のコードでどう実装できたか、そして演習11で見たように1回のリストの巡回においてこれらの挙動をどう組み合わせられたかを思い返しましょう。

## まとめ

* インターフェースのおかげで、異なる型で異なる挙動をする同じ関数を実装できます。
* 1つ以上のインターフェースの実装を引数に取る関数は*制約付き関数*と呼ばれます。
* インターフェースは他のインターフェースを*拡張*することで階層的に組織付けられます。
* インターフェースの実装には、それ自体が他の実装を必要とする*制約*が課されることがあります。
* インターフェースの関数には*既定実装*を与えられます。
  この実装は実装者によって上書きできます。
  例えば効率性の理由などからです。
* インターフェースを用意すれば、文字列や整数といった直値を自前のデータ型に使えることがあります。

ただ、この節ではまだ直値の一部始終をお話ししていません。
限られた値の集合のみを受け付ける型に直値を使うことに関するもっと詳しい話は、[原始型](Prim.md)についての章にあります。

### お次は？

[次の章](Functions2.md)では関数とその型にさらに迫ります。
名前付き引数、暗黙の引数、引数消去に加え、
より複雑な関数を実装するためのいくつかの構築子について学びます。

<!-- vi: filetype=idris2:syntax=markdown
-->
