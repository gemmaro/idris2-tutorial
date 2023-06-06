# 関数 その2

これまでIdris言語の核となる特徴について学びました。
Haskellのような他の純粋で強く型付けされたプログラミング言語と共通点があります。
（高階）関数、代数的データ型、パターン照合、パラメトリック多相（汎化型と汎化関数）、そしてアドホック多相（インターフェースと制約付き関数）がそうです。

この章ではIdrisの実践上の関数とその型を解剖し始めます。
暗黙引数、名前付き引数、そして型消去と数量的型を学びます。
しかしまずは`let`束縛と`where`ブロックを見ていきます。
これらのおかげで、複雑すぎて単一行のコードに収まりきらない関数も、
実装することができるようになります。
始めましょう！

```idris
module Tutorial.Functions2

%default total
```

## let束縛と局所定義

これまで見てきた関数はパターン照合で直接実装できる程度には単純なものでした。
追加の付属関数ないし変数を必要としませんでした。
いつもこういうわけではなくて、
新しい局所変数と局所関数を導入したり再利用したりするための、
2つの大事な言語的構築要素があります。
これらを2つの事例の観察から見ていきましょう。

### 使用例1：算術平均と標準偏差

この例では算術平均と標準偏差を浮動小数点数値のリストから計算することを考えます。

まず総和を数値のリストから計算する関数が必要です。
*Prelude*はこのための関数`sum`を公開しています。

```repl
Main> :t sum
Prelude.sum : Num a => Foldable t => t a -> a
```

これは、もちろんのこと、[直前の節](Interfaces.md)の演習10での`sumList`に似たものです。
しかし`Foldable`の実装がある全ての容器型に汎化されています。
インターフェース`Foldable`については後の節で学びましょう。

分散を計算するためにはリストの全ての値を新しい値に計算する必要もあります。
なぜならリスト中の全ての値から平均を引いて結果を平方する必要があるからです。
前の節の演習でこのための関数`mapList`を定義しました。
*Prelude*は、当然、既に似たような関数`map`を公開しています。
これもまたより汎用的で自前の`Maybe`のための`mapMaybe`や`Either e`のための`mapEither`としても動きます。
以下が型です。

```repl
Main> :t map
Prelude.map : Functor f => (a -> b) -> f a -> f b
```

インターフェース`Functor`についても後の節でお話しします。

最後に値のリストの長さを計算する方法が必要です。
これには関数`length`を使います。

```repl
Main> :t List.length
Prelude.List.length : List a -> Nat
```

ここで`Nat`は自然数型です。
（範囲がなく、符号なしです。）
`Nat`は実のところ原始的なデータ型ではなくて、
*Prelude*で定義された直和型で、
データ構築子`Z : Nat`（ゼロ）と`S : Nat -> Nat`（それ以上）からなります。
自然数をこうして定義するのはかなり非効率に思えますが、
Idrisはこうしたものといくつかの他の*数のような*型を特別に扱い、
コード生成の段階で原始的な整数に置き換えます。

これで`mean`の実装を与えられるようになります。
これはIdrisであり、明白な意味論に気をつけているので、
単に`Double`のタプルを返すのではなく、ささっと自前のレコード型を定義します。
こうすることでより明白になるのは、どちらの小数点数がどちらの統計的な実態に対応するのかということです。

```idris
square : Double -> Double
square n = n * n

record Stats where
  constructor MkStats
  mean      : Double
  variance  : Double
  deviation : Double

stats : List Double -> Stats
stats xs =
  let len      := cast (length xs)
      mean     := sum xs / len
      variance := sum (map (\x => square (x - mean)) xs) / len
   in MkStats mean variance (sqrt variance)
```

いつも通り、まずはREPLで試してみます。

```repl
Tutorial.Functions2> stats [2,4,4,4,5,5,7,9]
MkStats 5.0 4.0 2.0
```

動いているようなので1つずつ紐解いていきましょう。
いくつかの局所変数 (`len`, `mean`, `variance`) を導入し、
それら全ては実装の残りの部分で1度以上使われます。
これには`let`束縛を使います。
順に、`let`キーワード、1つ以上の変数代入が続き、最後の式には`in`が後置していなければいけません。
空白はここでも重要ですよ。
3つの変数名は適切に整列していなくてはいけません。
さあ、`mean`や`variance`の前の空白を削除すると何が起こるのかやってみましょう。
ただし、代入演算子`:=`は整列していなくても大丈夫です。
こうしたのは可読性がよくなると思っているからです。

それぞれの変数とその型についてもさくっと見ていきましょう。
`len`はリストの長さで、のちのちのために`Double`に嵌め込まれています。
というのは、`Double`な他の値を長さで割ることになるからです。
Idrisはこうしたことに大変厳格です。
明示的な嵌め込みなくして、数値型を混在させることはできません。
注意していただきたいのは、この場合はIdrisが`len`の型を周囲の文脈から*推論*することができているということです。
`mean`は直感的です。
リストに保管された値を`sum`で合計し、リストの長さで割っています。
`variance`は3つの中でもっとも込み入っています。
リストのそれぞれの要素について、
匿名関数を使って平均を引いたのちに、その平方を取っています。
そうしてできた値を合計し、再度値の数で割ります。

### 使用例2：簡素なWebサーバを模擬する

2つ目の使用例ではもうちょっと大きいアプリケーションを書いていきます。
実装したいビジネスロジックに対して、データ型と関数をどのように設計すればよいかを考えられるようになるでしょう。

音楽配信webサーバを稼動させているのだとします。
そこでは利用者はアルバム一式を買ってオンラインで聴くことができます。
サーバに接続して購入したアルバムの1つにアクセスする利用者を模擬したいところです。

まず沢山のレコード型を定義します。

```idris
record Artist where
  constructor MkArtist
  name : String

record Album where
  constructor MkAlbum
  name   : String
  artist : Artist

record Email where
  constructor MkEmail
  value : String

record Password where
  constructor MkPassword
  value : String

record User where
  constructor MkUser
  name     : String
  email    : Email
  password : Password
  albums   : List Album
```

これらはほぼ見ればわかります。
ただし、いくつかのレコード型（`Email`, `Artist`, `Password`）で単一の値を新しいレコード型で梱包しているところに注目です。
当然、剥き出しの`String`型を代わりに使うことも*できはします*が、そうすると最終的に`String`のフィールドが沢山あることになるため、見分けがつきにくくなるかもしれません。
Eメールの文字列とパスワードの文字列を混同するなんてことがないように、両方を新しいレコード型で梱包しておくと助けになります。
いくつかのインターフェースを実装し直さなければいけない負担と引き換えに、型安全性を劇的に高めますから。
*Prelude*由来のユーティリティ関数`on`はこうしたとき大変役に立ちます。
型をREPLで調べて、何をするものなのか理解するのをお忘れなく。

```idris
Eq Artist where (==) = (==) `on` name

Eq Email where (==) = (==) `on` value

Eq Password where (==) = (==) `on` value

Eq Album where (==) = (==) `on` \a => (a.name, a.artist)
```

`Album`の場合、レコードの2つのフィールドを`Pair`で梱包しています。
`Pair`には既に`Eq`の実装が付属しています。
なのでここでも関数`on`を使います。
とっても便利。

次に、サーバへの要求とサーバからの応答を表現するデータ型を定義します。

```idris
record Credentials where
  constructor MkCredentials
  email    : Email
  password : Password

record Request where
  constructor MkRequest
  credentials : Credentials
  album       : Album

data Response : Type where
  UnknownUser     : Email -> Response
  InvalidPassword : Response
  AccessDenied    : Email -> Album -> Response
  Success         : Album -> Response
```

サーバの応答については、自前の直和型を使って、顧客の要求に対するありうる出力を符号化します。
実践の場では、`Success`のときには実際にアルバム配信を開始するための何らかの接続を返すのでしょうが、
この挙動を模擬するために、ここでは単に見付かったアルバムを梱包することにします。

これで準備万端、サーバへの要求の制御を模擬できます。
利用者のデータベースを真似るには、利用者のリストがあれば事足ります。
こちらが実装したい関数の型です。

```idris
DB : Type
DB = List User

handleRequest : DB -> Request -> Response
```

`DB`という名前で`List User`に短い別名を定義しましたね。
長めの型処方をより読みやすく、そこでの文脈に即した型の意味を教えてくれるものにするために、こうしておくと役に立つことがよくあります。
しかし、これは決して新しい型を導入して*いない*ので、型安全性を増すこともありません。
`DB`と`List User`は*同一*であり、額面通りの意味で型`DB`の値は`List
User`の値が入るよう場所ならどこでも使えますし、逆もまた然りです。
したがって、より複雑なプログラムでは大抵、単一フィールドレコードに値をくるんで新しい型を定義するほうが好ましいです。

この関数の実装での処理は以下のように進行します。
まずEメールアドレスでデータベースから`User`を見付けだそうとします。
もしこれが成功したら、与えられたパスワードと利用者の実際のパスワードと比較します。
もし2つが一致したら、利用者のアルバムのリストから要求されたアルバムを見付けだします。
もしこれらの過程の全てが成功したら、結果は`Success`にくるまれた`Album`になります。
もしどれか1つでも過程が失敗したら、正確に何が起こったのかを表現する結果を返します。

考えられる実装はこちらです。

```idris
handleRequest db (MkRequest (MkCredentials email pw) album) =
  case lookupUser db of
    Just (MkUser _ _ password albums)  =>
      if password == pw then lookupAlbum albums else InvalidPassword

    Nothing => UnknownUser email

  where lookupUser : List User -> Maybe User
        lookupUser []        = Nothing
        lookupUser (x :: xs) =
          if x.email == email then Just x else lookupUser xs

        lookupAlbum : List Album -> Response
        lookupAlbum []        = AccessDenied email album
        lookupAlbum (x :: xs) =
          if x == album then Success album else lookupAlbum xs
```

この例にあるいくつかの点について指摘したいと思います。
まず、1回のパターン照合で入れ子のレコードから値を抽出することができます。
2つ目に2つの*局所*関数を`where`ブロック内に定義しました。
`lookupUser`と`lookupAlbum`です。
両方の関数は囲まれたスコープにある全ての変数にアクセスできます。
例えば`lookupUser`は実装の最初の行にあるパターン照合から`album`変数を使います。
同様に`lookupAlbum`も`album`変数を使用します。

`where`ブロックは新しい局所定義を導入し、
`where`がある周囲のスコープと同じ`where`ブロックにある後に定義された他の関数からのみ、
この定義にアクセスできます。
これらの定義は明示的に型付けされ同量の空白で字下げされていなければいけません。

局所定義は`let`キーワードを用いて関数の実装の*前*で導入しても構いません。
この`let`の使用法は前述した*let束縛*と混同しないようにしてください。
let束縛は一時的な計算の結果を束縛して再利用するものでした。
以下では`handleRequest`を`let`キーワードにより導入された局所定義でどのように実装できるかを示しています。
繰り返しますが、全ての定義は適切に型付けされ、字下げされている必要があります。

```idris
handleRequest' : DB -> Request -> Response
handleRequest' db (MkRequest (MkCredentials email pw) album) =
  let lookupUser : List User -> Maybe User
      lookupUser []        = Nothing
      lookupUser (x :: xs) =
        if x.email == email then Just x else lookupUser xs

      lookupAlbum : List Album -> Response
      lookupAlbum []        = AccessDenied email album
      lookupAlbum (x :: xs) =
        if x == album then Success album else lookupAlbum xs

   in case lookupUser db of
        Just (MkUser _ _ password albums)  =>
          if password == pw then lookupAlbum albums else InvalidPassword

        Nothing => UnknownUser email
```

### 演習

この節の演習で純粋関数型のコードを書く経験値が上がるでしょう。
場合によっては`let`式や`where`ブロックを使うと便利かもしれませんが、
いつも必要というわけではありません。

演習3はまたもや最重要です。
`traverseList`はより汎用的な`traverse`の特殊版です。
`traverse`は最も強力で多彩な関数の1つで、*Prelude*にあります（型を確認しましょう！）。

1. *base*のモジュール`Data.List`は関数`find`と`elemBy`を公開しています。
   型を調べた上で、`handleRequest`の実装で使ってください。
   これで完全に`where`ブロックを排除できます。

2. DND鎖に表れる4つの[核酸塩基](https://en.wikipedia.org/wiki/Nucleobase)をリストにした列挙型を定義してください。
   核酸塩基のリストについて、型別称`DNA`も定義してください。
   単一文字（型`Char`）を核酸塩基に変換する関数`readBase`を宣言・実装してください。
   実装では`'A'`や`'a'`のように文字直値が使えます。
   この関数は失敗するかもしれないので、結果の型をそれにしたがって調整してください。

3. 次の関数を実装してください。
   リスト中の全ての値を関数で変換しようとするものです。
   ただし、関数は失敗するかもしれません。
   全ての変換が成功したときに限って、
   結果は同じ順序で変換後の値のリストが入った`Just`になります。

   ```idris
   traverseList : (a -> Maybe b) -> List a -> Maybe (List b)
   ```

   関数が正しく振る舞うことを以下の検査で確かめられます。
   `traverseList Just [1,2,3] = Just [1,2,3]`

4. 演習2と3で定義した関数と型を使って、関数`readDNA : String -> Maybe DNA`を実装してください。
   *Prelude*の関数*unpack*も要ることでしょう。

5. DNA鎖の転写を計算する関数`complement : DNA -> DNA`を実装してください。

## 関数引数の真実

ここまで、最上位で定義された関数は以下のような見た目をしていました。

```idris
zipEitherWith : (a -> b -> c) -> Either e a -> Either e b -> Either e c
zipEitherWith f (Right va) (Right vb) = Right (f va vb)
zipEitherWith f (Left e)   _          = Left e
zipEitherWith f _          (Left e)   = Left e
```

関数`zipEitherWith`は汎化高階関数で、2つの`Either`に保管された値を2引数関数を介して結合します。
どちらかの`Either`引数が`Left`なら、結果もまた`Left`です。

これは*汎化関数*で*型変数*`a`, `b`, `c`, `e`を取ります。
しかし、もっと冗長な型が`zipEitherWith`にはあります。
この型はREPLで見ることができ、`:ti
zipEitherWith`と入力すればよいです（ここで`i`はIdrisが`implicit`（訳註：暗黙の）引数を含めるようにという意味です）。
こんな感じの型になります。

```idris
zipEitherWith' :  {0 a : Type}
               -> {0 b : Type}
               -> {0 c : Type}
               -> {0 e : Type}
               -> (a -> b -> c)
               -> Either e a
               -> Either e b
               -> Either e c
```

何が起こっているのかを理解するには、
名前付き引数、暗黙引数、そして数量子についてお話しせねばなりません。

### 名前付き引数

関数の型ではそれぞれの引数に名前を付けられます。
こんな感じ。

```idris
fromMaybe : (deflt : a) -> (ma : Maybe a) -> a
fromMaybe deflt Nothing = deflt
fromMaybe _    (Just x) = x
```

ここで最初の引数は`deflt`と名付けられており、2つ目のほうは`ma`です。
これらの名前は関数の実装で再利用することができ、
実際に`deflt`がそうなっています。
でもこれは必須ではありません。
実装で違う名前を使うことも自由です。
なぜ引数のための名前を選ぶのかということには、いくつかの理由があります。
名前はドキュメントとして機能しますが、
加えて以下の構文を使うときは任意の順序で関数に引数を渡せます。

```idris
extractBool : Maybe Bool -> Bool
extractBool v = fromMaybe { ma = v, deflt = False }
```

さらに言えば以下です。

```idris
extractBool2 : Maybe Bool -> Bool
extractBool2 = fromMaybe { deflt = False }
```

レコード構築子内の引数はフィールド名にしたがって自動的に名付けられます。

```idris
record Dragon where
  constructor MkDragon
  name      : String
  strength  : Nat
  hitPoints : Int16

gorgar : Dragon
gorgar = MkDragon { strength = 150, name = "Gorgar", hitPoints = 10000 }
```

上で述べた使用例では、名前付き引数は単に便利というだけで完全にあってもなくてもよいものでした。
しかし、Idrisは*依存型*プログラミング言語です。
つまり、型は値から計算することができ、型は値に依存することができます。
たとえば、関数の*結果の型*はその引数のうちの1つの*値*に*依存*するようにできます。
以下はわざとらしい例です。

```idris
IntOrString : Bool -> Type
IntOrString True  = Integer
IntOrString False = String

intOrString : (v : Bool) -> IntOrString v
intOrString False = "I'm a String"
intOrString True  = 1000
```

初めてこれを見ると、何が起こっているのか理解しにくいことでしょう。
まず、関数`IntOrString`は`Type`を`Bool`値から算出します。
引数が`True`なら返る型は`Integer`で、引数が`False`なら`String`が返ります。
これを、真偽値引数`v`に基づいて、関数`intOrString`の返却型を計算するのに使っています。
`v`が`True`なら返却型は`Integer`で（`IntOrString True =
Integer`に従っています）、そうでなければ`String`です。

ここで、`intOrString`の型処方では型`Bool`の引数に名前(`v`)を与える*必要*がありますね。
返却型`IntOrString v`で参照するためです。

今の時点では、どうしてこれが便利なのか、どうしてまたそんな妙な型の関数を定義したくなるものか、と怪訝に思われるかもしれません。
来たるべき時に、とても有用な例を沢山見ていきましょう！
依存型の関数の型を表現するために、
少なくともいくつかの関数の引数に名前を付けたり、
他の引数の型で名付けた引数の名前を参照したりする必要があるのだ、
ということが伝われば充分です。

### 暗黙引数

暗黙引数とは、
コンパイラが推論して自動的に記入してくれるような値の引数を指します。
たとえば、以下の関数処方では、コンパイラが型変数`a`の値を他の引数の型から自動的に推定してくれるようになっています。
（0数量子はここでは無視してください。
次の小節で説明します。）

```idris
maybeToEither : {0 a : Type} -> Maybe a -> Either String a
maybeToEither Nothing  = Left "Nope"
maybeToEither (Just x) = Right x

-- Please remember, that the above is
-- equivalent to the following:
maybeToEither' : Maybe a -> Either String a
maybeToEither' Nothing  = Left "Nope"
maybeToEither' (Just x) = Right x
```

見てとれるように、暗黙引数は波括弧に囲まれており、明示的な名前付き引数とは違います。
名前付き引数では丸括弧に囲まれていたのでした。
暗黙引数の値を推論することはいつもできるわけではありません。
たとえば、以下をREPLに入力すると、Idrisはエラーを出して実行に失敗します。

```repl
Tutorial.Functions2> show (maybeToEither Nothing)
Error: Can't find an implementation for Show (Either String ?a).
```

Idrisは`a`が実際に何であるかを知らずに`Show (Either String a)`の実装を見つけることはできません。
型変数の前の疑問符がありますね。
`?a`となっています。
こうなったら型検査器を手助けする方法がいくつかあります。
たとえば暗黙引数に値を明示的に渡すことができます。
以下がそうするための構文です。

```repl
Tutorial.Functions2> show (maybeToEither {a = Int8} Nothing)
"Left "Nope""
```

見てとれるように明示的な名前付き引数のところで前に見たのと同じ文法を使っています。
また、2種の引数の渡し方は混在させられます。

*Prelude*由来のユーティリティ関数`the`を使って、全体の式の型を指定することもできます。

```repl
Tutorial.Functions2> show (the (Either String Int8) (maybeToEither Nothing))
"Left "Nope""
```

`the`の型を見てみるとわかりやすいです。

```repl
Tutorial.Functions2> :ti the
Prelude.the : (0 a : Type) -> a -> a
```

ユーティリティ関数`id`と比較してみましょう。

```repl
Tutorial.Functions2> :ti id
Prelude.id : {0 a : Type} -> a -> a
```

唯一の2つの違いはというと、
`the`の場合型変数`a`が*明示的な*引数であるのに対し、
`id`の場合*暗黙の*引数であることです。
2つの関数はほぼ同じ型（と実装！）であるにも関わらず、
かなり異なる目的で使われます。
`the`は型推論を助けるために使われますが、
`id`は引数を全く変更することなしに返したいようなときに使います。
（`id`は高階関数があるときは驚くほどよく使います。）

上で見た型推論を向上する両方の手段はかなりよく使います。
Idrisのプログラマは理解しておく必要があります。

### 多重度

最後にゼロ多重度について話さねばなりません。
ゼロ多重度は本節の型処方でちらほら出ていました。
Idris 2は前作のIdris 1とは異なり、*数量的型理論* (quantitative type theory; QTT)
と呼ばれる中核言語に基づいています。
つまり、Idris 2での全ての変数には以下の3つの多重度のうち1つが関係するのです。

* `0`、これは変数が実行時に*消去*されるという意味です。
* `1`、これは変数が実行時に*ちょうど1回だけ*使われるという意味です。
* *制限なし*（既定値）、これは変数が実行時に際限なく使えるという意味です。

3つの中で最も複雑な多重度`1`についてはここでは触れません。
しかし、多重度`0`はよく着目されます。
多重度`0`の変数は*コンパイル時*のみに関係があります。
実行時には姿を見せず、その変数の計算はプログラムの実行時効率に何ら影響がありません。

`maybeToEither`の型処方では型変数`a`が多重度`0`を持っていましたが、
それはつまり型変数が消去されコンパイル時にのみ関係するということなのです。
一方で`Maybe a`引数は*制限なし*多重度です。

明示的に引数に多重度を註釈することもできます。
その場合ここでも引数は括弧内になくてはいけません。
例えば`the`の型処方をもう一度見てみてください。

### 下線文字

必要最小限のコードだけを書いて、残りをIdrisに調べさせたいことはよくあります。
既にそのような状況について学びました。
全捕捉パターンです。
パターン照合の変数が右側で使われなければ、
単に省略するだけということはできないものの（複数の引数のうちどれを省くつもりなのかをIdrisが推定できません）、
代わりに下線文字で場所取りをすることができます。

```idris
isRight : Either a b -> Bool
isRight (Right _) = True
isRight _         = False
```

しかし`isRight`の型処方を見れば、型変数`a`と`b`も1度のみ使われており、
したがって特に重要ではないことに気付きます。
型変数を省きましょう。

```idris
isRight' : Either _ _ -> Bool
isRight' (Right _) = True
isRight' _         = False
```

`zipEitherWith`の詳細な型処方では、Idrisにとって暗黙引数が型`Type`なことは明らかでしょう。
とどのつまり、全部あとで`Either`型構築子に適用されるのです。
この型構築子は型が`Type -> Type -> Type`です。
省いてみましょう。

```idris
zipEitherWith'' :  {0 a : _}
                -> {0 b : _}
                -> {0 c : _}
                -> {0 e : _}
                -> (a -> b -> c)
                -> Either e a
                -> Either e b
                -> Either e c
```

以下のわざとらしい例について考えましょう。

```idris
foo : Integer -> String
foo n = show (the (Either String Integer) (Right n))
```

`Integer`を`Right`の中にくるんでいるので、
`Either String Integer`の2つ目の引数が`Integer`であることは自明です。
`String`だけIdrisは推論できません。
さらにいいことに`Either`自体も明らかなのです！
不必要な雑音を消しましょう。

```idris
foo' : Integer -> String
foo' n = show (the (_ String _) (Right n))
```

注意していただきたいのは、`foo`でのように下線文字を使うことはいつも望ましいものとは限らないということです。
書かれたコードをかなり劇的に朧気なものにしてしまいかねないからです。
文法的に便利なものを使うのは常にコードを読みやすくするためにし、
人々にあなたの賢さを誇示しないようにしましょう。

## 虫食いプログラミング

ここまでの演習を全部解いてきましたか。
型検査器にいつも小言をくらっていて本当は役に立っていないと腹を立てているでしょうか。
今それが変わります。
Idrisにはいくつかの大変役に立つ対話的な編集機能が備わっています。
（型が充分に特定のものであれば）時々コンパイラは完全な関数を実装できることがあります。
それができない場合であっても、非常に有用で重要な特徴がIdrisにはあります。
型が複雑になりすぎたときに手助けしてくれるもの、それが虫食いです。
虫食いは変数で、変数名は疑問符が前に付きます。
あとで機能の一部を実装するつもりの場所であればどこにでも、虫食いを仮置場として使えます。
加えて虫食いの型と虫食いのスコープにある他の全ての変数の型と数量子をREPLで（あるいは必要なプラグインが設定できていればエディタで）調べることができます。
虫食いを実際に見てみましょう。

本節の前のほうの演習の`traverseList`の例を覚えていますか。
初めて適用的リスト巡回に出喰わしたのだとしたら、仕組みがちょっと腑に落ちなかったかもしれません。
そうですね、もう少しつぶさに見てみることにしましょう。
`Either e`を返す同じ機能の関数を実装することを考えます。
ここで`e`は`Semigroup`の実装を持つ型であり、
巡回の道中にある`Left`の全ての値を積み重ねます。

以下が関数の型です。

```idris
traverseEither :  Semigroup e
               => (a -> Either e b)
               -> List a
               -> Either e (List b)
```

さて、読み進めていくにあたって、読者のみなさんは自分でIdrisのソースファイルを書き始めてREPLセッションに読み込まれるとよいでしょう。
コードはこちらで記述されている内容にしたがって調整していきます。
最初にすることは右側に虫食いの実装の骨組を書くことです。

```repl
traverseEither fun as = ?impl
```

そうしたらREPLに向かい、コマンド`:r`を使ってファイルを再読み込みします。
そして`:m`とすれば全ての*メタ変数*が列挙されます。

```repl
Tutorial.Functions2> :m
1 hole:
  Tutorial.Functions2.impl : Either e (List b)
```

次は虫食いの型を表示したいところです（加えて周囲の文脈にある全ての変数とその型も）。

```repl
Tutorial.Functions2> :t impl
 0 b : Type
 0 a : Type
 0 e : Type
   as : List a
   fun : a -> Either e b
------------------------------
impl : Either e (List b)
```

というわけで、消去された型変数 (`a`, `b`, `e`)、
型`List a`の`as`という名前の値、
そして`a`から`Either e b`への関数で名前が`fun`のものがあります。
目標は型`Either a (List b)`の値を思い付くことです。

単に`Right []`を返すことも*できなくはない*のですが、
それは入力のリストがまさしく空リストのときのみ当てはまります。
したがってリストに関してパターン照合するところから始めるとよいでしょう。

```repl
traverseEither fun []        = ?impl_0
traverseEither fun (x :: xs) = ?impl_1
```

結果は2つの虫食いで、それぞれ別の名前でなくてはいけません。
`impl_0`を調べると以下の結果になります。

```repl
Tutorial.Functions2> :t impl_0
 0 b : Type
 0 a : Type
 0 e : Type
   fun : a -> Either e b
------------------------------
impl_0 : Either e (List b)
```

さあ、ここが面白いところです。
何にも手を付けることなく型`Either e (List b)`の値を思い付かなければいけません。
`a`については何も知らないので、その値を`fun`を呼び出すための引数に渡せないのです。
同様に`e`や`b`についても全然わからないため、
これらの値はいずれも生み出すことができません。
取るべき*唯一の*選択肢は`impl_0`を`Right`でくるまれた空リストで置き換えることです。

```idris
traverseEither fun []        = Right []
```

非空の場合はもちろんこれより少しだけ込み入っています。
以下が`?impl_1`の文脈です。

```repl
Tutorial.Functions2> :t impl_1
 0 b : Type
 0 a : Type
 0 e : Type
   x : a
   xs : List a
   fun : a -> Either e b
------------------------------
impl_1 : Either e (List b)
```

`x`は型が`a`であるため、
`fun`の引数に使ったり、
無視してしまったりできます。
他方で`xs`はリストの残り部分で型が`List a`です。
これも使わずにおいたり`traverseEither`をさらに再帰的に呼び出したりできます。
目標は*全ての*値を変換しようとすることですから、いずれも欠かせないことになります。
2つが`Left`な場合は値を積み重ねなければいけないため、
何にせよ結局は両方の計算をする必要があります。
（`fun`を実行し、そして再帰的に`traverseEither`を呼び出します。）
したがって両方を同時に行い、
`Pair`に両方をくるむことで1つのパターン照合により結果を分析できます。

```repl
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
   p => ?impl_2
```

もう一度文脈を調べます。

```repl
Tutorial.Functions2> :t impl_2
 0 b : Type
 0 a : Type
 0 e : Type
   xs : List a
   fun : a -> Either e b
   x : a
   p : (Either e b, Either e (List b))
------------------------------
impl_2 : Either e (List b)
```

間違いなく実装の解明には対`p`をパターン照合する必要があります。
この対は2つの計算が成功したかを表します。

```repl
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
    (Left y, Left z)   => ?impl_6
    (Left y, Right _)  => ?impl_7
    (Right _, Left z)  => ?impl_8
    (Right y, Right z) => ?impl_9
```

この時点で実際何をしたかったのかお忘れかもしれません。
（少なくとも私は、厄介なことにこうしたことがよくあります。）
なので目標をさくっと確認しましょう。

```repl
Tutorial.Functions2> :t impl_6
 0 b : Type
 0 a : Type
 0 e : Type
   xs : List a
   fun : a -> Either e b
   x : a
   y : e
   z : e
------------------------------
impl_6 : Either e (List b)
```

つまり、ここでも型`Either e (List b)`の値を追い求めており、
範疇には型`e`の2つの値があります。
仕様にしたがうと`e`の`Semigroup`実装を使って積み重ねたいところです。
他の場合も同様のやり方で進めることができます。
全ての変換が成功したときに限って`Right`を返す、ということを記憶に留めつつ。

```idris
traverseEither fun (x :: xs) =
  case (fun x, traverseEither fun xs) of
    (Left y, Left z)   => Left (y <+> z)
    (Left y, Right _)  => Left y
    (Right _, Left z)  => Left z
    (Right y, Right z) => Right (y :: z)
```

これまでの労働の成果をものにするために、小さな例をお見せします。

```idris
data Nucleobase = Adenine | Cytosine | Guanine | Thymine

readNucleobase : Char -> Either (List String) Nucleobase
readNucleobase 'A' = Right Adenine
readNucleobase 'C' = Right Cytosine
readNucleobase 'G' = Right Guanine
readNucleobase 'T' = Right Thymine
readNucleobase c   = Left ["Unknown nucleobase: " ++ show c]

DNA : Type
DNA = List Nucleobase

readDNA : String -> Either (List String) DNA
readDNA = traverseEither readNucleobase . unpack
```

REPLで試してみましょう。

```repl
Tutorial.Functions2> readDNA "CGTTA"
Right [Cytosine, Guanine, Thymine, Thymine, Adenine]
Tutorial.Functions2> readDNA "CGFTAQ"
Left ["Unknown nucleobase: 'F'", "Unknown nucleobase: 'Q'"]
```

### 対話的編集

いくつかのエディタやプログラミング環境ではプラグインが入手でき、
関数を実装するときにIdrisコンパイラとのやり取りを手助けしてくれます。
Idrisコミュニティでよく保証されているエディタの1つはNeovimです。
私自身Neovim利用者なので、
[補遺](../Appendices/Neovim.md)にどんなことができるのかについて幾つかの例を加えました。
そろそろそちらで記載した実用品を使い始めていい頃合いです。

他のエディタを使っているなら、
Idrisプログラミング言語をするにはやや保証が薄いかもしれませんが、
少なくとも常時REPLセッションを開いておくべきです。
このセッションでは現在取り組んでいるソースファイルを読み込んでおきます。
こうすればコードを開発しつつ新しいメタ変数を導入しその方と文脈を調べられます。

## まとめ

繰り返しになりますが本節では様々な領域の話題を述べました。
どんなに強調しても足りませんが、ぜひ虫食いのあるプログラミングに体を慣らして、型検査器に次何をすればよいのかを教えてもらうようにしましょう。

* 局所ユーティリティ関数が必要なときは、*whereブロック*中の局所定義に書くことを検討してください。

* *let式*を使って局所変数を定義・再利用してください。

* 関数の引数には名前を付けられます。
  こうすればドキュメントとして残すことができ、
  好きな順序で引数を渡すのに使え、
  そして依存型で参照するのに使えます。

* 暗黙引数は波括弧にくるまれます。
  コンパイラは文脈から型推論できなくてはいけません。
  それができないときは、明示的に他の名前付き引数として渡すことができます。

* 可能なときはできるだけIdrisは自動的に全ての型変数について暗黙の消去済み引数を加えようとします。

* 数量子はどのくらいの頻度で関数の引数が使われるのかを追跡することができます。
  数量子0は引数が実行時に消去されることを意味します。

* *虫食い*をあとで埋める予定のコード片の場所取りに使ってください。
  REPL（もしくはエディタ）を使って、虫食いの型とその文脈にある全ての変数の名前、型、数量子を調べてください。

### お次は？

[次節](Dependent.md)では依存型を使い始め、証明的に正しいコードを書くのに使います。
Idrisの型処方の読み方をよく理解しておくことは、そこでは最重要となります。
道を見失ったように感じたら、いくつか虫食いを加えてみてその文脈を調べ、次何をすべきかを決めましょう。

<!-- vi: filetype=idris2:syntax=markdown
-->
