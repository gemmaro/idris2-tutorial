# 依存型

値から型を計算したり、型を引数として関数に渡したり、型を関数からの結果として返したりできるということ、
これを端的に依存型言語であると言いますが、
そのことはIdrisの最も際立った特徴の1つです。
Haskellのような多くの（というかちょっと多すぎる）より発展的な型段階拡張を行う言語も、依存型を一息に処理できます。

```idris
module Tutorial.Dependent

%default total
```

以下の関数を考えます。

```idris
bogusMapList : (a -> b) -> List a -> List b
bogusMapList _ _ = []

bogusZipList : (a -> b -> c) -> List a -> List b -> List c
bogusZipList _ _ _ = []
```

実装は型検査を通りますがしかし、その実装は明らかにライブラリ利用者が期待するものではありません。
最初の例では実装で関数引数をリスト中に格納された全ての値に適用されることが期待されています。
1つとして欠落していてはいけませんし、順番が変わってもなりません。
2つ目はもう少し注意が必要です。
というのは、2つのリストの引数が異なる長さかもしれないからです。
その場合どうしたらいいのでしょうか。
2つのうち小さいほうのと同じ長さのリストを返すのでしょうか。
空リストを返すのでしょうか。
それともほとんどの使用例で2つのリストが同じ長さであることを期待すべきではないのでしょうか。
どうすればそのような前提条件を表現できるのでしょうか。

## 長さ指標付きリスト

上述した問題への答えはもちろん、依存型です。
そして最もよく知られた取っ掛かりの例は*ベクタ*、長さ指標付きリストです。

```idris
data Vect : (len : Nat) -> (a : Type) -> Type where
  Nil  : Vect 0 a
  (::) : (x : a) -> (xs : Vect n a) -> Vect (S n) a
```

進める前に、これと[代数的データ型の節](DataTypes.md)の`Seq`の実装を比較してください。
構築子はまったく同じで、`Nil`と`(::)`です。
それでも重大な違いがあります。
`Vect`は、`Seq`や`List`とは違い、`Type`から`Type`への関数ではなく、`Nat`から`Type`そして`Type`への関数なのです。
さあ、REPLを開いてこれを確かめましょう！
`Nat`引数（*指標*とも呼ばれます）はここではベクタの*長さ*を表しています。
`Nil`は型`Vect 0 a`で長さゼロのベクタです。
*Cons*は型`a -> Vect n a -> Vect (S n) a`です。
これは`n`2つ目の引数よりちょうど要素1つ分長い (`S n`) です。

この考え方を手を動かしてより深く理解しましょう。
長さがゼロのベクタを作る方法は1つだけです。

```idris
ex1 : Vect 0 Integer
ex1 = Nil
```

他方で以下は型エラーです。
（実際はかなり複雑なエラーです。）

```idris
failing "Mismatch between: S ?n and 0."
  ex2 : Vect 0 Integer
  ex2 = [12]
```

問題点は以下です。
`[12]`は`12 :: Nil`に脱糖されますが、
これは誤った型です！
`Nil`はここでは型`Vect 0 Integer`なので、`12 :: Nil`は型`Vect (S 0) Integer`、つまり`Vect 1
Integer`となります。
Idrisはベクタが正しい長さになっていることを、コンパイル時に検証するのです。

```idris
ex3 : Vect 1 Integer
ex3 = [12]
```

というわけでリストのようなデータ構造の*長さ*を*型*に書き換える方法がわかりました。
ベクタの要素数が型にある長さと合致しなければ*型エラー*になるのです。
すぐあとで幾つかの使用例を見ていきますが、
この追加情報により型をより精密なものにしてこれ以上のプログラミングの誤りを排除できます。
でもまずはさくっと幾つかの用語を明らかにしておかねばなりません。

### 型指標対型変数

`Vect`は汎化型、つまり保管している要素の型を変数として取るもの、というだけではなくて、
実のところは*型族*で、それぞれがその長さを表す自然数と関連付けられています。
もっと言うと型族`Vect`は長さが*指標付けられている*のです。

型変数と指標の違いは、後者がデータ構築子によって異なるようにすることができるということです。
対して前者は全てのデータ構築子について同じです。
あるいは視点を変えると、型族の*値*にパターン合致することで指標の*値*を知ることができますが、
これは型変数では不可能なことです。

以下のわざとらしい例について考えましょう。

```idris
data Indexed : Nat -> Type where
  I0 : Indexed 0
  I3 : Indexed 3
  I4 : String -> Indexed 4
```

ここで`Index`は`Nat`引数が指標付けられていますが、
それは指標値が構築子によって変わっているからです。
（それぞれの構築子には好きに値をを選びました。）
こうすると`Indexed`の値にパターン合致することでこれらの値がわかります。
例えばこれを`Indexed`の指標と同じ長さの`Vect`を作るのに使えます。

```idris
fromIndexed : Indexed n -> a -> Vect n a
```

さあ、自分でこれを実装してみましょう！
虫食いを使って`Indexed`引数でパターン合致し、そして虫食いとその文脈を調べることによって、それぞれの場合の期待される出力型を調べてください。

私の実装はこうです。

```idris
fromIndexed I0     va = []
fromIndexed I3     va = [va, va, va]
fromIndexed (I4 _) va = [va, va, va, va]
```

見てわかるように、`Indexed n`の引数の値にパターン合致することで`n`指標自体の値がわかり、
それを使って正しい長さの`Vect`を返す必要があるのです。

### 長さが保存された`map`

関数`bogusMapList`は期待した通りには振舞いませんでしたが、これはいつも空リストを返却していたからです。
これが`Vect`だったら型に正直でなければなりません。
`Vect`をmapする場合、引数*および*出力型は長さ指標を含んでおり、この長さ指標は*厳密に*ベクタの長さがどれほど変わったのかがわかります。

```idris
map3_1 : (a -> b) -> Vect 3 a -> Vect 1 b
map3_1 f [_,y,_] = [f y]

map5_0 : (a -> b) -> Vect 5 a -> Vect 0 b
map5_0 f _ = []

map5_10 : (a -> b) -> Vect 5 a -> Vect 10 b
map5_10 f [u,v,w,x,y] = [f u, f u, f v, f v, f w, f w, f x, f x, f y, f y]
```

こうした例はかなり面白いとはいえ、あまり便利ではありませんよね。
どうしてかというと、あまりにも局所的だからです。
どんな長さのベクタにもmapできる*汎化*関数がほしいものです。
型処方に固定長を使う代わりに、既に`Vect`の定義で見たように*変数*を使うこともできます。
これがあれば汎用的な場合を宣言できます。

```idris
mapVect' : (a -> b) -> Vect n a -> Vect n b
```

この型は長さが保存されたmapを表します。
暗黙引数も含めるようにすれば実際どうなっているのかがよりわかりやすくなります。
（必要ではありませんが。）

```idris
mapVect : {0 a,b : _} -> {0 n : Nat} -> (a -> b) -> Vect n a -> Vect n b
```

2つの型変数`a`と`b`は無視できます。
というのもこれらは単なる汎化関数を表しているからです（ただ、同じ型と数量子の引数を単一対の波括弧内にまとめられることは覚えておいてください。
これはやってもやらなくてもいいですが、型処方を少しだけ短くできることもあります）。
型`Nat`の暗黙引数はしかし、入出力の`Vect`が同じ長さであることを示しています。
この契約を履行しないと型エラーです。
`mapVect`を実装しているときなどでこの契約は大変説明的なもので、これに沿って実装したり虫食いを使ったりできます。
`Vect`の長さについての*どんな*情報を得るのにも、パターン合致が要ります。

```repl
mapVect _ Nil       = ?impl_0
mapVect f (x :: xs) = ?impl_1
```

このファイルをREPLセッションに読み込んで以下を試してみましょう。

```repl
Tutorial.Dependent> :t impl_0
 0 a : Type
 0 b : Type
 0 n : Nat
------------------------------
impl_0 : Vect 0 b


Tutorial.Dependent> :t impl_1
 0 a : Type
 0 b : Type
   x : a
   xs : Vect n a
   f : a -> b
 0 n : Nat
------------------------------
impl_1 : Vect (S n) b
```

最初の虫食い`impl_0`は型`Vect 0 b`です。
前述したようにそのような値は1つしかありません。

```idris
mapVect _ Nil       = Nil
```

2つ目の場合はこれまたもっと面白いものです。
`xs`は任意長の`n`（消去引数として与えられます）について型`Vect n a`であると書きました。
そうして結果は型`Vect (S n) b`なのです。
ということは、結果は`xs`よりも1要素分長くなければいけません。
運よく既に型`a`の値（変数`x`に束縛されています）があり、
`a`から`b`への関数（変数`f`に束縛されています）があるので、
`f`を`x`に適用して結果を未知の残りの部分の先頭にくっつけられます。

```repl
mapVect f (x :: xs) = f x :: ?rest
```

REPLで新しい虫食いを調べてみましょう。

```repl
Tutorial.Dependent> :t rest
 0 a : Type
 0 b : Type
   x : a
   xs : Vect n a
   f : a -> b
 0 n : Nat
------------------------------
rest : Vect n b
```

さて、`Vect n a`があり、`Vect n b`がほしいところです。
ただし`n`についてはなんにもわかりません。
さらに`xs`をパターン合致することで`n`をより知ることは*できはします*が、
すぐさまいたちごっこになってしまうでしょう。
というのはそのようなパターン合致をしたら、新しく未知の長さの尾鰭が生えるからです。
その代わり、`mapVect`を再帰的に呼び出して残り (`xs`) を`Vect n b`に変換できます。
`xs`と`mapVect f xs`の長さが等しいことは型検査器が保証してくれます。
式全体が型検査を通ったので、これにて完了です。

```idris
mapVect f (x :: xs) = f x :: mapVect f xs
```

### ベクタを縫い合わす

さて、`bogusZipList`を見てみましょう。
異な（りう）る型の要素を持つ2つのリストについて、所与の2引数関数を通して向かい合うものを1つに閉じるというものです。
前述したように、2つのリストと結果は何れも同じ長さになるのが一番理に適っています。
`Vect`があればこれは以下のように表現でき、実装されます。

```idris
zipWith : (a -> b -> c) -> Vect n a -> Vect n b -> Vect n c
zipWith f []        []         = Nil
zipWith f (x :: xs) (y :: ys)  = f x y :: zipWith f xs ys
```

さてさて、ここが面白いところです。
全域性検査器（最初の`%default total`プラグマがあるのでこのソースファイルを通じて有効）は、
あと2つ場合分けが足りないのですが、
上の実装を全域であるとして受理します。
これが動くのは、他の2つの場合が*不可能*であることを、
Idrisが自分で調べてくれるからです。
最初の`Vect`引数にパターン合致したことから、
Idrisは`n`がゼロかゼロよりあとに続く他の自然数だと読み取ります。
しかしここから、2つ目のベクタもまた長さが`n`であり、`Nil`ないし*cons*であることを導出できるのです。
それでも明示的に不可能な場合を加えたほうが親切なこともあります。
これには`impossible`キーワードが使えます。

```idris
zipWith _ [] (_ :: _) impossible
zipWith _ (_ :: _) [] impossible
```

もちろん、パターン合致中の場合に`impossible`を付けるのは、
Idrisがたしかに不可能だと確証できない限り、型エラーです。
後の節で、自分は不可能だとわかっているのにIdrisがわかってくれないときに、
どうすればよいのかを学びます。

ちょっとREPLで`zipWith`を動かしてみましょう。

```repl
Tutorial.Dependent> zipWith (*) [1,2,3] [10,20,30]
[10, 40, 90]
Tutorial.Dependent> zipWith (\x,y => x ++ ": " ++ show y) ["The answer"] [42]
["The answer: 42"]
Tutorial.Dependent> zipWith (*) [1,2,3] [10,20]
... ひどい型エラー ...
```

#### 型エラーを簡潔にする

Idrisがやってくれることの多さと、物事がうまく運んでいるときに自分で推論できることの多さには、目を瞠るものがあります。
しかし物事がうまく運んでいない場合は、Idrisが出力するエラー文言はかなり長く、理解しづらいものです。
とりわけ言語に入門したてのプログラマはそうでしょう。
例えば前述した最後のREPLでの例でのエラー文言はかなり長く、
Idrisが試みたことそれぞれを、なぜ失敗したのかについての理由を混じえて一覧にしています。

こうなってしまうと、型エラーとオーバーロード関数由来の曖昧さのごった煮に手を付けることになります。
上の例では2つのベクタは異なる長さであり、
そのためリスト表記をベクタとして見做すなら型エラーとなります。
しかしリスト表記はオーバーロードされており構築子`Nil`と`(::)`を持つ全てのデータ型に対して使えるため、
Idrisは`Vect`以外の他のデータ構築子を試し始めてしまうのです。
（今回の場合は*Prelude*にある`List`と`Stream`の構築子があたります。）
`zipWith`は型`Vect`の引数を期待しており、
`List`も`Stream`も当てはまらないため、
これらの構築子それぞれについても型エラーにより失敗します。

そんなときは名前空間をオーバーロードされた関数名に前置することで事態が簡単になることがよくあります。
Idrisがもはやこれらの関数の曖昧さを解消する必要がないからです。

```repl
Tutorial.Dependent> zipWith (*) (Dependent.(::) 1 Dependent.Nil) Dependent.Nil
Error: When unifying:
    Vect 0 ?c
and:
    Vect 1 ?c
Mismatch between: 0 and 1.
```

ほら、文言がぐっと明らかになりました。
Idrisは2つのベクタの長さを*統合*できていません。
*統合*とは、Idrisがコンパイル時に2つの式を同じ普遍的な形式に変換しようとすることです。
これが成功すれば2式は等価であると考えられ、
そうでない場合はIdrisは統合エラーにより失敗します。

名前空間でオーバーロードされた関数を前置する代替として、
`the`を使って型推論の手助けができます。

```repl
Tutorial.Dependent> zipWith (*) (the (Vect 3 _) [1,2,3]) (the (Vect 2 _) [10,20])
Error: When unifying:
    Vect 2 ?c
and:
    Vect 3 ?c
Mismatch between: 0 and 1.
```

興味深いことに上のエラーは "Mismatch between: 2 and 3" ではなく、
"Mismatch between: 0 and 1" になっています。
その理由はこうです。
Idrisは整数表記`2`と`3`を統合しようとします。
これらの整数は最初に対応する`Nat`値`S (S Z)`と`S (S (S Z))`にそれぞれ変換されます。
2式は`Z`と`S Z`に行き着くまでパターン合致され、
これは値`0`と`1`に対応します。
これがエラー文言で不一致として報告されます。

### ベクタを作る

これまでパターン合致することでベクタの長さについてのことを知ることができました。
`Nil`の場合は長さがゼロであることが明らかで、
*cons*の場合は長さが後続する他の自然数の長さなのでした。
新しいベクタを作りたいときはそう簡単にはいきません。

```idris
failing "Mismatch between: S ?n and n."
  fill : a -> Vect n a
```

`fill`を実装すると手詰まりになるでしょう。
例えば以下は型エラーになります。

```idris
  fill va = [va,va]
```

問題は*関数の呼び出し手が結果のベクタの長さを決める*というところにあります。
`fill`の型全体は実は以下のようです。

```idris
fill' : {0 a : Type} -> {0 n : Nat} -> a -> Vect n a
```

この型は以下のように読めます。
あらゆる型`a`とあらゆる自然数`n`（数量子ゼロなので実行時には*何にも*わかりません）について、
型`a`の値が与えられたとき、ちょうど`n`個の型`a`の要素を保管するベクタを渡してくれる、と。
これは次のように言うような感じです。
「自然数`n`について考えてください。
そしたら`n`の値を教えてくれなくても、`n`個のりんごをあげます。」
Idrisは強力ですが、透視能力者ではありません。

`fill`を実装するには`n`が実際なんであるかを知る必要があります。
`n`を明示的で消去されない引数として渡さねばなりません。
そうすることでそれをパターン合致でき、
その結果に基づいてどちらの`Vect`の構築子を使うのかを決定するのです。

```idris
replicate : (n : Nat) -> a -> Vect n a
```

ここで`replicate`は*依存関数型*です。
出力型は引数中の1つの値に*依存*しています。
`replicate`を`n`についてのパターン合致により実装するのは直感的です。

```idris
replicate 0     _  = []
replicate (S k) va = va :: replicate k va
```

こうしたことは指標付き型に取り組む際によく思い浮かぶパターンです。
型族の値にパターン合致によって指標の値について知ることができます。
しかし関数から型族の値を返すためには、
コンパイル時に指標の値を知っているか（例えば定数`ex1`や`ex3`を見てください）、
または実行時に指標値にアクセスする必要があります。
後者の場合、指標値に対してパターン合致でき、型族のどの構築子を使うべきかがわかります。

### 演習 その1

1. 関数`head`を非空のベクタに実装してください。

   ```idris
   head : Vect (S n) a -> a
   ```

   `Vect`の長さに*パターン*を使うことで非空性を表現できているところに注目してください。
   ここでは`Nil`の場合は排除されており、`Maybe`にくるむことなく型`a`の値を返せます！
   `Nil`の場合に`impossible`節を加えて確かめてみてください。
   （ただ、ここでは厳密には必要ありません。）

2. `head`を参照しつつ、非空のベクタに対して関数`tail`を宣言し実装してください。
   型では出力が入力よりちょうど1要素分短かくなることを反映してください。

3. `zipWith3`を実装してください。
   もし可能であれば`zipWith`の実装を見ずにやってみてください。

   ```idris
   zipWith3 : (a -> b -> c -> d) -> Vect n a -> Vect n b -> Vect n c -> Vect n d
   ```

4. `Semigroup`の結合演算子 (`<+>`) を通じて`List`に保管された値を累積する関数`foldSemi`を宣言し実装してください。
   （必ず`Semigroup`制約のみを使うようにしてください。`Monoid`制約ではありません。）

5. 非空のベクタについて演習4と同様のことをしてください。
   ベクタの非空性は出力型にどう影響するでしょうか？

6. 型`a`の初期値と関数`a -> a`が与えられているとき、
   `a`の`Vect`を生成したいとします。
   このベクタの最初の値は`a`で、2つ目の値は`f a`で、3つ目の値は`f (f a)`で、といった風に続きます。

   例えばもし`a`が1で`f`が`(* 2)`であれば、
   `[1,2,4,8,16,...]`のような結果が得られるようにしたいです。

   関数`iterate`を宣言し実装してください。
   この関数はこの挙動をカプセル化します。
   どこから始めたらよいかわからないときは`replicate`から着想が得られます。

7. 状態型`s`の初期値と関数`fun : s -> (s, a)`が与えられているとき、`a`の`Vect`を生成したいとします。
   関数`generate`を宣言し実装してください。
   この関数はこの挙動をカプセル化します。
   必ず全ての新しい`fun`の呼び出しで更新された状態を使うようにしてください。

   以下はこれを使って初めから`n`個のフィボナッチ数を生成する例です。

   ```repl
   generate 10 (\(x,y) => let z = x + y in ((y,z),z)) (0,1)
   [1, 2, 3, 5, 8, 13, 21, 34, 55, 89]
   ```

8. 関数`fromList`を実装してください。
   この関数は値のリストを同じ長さのベクタに変換します。
   詰まったら虫食いを使ってください。

   ```idris
   fromList : (as : List a) -> Vect (length as) a
   ```

   `fromList`の型で、リスト引数を関数*length*に渡すことで、結果のベクタの長さを*計算*できていることにご注目。

9. 以下の宣言について考えてください。

   ```idris
   maybeSize : Maybe a -> Nat

   fromMaybe : (m : Maybe a) -> Vect (maybeSize m) a
   ```

   `maybeSize`の理に適った実装を選び、
   その後で`fromMaybe`を実装してください。

## `Fin`: ベクタから安全に指標で引く

関数`index`を考えましょう。
この関数は`List`から所与の位置で値を抽出しようとします。

```idris
indexList : (pos : Nat) -> List a -> Maybe a
indexList _     []        = Nothing
indexList 0     (x :: _)  = Just x
indexList (S k) (_ :: xs) = indexList k xs
```

さて、ここで`indexList`のような関数を書くときに考慮すべき点があります。
出力型で失敗する可能性を表現したものか、
もしくは関数が決して失敗しないように受け付ける引数を制限したものか、ということです。
これは大切な設計時の決断であり、特に大きめのアプリケーションではそうです。
`Maybe`や`Either`を関数から返すと、
その関数を使う側のコードで結局`Nothing`や`Left`の場合に対処することになります。
そして対処するまでは中間結果は`Maybe`や`Either`の手荷物を持ち回ることになり、
これらの中間結果を計算するのが億劫になっていきます。
他方で入力として受け付ける値を制限するのは、
引数の型を複雑にすることになり、
関数の呼び出し手に入力の検証という重荷を強いることになります。
（とはいえ、auto暗示子でお話しすることになりますが、コンパイル時にIdrisから助けが得られます。）
出力は純粋で明快になるのですが。

依存型のない言語（例えばHaskell）は上の道筋のみをよく取ります。
つまり結果を`Maybe`や`Either`でくるむのです。
しかし、Idrisでは入力型を*洗練する*ことで受け付ける値の集合を制限でき、
したがって失敗の可能性を排除できるのです。

例として、（ゼロ始まりの）索引`k`で`Vect n a`から値を抽出したいときを考えましょう。
当然これが成功するのは、`k`がベクタの長さ`n`より厳密に小さい自然数であるときに限ります。
幸いにもこの前提条件を指標付き型で表現できます。

```idris
data Fin : (n : Nat) -> Type where
  FZ : {0 n : Nat} -> Fin (S n)
  FS : (k : Fin n) -> Fin (S n)
```

`Fin n`は`n`より厳密に小さい自然数の型で、帰納的に定義されています。
`FZ`は自然数*ゼロ*に対応し、型を見ての通りあらゆる自然数`n`に対して`S n`より厳密に小さいです。
`FS`は帰納的な場合です。
もし`k`が`n`より厳密に小さいなら（`k`は型が`Fin n`です）、`FS k`は`S n`より厳密に小さいです。

型`Fin`の値を幾つか挙げてみましょう。

```idris
fin0_5 : Fin 5
fin0_5 = FZ

fin0_7 : Fin 7
fin0_7 = FZ

fin1_3 : Fin 3
fin1_3 = FS FZ

fin4_5 : Fin 5
fin4_5 = FS (FS (FS (FS FZ)))
```

型`Fin 0`の値がないことにご注意を。
後の節で、「型`x`に値が1つもない」ことを型中で表現する方法を学びます。

`Fin`を使って`Vect`から安全に指標で引けるかどうかを確認してみましょう。

```idris
index : Fin n -> Vect n a -> a
```

読み進める前に自分で`index`を実装してみてください。
詰まったら虫食いを利用しましょう。

```idris
index FZ     (x :: _) = x
index (FS k) (_ :: xs) = index k xs
```

`Nil`の場合がなくても全域性検査器は満足していますね。
なぜかというと`Nil`は型が`Vect 0 a`ですが、型`Fin 0`が存在しないからです！
このことは欠けている不可能節を加えることで確かめられます。

```idris
index FZ     Nil impossible
index (FS _) Nil impossible
```

### 演習 その2

1. 関数`update`を実装してください。
   この関数は型`a -> a`の関数を受け取って`Vect n a`の位置`k < n`での値を更新します。

2. 関数`insert`を実装してください。
   この関数は`Vect n a`の位置`k <= n`に型`a`の値を挿入します。
   ここで`k`は新しく挿入された値の索引であり、なので以下が満たされます。

   ```repl
   index k (insert k v vs) = v
   ```

3. 関数`delete`を実装してください。
   この関数はベクタから所与の索引のところで値を削除します。

   これは演習1, 2よりも取っ付きにくいです。
   というのは、ベクタが1要素分短いことを適切に型に落とし込む必要があるからです。

4. `Fin`があれば`List`も同様に安全に索引で引くように実装できます。
   `safeIndexList`の型を思い浮かべて実装してください。

   注意：どこから手を付けたらよいかわからなかったら、
   `fromList`の型を見ると着想が得られるでしょう。
   また、`index`とは異なる順番で引数を与えなくてはならないでしょう。

5. 関数`finToNat`を実装してください。
   この関数は`Fin n`を対応する自然数に変換します。
   そして、これを使って関数`take`を宣言し実装してください。
   `take`は`Vect n a`から最初の`k`個分の要素を切り出します。
   なお`k <= n`です。

6. 自然数`n`から値`k`を差し引く関数`minus`を実装してください。
   なお`k <= n`です。

7. 演習6の`minus`を使って、`Vect n a`から最初の`k`個分の値を切り落とす関数`drop`を宣言し実装してください。
   なお`k <= n`です。

8. 位置`k <= n`で`Vect n a`を切り分ける関数`splitAt`を実装してください。
   この関数はベクタの前半部分と後半部分を対に包んで返します。

   解決の糸口：実装で`take`と`drop`を使ってください。

解決の糸口：`Fin n`は`n`より厳密に小さい値からなります。
`Fin (S n)`は`n`以下の値からなります。

附記：関数`take`, `drop`, `splitAt`は正確で全域性が証明されていますが、
それ以上に型付けるのが億劫です。
型を宣言する代わりの方法があるので、それを次の節で見ていきます。

## コンパイル時計算

先程の節、特に幾つかの演習では、関数や値の型を表現するために、ますますコンパイル時計算を使い始めました。
これは大変強力な概念で、というのも入力型から出力型を計算できるからです。
以下は例です。

`(++)`演算子で2つの`List`を結合することができます。
もちろんこれは`Vect`についても可能です。
しかし`Vect`は長さで指標付けられているので、入力の長さがどのように出力の長さに影響しているのかを厳密に型に反映させなくてはなりません。
こちらがその方法です。

```idris
(++) : Vect m a -> Vect n a -> Vect (m + n) a
(++) []        ys = ys
(++) (x :: xs) ys = x :: (xs ++ ys)
```

型段階で長さを監視していますね。
ここでも手違いで値が欠落するようなよくあるプログラミングの誤りの類を排除します。

型段階計算を入力型でのパターンとして使うこともできます。
こちらは`drop`の別の型と実装です。
この関数は演習で`Fin n`引数を使って実装したのでした。

```idris
drop' : (m : Nat) -> Vect (m + n) a -> Vect n a
drop' 0     xs        = xs
drop' (S k) (_ :: xs) = drop' k xs
```

### 制約

本節の全ての例と演習を終えたあとでは、型で任意の式が使えて、Idrisが喜んですべて評価・一体化してくれるのだ、という結論に至るかもしれません。

残念ですがそれは真実からはほど遠いものです。
本節の例は*ひとまず動く*ことが知られているような、選別されたものなのです。
その理由というのは、パターン合致とコンパイル時に使う関数の実装との間に常に直接の繋がりがあるためです。

例えば、以下は自然数の加算の実装です。

```idris
add : Nat -> Nat -> Nat
add Z     n = n
add (S k) n = S $ add k n
```

見てみると`add`は*最初の*引数でパターン合致して実装されており、
2つ目の引数は調べられていません。
これは`(++)`が`Vect`に実装されているのとちょうど同じですね。
最初の引数でパターン合致して、`Nil`の場合は2つ目を変更せずに返し、
*cons*の場合は尾っぽをくっつけた結果に先頭を前置したものを返しているのでした。
ここで2つのパターン合致には直接合致するところがあるので、
Idrisは`Nil`の場合に`0 + n`と`n`を、*cons*の場合に`(S k) + n`と`S (k + n)`を、それぞれ一体化できます。

以下の素朴な例では、手助けなしには、Idrisはもはや納得してくれません。

```idris
failing "Can't solve constraint"
  reverse : Vect n a -> Vect n a
  reverse []        = []
  reverse (x :: xs) = reverse xs ++ [x]
```

上記を型検査すると、
Idrisは以下のエラー文言とともに失敗します。
"Can't solve constraint between: plus n 1 and S n."
（訳註：制約を解決できません：plus n 1とS nとで差があります。）
何が起こっているのかというと、こうです。
左側のパターン合致から、Idrisはベクタの長さが`S n`であること、自然数`n`は`xs`の長さに対応することがわかります。
`(++)`の型と`xs`の長さおよび`[x]`によると、右側のベクタの長さは`n + 1`です。
オーバーロードされた演算子`(+)`は関数`Prelude.plus`を介して実装されており、
そのためIdrisはエラー文言で`(+)`を`plus`に置き換えています。

上からわかるように、Idrisは自分では`1 + n`が`n + 1`と同じことを確かめられません。
手助けを受けることはできるんですけどね。
上の等式が満たされるという*証明*を思い付いたら（あるいはもっと一般化して、自然数の加算の実装が*可換的*であれば）、
証明を`reverse`の右側の型を*書き換える*のに使うことができます。
証明を書いたり`rewrite`を使ったりするには詳細な説明と例が必要でしょう。
したがってこれらの話題は別の章まで待つことにします。

### 制約なし暗黙子

`replicate`のような関数では、自然数`n`を明示的で制約のない引数として渡しましたが、
これは返すベクタの長さから推論したものでした。
状況次第で`n`は文脈から推論できます。
例えば以下の例では`n`を明示的に渡すのは億劫です。

```idris
ex4 : Vect 3 Integer
ex4 = zipWith (*) (replicate 3 10) (replicate 3 11)
```

値`n`が文脈から導出できることは明らかで、下線文字で置き換えることでも確かめられます。

```idris
ex5 : Vect 3 Integer
ex5 = zipWith (*) (replicate _ 10) (replicate _ 11)
```

したがって`replicate`の代わりの版を実装でき、
*制約なし*数量子の暗黙引数として`n`を渡すようにできます。

```idris
replicate' : {n : _} -> a -> Vect n a
replicate' = replicate n
```

`replicate`の実装中で`n`を推論し、`replicate`の明示的な引数として渡せていますね。

潜在的に推論可能な引数を関数に渡す際、暗黙的にすべきか明示的にすべきか決定することは、その引数が実際どれほどIdrisによって推論可能*である*のかということなのです。その関数の両方の版があると便利なことさえあるでしょう。ただし覚えておいてほしいのですが、暗黙引数の場合でも明示的に値を渡せることには変わりないのです。

```idris
ex6 : Vect ? Bool
ex6 = replicate' {n = 2} True
```

上の型処方中の疑問符 (`?`) は、
Idrisがどうにかして自分で一体化により値を見付けだせるだろうという意味です。
こうなると`ex6`の右側で明示的に`n`を指定することになります。

#### 暗黙子に対するパターン合致

`replicate'`の実装は関数`replicate`を使い、そこで明示引数`n`でのパターン合致をしているのでした。
しかし、暗黙子、つまり非ゼロの数量子の名前付き引数でパターン合致することもできます。

```idris
replicate'' : {n : _} -> a -> Vect n a
replicate'' {n = Z}   _ = Nil
replicate'' {n = S _} v = v :: replicate'' v
```

### 演習 その3

1. 以下は`List`の`List`を平坦にする関数の宣言です。

   ```idris
   flattenList : List (List a) -> List a
   ```

   `flattenList`を実装し、これと似たベクタのベクタを平坦にする関数`flattenVect`を宣言し実装してください。

2. 前の節の演習のように関数`take'`と`splitAt'`を実装してください。
   ただし`drop'`で見た技法を使ってください。

3. `m x n`行列（`Vect m (Vect n a)`として表されます）を`n x
   m`行列に変換する関数`transpose`を実装してください。

   附記：これは発展的な演習かもしれませんが、ぜひ挑戦してみてください。
   いつも通り手詰まりになったら虫食いを活用しましょう！

   以下は実際に動かす例です。

   ```repl
   Solutions.Dependent> transpose [[1,2,3],[4,5,6]]
   [[1, 4], [2, 5], [3, 6]]
   ```

## まとめ

* 依存型があれば型を値から計算できます。
  この性質により値の性質を型段階に落とし込み、その性質をコンパイル時に検証できます。

* 長さで指標付けられたリスト（ベクタ）は、
  入出力ベクタの長さを強制的に正確にすることにより、
  特定の実装誤りを排除してくれます。

* 型処方でパターンを使用でき、例えばベクタの長さが非ゼロなのでベクタが非空だということを表現できます。

* 型族の値をつくる場合、指標値はコンパイル時に既知であるか、値を作る関数に引数として渡されていなくてはいけません。
  関数は指標値でパターン合致して、どの構築子を使うべきか調べられます。

* `n`より厳密に小さい自然数の型である`Fin n`を使って、安全に長さ`n`のベクタから索引で引くことができます。

* 時々推論できる引数を消去されない暗黙子として渡すと便利なことがあります。
  このとき、Idrisはできる限り値を埋めてくれますが、
  パターン合致したり他の関数に渡したりすることもできることには変わりありません。

データ型`Vect`とここで実装した大くの関数は*base*ライブラリのモジュール`Data.Vect`で使えます。
同様に`Fin`は*base*の`Data.Fin`で使えます。

### お次は？

[次節](IO.md)では、そろそろ副作用のあるプログラムを*純粋*なまま書く方法について学びましょう。

<!-- vi: filetype=idris2:syntax=markdown
-->
