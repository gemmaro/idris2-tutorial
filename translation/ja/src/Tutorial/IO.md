# IO: 副作用のあるプログラミング

ここまでの全ての例や演習で、純粋で全域な関数を扱ってきました。
ファイルから内容を読んだり書き込んだり、
標準出力に文言を書き込んだりするようなことはしてきませんでした。
今こそ流れを変え、副作用のあるプログラムをIdrisで書く方法を学ぶときです。

```idris
module Tutorial.IO

import Data.List1
import Data.String
import Data.Vect

import System.File

%default total
```

## 純粋な副作用？

[導入](Intro.md)の*hello world*の例をもう一度見ると、以下の型と実装がありました。

```idris
hello : IO ()
hello = putStrLn "Hello World!"
```

このモジュールをREPLセッションに読み込んで`hello`を評価すると、以下が得られるでしょう。

```repl
Tutorial.IO> hello
MkIO (prim__putStr "Hello World!")
```

実際にはプログラムに単に "Hello World!" を印字してほしかったとしたら、この挙動は期待したものではないでしょう。
ここで起こっていることを説明するためには、REPLでどのように評価が行われるのかを軽く知っておかねばなりません。

REPLで何らかの式を評価するとき、Idrisは行き着くところまで値に簡略しようとします。
上の場合、Idrisは関数`prim__putStr`で立ち止まります。
これは*Prelude*で定義された*異邦関数*であり、
それぞれのバックエンドで実装されることで使えるようになるものです。
コンパイル時（そしてREPL時）は、Idrisは異邦関数の実装について何も知らず、
したがってコンパイラ自身に組込まれていない限り異邦関数を簡略することはできません。
なので型`IO a`（`a`は型変数）の値も同様に大抵は簡略できないのです。

型`IO a`の値はプログラムを*記述*している、ということを理解することは大事です。
これは*実行*されると型`a`の値を返しますが、その道すがら任意の副作用を生じてからなのです。
例えば`putStrLn`は型`String -> IO ()`です。
読み下すとすればこうです。
「`putStrLn`は関数で、`String`引数を与えられると、
出力型が`()`の副作用付きのプログラムの記述を返す。」
（`()`は型`Unit`の糖衣構文で、*Prelude*で定義されている空タプルです。
`Unit`には唯一`MkUnit`という名前の値があり、コードでも`()`を使えるのです。）

型`IO a`の値は作用付き計算の記述に過ぎないことから、
そのような値を返したり引数として値を取ったりする関数はそれでもなお*純粋*で、つまりは参照透過なのです。
しかしながら、型`a`の値を型`IO a`の値から抽出することは不可能です。
というのは、汎化関数`IO a -> a`は存在しないということですが、
これは関数が引数から結果を抽出するときにうっかり副作用を実行するであろうからで、
つまりは参照透過性を破っているのです。
（実は`unsafePerformIO`という名前の関数が*あります*。
何をするものかわかっていない限り、決してコードで使わないでください。）

### doブロック

純粋関数型プログラミングを始めたてだったら、
今頃恐らく、というかきっと、実行できない作用付きプログラムのの記述の役立たなさを愚痴っているかもしれません。
まあ、聞いてください。
型`IO a`の値を実行することはできない、
つまり型`IO a -> a`の関数はどこにもありませんが、
こうした計算を連鎖させてより複雑なプログラムを記述できます。
Idrisはこのための特別な文法、*doブロック*を提供しています。
以下は例です。

```idris
readHello : IO ()
readHello = do
  name <- getLine
  putStrLn $ "Hello " ++ name ++ "!"
```

何が起こっているのかをお話しする前に、REPLでやってみましょう。

```repl
Tutorial.IO> :exec readHello
Stefan
Hello Stefan!
```

これは対話的プログラムであり、標準入力から1行読んで (`getLine`)、
結果を変数`name`に代入し、
そうして`name`を使って気さくな挨拶文をつくって標準出力に書き込みます。

`readHello`の実装の初めにある`do`キーワードに注目してください。
このキーワードから*doブロック*が始まり、
ここでは`IO`計算を連鎖できたり、
左向きの矢印 (`<-`) を使って中間結果を変数に束縛し、あとの`IO`行動で使えるようにできたりします。
型`IO`の値1つに副作用付きの任意のプログラムを内蔵化できるほどこの概念は強力です。
このような表現はそれから関数`main`から返されます。
`main`はIdrisプログラムへの主な入口で、コンパイルされたIdrisバイナリを走らせるときに実行されます。

### プログラム記述と実行の違い

作用のある計算を*記述*することと、*実行し*たり*走らせ*たりすること、この違いをよりよく理解するために、
以下の小さなプラグラムを見てみましょう。

```idris
launchMissiles : IO ()
launchMissiles = putStrLn "Boom! You're dead."

friendlyReadHello : IO ()
friendlyReadHello = do
  _ <- putStrLn "Please enter your name."
  readHello

actions : Vect 3 (IO ())
actions = [launchMissiles, friendlyReadHello, friendlyReadHello]

runActions : Vect (S n) (IO ()) -> IO ()
runActions (_ :: xs) = go xs
  where go : Vect k (IO ()) -> IO ()
        go []        = pure ()
        go (y :: ys) = do
          _ <- y
          go ys

readHellos : IO ()
readHellos = runActions actions
```

上のコードが何をするのかを説明する前に、
`runActions`の実装で使われている関数`pure`を見てください。
これは制約付き関数ですが、これについては次の章で学びましょう。
`IO`に特化すれば汎化型`a -> IO a`です。
つまり値を`IO`行動に包むことができます。
`IO`プログラムの結果は副作用を生じることなく単に包まれた値を返します。
これで`readHellos`で何が起こっているのかを大局的に眺められます。

まず、`readHello`のよりやさしい版を定義します。
実行されると名前をはっきりと尋ねます。
`putStrLn`の結果をこれ以上使うことがないので、全て堰き止めるパターンとしての下線文字をここで使えます。
そのあとで`readHello`が呼び出されます。
`launchMissiles`も定義します。
これが実行されると惑星地球が破壊されてしまいます。

さて、`runActions`は`IO`行動を*記述する*ことが*走らせる*ことと同じではないことを実演する関数です。
これは引数として取る非空ベクタから最初の行動を切り落として新しい`IO`行動を返します。
返される行動は残りの`IO`行動を順番に実行する記述です。
もしこれが期待通りに振る舞うとしたら、
`runActions`に渡された最初の`IO`行動はあらゆる潜在的な副作用とともに黙殺されます。

REPLで`readHellos`を実行すると、
`actions`は最初に`launchMissiles`も含んでいますが、名前を2回尋ねられます。
惑星を破壊する方法を記述したものの、
運よくその行動は実行されず、そして私達は（たぶん）まだここに立っています。

この例からいくつかのことを学びました。

* 型`IO a`の値はプログラムの*純粋記述*です。
  この記述が*実行*されると型`a`の値を返す前にありとあらゆる副作用を生じます。

* 型`IO a`の値は安全に関数から返したり引数やデータ構造に入れて受け渡したりできます。
  実行される惧れはありません。

* 型`IO a`の値は*doブロック*で安全に新しい`IO`行動に結合できます。

* `IO`行動は、REPLで`:exec`に渡されたり、
  コンパイルされたIdrisプログラムの`main`関数から実行されるものであったりするときにのみ実行されます。

* `IO`文脈の殻を破ることは絶対にできません。
  つまり型`IO a -> a`の関数はありませんが、
  それはそうした関数が最終的な結果を抽出するために引数を順番に実行する必要があり、
  これが参照透過性を破るからです。

### 純粋なコードと`IO`行動をくっつける

この小節の題はどこか誤読を誘うところがあります。
`IO`行動は純粋な値*です*が、
ここでの意味は`IO`ではない関数と作用のある計算をくっつけることです。

実演として本節では計算式を評価する小さなプログラムを書いていきます。
話を簡単にして演算子1つと2つの引数がある式のみ許すことにします。
引数はどちらも整数でなければならず、例えば`12 + 13`です。

*base*の`Data.String`由来の関数`split`を使って計算式を字句解析していきます。
それから2つの整数値と演算子のパースを試みます。
利用者の入力は不正かもしれず、これらの操作は失敗するかもしれません。
そのためエラー型も必要です。
実のところエラー型には単に`String`を使ってもいいのですが、
エラーの条件のための自前の直和型を使うことは良い作法だと考えます。

```idris
data Error : Type where
  NotAnInteger    : (value : String) -> Error
  UnknownOperator : (value : String) -> Error
  ParseError      : (input : String) -> Error

dispError : Error -> String
dispError (NotAnInteger v)    = "Not an integer: " ++ v ++ "."
dispError (UnknownOperator v) = "Unknown operator: " ++ v ++ "."
dispError (ParseError v)      = "Invalid expression: " ++ v ++ "."
```

整数表記をパースするために`Data.String`の関数`parseInteger`を使います。

```idris
readInteger : String -> Either Error Integer
readInteger s = maybe (Left $ NotAnInteger s) Right $ parseInteger s
```

同様に計算演算子をパースする関数を宣言し実装します。

```idris
readOperator : String -> Either Error (Integer -> Integer -> Integer)
readOperator "+" = Right (+)
readOperator "*" = Right (*)
readOperator s   = Left (UnknownOperator s)
```

これで簡単な計算式をパースし評価する準備ができました。
これはいくつかの段階（入力文字列を分割し、それぞれの表記をパースする）からなり、
それぞれの段階は失敗しうるものです。
あとでモナドを学んだら、
doブロックがそうした場合にちょうど同じように使えることを見ていきます。
しかしこの場合代わりの文法的な便宜を図れます。
let束縛でパターンマッチするのです。
以下がコードです。

```idris
eval : String -> Either Error Integer
eval s =
  let [x,y,z]  := forget $ split isSpace s | _ => Left (ParseError s)
      Right v1 := readInteger x  | Left e => Left e
      Right op := readOperator y | Left e => Left e
      Right v2 := readInteger z  | Left e => Left e
   in Right $ op v1 v2
```

これを少し解剖しましょう。
最初の行では入力文字列を全ての空白のある位置で分割します。
`split`は`List1`（*base*の`Data.List1`から高階されている非空のリスト型）を返しますが、
`List`でパターン照合するほうがもっと便利なので、
`Data.List1.forget`を使って結果を変換します。
ここで代入演算子`:=`の左側でパターン照合を使っていますね。
これは部分パターン照合（*部分*というのは、全ての可能な場合を網羅していないからです）なので、
他の可能性も同様に対処しなければいけません。
その対処は垂直線のあとで行われます。
これは次のように読めます。
「もし左側のパターン照合が成功し、ちょうど3つの字句のリストが得られたら、
`let`式を続ける。
そうでなければ直ちに`ParseError`を`Left`に入れて返す。」

他の3行はちょうど同じように振舞います。
つまり、それぞれに左側に部分パターン照合がありつつ、垂直棒のあとに不正な入力の場合に何を返すかという説明があります。
あとで見ていきますが、この構文は*doブロック*でも使えます。

ここで、これまで実装してきた機能の全ては*純粋*で、
副作用のある計算を記述していません。
（すでに失敗の可能性は観測できる*作用*だと言い張ることもできますが、
しかしそうだとしても上のコードはそれでも参照透過で、
REPLで簡単に試せたりコンパイル時に評価できます。
ここではこれが大事です。）

ついにこの機能を`IO`行動に包むことができます。
これは標準入力から文字列を読み取って計算式を評価しようとします。

```idris
exprProg : IO ()
exprProg = do
  s <- getLine
  case eval s of
    Left err  => do
      putStrLn "An error occured:"
      putStrLn (dispError err)
    Right res => putStrLn (s ++ " = " ++ show res)
```

`exprProg`で失敗する可能性に対処することを強いられており、
結果を表示するために`Either`の両方の構築子をそれぞれ扱っていますよね。
あと、*doブロック*は普通の式なので、
例えばcase式の右側で新しい*doブロック*を始められますよ。

### 演習 その1

この演習では小さなコマンドラインアプリケーションを実装していきます。
いくつかのものはアプリケーションを終了するためにキーワードを入力したときだけ止まるものなので、
潜在的に永久に実行されます。
そうしたプログラムはもはや全域であることは証明されません。
ソースファイルの冒頭に`%default total`プラグマを加えていたら、
これらの関数を`covering`で註釈する必要があります。
これは全てのパターン照合の全ての場合を網羅できているものの、
制約のない再帰によりプログラムが堂々巡りになるかもしれないことを意味します。

1. 関数`rep`を実装してください。
   これは端末からの入力のうち1行を読み、与えられた関数を使って評価し、
   そして標準出力に結果を印字します。

   ```idris
   rep : (String -> String) -> IO ()
   ```

2. 関数`repl`を実装してください。
   これは`rep`のように振舞いますが、（強制的に終了されるまで）永遠に関数自身を繰り返します。

   ```idris
   covering
   repl : (String -> String) -> IO ()
   ```

3. 関数`replTill`を実装してください。
   これはちょうど`repl`のように振舞いますが、与えられた関数が`Right`を返したときだけ繰り返すのを続けます。
   `Left`を返したら`replTill`は`Left`に包まれた最後の文言で印字し、それから停止します。

   ```idris
   covering
   replTill : (String -> Either String String) -> IO ()
   ```

4. 計算式を標準入力から読み、`eval`を使って評価し、
   標準出力に結果を印字するプログラムを書いてください。
   プログラムは利用者が "done" と入力して停止させるまで繰り返します。
   停止された場合はプログラムは気さくな挨拶とともに終了します。
   実装では`replTill`を使ってください。

5. 関数`replWith`を実装してください。
   これはちょうど`repl`と同じように振舞いますが、内部状態を使って値を積み重ねます。
   それぞれの回（初回も含みますよ）で関数`dispState`を使って現在の状態が標準出力に印字され、
   次の状態は関数`next`を使って計算されます。
   繰り返しは`Left`の場合に終了し、`dispResult`を使って最後の文言を印字します。

   ```idris
   covering
   replWith :  (state      : s)
            -> (next       : s -> String -> Either res s)
            -> (dispState  : s -> String)
            -> (dispResult : res -> s -> String)
            -> IO ()
   ```

6. 問題5の`replWith`を使って、標準入力から自然数を読み、
   積み重ねられたこれらの数値の合計を印字するプログラムを書いてください。
   プログラムは不正な入力の場合と利用者が "done" が入力したときに終了します。

## doブロックとその脱糖

ここで大事なお知らせがあります。
*doブロック*について特別なことは何もないということです。
これは単なる糖衣構文で、演算子の適用の羅列に変換されます。
[糖衣構文](https://en.wikipedia.org/wiki/Syntactic_sugar)があれば、
少しも言語自体を強力にしたり表現力豊かにすることなく、
その言語で特定のことを表現することをより簡単にできるようなプログラミング言語での構文で書くことができます。
つまり全ての`IO`プログラムを`do`記法を使わずに書くことができるのですが、
書いたコードはしばしば読みにくくなるでしょう。
*doブロック*はそうした場合によりよい構文を提供するものです。

以下のプログラム例について考えます。

```idris
sugared1 : IO ()
sugared1 = do
  str1 <- getLine
  str2 <- getLine
  str3 <- getLine
  putStrLn (str1 ++ str2 ++ str3)
```

コンパイラは*関数名の曖昧性を解決して型検査する前に*これを以下のプログラムに変換します。

```idris
desugared1 : IO ()
desugared1 =
  getLine >>= (\str1 =>
    getLine >>= (\str2 =>
      getLine >>= (\str3 =>
        putStrLn (str1 ++ str2 ++ str3)
      )
    )
  )
```

*bind*と呼ばれる新しい演算子 (`>>=`) が`desugared1`の実装中にあります。
REPLで型を見ると以下のようになっています。

```repl
Main> :t (>>=)
Prelude.>>= : Monad m => m a -> (a -> m b) -> m b
```

これは制約付き関数で`Monad`と呼ばれるインターフェースを必要とします。
`Monad`とその仲間達については次章でお話しします。
`IO`に限っていうと*bind*は以下の型を持ちます。

```repl
Main> :t (>>=) {m = IO}
>>= : IO a -> (a -> IO b) -> IO b
```

これは`IO`行動の連接を表現しています。
実行にあたって最初の`IO`行動が走り、
その結果が2つ目の`IO`行動を生成する関数に引数として渡されます。
2つ目の`IO`行動もそれから実行されていきます。

お気付きかもしれませんが、以前の演習で似たようなものを既に実装していました。
[代数的データ型](DataTypes.md)で`Maybe`と`Either e`に*bind*を実装しましたね。
次の章で学ぶことになりますが、
`Maybe`と`Either e`もまた`Monad`の実装が付属しています。
さしあたって言うべきこととしては、
`Monad`があれば何らかの種類の作用付きの計算を、
最初の計算の*結果*を2つ目の計算が返す関数に渡すことで、
順繰りに走らせられるということです。
`desugared1`を見るとわかりますが、
最初に`IO`行動を実施し、その結果を次の`IO`行動の計算に使い、というようになっています。
コードはどこか読み辛いものですが、
これは何層にも入れ子になった匿名関数があるからで、
だからこそそうした場合に*doブロック*が同じ機能を表現するよりよい代替となるのです。

*doブロック*は常に*bind*演算子の適用の羅列に脱糖されるため、
これを使っていかなるモナド計算をも連鎖させられます。
例えば関数`eval`を*doブロック*を使って書き換えられます。

```idris
evalDo : String -> Either Error Integer
evalDo s = case forget $ split isSpace s of
  [x,y,z] => do
    v1 <- readInteger x
    op <- readOperator y
    v2 <- readInteger z
    Right $ op v1 v2
  _       => Left (ParseError s)
```

まだよく飲み込めていなくても心配ないです。
より多くの例を見ていくことで、もうじきに会得できるでしょう。
覚えておくべき大事なことは*doブロック*が常に`desugared1`に示したような
*bind*演算子の羅列に変換されるということです。

### Unitを束縛する

`friendlyReadHello`の実装を覚えていますか？
以下に再掲します。

```idris
friendlyReadHello' : IO ()
friendlyReadHello' = do
  _ <- putStrLn "Please enter your name."
  readHello
```

下線文字がちょっと見辛く不必要です。
実際、よくある使用例は結果の型が`Unit` (`()`) で作用のある計算を単に連鎖させるだけであり、
発生する副作用だけがほしいのです。
例えば`friendlyReadHello`を3回繰り返すことができます、こんな風に。

```idris
friendly3 : IO ()
friendly3 = do
  _ <- friendlyReadHello
  _ <- friendlyReadHello
  friendlyReadHello
```

これはよくあることなので、Idrisでは下線文字への束縛を一気に削ぎ落とすことができます。

```idris
friendly4 : IO ()
friendly4 = do
  friendlyReadHello
  friendlyReadHello
  friendlyReadHello
  friendlyReadHello
```

ただしかし、上記は僅かに違う風に脱糖されます。

```idris
friendly4Desugared : IO ()
friendly4Desugared =
  friendlyReadHello >>
  friendlyReadHello >>
  friendlyReadHello >>
  friendlyReadHello
```

演算子 `(>>)` は以下の型を持ちます。

```repl
Main> :t (>>)
Prelude.>> : Monad m => m () -> Lazy (m b) -> m b
```

型処方中に`Lazy`キーワードがありますね。
これが意味するのは、包まれた引数が*遅延評価*されるということです。
これは多くの場合理に適っています。
例えばもし問題の`Monad`が`Maybe`であれば、最初の引数が`Nothing`なら結果が`Nothing`になるでしょう。
その場合2つ目の引数を評価する必要さえないのです。

### doをオーバーロード

Idrisでは関数と演算子のオーバーロードができるので、
自前の*束縛*演算子を書くことができ、
これによって`Monad`の実装を持たない型にも*do記法*が使えます。
例えば以下はベクタを返す連続計算のための`(>>=)`の自前実装です。
（長さ`m`の）1つ目のベクタ中の全ての値が長さ`n`のベクタに変換され、
連結された結果となるため長さ`m * n`のベクタになります。

```idris
flatten : Vect m (Vect n a) -> Vect (m * n) a
flatten []        = []
flatten (x :: xs) = x ++ flatten xs

(>>=) : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
as >>= f = flatten (map f as)
```

この挙動を内蔵化するような`Monad`の実装を書くことはできません。
型が合わないからです。
というのは、`Vect`に特化したモナドな*束縛*は`Vect k a -> (a -> Vect k b) -> Vect k b`の型を持つからです。
見てわかるように出現する3箇所の`Vect`大きさはどれも同じであり、これは自家製の*束縛*で表現しているものと異なります。
実際に動かしてみた例は以下です。

```idris
modString : String -> Vect 4 String
modString s = [s, reverse s, toUpper s, toLower s]

testDo : Vect 24 String
testDo = IO.do
  s1 <- ["Hello", "World"]
  s2 <- [1, 2, 3]
  modString (s1 ++ show s2)
```

手ずから脱糖してみて、`testDo`がどのように動いているのかを調べてみてください。
それからその結果とREPLで得られたものとを比較しましょう。
なお、ここではIdrisが曖昧さを解決できるように手助けしました。
演算子の名前空間の一部で`do`キーワードに前置することで、
どの版の*束縛*演算子を使うべきかを伝えています。
この場合、`Vect k`は`Monad`の実装を持ちますが、厳密には必要ではありません。
しかしそれでもコンパイラがdoブロックの曖昧さを解決することを手伝うことができると知っておくことは良いことです。

もちろん、`(>>=)`と同じ作法で`(>>)`をオーバーロードすることもできます（し、やるべきです
よ）。
もしdoブロックの挙動をオーバーロードしたければね。

#### モジュールと名前空間

あらゆるデータ型、関数、演算子は名前空間を前置することで曖昧さなく識別されるようにできます。
関数の名前空間は大抵定義されているモジュールと同じです。
例えば関数`eval`の完全に限定された名前は`Tutorial.IO.eval`になります。
関数と演算子の名前は名前空間において唯一でなければいけません。

既に見てきたように、Idrisはよく同名で異なる名前空間の関数を紐付く型で曖昧解決します。
これができなければ、関数や演算子の名前に完全な名前空間の後ろ部分を前置することでコンパイラを手助けできます。
REPLで実演します。

```repl
Tutorial.IO> :t (>>=)
Prelude.>>= : Monad m => m a -> (a -> m b) -> m b
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
```

見てとれるように、本モジュールをREPLセッションで読み込んで`(>>=)`の型を調べると、
その名前の2つの演算子が結果に出てきます。
REPLに自前の束縛演算子のみを印字させたいときは、
`IO`を前置しておけば充分です。
完全な名前空間を前置することもできますけどね。

```repl
Tutorial.IO> :t IO.(>>=)
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
Tutorial.IO> :t Tutorial.IO.(>>=)
Tutorial.IO.>>= : Vect m a -> (a -> Vect n b) -> Vect (m * n) b
```

関数名は名前空間で唯一でなければいけませんが、それでも1つのIdrisのモジュールで2つのオーバーロードされた版の関数を定義したいときがあるかもしれないので、Idrisではモジュールに追加の名前空間を加えることができます。例えば`eval`という名前の別の関数を定義するためには、その関数のためのの名前空間に加える必要があります（1つの名前空間中の全定義が同量の空白文字で前置されなければいけないことに注意です）。

```idris
namespace Foo
  export
  eval : Nat -> Nat -> Nat
  eval = (*)

-- `eval`を名前空間で前置していますが、ここでは厳密には不必要です
testFooEval : Nat
testFooEval = Foo.eval 12 100
```

さて、ここで大切な話があります。
外部の名前空間やモジュールから到達できる関数やデータ型というのは、
`export`や`public export`キーワードで印を付けることで*輸出*しなくてはいけません。

`export`と`public export`の違いは次の通り。
`export`の印が付けられた関数は型を輸出しており他の名前空間から呼ぶことができます。
`export`の印が付けられたデータ型は型構築子を輸出しますがデータ構築子は輸出しません。
`public export`の印が付けられた関数は実装も輸出します。
これはコンパイル時計算に使うために必要です。
`public export`の印が付けられたデータ型はデータ構築子も輸出します。

一般的にデータ型は`public export`の印を付けることを検討してください。
さもないとその型の値を作れなかったりパターン照合で解体できないからです。
また、関数をコンパイル時計算で使う予定がないときは`export`の印を付けましょう。

### 束縛 〜びっくりマークを添えて〜

ときどき作用付き計算の組み合わせを表現する上で*doブロック*さえも目にうるさいことがあります。この場合、純粋な式を変更しないままに、作用のある部分にびっくりマークを前置することができます（作用のある部分に空白が含まれる場合は括弧で囲みます）。

```idris
getHello : IO ()
getHello = putStrLn $ "Hello " ++ !getLine ++ "!"
```

上記は以下の*doブロック*に脱糖されます。

```idris
getHello' : IO ()
getHello' = do
  s <- getLine
  putStrLn $ "Hello " ++ s ++ "!"
```

以下は別の例です。

```idris
bangExpr : String -> String -> String -> Maybe Integer
bangExpr s1 s2 s3 =
  Just $ !(parseInteger s1) + !(parseInteger s2) * !(parseInteger s3)
```

そしてこれは以下の*doブロック*に脱糖されます。

```idris
bangExpr' : String -> String -> String -> Maybe Integer
bangExpr' s1 s2 s3 = do
  x1 <- parseInteger s1
  x2 <- parseInteger s2
  x3 <- parseInteger s3
  Just $ x1 + x2 * x3
```

次のことを心に留めておきましょう。
糖衣構文はコードをより読みやすくしたり書くのを便利にしたりするために導入されました。
自分がどれほど賢いかを誇示するためだけに乱用すると、
他のひと（と将来のあなたも！）がコードを読んで理解しようとすることが難しくなります。

### 演習 その2

1. 以下の*doブロック*を実装し直してください。
   1つはびっくりマーク記法を使って、もう1つは入れ子の*束縛*の形式に脱糖した形で書いてください。

   ```idris
   ex1a : IO String
   ex1a = do
     s1 <- getLine
     s2 <- getLine
     s3 <- getLine
     pure $ s1 ++ reverse s2 ++ s3

   ex1b : Maybe Integer
   ex1b = do
     n1 <- parseInteger "12"
     n2 <- parseInteger "300"
     Just $ n1 + n2 * 100
   ```

2. 以下は指標付けられた型族で、注目する値が空か証明的に空でないかのいずれかを取る値を指標で追跡します。

   ```idris
   data List01 : (nonEmpty : Bool) -> Type -> Type where
     Nil  : List01 False a
     (::) : a -> List01 False a -> List01 ne a
   ```

   注目していただきたいのは、`Nil`の場合では`nonEmpty`札が`False`に設定されて*いなければならず*、
   一方で*cons*の場合はどちらでもよいということです。
   なので、`List 01 False a`は空もしくは非空のどちらもありえて、
   どちらなのかはパターン照合することでのみ調べられます。
   他方で、`Nil`の場合は`nonEmpty`札が常に`False`なので、
   `List01 True a`は*cons*でなくてはいけません。

   1. 関数`head`を非空のリストに対して宣言し実装してください。

      ```idris
      head : List01 True a -> a
      ```

   2. あらゆる`List01 ne a`を同じ長さと値の順番の`List01 False
      a`に変換する関数`weaken`を宣言し実装してください。

   3. 非空のリストから空になりうる尾っぽを取り出す関数`tail`を宣言し実装してください。

   4. 型`List 01`の値を連結する関数`(++)`を実装してください。
      以下で、どのように型段階計算を使って、
      2つのうち少なくとも1つが非空であるときに限って、
      結果が非空であることを確かめているかに注目してください。

      ```idris
      (++) : List01 b1 a -> List01 b2 a -> List01 (b1 || b2) a
      ```

   5. ユーティリティ関数`concat'`を実装して`concat`の実装で使ってください。
      `concat`には2枚の真偽値の札が制約なし暗黙子として渡されていますね。
      これは結果が証明的に非空かそうでないかを、この札でパターン照合することで決定する必要があるからです。

      ```idris
      concat' : List01 ne1 (List01 ne2 a) -> List01 False a

      concat :  {ne1, ne2 : _}
             -> List01 ne1 (List01 ne2 a)
             -> List01 (ne1 && ne2) a
      ```

   6. `map01`を実装してください。

      ```idris
      map01 : (a -> b) -> List01 ne a -> List01 ne b
      ```

   7. `List01`を返す計算を並べるための、自前の*束縛*演算子を名前空間`List01`に実装してください。

      解決の糸口：実装では`map01`と`concat`を、
      必要に応じて制約なし暗黙子を使ってくださいね。

      自前の*束縛*演算子が動くことを確かめるためには以下の例が使えます。

      ```idris
      -- これとlfはリスト表記を使うときにどちらの札を使うのかを確定させるために必要です。
      lt : List01 True a -> List01 True a
      lt = id

      lf : List01 False a -> List01 False a
      lf = id

      test : List01 True Integer
      test = List01.do
        x  <- lt [1,2,3]
        y  <- lt [4,5,6,7]
        op <- lt [(*), (+), (-)]
        [op x y]

      test2 : List01 False Integer
      test2 = List01.do
        x  <- lt [1,2,3]
        y  <- Nil {a = Integer}
        op <- lt [(*), (+), (-)]
        lt [op x y]
      ```

演習2に数点補足します。
ここでは`List`と`Data.List1`の能力を単一の指標付けられた型族にまとめています。
これによりリストの結合を正しく扱えます。
つまり、少なくとも一方の引数が証明的に非空であるなら、結果もまた非空なのです。
このことを`List`と`List1`で取り組もうとすると、
合計4つの結合関数を書く必要があるでしょう。
なので、指標付けられた型族の代わりに個々のデータ型を定義できることはよくありますが、
指標付けられた型族のほうが、より複雑な型処方と引き換えに、
書く関数のより精密な事前・事後条件のある型段階計算を行えます。
加えて、データ値へのパターン照合だけからでは指標値を導出できないことはしばしばあり、
そのため消去されない（暗黙にできる）引数として渡さなければなりません。

覚えておいてほしいことは、*doブロック*が最初に脱糖されるもので、
それは型検査やどの*束縛*演算子かの曖昧解決をするかや暗黙引数を埋めていくより前だということです。
したがって上記のような好きな制約や暗黙引数付きの*束縛*演算子を定義することは全くもって大丈夫なのです。
Idrisは*doブロック*を脱糖した*後*に全ての詳細を取り扱います。

## ファイルを取り回す

モジュール`System.File`は*base*ライブラリに由来し、ファイル制御子を取り回したりファイルを読み書きしたりするのに必要なユーティリティを輸出しています。
ファイルパス（例えば"/home/hock/idris/tutorial/tutorial.ipkg"）があるとき、よく最初にすることはファイル制御子（型は`System.File.File`で`fileOpen`という名前）を作ろうとすることです。

以下はUnix/Linux上のファイル中の全空行を数えるプログラムです。

```idris
covering
countEmpty : (path : String) -> IO (Either FileError Nat)
countEmpty path = openFile path Read >>= either (pure . Left) (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- fEOF file | True => closeFile file $> Right k
          Right "\n" <- fGetLine file
            | Right _  => go k file
            | Left err => closeFile file $> Left err
          go (k + 1) file
```

上の例で*doブロック*なしに`(>>=)`を呼び出しました。
このときに起こることを確実に理解しましょう。
簡潔な関数型コードを読むことは他人のコードを理解するためには大切です。
REPLで関数`either`を見たり、
`(pure . Left)`がしていることを調べたり、
`go`のカリー化された版を`either`の2つ目の引数として使っていることに注目したりしてください。

関数`go`については追加で説明せねばなりません。
まず、`let`束縛でも見たのと同じ構文で、結果にそのままパターン照合を使っているところに着目しましょう。
見てとれるようにいくつかの垂直棒を使って1つ以上の追加のパターンを制御できます。
ファイルから1行読むために関数`fGetLine`を使っています。
ファイルシステムでのほとんどの操作につきものですが、
この関数は`FileError`を返すかもしれません。
そのような場合に正しく対処する必要があります。
さらに言えば`fGetLine`は空行のとき末尾の改行文字`'\n'`を含む行を返すので、
空行を確認するためには空文字列`""`の代わりに`"\n"`に照合する必要があります。

最後に`go`は証明的に全域ではなく、それはそうです。
`/dev/urandom`や`/dev/zero`のようなファイルはデータの無限ストリームを提供しており、
そのため`countEmpty`がそのようなファイルパスで呼び出されたときは終了することがないでしょう。

### 安全な資源制御

`countEmpty`で手動でファイル制御子を開いたり閉じたりしなければなりませんでしたね。
これはエラーの温床ですし億劫です。
資源制御は大きな話題であり、ここではその詳細に踏み込むことはありませんが、
`System.File`から輸出されている便利な関数があります。
それは`withFile`で、これはファイルを開いたり閉じたりファイルのエラーの制御の面倒を見てくれたりします。

```idris
covering
countEmpty' : (path : String) -> IO (Either FileError Nat)
countEmpty' path = withFile path Read pure (go 0)
  where covering go : Nat -> File -> IO (Either FileError Nat)
        go k file = do
          False <- fEOF file | True => pure (Right k)
          Right "\n" <- fGetLine file
            | Right _  => go k file
            | Left err => pure (Left err)
          go (k + 1) file
```

さあ、`withFile`の型を眺めてみて、
それからこれを使って`countEmpty'`の実装をどのように簡単にしているのか見てみましょう。
ちょっとだけより複雑な関数の型を読んで理解することはIdrisで書かれたプログラムを学ぶ上で大事です。

#### インターフェース`HasIO`

これまで使ってきた`IO`関数を見ると、
全てではないにしてもほとんどが実際には`IO`そのものを扱ってはおらず、
制約`HasIO`を持つ型変数`io`を使っていることに気付きます。
このインターフェースのおかげで型`IO a`の値を他の文脈に*持ち上げ*ることができます。
この使用例については後の章、特にモナド変換子について話すときに見ていきましょう。
現段階ではこれらの`io`変数を`IO`に特化させたものとして扱ってよいです。

### 演習 その3

1. 上の例で見てきたように、ファイル制御子を取り回す`IO`行動には失敗する危険性が付き纏います。
   したがってこういった入れ子の作用がを扱ういくらかのユーティリティ関数と自前の*束縛*演算子を書くことで、話を簡単にすることができます。
   新しい名前空間`IOErr`の中で以下のユーティリティ関数を実装し、これらを使ってさらに`countEmpty'`の実装を綺麗にしましょう。

   ```idris
   pure : a -> IO (Either e a)

   fail : e -> IO (Either e a)

   lift : IO a -> IO (Either e a)

   catch : IO (Either e1 a) -> (e1 -> IO (Either e2 a)) -> IO (Either e2 a)

   (>>=) : IO (Either e a) -> (a -> IO (Either e b)) -> IO (Either e b)

   (>>) : IO (Either e ()) -> Lazy (IO (Either e a)) -> IO (Either e a)
   ```

2. ファイル中の単語を数える関数`countWords`を書いてください。
   実装では`Data.String.words`と演習1のユーティリティを使うことを検討してください。

3. ファイル中の行を順次処理し道中の状態を累積するお助け関数を実装することで、
   `countEmpty`と`countWords`で使う機能を一般化することができます。
   `withLines`を実装し、それを使って`countEmpty`と`countWords`を実装してください。

   ```idris
   covering
   withLines :  (path : String)
             -> (accum : s -> String -> s)
             -> (initialState : s)
             -> IO (Either FileError s)
   ```

4. 値を累積するのによく`Monoid`が使われます。
   この場合は`withLines`に特化させると便利になるということですね。
   `withLines`を使って`foldLines`を以下の型に沿って実装してください。

   ```idris
   covering
   foldLines :  Monoid s
             => (path : String)
             -> (f    : String -> s)
             -> IO (Either FileError s)
   ```

5. 1つのテキスト文書中の行数、単語数、文字数を形状する関数`wordCount`を実装してください。
   これらの値を保管し累積できるように自前のレコード型を`Monoid`の実装とともに定義し、`foldLines`を`wordCount`の実装で使ってください。

## `IO`はどのように実装されているのか

随分長くなってしまった章のこの最後の節では、
勇気を出してIdrisでどのように`IO`が実装されているのか覗いてみましょう。
面白いことに、`IO`は組み込み型ではないものの、1点些細な特異性がある以外は普通のデータ型なのです。
そのことをREPLで学びましょう。

```repl
Tutorial.IO> :doc IO
data PrimIO.IO : Type -> Type
  Totality: total
  Constructor: MkIO : (1 _ : PrimIO a) -> IO a
  Hints:
    Applicative IO
    Functor IO
    HasLinearIO IO
    Monad IO
```

ここで`IO`が`MkIO`という名前の単一データ構築子を持ち、
この構築子が型`PrimIO a`で数量子*1*の単一引数を取ることがわかります。
今は数量子についてお話ししませんが、それは実のところ`IO`の仕組みを理解するのには重要ではないからです。

さて、`PrimIO`は以下の関数の型別称です。

```repl
Tutorial.IO> :printdef PrimIO
PrimIO.PrimIO : Type -> Type
PrimIO a = (1 _ : %World) -> IORes a
```

繰り返しますが数量子は気にしないでください。
唯一の見つかっていないパズルピースは`IORes a`で、
これは公に輸出されているレコード型です。

```repl
Solutions.IO> :doc IORes
data PrimIO.IORes : Type -> Type
  Totality: total
  Constructor: MkIORes : a -> (1 _ : %World) -> IORes a
```

ですので、このことを全てまとめると、`IO`は以下の関数型に似た何かの梱包になります。

```repl
%World -> (a, %World)
```

型`%World`のことはプログラムの外側の世界の状態（ファイルシステム、記憶装置、ネットワーク接続など）の
仮置場のように考えられます。
概念的には、`IO`行動を実行するには世界の現在の状態を渡し、
更新された世界状態に加えて型`a`の結果が返却される形です。
更新される世界状態はコンピュータプログラムで表現できる副作用の全てを表現します。

ここで理解しておいてほしいことは、*世界の状態*なんてものはないということです。
`%World`型はただの仮置場であって、
受け渡されはするものの実行時に一度も中身が調べられないような類の定数に変換されます。
なので型`%World`の値があったとして、
`IO a`行動に渡して実行することはできますが、
これは必ず実行時に起こることなのです。
つまり、型`%World`の単一の値
（特に意味のない仮置場で`null`や`0`や、JavaScriptバックエンドでは`undefined`のような値）は
`main`関数に渡され、
それから全体のプログラムが動き始めます。
しかし、型`%World`の値をプログラムで生み出すことは不可能であり、
したがって型`a`の値を`IO a`行動から抽出することは決してできないのです（`unsafePerformIO`を除く）。

モナド変換子と状態モナドについてお話ししたあとでは、
`IO`が抽象的な状態型付きではあれど変装した状態モナドに過ぎないとわかるでしょう。
この抽象的な点により作用付き計算を走らせることができないようになっています。

## まとめ

* 型`IO a`の値は副作用付きのプログラムを記述しており、
  最終的に型`a`の値になります。

* 安全に`IO a`から型`a`の値を取り出すことはできませんが、
  いくつかの結合子と構文的建材によって`IO`行動を組み合わせたりより複雑なプログラムを構築できます。

* *doブロック*があると`IO`行動を順番に組み合わせるのが便利になります。

* *doブロック*は*束縛*演算子 (`(>>=)`) の入れ子の適用に脱糖されます。

* *束縛*演算子、そして*doブロック*は、既定の（モナドな）*束縛*の代わりとなる自前の挙動を実現するためにオーバーロードできます。

* 見えないところでは、`IO`行動は象徴としての`%World`状態を操作する状態付き計算になっています。

### お次は？

さて、*モナド*と*束縛*演算子をチラ見したところで、
[次章](Functor.md)でいよいよ`Monad`と関連する実際のインターフェースのいくつかを紹介する時が来ました。

<!-- vi: filetype=idris2:syntax=markdown
-->
