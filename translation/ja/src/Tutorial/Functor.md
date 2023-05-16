# 関手と仲間達

プログラミングとは、数学がそうであるように、抽象化そのものです。
現実世界の一部をモデル化しようとし、抽象化によって繰り返されるパターンを再利用します。

この章ではいくつかの関連し合うインターフェースについて学びます。
これらは全て抽象化についてのものなので、最初のうちは理解するのが難しいかもしれません。
特に*なぜ*役に立つのか、*いつ*使うのかがわかるには時間と経験が必要です。
したがってこの章は山ほど演習が付属しており、
ほとんどはごく少ない行のコードで解くことができます。
演習を飛ばさないでください。
内容が自然に感じられるまで何度も立ち返ってください。
そうすれば当初感じていた複雑さが消えていることに気付くでしょう。

```idris
module Tutorial.Functor

import Data.List1
import Data.String
import Data.Vect

%default total
```

## 関手

一般に、`List`、`List1`、`Maybe`、`IO`のような型構築子はどのような型を持っているのでしたっけ。
一つ目に、すべて型`Type -> Type`です。
二つ目に、すべて与えられた型の値を何らかの*文脈*の中に入れます。
`List`については、*文脈*は*非決定論的*です。
つまり、ゼロ以上の値があることはわかりますが、
パターン照合によってリストを分解しない限り正確な数はわかりません。
`List1`も同様ですが、こちらは1つは値があることが確かです。
`Maybe`についても何個の値があるのかは定かではありませんが、選択肢はずっと小さく、ゼロか1です。
`IO`についての文脈は違ったものであり、それはあらゆる副作用です。

上で議論した型構築子は挙動の様子や便利になる場合がかなり異なりますが、これらに取り組んでいると何らかの操作は頭に上ってきます。
そのような操作の1つ目は*土台の構造に影響することなく、純粋な関数をデータ型に写す*ことです。

例えば数字のリストが与えられたとき、順番や値の削除なしに、それぞれの数を2倍したいとします。

```idris
multBy2List : Num a => List a -> List a
multBy2List []        = []
multBy2List (x :: xs) = 2 * x :: multBy2List xs
```

でもちょうど同じように文字列リスト中の全ての文字列を大文字に変換したいかもしれません。

```idris
toUpperList : List String -> List String
toUpperList []        = []
toUpperList (x :: xs) = toUpper x :: toUpperList xs
```

保管している値の種類が変わることもあります。
次の例ではリストに保管されている文字列の長さを計算しています。

```idris
toLengthList : List String -> List Nat
toLengthList []        = []
toLengthList (x :: xs) = length x :: toLengthList xs
```

これらの関数がどれほど退屈かよくお分かりいただけたでしょう。
ほとんど同じものであり、関心がある部分はそれぞれの要素に適用している関数なのです。
もちろんこれを抽象化するパターンがあるはずです。

```idris
mapList : (a -> b) -> List a -> List b
mapList f []        = []
mapList f (x :: xs) = f x :: mapList f xs
```

これはよく関数型プログラミングで行われる抽象化の初めの一歩です。
つまり高階関数（汎化も可）を書くということです。
これで上で示した全ての例を`mapList`を使って簡潔に実装することができます。

```idris
multBy2List' : Num a => List a -> List a
multBy2List' = mapList (2 *)

toUpperList' : List String -> List String
toUpperList' = mapList toUpper

toLengthList' : List String -> List Nat
toLengthList' = mapList length
```

しかしきっと同じ類のことを`List1`や`Maybe`でもしたいでしょう！
結局はちょうど`List`のような容器型なのです。
単に値の数で保管できたりできなかったりする違いがあるだけで。

```idris
mapMaybe : (a -> b) -> Maybe a -> Maybe b
mapMaybe f Nothing  = Nothing
mapMaybe f (Just v) = Just (f v)
```

`IO`であっても純粋な関数を作用付き計算に写せるようにしたいです。
入れ子の層になったデータ構築子があるため、実装はもう少し込み入っていますが、
疑問に思ったときは型がきっと導いてくれます。
ただしかし、`IO`は公に公開されていないので、データ構築子は使えません。
ですが`IO`を`PrimIO`と相互に変換するために関数`toPrim`や`fromPrim`を使えるので、
これらを使えば自由に解剖できます。

```idris
mapIO : (a -> b) -> IO a -> IO b
mapIO f io = fromPrim $ mapPrimIO (toPrim io)
  where mapPrimIO : PrimIO a -> PrimIO b
        mapPrimIO prim w =
          let MkIORes va w2 = prim w
           in MkIORes (f va) w2
```

*純粋な関数を文脈に写す*という概念からいくつか派生する関数が出てきますが、便利なことがよくあります。
以下は`IO`からいくつか取ってきたものです。

```idris
mapConstIO : b -> IO a -> IO b
mapConstIO = mapIO . const

forgetIO : IO a -> IO ()
forgetIO = mapConstIO ()
```

もちろん`mapConst`や`forget`を
`List`、`List1`、`Maybe`（そして他にも山程ある何らかの類の写す関数がある型構築子）にも同様に実装したいですし、
見た目が全部同じなのでこれもまた退屈です。

関数といくつかの派生した有用な関数の集まりが繰り返される場面に出喰わしたときは、
インターフェースを定義することを検討すべきです。
しかしここではどのようにすればよいのでしょうか。
`mapList`、`mapMaybe`、`mapIO`の型を見ると、除去する必要があるのは`List`、`List1`、`IO`型であるとわかります。
これらは型`Type`ではなく型`Type -> Type`です。
運が良いことにインターフェースが`Type`以外の何かを変数に取るようにするのに支障はありません。

探しているインターフェースは`Functor`と呼ばれます。
以下はその定義と実装例です。
（名前のあとに印を付けて*Prelude*から輸出されているインターフェースと関数と重ならないようにしました。）

```idris
interface Functor' (0 f : Type -> Type) where
  map' : (a -> b) -> f a -> f b

implementation Functor' Maybe where
  map' _ Nothing  = Nothing
  map' f (Just v) = Just $ f v
```

なお、変数`f`の型を明示的に与えなくてはいけず、
その場合実行時に消去されていてほしければ数量子ゼロで註釈を付ける必要があります。
（ほぼ常にそうであってほしいものです。）

さて、`map'`のように型変数のみからなる型処方を読むのは慣れるまで時間が掛かるかもしれません。
`f a`のように型変数が他の変数に提供されているときは特にそうです。
REPLでこれらの処方を全ての暗黙子とともに調べると大変理解の助けになります。
（出力を読みやすいように整形しました。）

```repl
Tutorial.Functor> :ti map'
Tutorial.Functor.map' :  {0 b : Type}
                      -> {0 a : Type}
                      -> {0 f : Type -> Type}
                      -> Functor' f
                      => (a -> b)
                      -> f a
                      -> f b
```

型変数`f`を同じ型の形がある値に置き換えるのもよいかもしれません。

```repl
Tutorial.Functor> :t map' {f = Maybe}
map' : (?a -> ?b) -> Maybe ?a -> Maybe ?b
```

覚えておいてほしいのですが、型処方を解釈できることはIdrisの宣言で起こっていることを理解する上での最重要事項です。
これを練習し与えられたツールやユーティリティを活用する*必要*があります。

### 導出される関数

インターフェース`Functor`から直接導出できる関数や演算子はいくつかあります。
これらは大変有用なので、最終的には全てを知り記憶するべきです。
以下は型と共に見たものです。

```repl
Tutorial.Functor> :t (<$>)
Prelude.<$> : Functor f => (a -> b) -> f a -> f b

Tutorial.Functor> :t (<&>)
Prelude.<&> : Functor f => f a -> (a -> b) -> f b

Tutorial.Functor> :t ($>)
Prelude.$> : Functor f => f a -> b -> f b

Tutorial.Functor> :t (<$)
Prelude.<$ : Functor f => b -> f a -> f b

Tutorial.Functor> :t ignore
Prelude.ignore : Functor f => f a -> f ()
```

`(<$>)`は`map`の演算子別称で括弧を省略できるときがあります。
例えば以下。

```idris
tailShowReversNoOp : Show a => List1 a -> List String
tailShowReversNoOp xs = map (reverse . show) (tail xs)

tailShowReverse : Show a => List1 a -> List String
tailShowReverse xs = reverse . show <$> tail xs
```

`(<&>)`は引数が入れ替わっていることを除けば`(<$>)`の別称と言えます。
他の3つ (`ignore`, `($>)`, `(<$)`) は全て、定数で文脈中の値を置き換えるために使われます。
値そのものには関心がないものの土台の構造を維持したいときによく使います。

### 1つ以上の型変数がある関手

これまで見てきた型構築子は全て型が`Type -> Type`でした。
しかし`Functor`を他の型構築子に実装することもできます。
唯一の事前要件は、関数`map`で変化させたい型変数が引数リストの最後になければいけないことです。
例えば以下が`Either e`のための`Functor`の実装です。
（なお、`Either e`はもちろん必要とされている型`Type -> Type`を持ちます。）

```idris
implementation Functor' (Either e) where
  map' _ (Left ve)  = Left ve
  map' f (Right va) = Right $ f va
```

以下は別の例で、この場合型構築子は`Bool -> Type -> Type`です。
（[直近の章](IO.md)の演習でこれを覚えているかもしれません。）

```idris
data List01 : (nonEmpty : Bool) -> Type -> Type where
  Nil  : List01 False a
  (::) : a -> List01 False a -> List01 ne a

implementation Functor (List01 ne) where
  map _ []        = []
  map f (x :: xs) = f x :: map f xs
```

### 関手の組み合わせ

関手の良いところは他の関手と対にしたり入れ子にしたりできることで、結果もまた関手になります。

```idris
record Product (f,g : Type -> Type) (a : Type) where
  constructor MkProduct
  fst : f a
  snd : g a

implementation Functor f => Functor g => Functor (Product f g) where
  map f (MkProduct l r) = MkProduct (map f l) (map f r)
```

上のコードにより、便利に関手の対の上で写せます。
ただしかし、Idrisが関係する型を推論するのに手助けが要ることがあります。

```idris
toPair : Product f g a -> (f a, g a)
toPair (MkProduct fst snd) = (fst, snd)

fromPair : (f a, g a) -> Product f g a
fromPair (x,y) = MkProduct x y

productExample :  Show a
               => (Either e a, List a)
               -> (Either e String, List String)
productExample = toPair . map show . fromPair {f = Either e, g = List}
```

もっとよくあるのは一度に何層かの入れ子になった関手の上で写したいときです。
以下は一例です。

```idris
record Comp (f,g : Type -> Type) (a : Type) where
  constructor MkComp
  unComp  : f (g a)

implementation Functor f => Functor g => Functor (Comp f g) where
  map f (MkComp v) = MkComp $ map f <$> v

compExample :  Show a => List (Either e a) -> List (Either e String)
compExample = unComp . map show . MkComp {f = List, g = Either e}
```

#### 名前付き実装

時には与えられた型により多くの実装方法があることがあります。
例えば数値型については、加算を表現する`Monoid`と乗算を表現するものを用意できます。
同様に入れ子の関手については`map`の解釈として値の最初の層の上のみで写すことも、
値のいくつかの層の上で写すこともできます。

こうするための1つの方法は単一フィールドの梱包を定義することで、上で見たデータ型`Comp`のような感じです。
しかしIdrisでは追加のインターフェース実装を定義することもでき、
それには名前が与えられている必要があります。
例えば以下。

```idris
[Compose'] Functor f => Functor g => Functor (f . g) where
  map f = (map . map) f
```

なお、これは`Functor`の新しい実装を定義していますが、
曖昧さを回避するための暗黙裡に行われる解決中には考慮され*ません*。
しかし、この実装を明示的に選ぶことはでき、
明示的な引数として`map`に渡せばよいです。
この引数には`@`が前置されます。

```idris
compExample2 :  Show a => List (Either e a) -> List (Either e String)
compExample2 = map @{Compose} show
```

上の例では`Compose'`の代わりに`Compose`を使いました。
なぜなら前者は既に*Prelude*により輸出されているからです。

### 関手則

ちょうど`Eq`や`Ord`の実装と同じように、`Functor`の実装にはある法則の遵守が必要です。
繰り返しますがこれらの法則はIdrisによって検証されません。
可能（で、よくややこしくなる）ではあるでしょうけれども。

1. `map id = id`：関手の上で同一関数を写すことで、
   容器の構造を変えたり`IO`アクションを走らせるときに生じる副作用で影響を与えたりするような、
   目に見えるいかなる作用もあってはならない。

2. `map (f . g) = map f . map g`：2回の写しの連続は、
   2つの関数の組合せを使って1回で写すことと同一でなければいけない。

これら両方の法則が要求しているのは、
`map`が値の*構造*を保存しているということです。
`List`, `Maybe`, `Either e`のような容器型だとより理解しやすいです。
ここで`map`は梱包された値に追加したりそこから削除したりすることは許しておらず、
`List`の場合は順番を変えることもできません。
`IO`については`map`により余剰の副作用を生じないことがこれをよく表しています。

### 演習 その1

1. `Maybe`, `List`, `List1`, `Vect n`, `Either e`, `Pair a`に対して、
   自力で`Functor'`のの実装を書いてください。

2. 関手の対について、`Functor`の名前付き実装を書いてください。
   （`Product`に実装したものと似ています。）

3. データ型`Identity`に`Functor`を実装してください。
   （これは*base*の`Control.Monad.Identity`から手に入ります。）

   ```idris
   record Identity a where
     constructor Id
     value : a
   ```

4. これは興味深い問題です：`Const e`に`Functor`を実装してください。
   （これも*base*の`Control.Application.Const`から手に入ります。）
   2つ目の型変数が絶対に実行時に関係しないところに当惑されるかもしれません、
   というのはその型の値が1つもないからです。
   そのような型は*幽霊型*と呼ばれるときがあります。
   幽霊型は値に追加の型情報を札付けするのにかなり便利です。

   上記で混乱しないようにしてください。
   可能な実装は1つしかありません。
   いつも通り虫食いを使い、道を見失ったときはコンパイラに導いてもらいましょう。

   ```idris
   record Const (e,a : Type) where
     constructor MkConst
     value : e
   ```

5. 以下はデータ保管所でのCRUD操作（Create, Read, Update, Delete）を記述する直和型です。

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

   `Functor`を`Crud i`に実装してください。

6. 以下はデータサーバからの応答を記述する直和型です。

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

   `Functor`を`Response e i`に実装してください。

7. `Functor`を`Vaidated e`に実装してください。

   ```idris
   data Validated : (e,a : Type) -> Type where
     Invalid : (err : e) -> Validated e a
     Valid   : (val : a) -> Validated e a
   ```

## アプリカティブ

`Functor`は純粋な1引数関数で文脈中の1つの値を写すことができますが、
n個のそのような値をn引数関数に結び付けることはできません。

例えば以下の関数を考えてください。

```idris
liftMaybe2 : (a -> b -> c) -> Maybe a -> Maybe b -> Maybe c
liftMaybe2 f (Just va) (Just vb) = Just $ f va vb
liftMaybe2 _ _         _         = Nothing

liftVect2 : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
liftVect2 _ []        []        = []
liftVect2 f (x :: xs) (y :: ys) = f x y :: liftVect2 f xs ys

liftIO2 : (a -> b -> c) -> IO a -> IO b -> IO c
liftIO2 f ioa iob = fromPrim $ go (toPrim ioa) (toPrim iob)
  where go : PrimIO a -> PrimIO b -> PrimIO c
        go pa pb w =
          let MkIORes va w2 = pa w
              MkIORes vb w3 = pb w2
           in MkIORes (f va vb) w3
```

この挙動は`Functor`で押さえられていないものの、とてもよく見かけるものです。
例えば2つの数字を標準入力から読んで（両方とも操作は失敗しえます）、2つの積を計算したいかもしれません。
以下がそのコードです。

```idris
multNumbers : Num a => Neg a => IO (Maybe a)
multNumbers = do
  s1 <- getLine
  s2 <- getLine
  pure $ liftMaybe2 (*) (parseInteger s1) (parseInteger s2)
```

そしてここで終わりではありません。
同様にして、3つの`Maybe`な引数を取る3引数関数のための`liftMaybe3`など、
好きな個数の引数についての関数が欲しくなります。

でもまだあります。
純粋な値を問題の文脈に持ち上げたくもあるのです。
以下のようにできます。

```idris
liftMaybe3 : (a -> b -> c -> d) -> Maybe a -> Maybe b -> Maybe c -> Maybe d
liftMaybe3 f (Just va) (Just vb) (Just vc) = Just $ f va vb vc
liftMaybe3 _ _         _         _         = Nothing

pureMaybe : a -> Maybe a
pureMaybe = Just

multAdd100 : Num a => Neg a => String -> String -> Maybe a
multAdd100 s t = liftMaybe3 calc (parseInteger s) (parseInteger t) (pure 100)
  where calc : a -> a -> a -> a
        calc x y z = x * y + z
```

もちろん既にお察しの通り、これからこの挙動を内蔵化する新しいインターフェースをお見せします。
それは`Applicative`と呼ばれます。
以下はその定義と実装例です。

```idris
interface Functor' f => Applicative' f where
  app   : f (a -> b) -> f a -> f b
  pure' : a -> f a

implementation Applicative' Maybe where
  app (Just fun) (Just val) = Just $ fun val
  app _          _          = Nothing

  pure' = Just
```

`Applicative`インターフェースはもちろんもう*Prelude*から輸出されています。
ここでは関数`app`は時々*app*や*apply*と呼ばれる`(<*>)`演算子の姿を取ります。

どうして`liftMaybe2`や`liftIO3`のような関数が*適用*演算子に関係あるのか、不思議に思われるかもしれません。
次のように実演してみます。

```idris
liftA2 : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2 fun fa fb = pure fun <*> fa <*> fb

liftA3 : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3 fun fa fb fc = pure fun <*> fa <*> fb <*> fc
```

ここで起こっていることを理解するのは本当に大切ですから、これらを分解していきましょう。
`liftA2`について`f`を`Maybe`に特化させると、`pure fun`は型`Maybe (a -> b -> c)`になります。
同様に`pure fun <*> fa`は型`Maybe (b -> c)`ですが、
これは`(<*>)`が`fa`の中に格納された値を`pure fun`に格納された関数に適用しているからです。
（カリー化ですね！）

そのような*apply*の適用の連鎖はよく見掛けることになるでしょうが、
*適用*している数は持ち上げている関数の引数の数に一致するのです。
時々以下を見掛けることもあるでしょうが、
こうすると最初の`pure`の呼び出しを省けて、代わりに`map`の演算子版を使うことができます。

```idris
liftA2' : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2' fun fa fb = fun <$> fa <*> fb

liftA3' : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3' fun fa fb fc = fun <$> fa <*> fb <*> fc
```

というわけで、インターフェース`Applicative`があると値（と関数も！）計算上の文脈に持ち上げることができ、
同じ文脈で値に適用させることができるのです。
より大きな例でなぜこれが便利なのかを見る前に、
アプリカティブ関手に取り組む際のいくつかの糖衣構文を手短かにご紹介します。

### 慣用括弧

`liftA2`や`liftA3`を実装するのに使ったプログラミングの流儀は*アプリカティブ形式*としても知られ、Haskellで複数の作用のある計算を単一の純粋な関数で結合するために多用されます。

Idrisではそのような演算子適用の連鎖を使う代わりの方法があります。
慣用括弧です。
以下は`liftA2`と`liftA3`をさらに実装し直したものです。

```idris
liftA2'' : Applicative f => (a -> b -> c) -> f a -> f b -> f c
liftA2'' fun fa fb = [| fun fa fb |]

liftA3'' : Applicative f => (a -> b -> c -> d) -> f a -> f b -> f c -> f d
liftA3'' fun fa fb fc = [| fun fa fb fc |]
```

上記の実装は`liftA2`や`liftA3`に与えた実装と同じように脱糖されます。
繰り返しますが、この脱糖は*曖昧解決や型検査、そして暗黙の値を埋める前*に行われます。
*束縛*演算子と同じように、`pure`や`(<*>)`のための自前の実装を書くことができ、
その場合オーバーロードされた関数名の曖昧解決ができればIdrisはその実装を使います。

### 用例：CSV読取器

アプリカティブ関手の持つ強力さと多芸さを実感するために、ほんの少し大きめの例を見ていきます。
CSVファイルから内容をパースしたりデコードしたりするユーティリティです。
ここでのCSVファイルはそれぞれの行にコンマ（あるいは他の区切文字）で区切られた値のリストがあるものです。
よくあるのがこれらを表のデータを格納するのに使うというもので、例えばスプレッドシートアプリケーションから用います。
やりたいことはCSVファイル中の行を変換して自前のレコードに保管するというもので、それぞれのレコードのフィールドは表中の列に対応します。

例えば以下は単純なファイルの例で、webストアの利用者情報の表が含まれています。
まず名前があり、名字、年齢（空欄可）、Eメールアドレス、性別、そしてパスワードがあります。

```repl
Jon,Doe,42,jon@doe.ch,m,weijr332sdk
Jane,Doe,,jane@doe.ch,f,aa433sd112
Stefan,Hoeck,,nope@goaway.ch,m,password123
```

そして以下がこの情報を実行時に持つのに必要なIdrisのデータ型です。
ここでも型安全性を向上させるために自前の文字列の梱包を使いましたが、
こうすることでそれぞれのデータ型について妥当と考えられる入力を定義できます。

```idris
data Gender = Male | Female | Other

record Name where
  constructor MkName
  value : String

record Email where
  constructor MkEmail
  value : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  firstName : Name
  lastName  : Name
  age       : Maybe Nat
  email     : Email
  gender    : Gender
  password  : Password
```

CSVファイル中のフィールドを読むのにインターフェースを定義することから始め、
読み込みたいデータ型に実装を書いていきます。

```idris
interface CSVField a where
  read : String -> Maybe a
```

以下は`Gender`と`Bool`向けの実装です。
それぞれ小文字1文字でそれぞれの値を符号化することに決めました。

```idris
CSVField Gender where
  read "m" = Just Male
  read "f" = Just Female
  read "o" = Just Other
  read _   = Nothing

CSVField Bool where
  read "t" = Just True
  read "f" = Just False
  read _   = Nothing
```

数値型については`Data.String`由来のパースする関数が使えます。

```idris
CSVField Nat where
  read = parsePositive

CSVField Integer where
  read = parseInteger

CSVField Double where
  read = parseDouble
```

オプショナルな値については、格納される型自身が`CSVField`のインスタンスでなければいけません。
そこで空文字列`""`を`Nothing`として扱うことにし、
非空文字列を内蔵化された型のフィールドの読取器に渡すことにします。
（`(<$>)`が`map`の別称なことを思い出してください。）

```idris
CSVField a => CSVField (Maybe a) where
  read "" = Just Nothing
  read s  = Just <$> read s
```

最後に文字列の梱包について、妥当な値だと考えられるものを決める必要があります。
簡単のために許される文字列の長さと妥当な文字集合で制限することに決めました。

```idris
readIf : (String -> Bool) -> (String -> a) -> String -> Maybe a
readIf p mk s = if p s then Just (mk s) else Nothing

isValidName : String -> Bool
isValidName s =
  let len = length s
   in 0 < len && len <= 100 && all isAlpha (unpack s)

CSVField Name where
  read = readIf isValidName MkName

isEmailChar : Char -> Bool
isEmailChar '.' = True
isEmailChar '@' = True
isEmailChar c   = isAlphaNum c

isValidEmail : String -> Bool
isValidEmail s =
  let len = length s
   in 0 < len && len <= 100 && all isEmailChar (unpack s)

CSVField Email where
  read = readIf isValidEmail MkEmail

isPasswordChar : Char -> Bool
isPasswordChar ' ' = True
isPasswordChar c   = not (isControl c) && not (isSpace c)

isValidPassword : String -> Bool
isValidPassword s =
  let len = length s
   in 8 < len && len <= 100 && all isPasswordChar (unpack s)

CSVField Password where
  read = readIf isValidPassword MkPassword
```

後の章で、精錬型と、消去される妥当性の証明を検証された値とともに保管する方法とを学びます。

これでCSVファイルの行全体を復号化し始められます。
そうするためにまず自前のエラー型を導入して、どう物事が失敗しうるかを内蔵化します。

```idris
data CSVError : Type where
  FieldError           : (line, column : Nat) -> (str : String) -> CSVError
  UnexpectedEndOfInput : (line, column : Nat) -> CSVError
  ExpectedEndOfInput   : (line, column : Nat) -> CSVError
```

これで`CSVField`を使って、CSVファイル中の与えられた行と位置での単一のフィールドを読み、
失敗したときは`FieldError`を返します。

```idris
readField : CSVField a => (line, column : Nat) -> String -> Either CSVError a
readField line col str =
  maybe (Left $ FieldError line col str) Right (read str)
```

予め読み込む必要があるフィールドの数を知っていれば、
文字列のリストを与えられた長さの`Vect`に変換を試みることができます。
こうすることで既知の数のフィールド分のレコード値を円滑に読み込むことができますが、
それはベクタにパターン照合するときに正しい数の文字列変数を得られるからです。

```idris
toVect : (n : Nat) -> (line, col : Nat) -> List a -> Either CSVError (Vect n a)
toVect 0     line _   []        = Right []
toVect 0     line col _         = Left (ExpectedEndOfInput line col)
toVect (S k) line col []        = Left (UnexpectedEndOfInput line col)
toVect (S k) line col (x :: xs) = (x ::) <$> toVect k line (S col) xs
```

最後にCSVファイル中の単一行を型`User`の値に変換しようとする関数`readUser`を実装することができます。

```idris
readUser' : (line : Nat) -> List String -> Either CSVError User
readUser' line ss = do
  [fn,ln,a,em,g,pw] <- toVect 6 line 0 ss
  [| MkUser (readField line 1 fn)
            (readField line 2 ln)
            (readField line 3 a)
            (readField line 4 em)
            (readField line 5 g)
            (readField line 6 pw) |]

readUser : (line : Nat) -> String -> Either CSVError User
readUser line = readUser' line . forget . split (',' ==)
```

ちょっとREPLで動かしてみましょう。

```repl
Tutorial.Functor> readUser 1 "Joe,Foo,46,j@f.ch,m,pw1234567"
Right (MkUser (MkName "Joe") (MkName "Foo")
  (Just 46) (MkEmail "j@f.ch") Male (MkPassword "pw1234567"))
Tutorial.Functor> readUser 7 "Joe,Foo,46,j@f.ch,m,shortPW"
Left (FieldError 7 6 "shortPW")
```

なお、`readUser'`の実装で慣用括弧を使い、6引数関数 (`MkUser`) を型`Either CSVError`の6つの値に写しました。
これは全てのパースが成功したとき、またそのときに限って、自動的に成功します。
もし立て続けに6重に入れ子になったパターン照合で`readUser'`を実装していたら、
考えるまでもなく面倒ではるかに読みづらいコードになっていたでしょう。

しかし上の慣用括弧はまだかなり繰り返しがあります。
きっと、もっと良くできますよね？

#### 混成リストの用例

型族を学ぶときが来ました。
型族はレコード型の汎化表現として使うことができ、
また最小量のコードで混成になっている表中の行を表現したり読み取ったりすることができます。

```idris
namespace HList
  public export
  data HList : (ts : List Type) -> Type where
    Nil  : HList Nil
    (::) : (v : t) -> (vs : HList ts) -> HList (t :: ts)
```

混成リストは*型のリスト*で指標付けされたリスト型です。
これによりそれぞれの位置にリストの指標中の同じ位置にある型の値を格納することができます。
例えば以下の例では型`Bool`、`Nat`、`Maybe String`の3つの値を（この順で）格納します。

```idris
hlist1 : HList [Bool, Nat, Maybe String]
hlist1 = [True, 12, Nothing]
```

混成リストは与えられた型の値を格納するただのタプルだと言い張ることもできるでしょう。
それはもちろん正しいのですが、演習で苦しみながら学ぶことになるように、
リスト指標を使って`HList`についてのコンパイル時計算を行うことができるのです。
例えば2つのリストを結合するときに、同時に結果で保管される型へ追従するなどです。

しかしまずは`HList`を簡潔にCSVの行をパースする手段として活用します。
そうするためにはCSVファイル中の全行に対応する型のための、新しいインターフェースを導入する必要があります。

```idris
interface CSVLine a where
  decodeAt : (line, col : Nat) -> List String -> Either CSVError a
```

これから`HList`のための`CSVLine`の2つの実装を書いていきます。
1つは`Nil`の場合のもので、文字列からなる現在のリストが空のとき、またそのときに限り成功します。
もう1つは*cons*の場合のもので、リストの先頭と尾っぽの残りから単一のフィールドを読もうとします。
ここでも結果を結合するのに慣用括弧を使います。

```idris
CSVLine (HList []) where
  decodeAt _ _ [] = Right Nil
  decodeAt l c _  = Left (ExpectedEndOfInput l c)

CSVField t => CSVLine (HList ts) => CSVLine (HList (t :: ts)) where
  decodeAt l c []        = Left (UnexpectedEndOfInput l c)
  decodeAt l c (s :: ss) = [| readField l c s :: decodeAt l (S c) ss |]
```

これでおしまいです！
加える必要があるのは2つのユーティリティ関数だけです。
いずれも字句に分割されたあとに行全体を復号化するもので、一方は`HList`に特化されており、引数に消去されたリスト型を取ります。
これはREPLで使うのにより便利にするものです。

```idris
decode : CSVLine a => (line : Nat) -> String -> Either CSVError a
decode line = decodeAt line 1 . forget . split (',' ==)

hdecode :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => (line : Nat)
        -> String
        -> Either CSVError (HList ts)
hdecode _ = decode
```

骨折りの成果を得るために、REPLで試すときが来ました。

```repl
Tutorial.Functor> hdecode [Bool,Nat,Double] 1 "f,100,12.123"
Right [False, 100, 12.123]
Tutorial.Functor> hdecode [Name,Name,Gender] 3 "Idris,,f"
Left (FieldError 3 2 "")
```

### アプリカティブ則

繰り返しになりますが、`Applicative`の実装もいくつかの法則に従います。
以下の通りです。

* `pure id <*> fa = fa`: 持ち上げて同値関数を適用しても目に見える効果はない。

* `[| f . g |] <*> v = f <*> (g <*> v)`: 関数を合成してから適用しても、関数を適用してから合成しても同じである。

  上記は理解しづらいかもしれないので、
  以下に再びはっきりした型と実装を置いておきます。

  ```idris
  compL : Maybe (b -> c) -> Maybe (a -> b) -> Maybe a -> Maybe c
  compL f g v = [| f . g |] <*> v

  compR : Maybe (b -> c) -> Maybe (a -> b) -> Maybe a -> Maybe c
  compR f g v = f <*> (g <*> v)
  ```

  2つ目のアプリカティブ則が主張しているのは、2つの実装`compL`と`compR`が等価に振る舞うということです。

* `pure f <*> pure x = pure (f x)`。これは*準同型写像*の法則とも呼ばれます。
  これ自体はかなりわかりやすいでしょう。

* `f <*> pure v = pure ($ v) <*> f`。これは*交換*の法則と呼ばれます。

  これも具体例で説明します。

  ```idris
  interL : Maybe (a -> b) -> a -> Maybe b
  interL f v = f <*> pure v

  interR : Maybe (a -> b) -> a -> Maybe b
  interR f v = pure ($ v) <*> f
  ```

  なお、`($ v)`は型`(a -> b) -> b`なので、`f`に適用される関数型です。
  `f`は型`a -> b`の関数が`Maybe`の文脈に包まれたものです。

  交換法則が主張していることは、純粋な値を*適用*演算子の左右どちらから適用しても変わってはいけないということです。

### 演習 その2

1. `Applicative`を`Either e`と`Identity`に実装してください。

2. `Applicative`を`Vect n`に実装してください。
   補足：`pure`を実装するためには、実行時に長さがわかっていなくてはいけません。
   これは長さを消去されない暗黙子としてインターフェースの実装に渡すことでできます。

   ```idris
   implementation {n : _} -> Applicative' (Vect n) where
   ```

3. `Applicative`を`Pair e`に実装してください。
   ただし`e`は`Monoid`制約を満たします。

4. `Const e`に`Applicative`を実装してください。
   ただし`e`は`Monoid`制約を満たします。

5. `Applicative`を`Validated e`に実装してください。
   ただし`e`は`Semigroup`制約を満たします。
   これがあると*apply*の実装で2つの`Invalid`な値になったときに、`(<+>)`を使ってエラーを積み重ねることができます。

6. 型が`CSVError -> CSVError -> CSVError`のデータ構築子を追加し、
   これを使って`Semigroup`を`CSVError`に実装してください。

7. CSVパーサと全ての関係する関数を、`Either`の代わりに`Validated`を返すようにしてリファクタしてください。
   これは演習6を解いたあとでないと動きません。

   2点補足：既存のコードを調整する必要があるのはごく一部ですが、
   これは`Validated`のアプリカティブ構文をそのまま使うことができるからです。
   また、この変更によりCSVパーサのエラー累積能力を向上させることができます。
   以下はREPLセッションでのいくつかの例です。

   ```repl
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "t,12,f"
   Valid [True, 12, Female]
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "o,-12,f"
   Invalid (App (FieldError 1 1 "o") (FieldError 1 2 "-12"))
   Solutions.Functor> hdecode [Bool,Nat,Gender] 1 "o,-12,foo"
   Invalid (App (FieldError 1 1 "o")
     (App (FieldError 1 2 "-12") (FieldError 1 3 "foo")))
   ```

   アプリカティブ関手と混成リストの強力さにご注目。
   たった数行のコードだけで、CSVファイル中の行にあるエラーの累積を含む、
   純粋で、型安全で、全域なパーサを書きました。
   それにこのパーサはとても使いやすいです！

8. この章で混成リストを紹介したので、ちょっと実験してみないと損でしょう。

   この演習の目的は型の妙義における読者の技能を研ぎ澄ますことです。
   したがって解決の糸口はほとんど付属しません。
   自力で与えられた関数からどんな挙動が期待されるか、その挙動をどう型で表現するか、そしてその後でどう実装するか、決めてみてください。
   型が正しく充分に精緻であれば、実装は実質無料で手に入ります。
   行き詰まっても早々に諦めないでください。
   本当に万策尽きたときだけ解法を一瞥すること（そのときは、まずは型だけ見るようにしてくださいね）。

   1. `head`を`HList`に実装してください。

   2. `tail`を`HList`に実装してください。

   3. `(++)`を`HList`に実装してください。

   4. `index`を`HList`に実装してください。
      これは他の3つより歯応えがあるかもしれません。
      [前の演習](Dependent.md)でいかにして`indexList`を実装したかに立ち返り、そこから始めましょう。

   5. パッケージ*contrib*……これはIdrisプロジェクトの一部ですが……
      は混成ベクタのデータ型である`Data.HVect.HVect`を提供します。
      私達の`HList`との唯一の相違点は`HVect`が型リストの代わりに型ベクタに指標付けられていることです。
      これによりいくつかの操作を型段階で表現することがより簡単になっています。

      自力で`HVect`と関数`head`、`tail`、`(++)`、そして`index`関数の実装を書いてください。

   6. 真の挑戦として、`Vect m (HVect ts)`を転地する関数を実装してみてください。
      まずはこの型をどのようにさえすれば表現できるかというところから思索することになるでしょう。

      補足：これを実装するには、少なくとも1つの場合分けでIdrisの型推論を手助けするために、
      消去される引数でのパターン照合が必要になるでしょう。
      消去される引数でパターン照合することは禁止されていますが、
      その照合される値の構造が他所の消去されない引数から導出できる場合は*その限りではありません*。

      また、この問題で行き詰まっても心配しないでください。
      筆者も理解するまで何度も試行しましたから。
      でもこの体験は楽しかったので、ここに含めない*わけにはいきません*でした。:-)

      ただ、このような関数がCSVファイルを扱うのに便利であろうことには頭に入れておきましょう。
      行の集まりからなる表（タプルのベクタ）を列の集まりからなる表（ベクタのタプル）に変換できるからです。

9. アプリカティブ関手の合成がこれまたアプリカティブ関手になることを、
   `Applicative`を`Comp f g`に実装することで示してください。

10. 2つのアプリカティブ関手の積がこれまたアプリカティブ関手になることを、
    `Applicative`を`Prod f g`に実装することで示してください。

## モナド

ついに`Monad`です。
これには多くの紙幅が割かれてきたものでした。
しかし既に[`IO`についての章](IO.md)で見てきたあとであり、
ここでお伝えすべきことはそれほど残っていません。
`Monad`は`Applicative`を拡張し2つの新しい関連する関数を追加します。
*束縛*演算子 (`(>>=)`) と関数`join`です。
以下がその定義です。

```idris
interface Applicative' m => Monad' m where
  bind  : m a -> (a -> m b) -> m b
  join' : m (m a) -> m a
```

`Monad`の実装者は`(>>=)`と`join`のどちらを実装するか、もしくは両方を実装するかを自由に選べます。
どうやって`join`が*束縛*を使って実装されるのか、またその逆については、演習で見ることになるでしょう。

`Monad`と`Applicative`の大きな違いは、
前者では何らかの計算がその前の計算の結果に依存することができる点にあります。
例えば標準入力から読んだ文字列に基づいてファイルを削除するか歌を流すかを決めることができます。
最初の`IO`行動（利用者の入力を読む）が、次に走る`IO`行動に影響するのです。
これは*適用*演算子ではできません。

```repl
(<*>) : IO (a -> b) -> IO a -> IO b
```

`(<*>)`への引数として渡される時分には、2つの`IO`行動は既に決定されています。
1つ目の結果は……一般的な場合において……2つ目に走る計算に影響することはありません。
（実は`IO`については副作用を介せば理論上可能です。
最初の行動が何らかの命令をファイルまたは何らかの可変な状態に上書きすれば、
2つ目の行動がそのファイルや状態から読むことができるので、次にすべきことを決定することができるのです。
しかしこれは`IO`に限った話であって、アプリカティブ関手一般の話ではありません。
もし問題の関手が`Maybe`や`List`や`Vector`だったら、そのようなことはできません。）

例で相違点を実演しましょう。
CSV読み取り機を改善して字句からなる行を直和型に復号化できるようにしたいとします。
例えばCSVファイルの行からCRUDリクエストを復号化したいとしましょう。

```idris
data Crud : (i : Type) -> (a : Type) -> Type where
  Create : (value : a) -> Crud i a
  Update : (id : i) -> (value : a) -> Crud i a
  Read   : (id : i) -> Crud i a
  Delete : (id : i) -> Crud i a
```

それぞれの行で復号にどのデータ構築子を選ぶべきか決める方法が必要です。
1つの方法はデータ構築子の名前（やその他の識別用の札）をCSVファイルの最初の行に置いておくことです。

```idris
hlift : (a -> b) -> HList [a] -> b
hlift f [x] = f x

hlift2 : (a -> b -> c) -> HList [a,b] -> c
hlift2 f [x,y] = f x y

decodeCRUD :  CSVField i
           => CSVField a
           => (line : Nat)
           -> (s    : String)
           -> Either CSVError (Crud i a)
decodeCRUD l s =
  let h ::: t = split (',' ==) s
   in do
     MkName n <- readField l 1 h
     case n of
       "Create" => hlift  Create  <$> decodeAt l 2 t
       "Update" => hlift2 Update  <$> decodeAt l 2 t
       "Read"   => hlift  Read    <$> decodeAt l 2 t
       "Delete" => hlift  Delete  <$> decodeAt l 2 t
       _        => Left (FieldError l 1 n)
```

2つのユーティリティ関数を加えて型推論を手助けしたり若干いい感じの構文になるようにしました。
大事なのは、いかにして最初の構文解析関数の結果でパターン照合し、データ構築子と次に使う構文解析関数を決定しているか、というところです。

以下はREPLで動かした様子です。

```repl
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Create,jon@doe.ch"
Right (Create (MkEmail "jon@doe.ch"))
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Update,12,jane@doe.ch"
Right (Update 12 (MkEmail "jane@doe.ch"))
Tutorial.Functor> decodeCRUD {i = Nat} {a = Email} 1 "Delete,jon@doe.ch"
Left (FieldError 1 2 "jon@doe.ch")
```

まとめると`Monad`は`Applicative`とは異なり計算を順番に連鎖させられます。
この連鎖では中間結果が後の計算に影響を与えられます。
なので、もしn個の関連のない作用付き計算があり、純粋でn引数の関数のもとに束ねたいなら、
`Applicative`で充分でしょう。
しかしもし、ある作用付き計算の結果に基づいて次にどの計算を走らせるか決めたいときは、`Monad`を使う必要があります。

しかし注意ですが、`Monad`は`Applicative`に比べて重要な欠点があります。
一般にモナドは組み合わさりません。
例えば`Either e . IO`への`Monad`インスタンスはありません。
あとでモナド変換子について学びますが、これがあると他のモナドと組み合わせられます。

### モナド則

早速ですが以下が`Monad`の法則です。

* `ma >>= pure = ma`と`pure v >>= f = f v`。
  これらはモナドの等価法則です。
  以下が具体例です。

  ```idris
  id1L : Maybe a -> Maybe a
  id1L ma = ma >>= pure

  id2L : a -> (a -> Maybe b) -> Maybe b
  id2L v f = pure v >>= f

  id2R : a -> (a -> Maybe b) -> Maybe b
  id2R v f = f v
  ```

  これら2つの法則は`pure`が*束縛*に対して中立にはたらくべきだと主張しています。

* `(m >>= f) >>= g = m >>= (f >=> g)`。
  これはモナドの結合性の法則です。
  2つ目の演算子`(>=>)`を見掛けたことがないかもしれません。
  これは作用付き計算を連接するのに使え、以下の型を持ちます。

  ```repl
  Tutorial.Functor> :t (>=>)
  Prelude.>=> : Monad m => (a -> m b) -> (b -> m c) -> a -> m c
  ```

上記は*公式の*モナド則です。
しかし、Idris（やHaskell）では`Monad`が`Applicative`を拡張していることからすれば、
3つ目の法則についても考える必要があります。
`(<*>)`が`(>>=)`を使って実装できるため、
`(<*>)`の実際の実装は`(>>=)`を使って実装と同じように振る舞わなくてはいけません。

* `mf <*> ma = mf >>= (\fun => map (fun $) ma)`

### 演習 その3

1. あらゆる`Applicative`は`Functor`でもあるので、`Applicative`は`Functor`の拡張です。
   このことを`map`を`pure`と`(<*>)`を使って実装することで証明してください。

2. あらゆる`Monad`は`Applicative`でもあるので、`Monad`は`Applicative`の拡張です。
   このことを`(<*>)`を`(>>=)`と`pure`を使って実装することで証明してください。

3. `(>>=)`を`join`と`Monad`に階層的に含まれる他の関数を使って実装してください。

4. `join`を`(>>=)`と`Monad`に階層的に含まれる他の関数を使って実装してください。

5. `Validated e`への合法な`Monad`実装はありません。
   なぜですか？

6. この若干発展的な演習では、データ保管所でのCRUD操作を模擬していきます。
   可変参照（*base*ライブラリの`Data.IORef`からインポートされます）を使い、
   利用者データベースとして`User`とこれに紐付く一意の`Nat`型のIDのリストを保持します。

   ```idris
   DB : Type
   DB = IORef (List (Nat,User))
   ```

  データベース上のほとんどの操作は失敗する危険性が付いて回ります。
  利用者を更新したり削除したりしようとするときには、
  対象のエントリがもはやそこにいないかもしれません。
  新しい利用者を加える際、与えられたEmailアドレスを持つ利用者が既に存在するかもしれません。
  以下がこれを扱う自前のエラー型です。

   ```idris
   data DBError : Type where
     UserExists        : Email -> Nat -> DBError
     UserNotFound      : Nat -> DBError
     SizeLimitExceeded : DBError
   ```

  したがって一般にここでの関数は以下のような型を持ちます。

   ```idris
   someDBProg : arg1 -> arg2 -> DB -> IO (Either DBError a)
   ```

  新しい梱包型を導入することで、これを抽象化したいと思います。

   ```idris
   record Prog a where
     constructor MkProg
     runProg : DB -> IO (Either DBError a)
   ```

  これでいくつかのユーティリティ関数を書く準備ができました。
  以下の関数を実装するときには次の取り決めにしたがうようにしてください。

   * DB中のEmailアドレスは一意でなくてはならない。
     （これを検証するために`Eq Email`を実装することを検討してください。）

   * 上限1000項目の大きさを超過してはいけない。

   * 利用者をIDで見付けだそうとする操作は、DBに項目が見付からなかった場合は`UserNotFound`で失敗しなければいけない。

  可変参照を扱う際は`Data.IORef`の次の関数が必要になるでしょう。
  すなわち、`newIORef`、`readIORef`、そして`writeIORef`です。
  加えて関数`Data.List.lookup`と`Data.List.find`は以降の関数を実装するのに便利なことなことがあります。

   1. インターフェース`Functor`、`Applicative`、`Monad`を`Prog`に実装してください。

   2. インターフェース`HasIO`を`Prog`に実装してください。

   3. 以下のユーティリティ関数を実装してください。

      ```idris
      throw : DBError -> Prog a

      getUsers : Prog (List (Nat,User))

      -- 項目数の上限を検査してください！
      putUsers : List (Nat,User) -> Prog ()

      -- `getUsers`と`putUsers`を使って実装してください。
      modifyDB : (List (Nat,User) -> List (Nat,User)) -> Prog ()
      ```

   4. 関数`lookupUser`を実装してください。
      この関数は与えられたIDに紐付く利用者が見付からなかったときは適切なエラーで失敗します。

      ```idris
      lookupUser : (id : Nat) -> Prog User
      ```

   5. 関数`deleteUser`を実装してください。
      この関数は与えられたIDに紐付く利用者が見付からなかったときは適切なエラーで失敗します。
      実装では`lookupUser`を使ってください。

      ```idris
      deleteUser : (id : Nat) -> Prog ()
      ```

   6. 関数`addUser`を実装してください。
      与えられた`Email`に紐付く利用者が既に存在していたり、
      データバンクの項目数上限である1000項目を超過したりした場合は、この関数は失敗します。
      加えてこの関数は新しい利用者の項目についての一意なIDを作って返します。

      ```idris
      addUser : (new : User) -> Prog Nat
      ```

   7. 関数`updateUser`を実装してください。
      問題の利用者が見付からなかったり更新された利用者の`Email`が既に存在している場合は失敗します。
      返値は更新された利用者です。

      ```idris
      updateUser : (id : Nat) -> (mod : User -> User) -> Prog User
      ```

   8. 実はデータ型`Prog`は限定的すぎます。
      エラー型と`DB`環境を抽象化することができます。

      ```idris
      record Prog' env err a where
        constructor MkProg'
        runProg' : env -> IO (Either err a)
      ```

      `Prog`に書いた全てのインターフェースの実装が、
      そのまま`Prog' env err`への同じインターフェースを実装するのに使えることを確認してください。
      関数の型に僅かに調整が必要ですが、それ以外は`throw`についても同じことが言えます。

## 背景とさらなる文献

*関手*や*モナド*といった概念は数学の一分野である*圏論*に起源があります。
それぞれの法則が来ているのもそこからです。
圏論はプログラミング言語理論への応用が発見されていますが、特に関数型言語で顕著です。
高度に抽象的な話題ですが、[Bartosz
Milewski](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/)によって書かれたプログラマにとってかなり手を出しやすい導入があります。

関手とモナドの中間地点としてのアプリカティブ関手の実用性は、Haskellで既にモナドが使われるようになってから数年後に発見されました。こちらは記事[*作用つきアプリカティブプログラミング*
(Applicative Programming with
Effects)](https://www.staff.city.ac.uk/~ross/papers/Applicative.html)で紹介されています。オンラインで自由に見ることができ、読まれることを強くお勧めします。

## まとめ

* インターフェース`Functor`、`Applicative`、そして`Monad`は、
  型`Type -> Type`の型構築子を扱うときに引き合いに出されるプログラミング様式を抽象化します。
  そのようなデータ型は*文脈付きの値*や*作用付き計算*としても参照されます。

* `Functor`があれば、文脈に土台の構造に影響することなく、文脈中の値を*写す*ことができます。

* `Applicative`があれば、
  n個の作用付き計算にn引数関数を適用したり、純粋な値を文脈に持ち上げたりすることができます。

* `Monad`があれば作用付き計算を連鎖させることができます。
  この連鎖では中間結果がその後どの計算を走らせるかに影響させられます。

* `Monad`とは異なり、`Functor`と`Applicative`は組み合わさります。
  2つの関手やアプリカティブの積や合成はこれまたそれぞれ関手やアプリカティブとなります。

* Idrisはここで提示したインターフェースのいくつかについて扱うための糖衣構文を提供します。
  `Applicative`の慣用括弧や*do記法*、そして`Monad`のびっくり演算子です。

### お次は？

[次章](Folds.md)では再帰、全域性検査、
そして容器型を折り畳むインターフェースである`Foldable`について学び始めます。

<!-- vi: filetype=idris2:syntax=markdown
-->
