# 関数 パート1

Idrisは *関数型* プログラミング言語です。
つまり、関数は抽象化の主な形式です（例えばJavaのようなオブジェクト指向言語とは違います。
オブジェクト指向言語では *オブジェクト* や *クラス* が主な抽象化の形式です）。
また、関数型であるということから、
Idrisではとても簡単に関数を構成・結合して新しい関数をつくれるということがわかります。
実際、Idrisの関数は *第一級* です。
関数は他の関数を引数に取ることができますし、関数の結果として関数を返すこともできます。

[導入](Intro.md)でIdrisでの最上位での関数宣言の基本形を学んできたので、
そこまでで学んできたことから続きをやりましょう。

```idris
module Tutorial.Functions1
```

## 1つ以上の引数を持つ関数

ある関数を実装してみましょう。
ここでは3つの `Integer` 型の引数が
[ピタゴラスの三つ組（訳註：ピタゴラスの定理を満たす3つの整数）](https://en.wikipedia.org/wiki/Pythagorean_triple)
になっているかを検査するものとします。
このために新しい演算子 `==` を使います。
相等性のための演算子です。

```idris
isTriple : Integer -> Integer -> Integer -> Bool
isTriple x y z = x * x + y * y == z * z
```

この演算子の型について軽く話しますが、
その前にREPLで動かしてみましょう。

```repl
Tutorial.Functions1> isTriple 1 2 3
False
Tutorial.Functions1> isTriple 3 4 5
True
```

この例からわかるように、
複数の引数を持つ関数の型は、
引数の型（*入力の型*とも言います）の連なりが関数の矢印 (`->`) で繋がっており、
出力の型（この場合 `Bool` です）で終わるようになっています。

この実装はちょっと数学的な等式に似ています。
`=` の左側に引数のリストを書き、
右側でこれの引数を使った計算を記述するのです。
関数型プログラミング言語での関数の実装は、手続き型言語での実装に比べてより数学的です。
関数型プログラミング言語では *何を* 計算するのかを記述しますが、
手続き型言語では手続き文の連なりとしてのアルゴリズムによって *どのように* 計算するのかを記述します。
あとでIdrisでもこの手続き的な書き方ができることを見ていきますが、
できるなら宣言的な書き方のほうがいいですね。

REPLでの実行例からわかるように、
関数は空白区切りの引数を渡すことで呼び出せます。
基本的に括弧は必要ではありません。
ただし、ある引数が既に空白を含む関数とその引数であった場合は、その引数を括弧でくくります。
この空白区切りの書き方ができることで、部分的に関数を適用するのがとても楽になります（この章で後述します）。

また実は `Integer` や `Bits8` とは違って、
`Bool` はIdris言語に組込まれた原始的なデータ型ではなく、
自前で書けるただのカスタムデータ型なのです。
新しいデータ型を宣言することについては次の章で学びましょう。

## 関数結合

関数はいくつかのやり方で組み合わせられます。
もっとも直接的なのは恐らくドット演算子でしょう。

```idris
square : Integer -> Integer
square n = n * n

times2 : Integer -> Integer
times2 n = 2 * n

squareTimes2 : Integer -> Integer
squareTimes2 = times2 . square
```

REPLで試してみてください！
予想した通りになりましたか？

以下のようにドット演算子を使わずに `squareTimes2` を実装することもできます。

```idris
squareTimes2' : Integer -> Integer
squareTimes2' n = times2 (square n)
```

大事なことですが、
ドット演算子で連鎖している関数は右から左に実行されます。
`times2 . square` は `\n => times2 (square n)` と同じですが、
`\n => square (times2 n)` ではありません。

いくつかの関数をドット演算子を使って連鎖させて、
もっと複雑な関数を簡便に書くことができます。

```idris
dotChain : Integer -> String
dotChain = reverse . show . square . square . times2 . times2
```

この関数はまず引数を4倍して、
2回平方を取って、
文字列に変換して (`show`)、
そして `String` を逆向きにします（関数 `show`, `reverse` はIdrisの *Prelude* の一部に含まれているので、
全てのIdrisのプログラムから使えます）。

## 高階関数

関数は他の関数を引数に取れます。
これは非常に強力な概念で、
それ故におかしなことになりやすくもあります。
とはいえ正気を保つために、まずはゆっくり進みましょう。

```idris
isEven : Integer -> Bool
isEven n = mod n 2 == 0

testSquare : (Integer -> Bool) -> Integer -> Bool
testSquare fun n = fun (square n)
```

まず `isEven` は `mod` 関数を使った検査をしています。
検査の内容は整数が2で割れるかどうかです。
しかし、興味深い関数は `testSquare` のほうです。
この関数は2つの引数を取ります。
1つ目の引数は *`Integer` から `Bool` への関数* であり、
2つ目の引数は `Integer` 型です。
この2つ目の引数は最初の引数に渡される前に平方を取られます。
繰り返しになりますが、
REPLでやってみましょう。

```repl
Tutorial.Functions1> testSquare isEven 12
True
```

時間を掛けて、何が起こっているのか理解しましょう。
ここでは `testSquare` に関数 `isEven` を引数として渡しています。
2つ目の引数は整数で、
平方を取られた後に `isEven` に渡されます。
これはあまり面白くない例かもしれませんが、
関数を引数として他の関数に渡す沢山の活用例を目にするでしょう。

前に述べたように、
簡単におかしなことになりがちです。
例えば次のを考えてみましょう。

```idris
twice : (Integer -> Integer) -> Integer -> Integer
twice f n = f (f n)
```

そしてREPLで……。

```repl
Tutorial.Functions1> twice square 2
16
Tutorial.Functions1> (twice . twice) square 2
65536
Tutorial.Functions1> (twice . twice . twice . twice) square 2
*** 巨大な数字 ***
```

この結果にはびっくりしたかもしれません。
なのでときほぐしていきましょう。
以下の2つの式は振舞いについて等価です。

```idris
expr1 : Integer -> Integer
expr1 = (twice . twice . twice . twice) square

expr2 : Integer -> Integer
expr2 = twice (twice (twice (twice square)))
```

つまり、 `square` は引数を2乗します。
`twice square` は（`square` を2回連続で呼び出すので）4乗します。
`twice (twice square)` は（`twice square` を2回連続で呼び出すので）16乗します。
そんな感じで続くと、
`twice (twice (twice (twice square)))` は65536乗することとなり、
度肝を抜くほど巨大な結果になるのです。

## カリー化

ひとたび高階関数を使いはじめると、
部分関数適用（またの名を *カリー化* と呼びます。数学者であり論理学者でもあったHaskell Curryに因みます）はとても大切な概念となります。

このファイルをREPLセッションに読み込んで以下を試してみましょう。

```repl
Tutorial.Functions1> :t testSquare isEven
testSquare isEven : Integer -> Bool
Tutorial.Functions1> :t isTriple 1
isTriple 1 : Integer -> Integer -> Bool
Tutorial.Functions1> :t isTriple 1 2
isTriple 1 2 : Integer -> Bool
```

注目すべきところは、
Idrisでは1つ以上の引数に部分的に関数を適用すると、
結果として新しい関数が返ってくるところです。
例えば、 `isTriple 1` は引数1が関数 `isTriple` にあてがわれており、
結果として型が `Integer -> Integer -> Bool` な新しい関数が返ってきています。
このような部分的に適用された関数を新しく最上位の定義に使うことさえできます。

```idris
partialExample : Integer -> Bool
partialExample = isTriple 3 4
```

そしてREPLで……。

```repl
Tutorial.Functions1> partialExample 5
True
```

もう `twice` の例でも部分関数適用を使いましたし、
そこではとても小さなコードで度肝を抜くような結果が得られたのでした。

## 匿名関数

ときどき、最上位の定義を書くことなしに、小さな自前の関数を高階関数に渡したいときがあります。
例えば、以下の関数 `someTest` はとても局所的な用途で一般的にはあまり有用ではないのですが、
とはいえ `testSquare` 高階関数に渡したいのだとします。

```idris
someTest : Integer -> Bool
someTest n = n >= 3 || n <= 10
```

`testSquare` に渡すとこうなります。

```repl
Tutorial.Functions1> testSquare someTest 100
True
```

`someTest` を定義して使う代わりに、
匿名関数を使うことができます。

```repl
Tutorial.Functions1> testSquare (\n => n >= 3 || n <= 10) 100
True
```

匿名関数はときどき *ラムダ式* とも呼ばれます。
（ラムダ式は[ラムダ計算](https://en.wikipedia.org/wiki/Lambda_calculus)から来ています。）
バックスラッシュが使われていますが、
これはギリシャ文字の *lambda* に似ているためです。
`\n =>` という文法により、1つの引数 `n` を取る新しい匿名関数が導入され、
関数の矢印の右側にその実装があります。
他の最上位の関数と同様に、
ラムダ式は1つ以上の引数を取ることができ、
引数はコンマ区切りです。
ラムダ式を高階関数の引数に渡したいときは、
だいたい括弧でくくったり、
ドル演算子 `($)` で区切ったりする必要があります。
（ドル演算子は次の節を参照してください。）

注意すべき点として、
ラムダ式では引数は型で註釈することができないということです。
なので、Idrisがそこでの文脈から型を推論できるようでないといけません。

## 演算子

`.` や `*` や `+` のようなIdrisの中置演算子は言語に組込まれてはいません。
これらの演算子は通常のIdrisの関数に、いくらかの中置記法で使うための特別なサポートが付いたものです。
演算子を中置記法で使わないときは、括弧でくるまねばなりません。

例として、型が `Bits8 -> Bits8` の関数を連ねる自前の演算子を定義してみましょう。

```idris
infixr 4 >>>

(>>>) : (Bits8 -> Bits8) -> (Bits8 -> Bits8) -> Bits8 -> Bits8
f1 >>> f2 = f2 . f1

foo : Bits8 -> Bits8
foo n = 2 * n + 3

test : Bits8 -> Bits8
test = foo >>> foo >>> foo >>> foo
```

演算子自体を宣言・定義することに加えて、
結合の向きを指定せねばなりません。
`infixr 4 >>>` は、 `(>>>)` が右結合
（というのは、 `f >>> g >>> h` は `f >>> (g >>> h)` として解釈されるということです）
で優先度4であることを意味します。
*Prelude* から公開されている演算子の結合についてREPLで見ることができます。

```repl
Tutorial.Functions1> :doc (.)
Prelude.. : (b -> c) -> (a -> b) -> a -> c
  Function composition.
  Totality: total
  Fixity Declaration: infixr operator, level 9
```

式で複数の演算子が混在するような場合は、
より高い優先度を持つ演算子がより強く結び付きます。
たとえば、 `(+)` は左結合で優先度が8、
`(*)` は左結合で優先度が9です。
したがって `a * b + c` は `a * (b + c)` ではなく、
`(a * b) + c` と同じです。

### 演算子節

演算子は通常の関数と同様に部分適用できます。
このとき、全体の式は括弧にくるまれている必要があります。
そしてこの式を *演算子節* と呼びます。
2つ例を挙げます。

```repl
Tutorial.Functions1> testSquare (< 10) 5
False
Tutorial.Functions1> testSquare (10 <) 5
True
```

例から見てとれるように、
`(< 10)` と `(10 <)` には違いがあります。
前者は引数が10より小さいかの検査で、
後者は10が引数より小さいかの検査です。

演算子節がうまくいかない例外の1つは*負符号*演算子`(-)`です。
以下はこのことを実演する例です。

```idris
applyToTen : (Integer -> Integer) -> Integer
applyToTen f = f 10
```

これは単に高階関数を数字の10に関数の引数として適用しているだけです。
以下の例では実にうまくいきます。

```repl
Tutorial.Functions1> applyToThen (* 2)
20
```

しかし、10から5を引こうとして以下のように失敗します。

```repl
Tutorial.Functions1> applyToTen (- 5)
Error: Can't find an implementation for Num (Integer -> Integer).

(Interactive):1:12--1:17
 1 | applyToTen (- 5)
```

ここでの問題は、Idrisが`- 5`を演算子節ではなく整数リテラルとして扱うということです。
この特別な場合においては、代わりに匿名関数を使わねばなりません。

```repl
Tutorial.Functions1> applyToTen (\x => x - 5)
5
```

### 演算子ではない関数のための中置記法

Idrisでは通常の2引数関数も、バッククォートにくるむことで中置記法することができます。
優先度（と結合の向き）を定義して、演算子節で使うこともできます。
ちょうど通常の演算子のように。

```idris
infixl 8 `plus`

infixl 9 `mult`

plus : Integer -> Integer -> Integer
plus = (+)

mult : Integer -> Integer -> Integer
mult = (*)

arithTest : Integer
arithTest = 5 `plus` 10 `mult` 12

arithTest' : Integer
arithTest' = 5 + 10 * 12
```

### *Prelude* から公開されている演算子

以下は *Prelude* から公開されている重要な演算子の一覧です。
これらのうちほとんどは *制約付き* のものです。
制約付きというのは、特定の *インターフェース* を実装した型に対してのみ使える、ということです。
今は心配しなくて大丈夫。
その時が来たらインターフェースについて学びましょう。
インターフェースを知らずとも、演算子は直感的に振舞うことでしょう。
たとえば加算と乗算は全ての数値型に対してはたらきますし、
比較演算子は *Prelude* の関数以外のほぼ全ての型に対してはたらきます。

* `(.)`: 関数結合
* `(+)`: 加算
* `(*)`: 乗算
* `(-)`: 減算
* `(/)`: 除算
* `(==)` : 2つの値が等しいとき真
* `(/=)` : 2つの値が異なるとき真
* `(<=)`, `(>=)`, `(<)`, `(>)` : 比較演算子
* `($)`: 関数適用

上記のうち最も特別なのは最後の演算子です。
優先度が0なので、他の全ての演算子はより強く結び付きます。
加えて、関数適用はそれよりさらに強く結び付くので、
この演算子によって必要な括弧の数を減らすことができます。
例えば、 `isTriple 3 4 (2 + 3 * 1)` と書くところを、
`isTriple 3 4 $ 2 + 3 * 1` とでき、
これは全く同じ意味です。
この演算子で可読性が上がることもあれば、下がることもあります。
覚えておくべきことは、
`fun $ x y` が `fun (x y)` と同じであるということです。

## 演習

1. ドット演算子を使い、2つ目の引数を省くことで、関数 `testSquare` と `twice` を再実装してください。
   （`squareTimes2` の実装を見れば方針が見えてきます。）
   この高度に簡潔な関数の実装の書き方はしばしば *ポイントフリースタイル* と呼ばれ、
   小間物的な関数を書くときによく好まれます。

2. 前述の関数 `isEven` と `not` （Idrisの *Prelude* 由来）を組み合わせて
   `isOdd` を宣言・実装してください。
   なお、ポイントフリースタイルを使ってください。

3. `isSquareOf` 関数を宣言・定義してください。
   この関数は最初の `Integer` な引数が2つ目の引数の平方であるか検査します。

4. 関数 `isSmall` を宣言・実装してください。
   この関数は `Integer` な引数が100以下かどうか検査します。
   実装では比較演算子 `<=` または `>=` を使ってください。

5. 関数 `absIsSmall` を宣言・定義してください。
   この関数は `Integer` な引数の絶対値を取ったものが100以下かどうか検査します。
   実装では関数 `isSmall` と `abs` （Idrisの *Prelude* 由来）を使ってください。
   また、ポイントフリースタイルを使ってください。

6. ちょっと発展的な演習として、 `Integer` に関する命題を扱う小間物を実装していきます。
   （ここでの命題とは、 `Integer` を取って `Bool` を返す関数です。）
   以下の高階関数を実装してください。
   （実装では真偽値演算子 `&&`, `||` と関数 `not` を使ってください。）

   ```idris
   -- 両方の命題が満たされているときに限り真
   and : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- 少なくとも一方の命題が満たされているときに限り真
   or : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- 命題が満たされないときに真
   negate : (Integer -> Bool) -> Integer -> Bool
   ```

   この演習を解いたら、
   REPLを立ち上げてください。
   以下の例では2引数関数 `and` をバッククォートでくるんだ中置記法にして使っています。
   これは単に文法的に便利だからで、
   こうすることで関数適用がより読みやすくなることがあります。

   ```repl
   Tutorial.Functions1> negate (isSmall `and` isOdd) 73
   False
   ```

7. 前述したように、
   Idrisでは自前の中置演算子を定義できます。
   さらにいいことにIdrisでは関数名の *オーバーロード* ができます。
   というのは、2つ以上の関数や演算子が違う型と実装を持ちつつ同じ名前を持つことができるということです。
   Idrisは同じ名前を持つ演算子と関数を型で見分けます。

   これにより、真偽値計算での既存の演算子と関数の名前を使いつつ、
   演習6から関数 `and`, `or`, `negate` を再実装することができます。

   ```idris
   -- 両方の命題が満たされているときに限り真
   (&&) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
   x && y = and x y

   -- 少なくとも1つの命題が満たされているときに限り真
   (||) : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool

   -- 命題が満たされていないとき真
   not : (Integer -> Bool) -> Integer -> Bool
   ```

   残りの2つの関数 `(||)` と `not` を実装してREPLで試してください。

   ```repl
   Tutorial.Functions1> not (isSmall && isOdd) 73
   False
   ```

## まとめ

この章で学んだことは以下です。

Idrisの関数はいくつでも引数を取ることができます。
引数は関数の型で `->` で区切られています。

* ドット演算子を連続して使うことで関数を組み合わせることができます。
こうすることでかなり簡潔なコードになります。

* 関数が期待するより少ない引数を渡すことで、
関数の部分適用ができます。
部分適用の結果は残りの引数を期待する新しい関数になります。
この技法は *カリー化* と呼ばれます。

* 関数は他の関数の引数に渡すことができます。
これにより、小さなコードの部品を組み合わせることで、
簡単により複雑な振舞いを生み出すことができます。

* 匿名関数（*ラムダ式*）を高階関数に渡すことができます。
匿名関数は、これに対応する最上位の関数を書くのがまどろっこしいときに使います。

* Idrisでは自前の中置演算子を定義することができます。
中置記法で使われないときは、中置演算子は括弧の中に書く必要があります。

* 中置演算子は部分適用することもできます。
この *演算子節* は括弧でくるまれていなければいけません。
そして、演算子節での引数の位置は、
演算子の1つ目の引数か2つ目の引数かを決めます。

* Idrisでは名前のオーバーロードができます。
関数は同じ名前を持ちつつ違う実装を持つことができます。
Idrisはどちらの関数を使うべきかを型から決めます。

注意したいことは、
1つのモジュール内の関数と演算子の名前は一意であるということです。
同じ名前の2つの関数を定義するには、
別々のモジュールで宣言する必要があります。
Idrisがどちらを使うべきか判断できないときは、
関数に（部分的にでも） *名前空間* を前置することで、名前解決できるようになります。

```repl
Tutorial.Functions1> :t Prelude.not
Prelude.not : Bool -> Bool
Tutorial.Functions1> :t Functions1.not
Tutorial.Functions1.not : (Integer -> Bool) -> (Integer -> Bool) -> Integer -> Bool
```

### お次は？

[次節](DataTypes.md)では、
自前のデータ型を定義する方法と、
この新しい型の値を構築したり分解したりする方法を学びます。
汎化型と汎化関数についても学びます。

<!-- vi: filetype=idris2
-->
