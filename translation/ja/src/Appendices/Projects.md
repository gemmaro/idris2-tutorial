# Idrisのプロジェクトを構築する

この節ではより大きなIdrisのプロジェクトを、組織立て、インストールし、依存先にする方法をお見せしていきます。Idrisのパッケージ、モジュールシステム、型と関数の可視性、コメントとドキュメント文字列を書くこと、ライブラリの管理にpackを使うことについて一望します。

この節は既に少しでもIdrisのコードを書いたことがある全読者にとって役に立つことでしょう。ここではあまり型水準の魔法を扱いませんが、`failing`コードブロックを使っていくつかの概念を実演します。このブロックはこれまでに見たことがないかもしれません。この比較的新しい言語への追加要素は推敲（型検査）の最中に失敗することが期待されるものです。例えば次の通りです。

```repl
failing "Can't find an implementation for FromString Bits8."
  ohno : Bits8
  ohno = "Oh no!"
```

ドキュメンテーションの目的で失敗ブロックの一部としてコンパイラのエラー文言の部分文字列を与えることができ、ブロックが期待されたエラーで失敗することを確かめられます。

## モジュール

全てのIdrisのソースファイルには*module*が定義されています。ファイルは大抵、以下のようなモジュールヘッダから始まります。

```idris
module Appendices.Projects
```

モジュール名はドットで区切られたいくつかの大文字始まりの識別子からなります。この識別子の並びはモジュールが保管されている`.idr`ファイルのパスを反映したものでなければなりません。例えばこのモジュールは`Appendices.Projects.md`に保管されているので、モジュール名は`Appendices.Projects`です。

「でもちょっと待ってください」と言う声が聞こえます。「`Appendices`の親フォルダについてはどうなんですか。どうして親フォルダはモジュール名の一部にならないのでしょう。」これを理解するには*ソースディレクトリ*の概念についてお話ししなければなりません。ソースディレクトリはIdrisがソースファイルを探す場所のことです。既定ではIdrisの実行ファイルが走っているところのディレクトリです。例えばこのプロジェクトの`src`フォルダにいるとき、このソースファイルを次のように開くことができます。

```sh
idris2 Appendices/Projects.md
```

しかし同じことをプロジェクトのルートフォルダからしようとすると動きません。

```sh
$ idris2 src/Appendices/Projects.md
...
Error: Module name Appendices.Projects does not match file name "src/Appendices/Projects.md"
...
```

ですから、モジュール名にどのフォルダ名が含まれるのかは、ソースディレクトリと見做す親ディレクトリに依るのです。慣習としてはソースディレクトリを`src`と名付けますが、これは必須ではありません（上で述べたように既定では実際はIdrisを走らせるディレクトリになります）。`--source-dir`コマンドラインオプションを使ってソースディレクトリを変えることができます。以下はこのプロジェクトのルートディレクトリ中で動きます。

```sh
idris2 --source-dir src src/Appendices/Projects.md
```

そして以下は親ディレクトリから動きます（この入門書が`tutorial`フォルダに保管されていることを前提としています）。

```sh
idris2 --source-dir tutorial/src tutorial/src/Appendices/Projects.md
```

しかしほとんどの場合、プロジェクトに`.ipkg`ファイルを指定し（この節の後のほうを参照）そのファイルでソースディレクトリを定義することでしょう。その後で（`idris2`実行ファイルの代わりに）packを使ってREPLセッションを開始しソースファイルを読み込むことができます。

### モジュールのインポート

Idrisのコードを書く際は、関数とデータ型をインポートする必要が出てくることがよくあります。これは`import`文でできます。以下の数例でどんな見た目をしているのかお見せします。

```idris
import Data.String
import Data.List
import Text.CSV
import public Appendices.Neovim
import Data.Vect as V
import public Data.List1 as L
```

最初の2行は別の*パッケージ*（パッケージについては後で学びます）からモジュールをインポートしています。`Data.List`は*base*パッケージ由来で、このパッケージはIdrisのインストール時にその一部としてインストールされたものです。

2行目は自分のソースディレクトリ`src`中からモジュール`Text.CSV`をインポートしています。作業しているファイルと同じソースディレクトリの一部にあるモジュールをインポートするのはいつでもできます。

3行目ではモジュール`Appendices.Neovim`をインポートしています。これも自分のソースディレクトリからです。ただしこの`import`文は`public`キーワードが追加されていますね。こうするとモジュールを*再輸出*することができ、現在のモジュールに加えて他のモジュールの中でも使えるようになります。別のモジュールが`Appendices.Projects`をインポートした場合、これ以上`import`文を書かなくてもモジュール`Appendices.Neovim`がインポートされるのです。この機能は複雑な機能を違うモジュールに分割しておいて、1つに全部まとめるモジュールにインポートするときに便利です。例として*base*の`Control.Monad.State`を参照してください。Idrisのソースは[Idris2プロジェクト](https://github.com/idris-lang/Idris2)をGitHub上かクローンしてきてから見ることができます。baseライブラリは`libs/base`サブフォルダにあります。

モジュール`A`の関数を使うために別のモジュール`B`のユーティリティが必要なことはよく起こるので、そうした場合は`A`は`B`を再輸出すべきです。例えば*base*の`Data.Vect`は`Data.Fin`を再輸出しますが、これは`Data.Fin`がベクタを扱うときによく必要になるからです。

4行目はモジュール`Data.Vect`をインポートし、新しい名前`V`を与えています。この名前はより短い接頭辞として使えます。よくモジュール名を前置して識別子の曖昧解決をする必要がある場合は、こうすることでコードをより簡潔にする助けになります。

```idris
vectSum : Nat
vectSum = sum $ V.fromList [1..10]
```

最後に5行目はモジュールを公に輸入して新しい名前を与えています。そうするとこの名前は`Appendices.Projects`を介して`Data.List1`を推移的にインポートしたときのものになります。これを見てみるために（入門書を型検査したあとで）REPLセッションを始めましょう。ただしこのプロジェクトのルートディレクトリからソースファイルを読み込みません。

```sh
pack typecheck tutorial
pack repl
```

そしてモジュール`Appendices.Projects`を読み込んで`singleton`の型を確認します。

```repl
Main> :module Appendices.Projects
Imported module Appendices.Projects
Main> :t singleton
Data.String.singleton : Char -> String
Data.List.singleton : a -> List a
L.singleton : a -> List1 a
```

見ての通り`singleton`の`List1`版が`Data.List1`ではなく`L`で前置されています。ただ「公式の」接頭辞を使うことも可能のままです。

```repl
Main> List1.singleton 12
12 ::: []
Main> L.singleton 12
12 ::: []
```

### 名前空間

時折、1つのモジュール中に同じ名前を持つ関数やデータ型を複数定義したいときがあります。Idrisはこれを許しませんが、それは全ての名前が*名前空間*で一意でなければならないからです。そしてモジュールの名前空間は単なる完全に修飾されたモジュール名です。しかし`namespace`キーワードとそれに続く名前空間名を使うことでモジュール中に追加で名前空間を定義することは可能です。この名前空間に属する全ての関数は同量の空白で字下げされなければなりません。

以下は例です。

```idris
data HList : List Type -> Type where
  Nil  : HList []
  (::) : (v : t) -> (vs : HList ts) -> HList (t :: ts)

head : HList (t :: ts) -> t
head (v :: _) = v

tail : HList (t :: ts) -> HList ts
tail (_ :: vs) = vs

namespace HVect
  public export
  data HVect : Vect n Type -> Type where
    Nil  : HVect []
    (::) : (v : t) -> (vs : HVect ts) -> HVect (t :: ts)

  public export
  head : HVect (t :: ts) -> t
  head (v :: _) = v

  public export
  tail : HVect (t :: ts) -> HVect ts
  tail (_ :: vs) = vs
```

関数名`HVect.head`と`HVect.tail`及び構築子`HVect.Nil`と`HVect.(::)`は外側の名前空間
(`Appendices.Projects`)
にある同名の関数と構築子と衝突するので、専用の名前空間に置かなくてはなりません。名前空間の外側から使えるようにするには輸出する必要があります（以下の可視性の節を参照）。これらの名前の曖昧解決をする必要があるときは、名前に名前空間の一部を前置すればよいです。例えば以下は曖昧解決エラーで失敗しますが、それはスコープで`head`という名前の関数が複数あって、`head`の引数（リストの構文に対応している型があり、それもスコープに複数あるのです）からはどのバージョンを使いたいのかが明らかにならないからです。

```idris
failing "Ambiguous elaboration."
  whatHead : Nat
  whatHead = head [12,"foo"]
```

`head`に名前空間の一部を前置することで両方の曖昧性を解決をすることができます。これで`[12,"foo"]`が`HVect`でなければいけないことが直ちに明らかになりました。それが`HVect.head`の引数の型だからです。

```idris
thisHead : Nat
thisHead = HVect.head [12,"foo"]
```

以下の副節では可視性の原理を実演するために名前空間を活用していきます。

### 可視性

関数やデータ型を定義されているモジュールや名前空間の外で使うためには、*可視性*を変える必要があります。既定の可視性は`private`です。この可視性の関数やデータ型はモジュールや名前空間の外側からは見えません。

```idris
namespace Foo
  foo : Nat
  foo = 12

failing "Name Appendices.Projects.Foo.foo is private."
  bar : Nat
  bar = 2 * foo
```

関数が見えるようにするには`export`キーワードを註釈します。

```idris
namespace Square
  export
  square : Num a => a -> a
  square v = v * v
```

こうすると（`Appendices.Projects`を輸入した後に）他のモジュールや名前空間内で関数`square`を呼び出すことができます。

```idris
OneHundred : Bits8
OneHundred = square 10
```

しかし`square`の*実装*は輸出されないため、`square`は推敲の際に簡約されません。

```idris
failing "Can't solve constraint between: 100 and square 10."
  checkOneHundred : OneHundred === 100
  checkOneHundred = Refl
```

これが動くようにするには`square`を*公に輸出*する必要があります。

```idris
namespace SquarePub
  public export
  squarePub : Num a => a -> a
  squarePub v = v * v

OneHundredAgain : Bits8
OneHundredAgain = squarePub 10

checkOneHundredAgain : OneHundredAgain === 100
checkOneHundredAgain = Refl
```

したがって遂行中に簡約する関数が必要なときは`export`ではなく`public
export`を註釈してください。型を計算する関数を使っている場合はとくに大切です。そうした関数は推敲中の簡約が*必須*であり、公に輸出しないと完全に役に立ちません。

```idris
namespace Stupid
  export
  0 NatOrString : Type
  NatOrString = Either String Nat

failing "Can't solve constraint between: Either String ?b and NatOrString."
  natOrString : NatOrString
  natOrString = Left "foo"
```

型別称を公に輸出すると全型検査が正常になります。

```idris
namespace Better
  public export
  0 NatOrString : Type
  NatOrString = Either String Nat

natOrString : Better.NatOrString
natOrString = Left "bar"
```

### データ型の可視性

データ型の可視性は僅かに異なった挙動をします。`private`（既定）に設定されている場合、定義されている名前空間の外側では*型構築子*も*データ構築子*も見えません。`export`と註釈が付いていれば型構築子は輸出されますがデータ構築子は輸出されません。

```idris
namespace Export
  export
  data Foo : Type where
    Foo1 : String -> Foo
    Foo2 : Nat -> Foo

  export
  mkFoo1 : String -> Export.Foo
  mkFoo1 = Foo1

foo1 : Export.Foo
foo1 = mkFoo1 "foo"
```

見ての通り型`Foo`と関数`mkFoo1`を名前空間`Export`の外側で使えています。しかし`Foo1`構築子を使って直接型`Foo`の値を作ることはできません。

```idris
failing "Export.Foo1 is private."
  foo : Export.Foo
  foo = Foo1 "foo"
```

公にデータ型を輸出すると状況は変わります。

```idris
namespace PublicExport
  public export
  data Foo : Type where
    Foo1 : String -> PublicExport.Foo
    Foo2 : Nat -> PublicExport.Foo

foo2 : PublicExport.Foo
foo2 = Foo2 12
```

インターフェースについても同じことが言えます。公に公開されている場合、インターフェース（型構築子）に加えて全ての関数が輸出され、それらの関数が定義されている名前空間の外側で実装を書くことができます。

```idris
namespace PEI
  public export
  interface Sized a where
    size : a -> Nat

Sized Nat where size = id

sumSizes : Foldable t => Sized a => t a -> Nat
sumSizes = foldl (\n,e => n + size e) 0
```

公に公開されていなければ、メンバー関数が定義されている名前空間の外側では実装を書くことができません（しかし型と関数についてはコードで使うことができます）。

```idris
namespace EI
  export
  interface Empty a where
    empty : a -> Bool

  export
  Empty (List a) where
    empty [] = True
    empty _  = False

failing
  Empty Nat where
    empty Z = True
    empty (S _) = False

nonEmpty : Empty a => a -> Bool
nonEmpty = not . empty
```

### 子名前空間

時には別のモジュールや名前空間にあるプライベート関数にアクセスする必要があります。これは子名前空間（もっと良い名前があるといいのですが）の内側から可能です。モジュールと名前空間は親モジュールまたは親名前空間の接頭辞を共有します。例えば次の通りです。

```idris
namespace Inner
  testEmpty : Bool
  testEmpty = nonEmpty (the (List Nat) [12])
```

見ての通り、`nonEmpty`はモジュール`Appendices.Projects`のプライベート関数ですが、名前空間`Appendices.Projects.Inner`からは関数にアクセスできています。これはモジュールについても可能です。仮にモジュール`Data.List.Magic`を書いたら、*base*のモジュール`Data.List`に定義されたプライベートの補助関数にアクセスすることができるでしょう。事実、このIdrisのモジュールシステムの妙な癖を実演するモジュール`Data.List.Magic`を加えたところです（見に行ってください）。一般にこれはどちらかと言えばハック的な可視性の制約を迂回する方法ですが、場合によっては役に立つこともあります。

## 引数ブロック

この副節では`parameters`ブロックという言語の構成要素を眺めていきたいと思います。これにより複数の関数に共通する読取専用の引数（パラメータ）の集合を分配することができ、したがってより簡潔な関数の処方を書くことができます。小さなプログラムの例でどのように使うことができるか実演していきます。

外部の情報を関数で使えるようにする一番基本的な方法は追加の引数として渡すことです。オブジェクト指向プログラミングではこの原理は時に[依存性の注入](https://en.wikipedia.org/wiki/Dependency_injection)と呼ばれて人口に膾炙しており、オブジェクト指向のライブラリやフレームワークはこれに基づいて構築されています。

関数型プログラミングではこうしたことからは完全に一歩身を引いていられます。
アプリケーションから何らかの設定データにアクセスする必要がありますか。
関数に追加の引数を渡してください。
局所的な可変状態を使いたいですか。
関数に追加の引数として対応する`IORef`を渡してください。
引数に渡すことはかなり効率的で非常に単純です。
唯一の欠点は、関数の処方を振り出しに戻してしまうことです。
この考え方を抽象化するためのモナドさえあり、`Reader`モナドと呼ばれます。
baseライブラリの`Control.Monad.Reader`モジュールにあります。

しかしIdrisではもっと簡単な方法があります。依存性の注入のために証明検索と自動暗黙引数が使えるのです。以下はそうしたコード例です。

```idris
data Error : Type where
  NoNat  : String -> Error
  NoBool : String -> Error

record Console where
  constructor MkConsole
  read : IO String
  put  : String -> IO ()

record ErrorHandler where
  constructor MkHandler
  handle : Error -> IO ()

getCount' : (h : ErrorHandler) => (c : Console) => IO Nat
getCount' = do
  str <- c.read
  case parsePositive str of
    Nothing => h.handle (NoNat str) $> 0
    Just n  => pure n

getText' : (h : ErrorHandler) => (c : Console) => (n : Nat) -> IO (Vect n String)
getText' n = sequence $ replicate n c.read

prog' : ErrorHandler => (c : Console) => IO ()
prog' = do
  c.put "Please enter the number of lines to read."
  n  <- getCount'
  c.put "Please enter \{show n} lines of text."
  ls <- getText' n
  c.put "Read \{show n} lines and \{show . sum $ map length ls} characters."
```

プログラムの例は何らかの`Console`型から入力を読み、また出力を印字します。この型の実装は関数の呼び出し側に委ねられています。これは典型的な依存性の注入の例になっています。`IO`アクションはテキストの数行をどう読み書きしたらいいのかを知りませんが（例えば直接`putStrLn`や`getLine`を呼び出したりはしません）、外部の*オブジェクト*によってこうしたタスクを扱ってくれます。これにより例えばテスト時に単純な*モックオブジェクト*を使い、実際のアプリケーションを走らせるときは、2つのファイル制御子やデータベース接続を使うことができます。オブジェクト指向プログラミングでよく見られる典型的な技法が存在し、事実、この例は典型的なオブジェクト指向のパターンを純粋に関数型プログラミング言語でエミュレートしたものになります。`Console`のような型は機能（*メソッド*`read`および`put`）を提供する*クラス*として見ることができ、型`Console`の値はこのクラスの*オブジェクト*として見ることができます。その値はこれらのメソッドを呼び出すことができます。

エラー制御についても同じことが言えます。エラー制御子を、どんなエラーが起こっても静かに無視するようにさせることができますし、`stderr`に印字しつつ同時にログファイルに書き込むようにすることもできます。どんなことが起ころうと関数は意に介しません。

しかしこのとても単純な例であっても既に追加の関数引数を導入していますよね。そして実世界のアプリケーションともなるとより多くの引数が必要になるでしょうし、関数の処方が膨れ上がってしまうことは容易に想像が付きます。朗報ですが、Idrisにはこのためのとても明快で単純な解決法があります。`parameters`ブロックです。このブロックではブロック内に挙げられた全ての関数で共通する（関数の引数を変えない）*引数*のリストを指定することができます。そうすればこうした引数はそれぞれの関数でリストにする必要はなく、もう関数の処方を散らかしてしまうこともありません。以下は上の例で引数ブロックを使ったものです。

```idris
parameters {auto c : Console} {auto h : ErrorHandler}
  getCount : IO Nat
  getCount = do
    str <- c.read
    case parsePositive str of
      Nothing => h.handle (NoNat str) $> 0
      Just n  => pure n

  getText : (n : Nat) -> IO (Vect n String)
  getText n = sequence $ replicate n c.read

  prog : IO ()
  prog = do
    c.put "Please enter the number of lines to read."
    n  <- getCount
    c.put "Please enter \{show n} lines of text."
    ls <- getText n
    c.put "Read \{show n} lines and \{show . sum $ map length ls} characters."
```

`parameters`ブロック中の引数としていくらでも（暗黙子、明示子、自動暗黙子、名前付き、名前なしのような）任意の引数を自由に挙げることができますが、一番のはたらきを見せるのは暗黙子と自動暗黙子の引数のときです。明示引数は引数ブロックで関数に明示的に渡さねばならず、同じ明示引数を持つ他の引数ブロックから呼び出すときもそうなります。これはむしろ紛らわしくなりえます。

この例を締め括るにあたって、以下はプログラムを走らせるメイン関数です。`prog`を呼び出すときに`Console`と`ErrorHandler`を明示的に組み合わせて使われているところに注目してください。

```idris
main : IO ()
main =
  let cons := MkConsole (trim <$> getLine) putStrLn
      err  := MkHandler (const $ putStrLn "It didn't work")
   in prog
```

自動暗黙引数を介した依存性の注入は引数ブロックがなしえる実例の1つに過ぎません。このブロックは複数の関数で繰り返し登場する引数のリストがあるときは常に一般に有用です。

## ドキュメンテーション

ドキュメンテーションは鍵です。自分が書いたライブラリを使う他のプログラマやコードを理解しようとする人々（将来の自分自身を含む）のためのものであって、非自明な実装の詳細を説明するコメントや輸出されたデータ型と関数の意図と機能を記述するドキュメント文字列でコードに註釈を付けることは大事です。

### コメント

Idrisのソースファイルにコメントを書くには、単に2つのハイフンに続けてテキストを書き加えるだけです。

```idris
-- これは全き退屈なコメント
boring : Bits8 -> Bits8
boring a = a -- 恐らく単にPreludeの`id`を使うべき
```

文字列表記の一部でない2つのハイフンを含む行は皆、ハイフン以降の部分がIdrisによってコメントとして解釈されます。

仕切り`{-`及び`-}`を使って複数行コメントを書くこともできます。

```idris
{-
  これは複数行コメントです。
  コードのブロック全体をコメントアウトするのに使えます。
  例えば比較的大きなファイルで複数の型エラーがあったときとかです。
-}
```

### ドキュメント文字列

コメントはソースコードを読んで理解しようとするプログラマを対象にするものですが、ドキュメント文字列は輸出される関数とデータ型にドキュメンテーションを提供するもので、他者にその意図や挙動を説明するためのものです。

以下はドキュメントが付いた関数の例です。

```idris
||| リストの先頭から最初の2要素を取り出そうとします。
|||
||| リストに2つ以上の要素があれば値の対を`Just`に包んで返します。
||| リストが2要素より少なければ`Nothing`を返します。
export
firstTwo : List a -> Maybe (a,a)
firstTwo (x :: y :: _) = Just (x,y)
firstTwo _             = Nothing
```

REPLでドキュメント文字列を眺めることができます。

```repl
Appendices.Projects> :doc firstTwo
Appendices.Projects.firstTwo : List a -> Maybe (a,a)
  Tries to extract the first two elements from the beginning
  of a list.

  Returns a pair of values wrapped in a `Just` if the list has
  two elements or more. Returns `Nothing` if the list has fewer
  than two elements.
  Visibility: export
```

データ型やその構築子も似たような風にドキュメントを書けます。

```idris
||| 保管されている値の数で指標付けられた二分木
|||
||| @param `n` : `Tree`に保管されている値の数
||| @param `a` : `Tree`で保管されている値の型
public export
data Tree : (n : Nat) -> (a : Type) -> Type where
  ||| 二分木の葉に保管されている単一の値
  Leaf   : (v : a) -> Tree 1 a

  ||| 2つの部分木を結わえる分枝
  Branch : Tree m a -> Tree n a -> Tree (m + n) a
```

さあ、これにより生成されたドキュメント文字列をREPLで見てみましょう。

コードにドキュメントを書くことは大変重要です。これに気付くのは、ひとたび他の人のコードを理解しようとしたり、自分でそれなりの規模のコードを書いたのち数カ月間触れない状態が続いたあとに読み返したりするときです。充分にドキュメント化されていないと、気の晴れないことになるかもしれません。Idrisではコードにドキュメントを書いたり註釈を付けたりするのに必要なツールが提供されているので、そういったことをする時間は取るべきです。ドキュメントを書くことは愉快なことです。

## パッケージ

Idrisのパッケージがあると複数のモジュールを1つの論理的な単位にまとめて、パッケージを*インストール*することによって他のIdrisのプロジェクトから使えるようにすることができます。この節ではIdrisのパッケージの構造とプロジェクトで他のパッケージに依存する方法について学んでいきます。

### `.ipkg`ファイル

Idrisのパッケージの核心は`.ipkg`ファイルにあります。このファイルは大抵プロジェクトのルートディレクトリに保管されますが、必須ではありません。例えばこのIdrisの入門書では、入門書のルートディレクトリに`tutorial.ipkg`ファイルがあります。

`.ipkg`ファイルは複数のキーバリュー対（ほとんどがオプション）から構成され、そのうち重要なものをここに記述していきます。今のところ新しいIdrisのプロジェクトを立ち上げる最も簡単な方法はpackまたはIdris自体を使うことです。以下を走らせるだけです。

```sh
pack new lib pkgname
```

上記は新しいライブラリの骨子をつくります。あるいは

```sh
pack new bin appname
```

とすると新しいアプリケーションを立ち上げます。新しいディレクトリと相応しい`.ipkg`ファイルを作るのに加えて、これらのコマンドは`pack.toml`ファイルも追加します。このファイルについて詳しくは後述します。

### 依存関係

`.ipkg`ファイルの最重要の側面の1つは、`depends`フィールドにライブラリが依存するパッケージを一覧にすることです。以下は[*hedgehog*パッケージ](https://github.com/stefan-hoeck/idris2-hedgehog)からの例です。このパッケージはIdrisで性質テストを書くための枠組みです。

```ipkg
depends    = base         >= 0.5.1
           , contrib      >= 0.5.1
           , elab-util    >= 0.5.0
           , pretty-show  >= 0.5.0
           , sop          >= 0.5.0
```

見ての通り*hedgehog*は*base*と*contrib*に依存しており、両方ともIdrisのインストールに含まれる一部です。しかし[*elab-util*](https://github.com/stefan-hoeck/idris2-elab-util)という推敲スクリプトを書くためのユーティリティライブラリ（Idrisのコードを書くことによってIdrisの宣言を作る強力な技法です。ご興味があれば分量のある入門書があるのでどうぞ）、[*sop*](https://github.com/stefan-hoeck/idris2-sop)という*積和*表現を介してインターフェースの実装を一般的に導出するライブラリ（便利なものでいつの日にか確認したくなるでしょう）、[*pretty-show*](https://github.com/stefan-hoeck/idris2-pretty-show)というIdrisの値を綺麗に印字するためのライブラリ（*hedgehog*はこれをテストが失敗した場合に活用しています）にも依存しています。

なので自分のプロジェクトで性質テストを書くのに実際に*hedgehog*を使えるようになるまでには、*hedgehog*自体をインストールする前にそれに依存するパッケージをインストールする必要があるでしょう。こうしたことを手作業でするのは億劫なのでpackのようなパッケージ管理に対応してもらうのが一番です。

#### 依存関係のバージョン

Idrisが依存関係に使うべきバージョンを特定のもの（あるいは範囲）に指定したいことがあるでしょう。この指定ができると、同じパッケージの複数のバージョンがインストールされていて、全部が全部プロジェクトと互換性があるわけではないようなときに、役に立つことでしょう。以下にいくつかの例を示します。

```ipkg
depends    = base         == 0.5.1
           , contrib      == 0.5.1
           , elab-util    >= 0.5.0
           , pretty-show
           , sop          >= 0.5.0 && < 0.6.0
```

このようにすると、パッケージ*base*と*contrib*は厳密に与えられたバージョンを、パッケージ*elab-util*は`0.5.0`以上のバージョンを、パッケージ*pretty-show*はどんなバージョンも、パッケージ*sop*は与えられた範囲内のバージョンを、それぞれ探し出すことになります。全ての場合において、指定された範囲に合致するパッケージのインストールされたバージョンが複数ある場合、最新版が使用されます。

自分のパッケージでこの依存関係の指定が使えるようにするためには、`.ipkg`ファイルには必ずパッケージ名と現在のバージョンを与えるべきです。

```ipkg
package tutorial

version    = 0.1.0
```

後述するようにpackと厳選されたパッケージコレクションを使う際はあまりパッケージのバージョンは大事な役割を持ちません。しかしそれでも最前線で導入された破壊的な変更を確実に察知できるようにするために、パッケージのバージョンを制限することを検討したいこともあるでしょう。

### ライブラリのモジュール

GitHubで入手できるIdrisのパッケージはほとんどでないとしてもその多くがプログラミング用の*ライブラリ*です。これらのライブラリは何らかの機能を実装していて、与えられたパッケージに依存する全てのプロジェクトで使うことができるものです。これはIdrisの*アプリケーション*とは違います。アプリケーションは実行ファイルにコンパイルしてコンピュータで走らせられるもののはずです。Idrisのプロジェクト自体は両方を提供しています。1つはIdrisのコンパイラのアプリケーションで、Idrisのライブラリとアプリケーションを型検査してビルドするのに使います。もう1つは*prelude*、*base*、*contrib*のようないくつかのライブラリで、ほとんどのIdrisのプロジェクトで便利な基本的なデータ型と関数を提供します。

ライブラリで書いたモジュールを型検査してインストールするためには、`.ipkg`ファイルの`modules`フィールドにそれらを列挙しなければなりません。以下は*sop*パッケージからの抜粋です。

```ipkg
modules = Data.Lazy
        , Data.SOP
        , Data.SOP.Interfaces
        , Data.SOP.NP
        , Data.SOP.NS
        , Data.SOP.POP
        , Data.SOP.SOP
        , Data.SOP.Utils
```

この一覧に欠けているモジュールはインストール*されず*、そのためsopライブラリに依存する別のパッケージからは決して利用できません。

### packと厳選されたパッケージのコレクション

プロジェウトの依存関係グラフがより大きく複雑なものになってきたとき、つまりプロジェクトが多くのライブラリに依存していて、そのライブラリもまた他のライブラリに依存しているとき、2つのパッケージが両方とも、第三のパッケージの異なる……そして非互換の可能性がある……バージョンに依存しているということは起こりえます。この状況は解決することが不可能に近いことがあり、競合するライブラリに対処する際はかなりいらいらすることになりかねません。

したがってpackプロジェクトの考え方として、そのような状況を避けるために、初めから*厳選されたパッケージコレクション*を活用することとしています。packのコレクションはIdrisのコンパイラとパッケージの集まりからなるGitのコミットから構成されており、それぞれのGitのコミットについて、コレクション中の全てのものが一緒に使っても正常に動作し問題がないことを検査されているのです。packで使えるパッケージの一覧は[here](https://github.com/stefan-hoeck/idris2-pack-db/blob/main/STATUS.md)で見ることができます。

作業しているプロジェクトがpackのパッケージコレクションの一覧にあるライブラリの1つに依存しているなら、packは自動的にそのライブラリとその依存関係インストールしてくれます。
しかしpackのコレクションにまだ含まれていないライブラリへの依存関係を作りたいこともあるでしょう。
その場合、問題のライブラリをどこかの`pack.toml`ファイルに指定しなければなりません。
このファイルは、大域的なものだと`$HOME/.pack/user/pack.toml`にあり、局所的なものは現在のプロジェクトや（もしあれば）その親ディレクトリのどこかにあります。
そのファイルでは、システム上またはGitのプロジェクト（ローカルまたはリモート）にある依存関係を指定することができます。それぞれについての例は以下の通りです。

```toml
[custom.all.foo]
type = "local"
path = "/path/to/foo"
ipkg = "foo.ipkg"

[custom.all.bar]
type   = "github"
url    = "https://github.com/me/bar"
commit = "latest:main"
ipkg   = "bar.ipkg"
```

見ての通り両方の場合について、プロジェクトがどこで見つかるかということと、`.ipkg`ファイルの名前と場所を指定せねばなりません。Gitのプロジェクトの場合、使うコミットをpackに伝える必要があります。上の例では`main`ブランチの最新コミットを使いたいとしています。`pack
fetch`を使って現在の最新コミットのハッシュを格納することができます。

上で与えられているような項目が、packに独自のライブラリの対応を追加するのに必要なことの全てです。これで自分のプロジェクトの`.ipkg`ファイルに依存関係としてこれらのライブラリを挙げることができ、packはそれらの依存関係を自動的にインストールしてくれます。

## まとめ

Idrisのプロジェクトを構築することについての節を締め括ります。いくつかの種類のコードブロックについて学んできました。`failing`ブロックは推敲でコード片が失敗することを示すものであり、`namespace`には同じソースファイル中でオーバーロードされた名前があり、引数ブロックは複数の関数で引数のリストを共有するものでした。そしていくつかのソースファイルを1つのIdrisのライブラリやアプリケーションにまとめる方法についても学びました。最後に、Idrisのプロジェクトに外部のライブラリを含める方法とこうした依存関係をpackに管理してもらうための方法を学びました。

<!-- vi: filetype=idris2:syntax=markdown
-->
