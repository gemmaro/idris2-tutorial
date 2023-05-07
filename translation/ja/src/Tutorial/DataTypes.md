# 代数的データ型

[前の節](Functions1.md)では自前の関数を書いたり、関数同士を組み合わせてより複雑な機能をつくったりしました。
関数と同じくらい大事なのは、自前のデータ型を定義できたり、関数の引数や返り値に使えたりすることです。

この章は分量が多く、情報が密に詰まっています。
Idrisや関数型プログラミングが初見でしたら、
ゆっくりと読み進めたり、
例で実験したり、
できれば自分で色々試してみてくださいね。
是非 *全ての* 演習を解いてみてください。
演習の解答は[ここ](../Solutions/DataTypes.idr)にあります。

```idris
module Tutorial.DataTypes
```

## 列挙型

例として曜日のデータ型から始めましょう。

```idris
data Weekday = Monday
             | Tuesday
             | Wednesday
             | Thursday
             | Friday
             | Saturday
             | Sunday
```

上記の宣言は新しい *型* （`Weekday`）と、
この型のいくつかの新しい *値* （`Monday`から`Sunday`まで）を定義しています。
さあ、REPLで確かめてみてください。

```repl
Tutorial.DataTypes> :t Monday
Tutorial.DataTypes.Monday : Weekday
Tutorial.DataTypes> :t Weekday
Tutorial.DataTypes.Weekday : Type
```

つまり、`Monday`は`Weekday`の型で、
`Weekday`自体の型は`Type`です。

これは大事なことなのですが、型`Weekday`の値は必ず上に挙げた値のうち、どれか1つでなければいけません。`Weekday`が期待されているところで何か他の値を使うと
*型エラー* になります。

### パターン照合

新しいデータ型を関数の引数として使うためには、関数型プログラミング言語の重要な概念、パターン照合について学ばねばなりません。次の曜日を計算する関数を実装してみましょう。

```idris
total
next : Weekday -> Weekday
next Monday    = Tuesday
next Tuesday   = Wednesday
next Wednesday = Thursday
next Thursday  = Friday
next Friday    = Saturday
next Saturday  = Sunday
next Sunday    = Monday
```

`Weekday`な引数の正体を調べるために、
ありうる値を照合して対応する結果を返しています。
この照合という概念はとても強力で、
深く入れ子になった構造体のデータから値を抜き出すことができるのです。
パターン照合のそれぞれの場合は上から下に順番に調べられ、
関数の引数に対して比較されます。
最初に照合するパターンが見つかったら、
そのパターンの右側にある計算が実行されます。
それ以降のパターンは無視されます。

例えば、`next`を引数`Thursday`で呼び出したら、最初の3つの引数（`Monday`, `Tuesday`,
`Wednesday`）は引数と比較されるものの、照合に失敗します。4つ目のパターンには合致し、結果である`Friday`が返されます。それ以降のパターンは無視され、たとえ引数と照合したとしてもダメです（これは全部受け止めるパターンと関係してきますが、これについては少しあとでお話します）。

上記の関数は証明上全域です。Idrisは`Weekday`の取り得る値を知っており、したがってパターン照合が全ての可能性を網羅していることを突き止めるのです。したがって関数を`total`キーワードで註釈することができ、Idrisはその関数の全域性を検証できなかったときに型エラーで応えるようになります（さあさあ、`next`から節を1つ消してみてください。網羅性検査器はどういった感じのエラー文言を出しましたか）。

覚えておいてほしいのですが、こういったことには型検査器による大変強力な保証がなされているのです。充分なリソースがあれば、証明上全域な関数は *常に*
有限時間内で正しい型の結果を返します（ここでの*リソース*とはメモリのような計算機の資源を指します。再帰関数の場合で言えばスタック空間のことです）。

### 全部受け止めるパターン

ときどき、ありうる値のうち一部のみを照合し、
残りの可能性を全部受け止める節で回収すると便利なときもあります。

```idris
total
isWeekend : Weekday -> Bool
isWeekend Saturday = True
isWeekend Sunday   = True
isWeekend _        = False
```

全部受けとめるパターンのある最後の行が呼び出されるのは、引数が`Saturday`でも`Sunday`でもないときだけです。ただし、パターン照合中のパターンは入力に対して上から下に照合が試みられ、最初に合致したものによって右側へのどの進路を取るのかが決定されます。

全部受け止めるパターンがあれば、
`Weekday`の等価性検査を実装できます。
（これにはまだ`==`は使えません。
*インターフェース*を学んでからにしましょう。）

```idris
total
eqWeekday : Weekday -> Weekday -> Bool
eqWeekday Monday Monday        = True
eqWeekday Tuesday Tuesday      = True
eqWeekday Wednesday Wednesday  = True
eqWeekday Thursday Thursday    = True
eqWeekday Friday Friday        = True
eqWeekday Saturday Saturday    = True
eqWeekday Sunday Sunday        = True
eqWeekday _ _                  = False
```

### Preludeにある列挙型

`Weekday`のようなデータ型は限られた数の値からなっており、しばしば*列挙*と呼ばれます。Idrisの*Prelude*では一般によくある列挙型を定義してくれています。例えば`Bool`や`Ordering`です。`Weekday`と同様に、これらの型を扱う関数を実装するときにはパターン照合が使えます。

```idris
-- `not`の*Prelude*での実装
total
negate : Bool -> Bool
negate False = True
negate True  = False
```

`Ordering`データ型は2つの値の序列を表現します。
例えば次のように。

```idris
total
compareBool : Bool -> Bool -> Ordering
compareBool False False = EQ
compareBool False True  = LT
compareBool True True   = EQ
compareBool True False  = GT
```

ここで、`LT`は最初の引数が2つ目*よりも小さい*ということを、
`EQ`は2つの引数が互いに*等しい*ことを、
そして`GT`は最初の引数が2つ目*よりも大きい*ということを、
それぞれ意味しています。

### case式

ときどき、引数を使った計算を行って、
その結果をパターン照合したいときがあります。
こんなときは*case式*が使えます。

```idris
-- 2つの引数のうち、より大きい方を返す
total
maxBits8 : Bits8 -> Bits8 -> Bits8
maxBits8 x y =
  case compare x y of
    LT => y
    _  => x
```

case式の最初の行（`case compare x y of`）では、
関数`compare`を引数`x`と`y`に対して呼び出しています。
次の（字下げされた）行ではこの計算結果に対してパターン照合しています。
この計算結果の型は`Ordering`なので、
3つの構築子`LT`, `EQ`, `GT`のうちのいずれかです。
最初の行で明示的に`LT`の場合を扱っており、
他の2つの行は全部を受け止めるパターンである下線文字で扱っています。

ここでの字下げは大事ですよ。caseブロック全体は（新しい行から始まる場合）字下げされていなければいけません。そしてそれぞれの場合は同量の空白文字で字下げされていなければなりません。

関数`compare`は多くのデータ型でオーバーロードされています。
この仕組みについてはインターフェースのところでお話しします。

#### もし、そうなら、でないなら

`Bool`で何かするときは、パターン照合の代わりにほとんどのプログラミング言語でもよくあるアレがあります。

```idris
total
maxBits8' : Bits8 -> Bits8 -> Bits8
maxBits8' x y = if compare x y == LT then y else x
```

ただし、`if then
else`式は常に値を返すため、`else`の分枝は省けません。これは典型的な命令型言語の振舞いとは違います。命令型言語では`if`は文で、副作用がありうるためです。

### 命名慣習：識別子

関数名には小文字始まりの識別子も大文字始まりの識別子も両方使えますが、
型構築子とデータ構築子は大文字始まりの識別子でなければいけません。
でなければIdrisが困惑します。
（ちなみに演算子は大文字でもOKです。）
たとえば以下のデータ定義は妥当ではなく、Idrisは大文字の識別子ではないことに小言を言います。

```repl
data foo = bar | baz
```

同じことはレコードや直和型のデータ定義についても言えます。
（これらについては後述します。）

```repl
-- not valid Idris
record Foo where
  constructor mkfoo
```

他方で、ほぼ型検査で使うつもりでない限り（詳細はのちほど）、関数名には大抵小文字始まりの識別子を使います。
とはいえこれはIdrisが何か後押しするわけではないので、
大文字始まりの識別子が好ましいような状況では自由に使ってください。

```idris
foo : Bits32 -> Bits32
foo = (* 2)

Bar : Bits32 -> Bits32
Bar = foo
```

### 演習 その1

1. パターン照合を使って自前の真偽値演算子`(&&)`と`(||)`を実装してください。
   それぞれの関数名は`and`と`or`にしてください。

   附記：1つの解決策としては、2つの真偽値のありうるあらゆる組み合わせを列挙して、それぞれの結果を与える、というのがあります。
   しかし、もっと短かくてもっと賢い方法があります。
   その方法だとそれぞれの関数の実装に、パターン照合の分岐の数が2つだけで済みます。

2. 異なる時間の単位（秒 (second)、分 (minute)、時 (hour)、日 (day)、週
   (week)）を表す自前のデータ型を定義してください。
   そして、単位間で期間を変換する以下の関数を実装してください。
   解決の糸口：秒から時のようなより大きい単位に変換するには、
   整数の除算(`div`)を使ってください。

   ```idris
   data UnitOfTime = Second -- 残りの値を追加してください

   -- 与えられた時間の単位での長さから、
   -- その秒数を計算してください
   total
   toSeconds : UnitOfTime -> Integer -> Integer

   -- 秒数がわかっているとき、
   -- 与えられた時間の単位での長さを計算してください
   total
   fromSeconds : UnitOfTime -> Integer -> Integer

   -- 与えられた時間の単位とその長さを、
   -- 他の時間の単位での長さに変換してください。
   -- 実装では`fromSeconds`と`toSeconds`を使ってください
   total
   convert : UnitOfTime -> Integer -> UnitOfTime -> Integer
   ```

3. 化学の原子の一部を表すデータ型を定義してください。
   水素 (H)、炭素 (C)、窒素 (N)、酸素 (O)、そしてフッ素 (F) だけでよいです。

   `atomicMass`を宣言して実装してください。
   この関数は、それぞれの原子に対して、
   dalton単位（統一原子質量単位）での粒子の質量を返します。

   ```repl
   Hydrogen : 1.008
   Carbon : 12.011
   Nitrogen : 14.007
   Oxygen : 15.999
   Fluorine : 18.9984
   ```

## 直和型

なんらかのWebフォームを書くとします。
このフォームでは、Webアプリケーションのユーザーがどう呼ばれてほしいかを決められます。
2つのよくある事前に定義された呼び方（MrとMrs）だけではなく、
自前で決められる形式にもできるとします。
取れる選択肢は、Idrisのデータ型で次のようにカプセル化できます。

```idris
data Title = Mr | Mrs | Other String
```

これは列挙型とそっくりですが、
1つ新しい要素があります。
これは*データ構築子*と呼ばれるもので、
`String`な引数を受け付けます。
（実は、列挙型での値は（引数のない）データ構築子とも呼ばれます。）
REPLで型を調べると、以下がわかります。

```repl
Tutorial.DataTypes> :t Mr
Tutorial.DataTypes.Mr : Title
Tutorial.DataTypes> :t Other
Tutorial.DataTypes.Other : String -> Title
```

つまり、`Other`は`String`から`Type`への*関数*です。
言い換えると、`Other`に`String`な引数を渡すと、結果として`Title`な値が得られます。

```idris
total
dr : Title
dr = Other "Dr."
```

繰り返しになりますが、
型`Title`の値は前述した3つの選択肢のうちのいずれかです。
さらに、パターン照合を使って`Title`データ型に関する関数を実装できるのも同じです。
この実装は全域であることが証明されています。

```idris
total
showTitle : Title -> String
showTitle Mr        = "Mr."
showTitle Mrs       = "Mrs."
showTitle (Other x) = x
```

パターン照合の最後の場合にご注目。
`Other`データ構築子に格納された文字列の値が局所変数`x`に*束縛*されています。
また、`Other x`パターンは括弧でくるまれていなければいけません。
そうしないとIdrisは`Other`と`x`が別個な関数の引数だと考えます。

これはデータ構築子から値を抽出する大変よくある方法です。
`showTitle`を使えば慇懃な挨拶をする関数を実装できます。

```idris
total
greet : Title -> String -> String
greet t name = "Hello, " ++ showTitle t ++ " " ++ name ++ "!"
```

`greet`の実装では文字列リテラルと文字列結合演算子`(++)`を使っています。
これにより部品から挨拶を組み立てられます。

REPLで次のようにしてみましょう。

```repl
Tutorial.DataTypes> greet dr "Höck"
"Hello, Dr. Höck!"
Tutorial.DataTypes> greet Mrs "Smith"
"Hello, Mrs. Smith!"
```

`Title`のようなデータ型は*直和型*と呼ばれます。
なぜならこの型はそれぞれの場合の和からなっているためです。
型`Title`の値は`Mr`か`Mrs`かそれとも`Other`にくるまれた`String`かのいずれかです。

また、以下は他の（劇的に簡素な）直和型の例です。
Webアプリケーションで2つの形式の認証ができるとしましょう。
利用者名とパスワード（ここでは符号なし64ビット整数）を入力するか、
利用者名と（とても複雑な）秘密鍵を使うかのいずれかです。
こちらがこの用例をカプセル化したデータ型です。

```idris
data Credentials = Password String Bits64 | Key String String
```

とても原始的なログイン関数の例として、
既知の認証情報を埋め込むことにします。

```idris
total
login : Credentials -> String
login (Password "Anderson" 6665443) = greet Mr "Anderson"
login (Key "Y" "xyz")               = greet (Other "Agent") "Y"
login _                             = "Access denied!"
```

上の例からわかるように、
整数と文字列のリテラルで原始的な値に対してパターン照合することもできます。
REPLで`login`を試してみましょう。

```repl
Tutorial.DataTypes> login (Password "Anderson" 6665443)
"Hello, Mr. Anderson!"
Tutorial.DataTypes> login (Key "Y" "xyz")
"Hello, Agent Y!"
Tutorial.DataTypes> login (Key "Y" "foo")
"Access denied!"
```

### 演習 その2

1. `Title`の等価性検査を実装してください。
   （2つの`String`を比較するのに等価性演算子`(==)`が使えます。）

   ```idris
   total
   eqTitle : Title -> Title -> Bool
   ```

2. `Title`について、
   自前の敬称が使われているかを確認する簡単な検査を実装してください。

   ```idris
   total
   isOther : Title -> Bool
   ```

3. 前述した簡素な`Credential`型についてだけでも、
   3つの認証失敗の場合があります。

   * 不明な利用者名が使われた。
   * 与えられたパスワードが利用者名に紐付くパスワードと一致しない。
   * 不正な鍵が使用された。

   これら3つの可能性を`LoginError`という名前の直和型でカプセル化してください。
   ただし、あらゆる機密情報を漏洩しないようにしてくださいね。
   不正な利用者名は対応するエラー型に格納されますが、
   不正なパスワードや鍵は格納されません。

4. 関数`showError : LoginError -> String`を実装してください。
   この関数はWebアプリケーションにログインしようとして失敗した利用者にエラー文言を表示するのに使えます。

## レコード

いくつかの値を論理的な単位として集めておくと便利なことがよくあります。
たとえば、Webアプリケーションで利用者の情報を単一のデータ型に集めておきたいことがあるでしょう。
そのようなデータ型はしばしば*直積型*と呼ばれます。
（後述の説明を参照してください。）
これを定義するもっとも一般的で便利な方法は*record*構築子を使うというものです。

```idris
record User where
  constructor MkUser
  name  : String
  title : Title
  age   : Bits8
```

上記の宣言は`User`という名前の新しい*型*と`MkUser`という名前の新しい*データ構築子*を作ります。
いつものように、型をREPLでのぞいてみましょう。

```repl
Tutorial.DataTypes> :t User
Tutorial.DataTypes.User : Type
Tutorial.DataTypes> :t MkUser
Tutorial.DataTypes.MkUser : String -> Title -> Bits8 -> User
```

`MkUser`（`String`と`Title`と`Bits8`から`User`を返す関数）は型`User`の値を作るのに使えます。

```idris
total
agentY : User
agentY = MkUser "Y" (Other "Agent") 51

total
drNo : User
drNo = MkUser "No" dr 73
```

パターン照合で`User`の値からフィールドを抽出することもできます（ここでもパターン照合で局所変数に束縛できます）。

```idris
total
greetUser : User -> String
greetUser (MkUser n t _) = greet t n
```

上の例では、`name`, `title`フィールドが2つの新しい局所変数（それぞれ`n`と`t`）に束縛されています。
これらの局所変数は右側にある`greetUser`の実装で使うことができます。
`age`フィールドについては右側で使われないので、その部分には全てを受け止めるパターンとしての下線文字を使うことができます。

ここでIdrisがよくある間違いを防いでいることにご注目。
引数の順序を混同したら実装は型検査を通りません。
エラーを含むコードを`failing`ブロック内に置くことで、このことを確かめられます。
これは字下げされたブロックで、このブロックの中のコードは細密化（型検査）の段階でエラーになります。
期待されるエラー文言の一部を失敗ブロックの引数に加えても構いません。
これがエラー文言の一部と一致しないとき（もしくはコードブロック全体が型検査に失敗しなかったとき）は、
`failing`ブロック自体が型検査に失敗します。
これは型安全性が2つの方面で便利な道具であることを示しています。
Idrisの細密化器によって、妥当なコードが型検査に通ることだけではなく、不当なコードが弾かれることがわかるのです。

```idris
failing "Mismatch between: String and Title"
  greetUser' : User -> String
  greetUser' (MkUser n t _) = greet n t
```

加えて、全てのレコードのフィールドについて、
Idrisはそれらと同名の抽出関数を作ります。
この関数は通常の関数として使うこともできますし、
レコード型の変数にドット区切りでフィールド名を後置する使い方もできます。
こちらが利用者から年齢を抽出する2つの例です。

```idris
getAgeFunction : User -> Bits8
getAgeFunction u = age u

getAgePostfix : User -> Bits8
getAgePostfix u = u.age
```

### レコードの糖衣構文

既に[導入](Intro.md)で言及したように、
Idrisは*純粋*関数型プログラミング言語です。
純粋な関数では、大域的な可変の状態に変更を加えることができません。
そういうわけで、
レコードの値を変更したければ、
変更する部分以外の値は元のままに常に*新しい*値を作る必要があります。
レコードやその他のIdrisでの値は*不変*なのです。
このことはパフォーマンスに若干の影響が*ありうる*ものの、
レコードの値を別々の関数に気ままに渡すことができるという利点があります。
関数がその場で値に変更を加えるかもしれないと恐れる必要がありません。
再三ですが、これはとても強力な保証です。
これによりコードの検証が劇的に容易になるのです。

レコードを変更するにはいくつかの方法があります。
もっとも一般的なものとしては、
レコードに対してパターン照合し、
好きなようにそれぞれのフィールドを調整するというものです。
たとえばもし`User`の年齢を1歳上げたかったら、以下のようにすればできます。

```idris
total
incAge : User -> User
incAge (MkUser name title age) = MkUser name title (age + 1)
```

こんな簡単なことなのに、コードを沢山書いています。
なのでIdrisではこうした操作について、いくつかの文法的な便宜が図られています。
たとえば、*record*文法を使えば、
値の`age`フィールドにアクセスして更新することができます。

```idris
total
incAge2 : User -> User
incAge2 u = { age := u.age + 1 } u
```

代入演算子`:=`は`u`の`age`フィールドに新しい値を代入します。
ただし、これは新しい`Usre`の値を作ります。
`u`の値はこの影響を受けず元のままです。

レコードのフィールドは2つの方法で読み取れます。
1つはフィールド名の射影関数（`age u`のように。REPLで`:t age`としてみてください。）を使うことで、
もう1つは`u.age`のようなドット文法を使うものです。
ドット文法は特殊な文法であり、関数合成のためのドット演算子（`(.)`）とは関係*ありません*。

レコードのフィールドを変更する使用例はとてもよくあるので、
Idrisはさらにこのための特別な文法を提供しています。

```idris
total
incAge3 : User -> User
incAge3 u = { age $= (+ 1) } u
```

ここではコードをもっと簡潔にするために*演算子節* (`(+ 1)`) を使いました。
演算子節の代わりに匿名関数を使うこともできます。

```idris
total
incAge4 : User -> User
incAge4 u = { age $= \x => x + 1 } u
```

最後に、上記の関数の引数`u`は末尾に1度だけしか使われていないので、
引数と実装の両方から省略して以下の定義が得られます。
とても簡潔になりました。

```idris
total
incAge5 : User -> User
incAge5 = { age $= (+ 1) }
```

いつも通りREPLで結果を確認してみましょう。

```repl
Tutorial.DataTypes> incAge5 drNo
MkUser "No" (Other "Dr.") 74
```

この文法では複数のレコードフィールドを一度に設定・更新することができます。

```idris
total
drNoJunior : User
drNoJunior = { name $= (++ " Jr."), title := Mr, age := 17 } drNo
```

### タプル

レコードは*直積型*とも呼ばれていると書きました。
これは与えられた型のありえる値の数を考えればかなり明らかです。
たとえば、以下の自前のレコードについて考えてみてください。

```idris
record Foo where
  constructor MkFoo
  wd   : Weekday
  bool : Bool
```

このとき、型`Foo`の取り得る値はいくつあるでしょうか。
答えは`7 * 2 = 14`です。
なぜなら`Monday`の全ての取り得るもの（計7つ）と
`Bool`の全ての取り得るもの（計2つ）の組であると見なせるためです。
ですから、レコード型で有り得る値の数はそれぞれのフィールドの有り得る値の数の*積*なのです。

基本的な直積型は`Pair`です。
これは*Prelude*から使うことができます。

```idris
total
weekdayAndBool : Weekday -> Bool -> Pair Weekday Bool
weekdayAndBool wd b = MkPair wd b
```

いくつかの値を関数から`Pair`やより大きなタプルにくるんで返すことはかなりよくあるので、
Idrisはいくつかの糖衣構文を提供しています。
`Pair Weekday Bool`とする代わりに、
ただ`(Weekday, Bool)`と書けばよいです。
そんな感じで`MkPair wd b`とする代わりに単に`(wd, b)`と書けばよいのです。
（空白は任意です。）

```idris
total
weekdayAndBool2 : Weekday -> Bool -> (Weekday, Bool)
weekdayAndBool2 wd b = (wd, b)
```

この糖衣構文は入れ子のタプルでも大丈夫。

```idris
total
triple : Pair Bool (Pair Weekday String)
triple = MkPair False (Friday, "foo")

total
triple2 : (Bool, Weekday, String)
triple2 = (False, Friday, "foo")
```

上の例での`triple2`はIdrisのコンパイラによって`triple`での形式に変換されます。

タプルの構文をパターン照合で使うことさえできます。

```idris
total
bar : Bool
bar = case triple of
  (b,wd,_) => b && isWeekend wd
```

### asパターン

ときどき、値をパターン照合でばらしつつ、
あとあとの計算で使うために元の全体の値をそのまま取っておきたいときがあります。

```idris
total
baz : (Bool,Weekday,String) -> (Nat,Bool,Weekday,String)
baz t@(_,_,s) = (length s, t)
```

`baz`では変数`t`はタプル全体に*束縛*されています。
この変数は結果の3要素のタプルを構築するときに再利用されます。
ここで、`(Nat,Bool,Weekday,String)`はただの糖衣で、
`Pair Nat (Bool,Weekday,String)`と同じです。
また、`(length s, t)`も糖衣で`MkPair (length s) t`と同じです。
だから、上の実装は型検査器で確証される正しいものなのです。

### 演習 その3

1. 期間を表すレコード型を定義してください。
このレコード型は`UnitOfTime`とその時間の単位での期間の幅を表す整数の対です。
期間を秒数で表したときの`Integer`に変換する関数も定義してください。

2. 期間の等価性検査を実装してください。
2つの期間が等しいのは、
秒数に直したときに一致するときに限ります。

3. 期間を綺麗に表示する関数を実装してください。
結果の文字列は与えられた単位での期間を表示し、
なおかつ単位が秒でないときは括弧内に秒数を表示するようにしてください。

4. 2つの期間を加算する関数を実装してください。
もし2つの期間が異なる時間の単位を使っていたら、
小さいほうの時間の単位を使うようにしてください。
これは損失のない変換を実現するためです。

## 汎化データ型

ときどき、概念が充分に汎用的であるために、
1つの型だけに適用するのではなく、
ある種類の型全てに適用したいときがあります。
たとえば、整数型のリストと文字列型のリストと真偽値型のリストを定義したくはありません。
どうしてかっていうと、これをやると沢山コードに重複が生まれるためです。
その代わりに、1つの汎化されたリスト型でもって、
そのリストが持つ値の型を*変数に取る*ようにしたいのです。
この節では汎化型をどう定義しどう使うかを説明します。

### Maybe

`Weekday`をユーザーの入力からパースする場合を考えましょう。
当然、文字列の入力が`"Saturday"`なら、関数が返すのは`Saturday`です。
でも入力が`"sdfkl332"`だったらどうなるでしょうか。
ここでいくつか選択肢があります。
たとえば、デフォルト値を返すというもの。
（`Sunday`とか？）
でもこれはライブラリを使うプログラマが期待する振舞いなのでしょうか。
そうではないでしょう。
不正な利用者の入力を目の前にして、
何事もなかったかのようにデフォルト値で続行するのはめったに最善の選択ではないですし、
多大な混乱のもとになるでしょう。

命令型言語では関数は例外を投げるのかもしれません。
Idrisでもそれはできます
（このために*Prelude*に`idris_crash`という関数があります）、
がしかし、そうすると全域性を放棄することになります！
パースエラーのようなよくあることのために、全域性を捨てるのはコスパが悪いです。

Javaのような言語では関数は`null`値の類を返すこともあります（使う側のコードで適切に対処されていないと、恐るべき`NullPointererException`に繋がります）。
Idrisの解決策もこれに似ていますが、しれっと`null`を返すのではなく、型で失敗する可能性があることを目に見えるようにするのです。
このために自前のデータ型を定義し、その型が失敗する可能性をカプセル化するようにします。
Idrisで新しいデータ型を定義することは（必要なコードの量の意味で）とても安く済みます。
なのでこれは型安全性を増すためにはよくある方法です。
例はこちら。

```idris
data MaybeWeekday = WD Weekday | NoWeekday

total
readWeekday : String -> MaybeWeekday
readWeekday "Monday"    = WD Monday
readWeekday "Tuesday"   = WD Tuesday
readWeekday "Wednesday" = WD Wednesday
readWeekday "Thursday"  = WD Thursday
readWeekday "Friday"    = WD Friday
readWeekday "Saturday"  = WD Saturday
readWeekday "Sunday"    = WD Sunday
readWeekday _           = NoWeekday
```

でもここで、`Bool`も利用者の入力から読めるようにしたいのだとします。
そうしたら自前のデータ型`MaybeBool`を書くはめになり、
`String`から読み取りたい全ての型と失敗するかもしれない変換に対して同じようなことをすることになります。

Idrisは他のプログラミング言語のようにこの振舞いを*汎化データ型*で汎化できます。
例はこんな感じ。

```idris
data Option a = Some a | None

total
readBool : String -> Option Bool
readBool "True"    = Some True
readBool "False"   = Some False
readBool _         = None
```

REPLで型を見るのは大事です。

```repl
Tutorial.DataTypes> :t Some
Tutorial.DataTypes.Some : a -> Option a
Tutorial.DataTypes> :t None
Tutorial.DataTypes.None : Optin a
Tutorial.DataTypes> :t Option
Tutorial.DataTypes.Option : Type -> Type
```

ここでいくつかの専門用語を紹介しなければいけません。
`Option`は*型構築子*と呼ぶものです。
これは完全な型ではなく、`Type`から`Type`への関数です。
一方で`Option Bool`は型です。
`Option Weekday`なんかがそうです。
`Option (Option Bool)`さえ妥当な型です。
`Option`は型構築子で、型が`Type`の*変数*を*引数に取る*ものなのです。
`Some`と`None`は`Option`の*データ構築子*です。
これは関数で、型`a`があったとして、型`Option a`の値をつくるのに使われます。

`Option`の他の使用例を見てみましょう。
以下は安全な除算の操作です。

```idris
total
safeDiv : Integer -> Integer -> Option Integer
safeDiv n 0 = None
safeDiv n k = Some (n `div` k)
```

不正な入力に直面したときに*null*のような類の値を返しうるというのはよくあるので、
*Prelude*には既に`Option`のようなデータ型があります。
その名は`Maybe`。
データ構築子は`Just`と`Nothing`です。

失敗しうる関数で`Maybe Integer`を返すのと、
Javaのような言語で`null`を返すのには違いがある、ということを理解するのは大事です。
前者では失敗する可能性があることは型で見てとれます。
型検査器によって`Maybe Integer`を`Integer`とは違う風に取り扱うようにしなくてはいけません。
Idrisは決して失敗する場合の対処をするのを忘れさせ*ません*。
`null`が何食わぬ顔で返されて、型に合わし損ねるのとは違います。
プログラマはもしかすると（というかまあ*きっと*）
`null`の場合の対処をするのを忘れるかもしれないので、
予想していないような、ときに修復しにくい実行時例外に繋がるのです。

### Either

`Maybe`がとても便利で、手っ取り早くなんらかの失敗を知らせるために既定値を返してくれるとはいえ、
この値 (`Nothing`) はそれほど有意味ではありません。
*実際に何が*まずかったのかがわからないのです。
たとえば、`Weekday`を読み取る関数の例でいうと、
あとあとで不正な入力文字列の値を知りたくなることがあるかもしれません。
そしてちょうど上記の`Maybe`と`Option`のように、
この概念は充分に汎用的なので、
不正な値のための型を文字列型以外に変えたいことがあるかもしれません。
これをカプセル化するデータ型はこうなります。

```idris
data Validated e a = Invalid e | Valid a
```

`Validated`は2つの型変数`e`と`a`を引数に取る型構築子です。
データ構築子は`Invalid`と`Valid`で、
前者は何らかのエラーの状態を、
後者は成功した場合の計算の結果を表現します。
実際に見てみましょう。

```idris
total
readWeekdayV : String -> Validated String Weekday
readWeekdayV "Monday"    = Valid Monday
readWeekdayV "Tuesday"   = Valid Tuesday
readWeekdayV "Wednesday" = Valid Wednesday
readWeekdayV "Thursday"  = Valid Thursday
readWeekdayV "Friday"    = Valid Friday
readWeekdayV "Saturday"  = Valid Saturday
readWeekdayV "Sunday"    = Valid Sunday
readWeekdayV s           = Invalid ("Not a weekday: " ++ s)
```

繰り返しますが、これは汎用的な概念なので`Validated`に似たデータ型が既に*Prelude*にあります。
それは`Either`で、データ構築子は`Left`と`Right`です。
関数が失敗する可能性をカプセル化して`Either err val`として返すことはとてもよくあります。
ここで`err`はエラーの型で`val`は求める結果の型です。
これは型安全であり（加えて全域です！）、
命令型言語で例外を投げたり捕えたりするものに代わるものです。

ただしかし、`Either`の意味論は必ずしも「`Left`が失敗で`Right`が成功を表す」ものとは限りません。
関数が`Either`を返すということは、単に異なる型の結果を返すという意味であり、
それぞれが対応するデータ構築子に*タグ付けされている*だけなのです。

### List

純粋関数型プログラミングで最も重要なデータ構造の1つは単方向連結リストです。
以下がその定義です。
（`Seq`と呼び、`List`と衝突しないようにしています。
`List`はもちろんPreludeで既にあります。）

```idris
data Seq a = Nil | (::) a (Seq a)
```

これには少々説明が必要です。
`Seq`は2つの*データ構築子*からなります。
`Nil`（値の連なりが空であることを表す）と`(::)`（またの名を*cons演算子*）です。
`(::)`は型`a`の新しい値を既存の同じ型の値からなるリストに後付けします。
見てみると、演算子をデータ構築子としても使えることがわかります。
しかし、乱用しないでください。
関数とデータ構築子には明白な名前を使い、
本当に可読性を向上させるときにだけ新しい演算子を導入すること！

`List`の構築子を使う方法の例はこちらです。
（ここでは`List`を使っています。
今後、実際には`Seq`ではなく`List`を使うことになるからです。）

```idris
total
ints : List Int64
ints = 1 :: 2 :: -3 :: Nil
```

しかし、上の書き方はもっと簡潔にできます。
Idrisには特殊な文法があり、
2つの構築子`Nil`と`(::)`からなるデータ型であれば、値の構築に使えます。

```idris
total
ints2 : List Int64
ints2 = [1, 2, -3]

total
ints3 : List Int64
ints3 = []
```

2つの定義`ints`と`ints2`はコンパイラによって同一のものとして扱われます。
なお、リストの文法はパターン照合でも使えます。

前述の`Seq`と`List`には他にも特別なことがあります。
どちらも自分自身を使って定義されていることです（cons演算子は値と別の`Seq`を引数に取ります）。
このようなデータ型を*再帰的な*データ型と呼び、この再帰的な性質のために、この型の値を分解したり消費したりするためには再帰的な関数が必要になるのがお約束です。
命令型言語ではforの繰返しのようなもので`List`や`Seq`の値を巡っていきますが、そのようなものはその場で値を変更することがない言語には存在しません。
こちらが整数のリストの合計を求める方法です。

```idris
total
intSum : List Integer -> Integer
intSum Nil       = 0
intSum (n :: ns) = n + intSum ns
```

再帰的な関数は最初は取っ付きにくいかもしれませんから、
少し分解してみましょう。
空のリストに対して`intSum`を呼び出すと、
最初のパターンが照合して関数は直ちにゼロを返します。
一方で空ではないリスト、例えば`[7,5,9]`、に対して`intSum`を呼び出すと、
以下のようなことが起こります。

1. 2つ目のパターンが照合し、リスト2つに分割します。
   頭部(`7`)は変数`n`に束縛し、
   尾部(`[5,9]`)は`ns`に束縛します。

   ```repl
   7 + intSum [5,9]
   ```
2. 2回目の呼び出しでは、`intSum`は新しいリスト`[5,9]`とともに呼ばれます。
   2つ目のパターンが照合し、`n`は`5`に束縛し、
   `ns`は`[9]`に束縛します。

   ```repl
   7 + (5 + intSum [9])
   ```

3. 3回目の`intSum`の呼び出しではリスト`[9]`とともに呼ばれます。
   2つ目のパターンが照合し、`n`は`9`に束縛し、`ns`は`[]`に束縛します。

   ```repl
   7 + (5 + (9 + intSum [])
   ```

4. 4回目の呼び出しでは`intSum`はリスト`[]`とともに呼ばれ、直ちに`0`を返します。

   ```repl
   7 + (5 + (9 + 0)
   ```

5. 3回目の呼び出しの部分で、`9`と`0`は加算され、`9`が返ります。

   ```repl
   7 + (5 + 9)
   ```

6. 2回目の呼び出しの部分で、`5`と`9`が加算され`14`が返ります。

   ```repl
   7 + 14
   ```

7. 最後に`intSum`の最初の呼び出しの部分で、`7`と`14`が加算されて`21`が返ります。

なので、`intSum`の再帰的な実装によって、`intSum`の入れ子の呼び出しの連なりになり、
その連なりは引数が空リストになったときに終わります。

### 汎化関数

汎化データ型によりもたらされる多様性を十全に享受するためには、
汎化関数についても語らねばなりません。
汎化型のように汎化関数は1つ以上の型変数を変数に取ります。

たとえば`Option`データ型の殻を破ることを考えてみましょう。
`Some`の場合は保持している値を返し、
`None`の場合はデフォルト値を提供します。
これをする方法は以下で、ここでは`Integer`に特殊化しています。

```idris
total
integerFromOption : Integer -> Option Integer -> Integer
integerFromOption _ (Some y) = y
integerFromOption x None     = x
```

これもまたかなり明らかなことですが、充分に汎用的ではありません。
当然`Option Bool`や`Option String`を似たような様式で解体したくなるでしょう。
そしてこれを実現するのがまさに汎化関数`fromOption`なのです。

```idris
total
fromOption : a -> Option a -> a
fromOption _ (Some y) = y
fromOption x None     = x
```

小文字`a`もまた*型変数*です。
型シグネチャを以下のように読むことができます。
「あらゆる型`a`について、型`a`と`Option a`の*値*があったら、
型`a`の値を返すことができる。」
ここで、`fromOption`は`a`について何も知りません。
知っているのは`a`が型であることぐらいです。
したがって、型`a`の値の中身を掻き回すことは不可能です。
`None`の場合に対処できる値が*なくてはいけません*。

`Maybe`用の`fromOption`は`fromMaybe`と呼ばれ、
モジュール`Data.Maybe`にあり、そのモジュールは*base*ライブラリにあります。

ときどき、`fromOption`では充分に汎用的でないときがあります。
`Bool`をパースして文字で表示したいのだとしましょう。
`None`の場合は何かの汎用的なエラー文言を出します。
これには`fromOption`は使えません。
`Option Bool`があって`String`を返したいからです。
次のようにすればできます。

```idris
total
option : b -> (a -> b) -> Option a -> b
option _ f (Some y) = f y
option x _ None     = x

total
handleBool : Option Bool -> String
handleBool = option "Not a boolean value." show
```

関数`option`は*2つの*型変数を引数に取ります。
`a`は`Option`に保管されている値の型を表現しており、
`b`は返り値の型です。
`Just`の場合は保管されている`a`を`b`に変換する方法が必要であり、
それには関数の引数`a -> b`を使えばよいです。

Idrisでは関数の型での小文字の識別子は*型変数*として扱われます。
一方で大文字の識別子は型か型構築子でスコープにある必要があります。

### 演習パート4

もしこれが初めての関数型言語でのプログラミングであれば、
以下の演習は*とても*大事です。
1つも飛ばしてはいけません！
時間を取って全てに取り組んでください。
ほとんどの場合、型から何が起こるのかを充分に読み取れます。
最初は取っ付きにくいかもしれませんが。
もし読み取れない場合は（もしあれば）それぞれの演習のコメントを見てください。

いいですか、関数のシグネチャにある小文字の識別子は型変数と見なされますよ。

1. 以下の`Maybe`に関する汎化関数を実装してください。

   ```idris
   -- `Just`は`Just`に写してください。
   total
   mapMaybe : (a -> b) -> Maybe a -> Maybe b

   -- 例：`appMaybe (Just (+2)) (Just 20) = Just 22`
   total
   appMaybe : Maybe (a -> b) -> Maybe a -> Maybe b

   -- 例：`bindMaybe (Just 12) Just = Just 12`
   total
   bindMaybe : Maybe a -> (a -> Maybe b) -> Maybe b

   -- 与えられた命題が満たされているときにのみ、`Just`の値を保持してください。
   total
   filterMaybe : (a -> Bool) -> Maybe a -> Maybe a

   -- 最初の`Nothing`でない値を保持してください。（もし1つでもあるなら）
   total
   first : Maybe a -> Maybe a -> Maybe a

   -- 最後の`Nothing`でない値を保持してください。（もし1つでもあるなら）
   total
   last : Maybe a -> Maybe a -> Maybe a

   -- `Maybe`から値を抽出する別の一般的な方法です。
   -- ただし、以下を満たします。
   -- `foldMaybe (+) 5 Nothing = 5`
   -- `foldMaybe (+) 5 (Just 12) = 17`
   total
   foldMaybe : (acc -> el -> acc) -> acc -> Maybe el -> acc
   ```

2. 以下の`Either`についての汎化関数を実装してください。

   ```idris
   total
   mapEither : (a -> b) -> Either e a -> Either e b

   -- 両方の`Either`が`Left`なら、
   -- 最初の`Left`に格納された値を保持してください。
   total
   appEither : Either e (a -> b) -> Either e a -> Either e b

   total
   bindEither : Either e a -> (a -> Either e b) -> Either e b

   -- 最初の`Left`ではない値を保持してください。
   -- もし両方の`Either`が`Left`であれば、与えられた積載子を使ってエラーの値を出してください。
   total
   firstEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

   -- 最後の`Left`ではない値を保持してください。
   -- 両方の`Either`が`Left`なら、与えられた積載子を使ってエラーの値を出してください。
   total
   lastEither : (e -> e -> e) -> Either e a -> Either e a -> Either e a

   total
   fromEither : (e -> c) -> (a -> c) -> Either e a -> c
   ```

3. `List`についての以下の汎化関数を実装してください。

   ```idris
   total
   mapList : (a -> b) -> List a -> List b

   total
   filterList : (a -> Bool) -> List a -> List a

   -- リストの最初の値を返してください。もし空でなければですが。
   total
   headMaybe : List a -> Maybe a

   -- リストの最初の値以外全部を返してください。もし空でなければですが。
   total
   tailMaybe : List a -> Maybe (List a)

   -- リストの最後の値を返してください。もし空でなければですが。
   total
   lastMaybe : List a -> Maybe a

   -- リストの最後の値以外全部を返してください。もし空でなければですが。
   total
   initMaybe : List a -> Maybe (List a)

   -- リストの値を積み上げてください。
   -- 与えられた積載関数と初期値を使います。
   --
   -- 例：
   -- `foldList (+) 10 [1,2,7] = 20`
   -- `foldList String.(++) "" ["Hello","World"] = "HelloWorld"`
   -- `foldList last Nothing (mapList Just [1,2,3]) = Just 3`
   total
   foldList : (acc -> el -> acc) -> acc -> List el -> acc
   ```

4. Webアプリケーションで、以下のレコードで利用者のデータを保存するのだとしましょう。

   ```idris
   record Client where
     constructor MkClient
     name          : String
     title         : Title
     age           : Bits8
     passwordOrKey : Either Bits64 String
   ```

前の演習での`LoginError`を使って、関数`login`を実装してください。
この関数は`Client`のリストと`Credentials`な値を受け取って、
もし1つも妥当な認証情報がなかったときは`LoginError`を、
そうでないときは最初に認証情報が合致した`Client`を、それぞれ返します。

5. 前の演習での化学原子のデータ型を使って、
   分子式からモル質量を計算する関数を実装してください。

   原子とその個数（自然数）が対になったリストを使って式を表現してください。
   例えばこんな感じです。

   ```idris
   ethanol : List (Element,Nat)
   ethanol = [(C,2),(H,6),(O,1)]
   ```

   解決の糸口：関数`cast`を使えば自然数を`Double`に変換できます。

## データ定義の別の文法

引数を取るデータ型の節での例は短く簡潔でしたが、
それより僅かに冗長でもはるかに汎用的な形式があります。
そのような定義の書き方をすると、何が起こっているのかもっと明白になります。
持論ですが、
最も簡素なデータ定義を除く全ての場合で、
このより汎用的な形式は優れているだろうと考えます。

`Option`, `Validated`, `Seq`の定義を改めて出します。
ただしこの汎用的な形式で。
（定義を*namespace*の中に置きましたが、
これでIdrisは1つのソースファイル中に同じ名前があることについて文句を言わなくなります。

```idris
-- GADTは"generalized algebraic data type"の頭字語です
namespace GADT
  data Option : Type -> Type where
    Some : a -> Option a
    None : Option a

  data Validated : Type -> Type -> Type where
    Invalid : e -> Validated e a
    Valid   : a -> Validated e a

  data Seq : Type -> Type where
    Nil  : Seq a
    (::) : a -> GADT.Seq a -> Seq a
```

ここで`Option`ははっきりと型構築子として宣言されています。
（型の関数`Type -> Type`です。）
また、`Some`は汎化関数で型`a -> Option a`であり（ここで`a`は*型変数*です）、
`None`は引数を持たない汎化関数で型`Option a`です（ここでも`a`は型変数です）。
`Validated`と`Seq`についても似たようなものです。
ただ、`Seq`の場合、再帰する部分での異なる`Seq`の定義の曖昧さ回避をせねばなりません。
たいていは同じ名前のデータ型を1つのファイルで複数回定義することはないので、
ほとんどの場合は必要ではありません。

## まとめ

この章では多くの領域の内容を押さえました。
以下に最も大事な点を要約します。

* 列挙型はデータ型で有限の数の取り得る*値*からなります。

* 直和型もデータ型で1つ以上のデータ構築子からなります。
それぞれの構築子は可能な*選択*を表現するのでした。

* 直積型もデータ型で1つの構築子を持ち、
複数の互いに異なってもよい型の値を取り纏めるのに使います。

* パターン照合を使ってIdrisの不変な値を分解します。
使えるパターンはデータ型のデータ構築子に対応します。

* パターンでは値に変数を*束縛*したり下線文字で右側にある実装では不要な値の場所取りをしたりできます。

* *caseブロック*を導入することで、一時的な結果にパターン照合できます。

* 新しい直積型を定義する好ましい方法は*レコード*として定義することです。
なぜなら型に加えて、
それぞれの*レコードのフィールド*を設定したり変更したりするための文法的な便宜があるためです。

* 汎化型と汎化関数で概念を汎化したり関数の型シグネチャで決まった型を使う代わりに*型変数*を使うことで
多くの型で使えるようにしました。

* *nullになりかねない値* (`Maybe`) のようなよくある概念や、
何らかのエラー状態でもって失敗するかもしれない計算 (`Either`)、
そして同じ型の値の集まりを一度に扱うこと (`List`) は汎化型と汎化関数の使用例で、
既に*Prelude*から提供されています。

## お次は？

[次の節](Interfaces.md)では*インターフェース*を導入します。
インターフェースは*関数のオーバーロード*の他の手法です。

<!-- vi: filetype=idris2:syntax=markdown
-->
