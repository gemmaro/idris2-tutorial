# 作用付き巡回

この章では最終的に*Prelude*にある高度な種のインターフェースの扱いを取り入れていきます。
そうするために章[関手とその仲間達](Functor.md)で実装し始めたCSV読み取り機の開発を継続していきます。
その章からいくつかのデータ型とインターフェースをそれ自体のモジュールに移したため、
ここでそれらを輸入することができ、一から書き直す必要はありません。

なお元のCSV読み取り機とは異なり例外を扱うのに`Either`の代わりに`Validated`を使っていきます。
そうするとCSVファイルを読み込むときの全てのエラーを累積できるからです。

```idris
module Tutorial.Traverse

import Data.HList
import Data.IORef
import Data.List1
import Data.String
import Data.Validated
import Data.Vect
import Text.CSV

%default total
```

## CSVの表を読む

CSV読み取り機の開発は関数`hdecode`で止めていました。
この関数があるとCSVファイル中の単一行を読み混成リストに複合できます。
思い起こすと以下がREPLでの`hdecode`の使い方でした。

```repl
Tutorial.Traverse> hdecode [Bool,String,Bits8] 1 "f,foo,12"
Valid [False, "foo", 12]
```

次の工程はCSVの表全体を構文解析することです。
表は文字列のリストで表現され、それぞれの文字列は表の行の1つに対応します。
これを適切に行うにはいくつかの側面があるため段階的に進めていきましょう。
今求めているものは……最終的に……以下の型の関数です。
（この関数のいくつかの版を実装していくため、連番を振っています。）

```idris
hreadTable1 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
```

最初の実装では行番号は気にしないことにします。

```idris
hreadTable1 _  []        = pure []
hreadTable1 ts (s :: ss) = [| hdecode ts 0 s :: hreadTable1 ts ss |]
```

なお`hreadTable1`実装で単にアプリカティブ構文を使っています。
わかりやすくするために最初の行でより限定的な`Valid []`の代わりに`pure []`を使いました。
実際`Validated`の代わりに`Either`や`Maybe`をエラー制御に使う場合、
`hreadTable1`の実装はちょうど同じになるでしょう。

疑問に思うのは、この観察から様式を抽象的なものに取り出せないかということです。
`hreadTable1`でしていることは、
文字列のリストに
型`String -> Validated CSVError (HList ts)`の作用付き計算を走らせていることなので、
結果は`Hlist ts`のリストを`Validated CSVError`に包んだものになります。
抽象化の最初の工程は入出力に型変数を使うことです。
つまり`List a`のリストに型`a -> Validated CSVError b`の計算を走らせることになります。

```idris
traverseValidatedList :  (a -> Validated CSVError b)
                      -> List a
                      -> Validated CSVError (List b)
traverseValidatedList _ []        = pure []
traverseValidatedList f (x :: xs) = [| f x :: traverseValidatedList f xs |]

hreadTable2 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
hreadTable2 ts = traverseValidatedList (hdecode ts 0)
```

しかし観察したところでは、
`hreadTable1`の実装で`Validated CSVError`の代わりに
`Either CSVError`や`Maybe`を作用型として使っても、
ちょうど同じになるだろうというものでした。
なので次の工程は*作用型*を抽象化することになりましょう。
なお実装ではアプリカティブ構文（慣用括弧と`pure`）を使っているので、
作用型について`Applicative`制約付きで関数を書く必要があります。

```idris
traverseList :  Applicative f => (a -> f b) -> List a -> f (List b)
traverseList _ []        = pure []
traverseList f (x :: xs) = [| f x :: traverseList f xs |]

hreadTable3 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List String
            -> Validated CSVError (List $ HList ts)
hreadTable3 ts = traverseList (hdecode ts 0)
```

`traverseList`の実装がちょうど`traverseValidatedList`のそれと同じですが、
型がより一般的になり、したがって`traverseList`がより強力になった点に注目です。

ちょっとREPLで動かしてみましょう。

```repl
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,0"]
Valid [[False, 12], [True, 0]]
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["f,12","t,1000"]
Invalid (FieldError 0 2 "1000")
Tutorial.Traverse> hreadTable3 [Bool,Bits8] ["1,12","t,1000"]
Invalid (Append (FieldError 0 1 "1") (FieldError 0 2 "1000"))
```

既にとてもよく動作していますが、エラー文言がまだ正しい行番号を印字していませんね。
これは驚くことではなく、`hdecode`を呼ぶところで仮の定数を使っているからです。
この章の後のほうで状態付き計算についてお話しするときに、
どのようにすれば行番号を自然に出せるのかを見ていきます。
現段階では単に手作業でそれぞれの数で行を註釈し`hreadTable`に対のリストを渡すことができます。

```idris
hreadTable4 :  (0 ts : List Type)
            -> CSVLine (HList ts)
            => List (Nat, String)
            -> Validated CSVError (List $ HList ts)
hreadTable4 ts = traverseList (uncurry $ hdecode ts)
```

関数`uncurry`に始めて出喰わしたのであれば、
必ず型を見てみた上で、なぜここで使われているのか調べてみてください。
このようないくつかの便利関数が*Prelude*にあり、
`curry`、`uncurry`、`flip`、果ては`id`なんかがそうです。
これらは全て高階関数に取り組む際にとても便利なものです。

完全ではありませんが、
この版があれば少なくともREPLで行番号がエラー文言に正しく渡されていることを確かめられます。

```repl
Tutorial.Traverse> hreadTable4 [Bool,Bits8] [(1,"t,1000"),(2,"1,100")]
Invalid (Append (FieldError 1 2 "1000") (FieldError 2 1 "1"))
```

### インターフェースTraversable

さて、ここで興味深い観点があります。
他の容器型についても`traverseList`のような関数も同様に実装できるのです。
容器型をインターフェース`Foldable`の関数`toList`を介してリストにできるなら、
それは明らかなことだと思われるかもしれません。
しかし、`List`を介してうまくいく場合もあるでしょうが、一般的には望ましくはありません。
というのも型情報を緩めてしまうためです。
例えば以下はそのような`Vect`のための関数です。

```idris
traverseVect' : Applicative f => (a -> f b) -> Vect n a -> f (List b)
traverseVect' fun = traverseList fun . toList
```

元の容器型の構造についての全情報が失われてしまいましたね。
今求めているものはこの型水準情報を保持する`traverseVect`のような関数です。
結果は入力が同じ長さのベクタであるべきです。

```idris
traverseVect : Applicative f => (a -> f b) -> Vect n a -> f (Vect n b)
traverseVect _   []        = pure []
traverseVect fun (x :: xs) = [| fun x :: traverseVect fun xs |]
```

ぐっと良くなりました！
そして上に書いたように`List1`、`SnocList`、`Maybe`などといった他の容器型にも簡単に同じことができます。
例に漏れずいくつかの派生関数が`traverseXY`から直ちにしたがいます。
例えば以下。

```idris
sequenceList : Applicative f => List (f a) -> f (List a)
sequenceList = traverseList id
```

こうなると新しいインターフェースが必要になりますが、
それは`Traversable`と呼ばれており*Prelude*から輸出されています。
以下は定義です。
（曖昧回避のためプライム記号を付けました。）

```idris
interface Functor t => Foldable t => Traversable' t where
  traverse' : Applicative f => (a -> f b) -> t a -> f (t b)
```

関数`traverse`は*Prelude*で手に入る最も抽象的で多芸な関数の1つです。
どれほど強力なのかはコードで何度も何度も使いだしてこそ明らかになるでしょう。
しかしこの章の残りの目標はいくつかの幅広く興味深い使用例をお見せすることです。

今のところ抽象の度合いに目を向けていきます。
関数`traverse`は少なくとも4つの変数を引数に取ります。
容器型`t`（`List`、`Vect n`、`Maybe`、枚挙に暇がありません）、
作用型（`Validated e`、`IO`、`Maybe`、など）、
入力要素型`a`、そして出力要素型`b`です。
Idrisプロジェクトに組込まれたライブラリが`Applicative`の実装が付いた30以上のデータ型と
10以上の巡回可能容器型を輸出していることを考えると、
作用付き計算で容器を巡回する文字通り100通りの組み合わせがあることになります。
巡回可能容器……例えばアプリカティブ関手……が合成で閉じていることに気付けばこの数はさらに大きくなります。
（演習とこの章の最後の節を参照してください。）

### 巡回可能法則

関数`traverse`が従わなければいけない2つの法則があります。

* `traverse (Id . f) = Id . map f`: `Identity`モナドを巡回することは単なる関手`map`です。
* `traverse (MkComp . map f . g) = MkComp . map (traverse f) . traverse g`:
  作用の合成で巡回することは
  1回の巡回（左側）でも2つの巡回の並び（右側）でも同じようにできなくてはいけません。

（関手の同値法則から）`map id = id`なので、
最初の法則から`traverse Id = Id`を導出できます。
この意味は、`traverse`は容器型の大きさや形を変えてはならず、
要素の順番も変えることが許されていないということです。

### 演習 その1

1. `Traversable`が`Functor`制約を持つことは興味深いことです。
   `map`を`traverse`を使って実装することにより、
   全ての`Traversable`が独りでに`Functor`になることを証明してください。

   解決の糸口：`Control.Monad.Identity`を思い出してください。

2. 同様に`Traverse`を使って`foldMap`を実装することにより、
   全ての`Traversable`が`Foldable`であることを証明してください。

   解決の糸口：`Control.Applicative.Const`を思い出してください。

3. 反復練習のため`Traversable`を`List1`、`Either e`、そして`Maybe`に実装してください。

4. `Traversable`を`List01 ne`に実装してください。

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

5. `Traversable`を木薔薇に実装してください。
   ズルすることなく全域性検査器を満足させてみてください。

   ```idris
   record Tree a where
     constructor Node
     value  : a
     forest : List (Tree a)
   ```

6. `Traversable`を`Crud i`に実装してください。

   ```idris
   data Crud : (i : Type) -> (a : Type) -> Type where
     Create : (value : a) -> Crud i a
     Update : (id : i) -> (value : a) -> Crud i a
     Read   : (id : i) -> Crud i a
     Delete : (id : i) -> Crud i a
   ```

7. `Traversable`を`Response e i`に実装してください。

   ```idris
   data Response : (e, i, a : Type) -> Type where
     Created : (id : i) -> (value : a) -> Response e i a
     Updated : (id : i) -> (value : a) -> Response e i a
     Found   : (values : List a) -> Response e i a
     Deleted : (id : i) -> Response e i a
     Error   : (err : e) -> Response e i a
   ```

8. `Functor`、`Applicative`、`Foldable`と同様に、
   `Traversable`は合成の元で閉じています。
   `Traversable`を`Comp`と`Product`に実装することでこれを証明してください。

   ```idris
   record Comp (f,g : Type -> Type) (a : Type) where
     constructor MkComp
     unComp  : f (g a)

   record Product (f,g : Type -> Type) (a : Type) where
     constructor MkProduct
     fst : f a
     snd : g a
   ```

## 状態付きプログラミング

CSV読み取り機に戻りましょう。
合理的なエラー文言を得るために、それぞれの行にインデックスを札付けしたいと思います。

```idris
zipWithIndex : List a -> List (Nat, a)
```

もちろんこれに場当たりの実装を思い付くのはとても簡単です。

```idris
zipWithIndex = go 1
  where go : Nat -> List a -> List (Nat,a)
        go _ []        = []
        go n (x :: xs) = (n,x) :: go (S n) xs
```

これは充分完璧ですが、それでも同じことを木、ベクタ、非空リストなどなどの要素についても行いたくなるかもしれない、
ということには注意すべきです。
そして繰り返しますが、そのような計算を記述するのに使える何らかの抽象化の形式があるかどうかに興味があるのです。

### Idrisでの可変参照

少しの間、そうしたことを命令型言語ではどのようにするのかについて考えましょう。
そこでは恐らく局所（可変）変数を定義し現在のインデックスを追跡することでしょう。
このインデックスはリスト上を`for`や`while`ループで繰り返す間に増加されます。

Idrisではそのような可変状態はありません。
それともあるのでしょうか？
思い出してほしいのですが、以前の演習でデータベース接続を模擬するのに可変参照を用いました。
そこでは実際には何らかの本当の可変参照を使っていました。
しかし可変変数を閲覧したり変更したりすることは参照透過操作ではなく、
そのような動作は`IO`の裡に実施されねばなりません。
さもなくば、コードで可変変数を使わない手はありません。
必要な機能は*base*ライブラリのモジュール`Data.IORef`から手に入ります。

軽い演習として1つ関数を実装してみましょう。
この関数は……`IORef Nat`が与えられると……インデックスを増加した後で値と現在のインデックスを対にします。

筆者がするとすれば以下になります。

```idris
pairWithIndexIO : IORef Nat -> a -> IO (Nat,a)
pairWithIndexIO ref va = do
  ix <- readIORef ref
  writeIORef ref (S ix)
  pure (ix,va)
```

なお毎回`pairWithIndexIO ref`を*走らせ*ており、
`ref`に保管された自然数は1増加します。
また、`pairWithIndexIO ref`の型を見ると`a -> IO (Nat,a)`となっています。
この作用付き計算をリスト中のそれぞれの要素に適用したいのですが、
そうなると`IO`に包まれた新しいリストに至ります。
なぜならこの全ては副作用のある単一の計算を記述しているからです。
しかしこれは*ちょうど*関数`traverse`がすることです。
ここでの入力型は`a`で、出力型は`(Nat,a)`で、
容器型は`List`で、そして作用型は`IO`なのです！

```idris
zipListWithIndexIO : IORef Nat -> List a -> IO (List (Nat,a))
zipListWithIndexIO ref = traverse (pairWithIndexIO ref)
```

さて*これ*は本当に強力です。
同じ関数を*どんな*巡回可能データ構造に適用できるからです。
したがって`zipListWithIndexIO`をリストのみに特殊化することは全くの無意味になります。

```idris
zipWithIndexIO : Traversable t => IORef Nat -> t a -> IO (t (Nat,a))
zipWithIndexIO ref = traverse (pairWithIndexIO ref)
```

私達の理知的な頭脳を満たすために、ポイントフリー形式の同じ関数を以下に示します。

```idris
zipWithIndexIO' : Traversable t => IORef Nat -> t a -> IO (t (Nat,a))
zipWithIndexIO' = traverse . pairWithIndexIO
```

今残っていることは`zipWithIndexIO`に渡す前に新しい可変変数を初期化することです。

```idris
zipFromZeroIO : Traversable t => t a -> IO (t (Nat,a))
zipFromZeroIO ta = newIORef 0 >>= (`zipWithIndexIO` ta)
```

ちょっとREPLで動かしてみましょう。

```repl
> :exec zipFromZeroIO {t = List} ["hello", "world"] >>= printLn
[(0, "hello"), (1, "world")]
> :exec zipFromZeroIO (Just 12) >>= printLn
Just (0, 12)
> :exec zipFromZeroIO {t = Vect 2} ["hello", "world"] >>= printLn
[(0, "hello"), (1, "world")]
```

こうしてそれぞれの要素をインデックスで札付けする問題をひとたび、
また全ての巡回可能容器型について解決しました。

### 状態モナド

ああ、上で提示した解法は流麗で実によく動きますが、
それでも`IO`の染みを引き摺っています。
この染みは既に`IO`の世界にいるなら構わないのですが、
そうでなければ受け入れ難いものです。
状態付きの要素の札付けという単純な場合のためだけに、
純粋関数を遥かに検査したり検証したりしにくくしたくありません。

幸運にも可変参照を使うことの代替となるものが存在します。
これがあると計算を純粋で汚染されていない状態に保つことができます。
しかしこの代替策を自力で閃くことは易しいものではなく、
ここで何が起こっているのか解明することは難しいかもしれません。
なのでこれについてはゆっくりと紹介してみようと思います。
まず純粋計算であること以外で「状態付き」に必須のものについて自問せねばなりません。
2つの必須の材料があります。

1. *現在の*状態を閲覧すること。
   純粋関数の場合、これが意味するのは関数が現在の状態を引数の1つとして取るべきであるということです。
2. 更新された状態を後の状態付き計算に伝える能力。
   純粋関数の場合にこれが意味するのは、
   関数が値の対を返すということです。
   計算の結果に加えて更新された状態の対です。

これら2つの前提条件から、型`st`の状態を操作し型`a`の値を生産する純粋で状態付きの計算のための、
以下の汎化型が導かれます。

```idris
Stateful : (st : Type) -> (a : Type) -> Type
Stateful st a = st -> (st, a)
```

ここでの用例は要素をインデックスと対にすることで、
これは以下のような純粋で状態付きの計算として実装することができます。

```idris
pairWithIndex' : a -> Stateful Nat (Nat,a)
pairWithIndex' v index = (S index, (index,v))
```

インデックスを増加すると同時に、新しい状態として増加した値を返していますね。
また最初の引数を元のインデックスと対にしています。

さて、ここで注意すべき大切なことがあります。
`Stateful`は便利な型別称ですが、
Idrisは一般的に関数型のためにインターフェース実装を解決*しません*。
したがって、そのような型に便利関数の小さなライブラリを書きたければ、
単一構築子データ型に包んでより複雑な計算を書く建築ブロックとして使うのが一番です。
そこで純粋な状態付き計算のための梱包としてレコード`State`を導入します。

```idris
record State st a where
  constructor ST
  runST : st -> (st,a)
```

これで`State`を使って以下のように`pairWithIndex`を実装することができます。

```idris
pairWithIndex : a -> State Nat (Nat,a)
pairWithIndex v = ST $ \index => (S index, (index, v))
```

加えていくつかの便利関数を定義することができます。
以下は現在の状態を変更することなく取得するものです。
（これは`readIORef`に対応します。）

```idris
get : State st st
get = ST $ \s => (s,s)
```

以下にもう2つあり、現在の状態を上書きするものです。
これらは`writeIORef`と`modifyIORef`です。

```idris
put : st -> State st ()
put v = ST $ \_ => (v,())

modify : (st -> st) -> State st ()
modify f = ST $ \v => (f v,())
```

最後に`runST`に加えて作用付き計算を走らせるための3つの関数を定義できます。

```idris
runState : st -> State st a -> (st, a)
runState = flip runST

evalState : st -> State st a -> a
evalState s = snd . runState s

execState : st -> State st a -> st
execState s = fst . runState s
```

これら全てはそれ自体便利なものですが、
`State s`の真の力はそれがモナドであるという観察から来ています。
読み進める前に時間を取って`Functor`、`Applicative`、`Monad`を`State s`に自力で実装してみてください。
たとえうまくいかなかったとしても以下の実装が動く仕組みを理解するのはより簡単になるでしょう。

```idris
Functor (State st) where
  map f (ST run) = ST $ \s => let (s2,va) = run s in (s2, f va)

Applicative (State st) where
  pure v = ST $ \s => (s,v)

  ST fun <*> ST val = ST $ \s =>
    let (s2, f)  = fun s
        (s3, va) = val s2
     in (s3, f va)

Monad (State st) where
  ST val >>= f = ST $ \s =>
    let (s2, va) = val s
     in runST (f va) s2
```

これを消化するには時間が掛かるかもしれないので、
僅かに発展的な演習で立ち返ることにします。
気を付けるべき最も重要なことは、
全ての状態値を必ず1度だけ使うということです。
更新された状態が後の計算に渡されることを確かめる*必要*があり、
さもなければ状態更新についての情報が失われてしまいます。
これは`Applicative`の実装が一番よくわかります。
初期状態は`s`で、関数値の計算で使われ、
更新された状態`s2`を返し、
それから関数引数の計算で使われるのです。
これは再び更新された状態`s3`を返し、
`f`を`va`に適用した結果と共に後の状態付き計算へ渡されます。

### 演習 その2

本節には2つの発展的な演習があり、その目的は状態モナドの理解を増すことです。
最初の演習で状態付き計算の古典的応用である乱択値生成を見ます。
2つ目の演習で状態モナドの指標付けされた版を見ます。
これがあると計算中に状態の値だけでなく*型*も変えることができるようになります。

1. 以下は単純な疑似乱数生成器の実装です。
   *疑似乱*数生成器と読んでいますが、
   これはその数がかなり乱択に見えるものの予見された通りに生成されるためです。
   もし真に乱択な種でそのような計算の並びを初期化したならば、
   ライブラリのほとんどの利用者はこの計算の出力を予期できないでしょう。

   ```idris
   rnd : Bits64 -> Bits64
   rnd seed = fromInteger
            $ (437799614237992725 * cast seed) `mod` 2305843009213693951
   ```

   ここでの考え方は次の疑似乱数が前のものから計算されるということです。
   しかしひとたびこれらの数を種として他の型の乱択値を計算するのに使う方法を考えれば、
   これらが単なる状態付き計算であることに気が付きます。
   したがって乱択値生成器の別称を状態付き計算として書き下すことができます。

   ```idris
   Gen : Type -> Type
   Gen = State Bits64
   ```

   始める前に`rnd`があまり強力でない疑似乱数生成器であることにお気を付けください。
   64ビット全域の値を生成しないでしょうし、
   暗号的アプリケーションで使用することは安全ではありません。
   この章での目的には充分ではありますが。
   もう1点、この演習の一部で実装することになる関数に指1本触れず
   `rnd`をより強力な生成器に置き換えることができます。

   1. `rnd`を使って`bits64`を実装してください。
      これは現在の状態を関数`rnd`を呼び出すことで更新したものを返します。
      必ず状態が適切に更新されているようにしてください。
      さもないと期待通りに動きません。

      ```idris
      bits64 : Gen Bits64
      ```

      これは*唯一*の原始生成器となります。
      ここから他の全てのものを導出していきます。
      したがって続ける前に、REPLで簡単に`bits64`の実装を試してください。

      ```repl
      Solutions.Traverse> runState 100 bits64
      (2274787257952781382, 100)
      ```

   2. 範囲`[0,upper)`にある乱択値を生成する`range64`を実装してください。
      手掛かり：実装で`bits64`と`mod`を使ってほしいのですが、
      必ず`mod x upper`が範囲`[0,upper)`中の値を生成するという事実に即してください。

      ```idris
      range64 : (upper : Bits64) -> Gen Bits64
      ```

      同様に範囲`[min a b, max a b]`にある値を生成する`interval64`を実装してください。

      ```idris
      interval64 : (a,b : Bits64) -> Gen Bits64
      ```

      最後に任意の整数型用の`interval`を実装してください。

      ```idris
      interval : Num n => Cast n Bits64 => (a,b : n) -> Gen n
      ```

      なお`interval`は与えられた間の領域にある全ての取り得る値を生成するわけではありません。
      範囲`[0,2305843009213693950]`中にある`Bits64`の表現上の値のみです。

   3. 乱択真偽値の生成器を実装してください。

   4. `Fin n`の生成器を実装してください。
      この生成器が型検査を通りズルすることなく全域性検査器に受け付けられるよう、注意深く考えなくてはいけません。
      補足：関数`Data.Fin.natToFin`を見てみてください。

   5. 複数の値からなるベクタから要素を乱択する生成器を実装してください。
      実装では演習4の生成器を使ってください。

   6. `vect`と`list`を実装してください。
      `list`の場合、最初の引数はリストの長さを乱択に決定するために使います。

      ```idris
      vect : {n : _} -> Gen a -> Gen (Vect n a)

      list : Gen Nat -> Gen a -> Gen (List a)
      ```

      REPLで生成器を試すために、`vect`を使って便利関数`testGen`を実装してください。

      ```idris
      testGen : Bits64 -> Gen a -> Vect 10 a
      ```

   7. `choice`を実装してください。

      ```idris
      choice : {n : _} -> Vect (S n) (Gen a) -> Gen a
      ```

   8. `either`を実装してください。

      ```idris
      either : Gen a -> Gen b -> Gen (Either a b)
      ```

   9. 印字できるASCII文字の生成器を実装してください。
      これらの文字は`[32,126]`の合間にあるASCIIコードです。
      手掛かり：*Prelude*の関数`chr`がここでは便利でしょう。

   10. 文字列用の生成器を実装してください。
       手掛かり：これには*Prelude*の関数`pack`が便利かもしれません。

       ```idris
       string : Gen Nat -> Gen Char -> Gen String
       ```

   11. Idrisにおいて、型にまつわる興味深い事柄を織り込むことができる点を忘れるべきではありません。
       なので1つの挑戦として、難しい話は抜きにして、`hlist`を実装してください（`HListF`と`HList`の区別に注意してください）。
       もし依存型に慣れていなければ、飲み込むのに少し時間が掛かるかもしれませんから、虫食いを使うのを忘れないようにしてください。

       ```idris
       data HListF : (f : Type -> Type) -> (ts : List Type) -> Type where
         Nil  : HListF f []
         (::) : (x : f t) -> (xs : HLift f ts) -> HListF f (t :: ts)

       hlist : HListF Gen ts -> Gen (HList ts)
       ```

   12. `hlist`を一般化して`Gen`だけでなくどんなアプリカティブ関手でも動くようにしてください。

  ここまで辿り着いたら、
  現時点でほとんどの原始型について疑似乱数値を生成できていることに着目してください。
  またこれは通常の直和型と直積型についても同様です。
  以下はREPLセッションの例です。

   ```repl
   > testGen 100 $ hlist [bool, printableAscii, interval 0 127]
   [[True, ';', 5],
    [True, '^', 39],
    [False, 'o', 106],
    [True, 'k', 127],
    [False, ' ', 11],
    [False, '~', 76],
    [True, 'M', 11],
    [False, 'P', 107],
    [True, '5', 67],
    [False, '8', 9]]
   ```

   最後に1つ、疑似乱択値生成器は[QuickCheck](https://hackage.haskell.org/package/QuickCheck)
   や[Hedgehog](https://github.com/stefan-hoeck/idris2-hedgehog)のような
   性質に基づく検査ライブラリで重要な役割を担います。
   性質に基づく検査は事前に定義された純粋関数の*性質*を、
   大量の乱択して生成された引数に対して検査することで、
   こうした性質が*全て*の可能な引数について満たされていることについての
   強力な保証を得るものです。
   1例としてリストを2回反転させた結果は元のリストに等しいという試験が挙げられます。
   Idrisでは比較的単純な性質の多くは試験する必要がなく証明することができますが、
   関数が込み入るや否やもはや可能ではなくなります。
   異邦関数呼び出しや関数が他のモジュールから公に輸出されていないときなどは
   統合化中の簡約がなされないためです。

2. `State s a`は状態付き計算について語るのに便利な方法を与えるものですが、状態の*値*は変えられても*型*はその限りではありませんでした。
   例えば以下の関数は状態の型が変わるため`State`にカプセル化できません。

   ```idris
   uncons : Vect (S n) a -> (Vect n a, a)
   uncons (x :: xs) = (xs, x)
   ```

  やるべきことはそのような変化を許容する新しい状態型を思い付くことです。
  （時に*指標付けられた*状態データ型として参照されます。）
  この演習の目的は型水準で導出される関数型やインターフェースを含む物事を
  表現する技能を研ぎ澄ますことでもあります。
  したがって進め方については少しの導入のみとします。
  もし行き詰まったら自由に解法を覗き見して大丈夫ですが、
  必ずまずは型だけを見るようにしてください。


   1. 入出力の型が異なりうる状態付き計算をカプセル化する、引数を取るデータ型を思い付いてください。
      `uncons`をこの型の値に包むことができなくてはいけません。

   2. `Functor`を指標付けられた状態型に実装してください。

   3. `Applicative`をこの*指標付けられた*状態型に実装することはできません。
      （ただし演習 2.vii も見てください。）
      それでも慣用括弧を使うために必要な関数を実装してください。

   4. `Monad`をこの指標付けられた状態型に実装することはできません。
      それでもdoブロックの中に書くために必要な関数を実装してください。

   5. 演習3と4の関数を汎化して2つの新しいインターフェース
      `IxApplicatieve`と`IxMonad`とし、
      これらの実装を指標付けられた状態データ型に提供してください。

   6. 関数`get`、`put`、`modify`、`runState`、`evalState`、`execState`を
      指標付けられた状態データ型に実装してください。
      必要なときは必ず型変数を調整してください。

   7. 指標付けられた状態型が`State`よりはっきりとより強力であることを、
      `Applicative`と`Monad`を実装することで示してください。

      手掛かり：入出力の状態を同じに保ってください。
      なおまた、Idrisが型を正しく推論する上で問題が起きたら
      `join`を手作業で実装する必要があるかもしれません。

   指標付けられた状態型は、
   必ず状態付き計算が正しい並びで結合されているようにしたいときや、
   供給不足の資源を適切に整頓したい場合に便利です。
   そうした用例について後の例で立ち返ることでしょう。

## 合成の力

状態付き計算の世界を小旅行したあとは話を戻して、
1回の巡回でCSVの行を札付けしつつ読むために可変状態をエラーの累積と結合していきます。
既に行をインデックスで札付けする`pairWithIndex`を定義しました。
また、個々の札付けされた行を復号するための`uncurry $ hdecode ts`もあります。
これで2つの作用を結合して1度きりの計算にできます。

```idris
tagAndDecode :  (0 ts : List Type)
             -> CSVLine (HList ts)
             => String
             -> State Nat (Validated CSVError (HList ts))
tagAndDecode ts s = uncurry (hdecode ts) <$> pairWithIndex s
```

さて、前に学んだようにアプリカティブ関手は合成の元で閉じており、
`tagAndDecode`の結果は2つのアプリカティブ
`State Nat`と`Validated CSVError`の入れ子でした。
*Prelude*は対応する名前付きインターフェース実装 (`Prelude.Applicative.Compose`)
を輸出しており、`tagAndDecode`と共に文字列のリストを巡回するのに使えます。
ただ明示的に名前付き実装を提供しなければいけないことは覚えておいてください。
`traverse`には2つ目の制約としてアプリカティブ関手を持っているため、
最初の制約 (`Traversable`) についても明示的に提供する必要があるのです。
しかしこれは名前のない既定実装になってしまうでしょう！
そのような値を手に入れるには、`%search`プラグマを使うことができます。

```idris
readTable :  (0 ts : List Type)
          -> CSVLine (HList ts)
          => List String
          -> Validated CSVError (List $ HList ts)
readTable ts = evalState 1 . traverse @{%search} @{Compose} (tagAndDecode ts)
```

こうすることでIdrisに`Traversable`制約のために既定実装を、
`Applicative`制約に`Prelude.Applicative.Compose`を使うようにさせます。
この構文はあまりいい感じはしませんが、
あまりよく出てくるわけではなく、もしよく出てくるとしたら
自前の関数を提供することで可読性を改善することができます。

```idris
traverseComp : Traversable t
             => Applicative f
             => Applicative g
             => (a -> f (g b))
             -> t a
             -> f (g (t b))
traverseComp = traverse @{%search} @{Compose}

readTable' :  (0 ts : List Type)
           -> CSVLine (HList ts)
           => List String
           -> Validated CSVError (List $ HList ts)
readTable' ts = evalState 1 . traverseComp (tagAndDecode ts)
```

これで1回のリスト巡回で2つの計算作用（可変状態とエラー累積）
を結合することができましたね。

しかしまだ合成の力の実演は終わりではありません。
どこかの演習で見たように`Traversable`もまた合成で閉じているので、
巡回可能性の入れ子もまた巡回可能なのです。
以下の用例を考えてみましょう。
CSVファイルを読むとき、
行に追加の情報を註釈付けられるようにしたいとします。
そのような註釈はただのコメントでもよいですし、
何らかの書式指定や他の自前のデータタグについても可能です。
註釈は単一のハッシュ文字 (`#`) で他のの内容から分離しているとします。
これらのオプショナルな註釈を追跡したいため、
この区別を内包する自前のデータ型に思い至ります。

```idris
data Line : Type -> Type where
  Annotated : String -> a -> Line a
  Clean     : a -> Line a
```

これは単なる容器型で簡単に`Traversable`を`Line`に実装できます。
（簡単な演習として自力でやりましょう。）

```idris
Functor Line where
  map f (Annotated s x) = Annotated s $ f x
  map f (Clean x)       = Clean $ f x

Foldable Line where
  foldr f acc (Annotated _ x) = f x acc
  foldr f acc (Clean x)       = f x acc

Traversable Line where
  traverse f (Annotated s x) = Annotated s <$> f x
  traverse f (Clean x)       = Clean <$> f x
```

以下は行を構文解析して正しく分別する関数です。
簡単のために単純に行をハッシュで分割しています。
結果がちょうど2つの文字列からなるとき、
2つ目の部分を註釈として扱い、
そうでない場合は行全体を札付けされていないCSVの内容として扱います。

```idris
readLine : String -> Line String
readLine s = case split ('#' ==) s of
  h ::: [t] => Annotated t h
  _         => Clean s
```

いよいよ行の註釈を追跡しつつCSVの表全体を読む関数を実装していきます。

```idris
readCSV :  (0 ts : List Type)
        -> CSVLine (HList ts)
        => String
        -> Validated CSVError (List $ Line $ HList ts)
readCSV ts = evalState 1
           . traverse @{Compose} @{Compose} (tagAndDecode ts)
           . map readLine
           . lines
```

この異形を噛み砕いていきましょう。
これはポイントフリー形式で書かれており、終わりから始めに向かって読むことになります。
最初に（関数`Data.String.lines`で）全体の文字列を改行で分割して文字列のリストを得ます。
次に（`map readLine`で）それぞれの行を解析し、オプショナルな註釈を追跡します。
これにより型`List (Line String)`の値が得られます。
これは入れ子の巡回可能性なので、*Prelude*からの名前付きインスタンス`Prelude.Traversable.Compose`とともに`traverse`を呼び出しています。
Idrisはこれを型に基いて曖昧解決できるため、前置名前空間を省略できます。
しかし行のリスト上を走査する作用付き計算の結果はアプリカティブ関手の合成になるため、2つ目の制約でアプリカティブの合成のための名前付き実装も必要になるのです（ここでも`Prelude.Applicative`のような明示的な前置は必要ありません）。
最終的に`evalState 1`で作用付き計算を評価することができます。

正直言って動くかどうか確かめずに全部書いているので、
REPLで動かすことにしましょう。
これにはエラーのない妥当なものと不当なものの2つの文字列の例を提供します。
ここで*複数行文字列表記*を使いましたが、
後の章でより詳しくお話しします。
今のところこのお陰で便利に改行のある文字列表記を入力できるのだと思ってください。

```idris
validInput : String
validInput = """
  f,12,-13.01#this is a comment
  t,100,0.0017
  t,1,100.8#color: red
  f,255,0.0
  f,24,1.12e17
  """

invalidInput : String
invalidInput = """
  o,12,-13.01#another comment
  t,100,0.0017
  t,1,abc
  f,256,0.0
  f,24,1.12e17
  """
```

そして以下はREPLでの様子です。

```repl
Tutorial.Traverse> readCSV [Bool,Bits8,Double] validInput
Valid [Annotated "this is a comment" [False, 12, -13.01],
       Clean [True, 100, 0.0017],
       Annotated "color: red" [True, 1, 100.8],
       Clean [False, 255, 0.0],
       Clean [False, 24, 1.12e17]]

Tutorial.Traverse> readCSV [Bool,Bits8,Double] invalidInput
Invalid (Append (FieldError 1 1 "o")
  (Append (FieldError 3 3 "abc") (FieldError 4 2 "256")))
```

沢山のコードを書き、
いつも型と全域性の検査器に導かれながら、
最終的に適切に型付けられたCSVの表を構文解析する、
それも自動行番号とエラー累積付きの関数に行き着きました。
これはかなり驚くべきことです。

### 演習 その3

*Prelude*は`Either`や`Pair`のような*2つ*の型変数を引数に取る容器型要に
追加で3つのインターフェースを提供しています。
`Bifunctor`、`Bifoldable`、そして`Bitraversable`です。
以下の演習でこれらを扱って実際に手を動かす経験をします。
どのような関数を提供しておりどう実装して使うかを自力で調べ上げることになるでしょう。

1. CSVの内容だけではなく、CSVファイルのオプショナルな付記タグも解釈したいのだとします。
   このために`Tagged`のようなデータ型を使うことができるでしょう。

   ```idris
   data Tagged : (tag, value : Type) -> Type where
     Tag  : tag -> value -> Tagged tag value
     Pure : value -> Tagged tag value
   ```

   インターフェース`Functor`、`Foldable`、`Traversable`だけでなく
   `Bifunctor`、`Bifoldable`、`Bitraversable`も`Tagged`に実装してください。

2. `Either (List a) (Maybe b)`といった2つの関手からなる双関手の合成が、
   これまた双関手になることを、そのような合成専用の梱包型を定義して
   対応する実装を`Bifunctor`に書くことで示してください。
   同様に`Bifoldable`/`Foldable`と`Bitraversable`/`Traversable`についても行ってください。

3. `List (Either a b)`のような関手と双関手の合成がこれまた双関手であることを、
   そのような合成専用の梱包型を定義し対応する`Bifunctor`の実装を書くことで示してください。
   同様に`Bifoldable`/`Foldable`と`Bitraversable`/`Traversable`についても行ってください。

4. これから`readCSV`を調整して付記タグとCSVの内容が1回の巡回で復号されるようにしていきます。
   これには不当なタグを含む新しいエラー型が必要です。

   ```idris
   data TagError : Type where
     CE         : CSVError -> TagError
     InvalidTag : (line : Nat) -> (tag : String) -> TagError
     Append     : TagError -> TagError -> TagError

   Semigroup TagError where (<+>) = Append
   ```

   試験用に色タグ用の単純なデータ型も定義します。

   ```idris
   data Color = Red | Green | Blue
   ```

   これで以下の関数を実装し始められます。
   ただし`readColor`はエラー時に現在の行番号を読み取る必要がありますが、
   増加させてはいけないということにご注意ください。
   さもないと行番号が`tagAndDecodeTE`の呼び出しで誤ったものになってしまうからです。

   ```idris
   readColor : String -> State Nat (Validated TagError Color)

   readTaggedLine : String -> Tagged String String

   tagAndDecodeTE :  (0 ts : List Type)
                  -> CSVLine (HList ts)
                  => String
                  -> State Nat (Validated TagError (HList ts))
   ```

   最後に演習3の梱包型と共に`readColor`と`tagAndDecodeTE`を
   `bitraverse`の呼び出しで使うことで、`readTagged`を実装してください。
   実装は`readCSV`ととても似た見た目をしていますが、
   適切な箇所で追加の梱包と開封が行われています。

   ```idris
   readTagged :  (0 ts : List Type)
              -> CSVLine (HList ts)
              => String
              -> Validated TagError (List $ Tagged Color $ HList ts)
   ```

   REPLで実装を何らかの試しの文字列を使って試してください。


関手と双関手の合成についてのより多くの例はHaskellの
[bifunctors](https://hackage.haskell.org/package/bifunctors)パッケージにあります。

## まとめ

インターフェース`Traversable`とその主な関数`traverse`は物凄く強力な抽象化の形式であり、
`Applicative`と`Traversable`が合成の元で閉じているため尚更です。
さらなる用例に興味があれば、
`Traversable`をHaskellに導入した刊行物[The Essence of the Iterator
Pattern](https://www.cs.ox.ac.uk/jeremy.gibbons/publications/iterator.pdf)はかなり読むのにお勧めです。

*base*ライブラリはモジュール`Control.Monad.State`で状態モナドの拡張版を提供します。
これはモナド変換子についてお話しする際により詳しく見ていきます。
なおまた`IO`自体も、抽象的で原始的な状態型`%World`上の
[単純な状態モナド](IO.md#how-io-is-implemented)として実装されています。

この章で学んだことの要約は以下です。

* 関数`traverse`は作用付き計算を容器型に走らせるために使われます。
  ただし容器型の大きさや形には影響しません。
* `IO`で走らせる作用付き計算では可変参照として`IORef`が使えます。
* 「可変」状態を伴う参照透過な計算には`State`モナドが極めて便利です。
* アプリカティブ関手は合成の元で閉じているため、
  複数の作用付き計算を1回の巡回で走らせることができます。
* 巡回可能性も合成の元で閉じているため、`traverse`を使って入れ子の容器を操作することができます。

ここまででが*Prelude*の高階インターフェースの導入のまとめになります。これらのインターフェースは`Functor`の導入に始まり、`Applicative`や`Monad`、そして`Foldable`に移り、これらに優るとも劣らぬ`Traversable`で締め括りました。まだ1つ欠けている`Alternative`がありますが、これはもう少し待たねばなりません。なぜならまず、いくつかのより[型水準の魔術](./DPair.md)で脳を煙に巻かなくてはならないからです。

<!-- vi: filetype=idris2:syntax=markdown
-->
