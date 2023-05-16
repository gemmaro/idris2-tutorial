# Idrisでの関数型プログラミング

[中文翻译](https://github.com/running-grass/idris2-tutorial-zh/blob/main/translation/README.md),
[日本語訳](https://github.com/gemmaro/idris2-tutorial/blob/ja/translation/ja/README.md)

このプロジェクトの目標を手短かに説明するとこうなります。
Idrisプログラミング言語の多少なりとも網羅的な手引きとし、関数型プログラミングの入門者を対象とした入門的な題材をちりばめることです。

内容はいくつかの部にまとまっています。
中核的な言語の特徴についての部は、Idrisでの関数型プログラミングのための手引きです。
各部はいくつかの章からなり、それぞれの章ではIdrisプログラミング言語や中核ライブラリの一側面を踏み込んで扱います。
ほとんどの章は（時に多くの）演習が付録しており、ディレクトリ`src/Solutions`に解法があります。

現時点では、中核的な言語機能の部分もまだ完了しておらず、活発に開発されているところです。
その開発には筆者の生徒の中からも数名挑戦しており、関数型プログラミングを完全に初めたばかりの人もいます。

## 目次

### 第1部：中核にある言語の特徴

この部ではIdrisプログラミング言語への導入を地道に一歩ずつ進めることを試みます。
もし関数型プログラミングが初めてであれば、必ず順番にこの部の章にしたがい、また*全ての演習を解いてください*。

Haskellのような他の純粋関数型プログラミング言語を使ったことがあるなら、
導入的な内容（関数 その1、代数的データ型、インターフェース）に素早く目を通すのでもよいでしょう。
ほとんどは既に馴染みのある事柄でしょうから。

1. [導入](src/Tutorial/Intro.md)
   1. [プログラミング言語Idrisについて](src/Tutorial/Intro.md#about-the-idris-programming-language)
   2. [REPLを使う](src/Tutorial/Intro.md#using-the-repl)
   3. [最初のIdrisプログラム](src/Tutorial/Intro.md#a-first-idris-program)
   4. [Idrisの定義の形](src/Tutorial/Intro.md#the-shape-of-an-idris-definition)
   5. [困ったときは](src/Tutorial/Intro.md#where-to-get-help)
2. [関数 その1](src/Tutorial/Functions1.md)
   1. [1つ以上の引数を持つ関数](src/Tutorial/Functions1.md#functions-with-more-that-one-argument)
   2. [関数結合](src/Tutorial/Functions1.md#function-composition)
   3. [高階関数](src/Tutorial/Functions1.md#higher-order-functions)
   4. [カリー化](src/Tutorial/Functions1.md#currying)
   5. [匿名関数](src/Tutorial/Functions1.md#anonymous-functions)
   6. [演算子](src/Tutorial/Functions1.md#operators)
3. [代数的データ型](src/Tutorial/DataTypes.md)
   1. [列挙型](src/Tutorial/DataTypes.md#enumerations)
   2. [直和型](src/Tutorial/DataTypes.md#sum-types)
   3. [レコード](src/Tutorial/DataTypes.md#records)
   4. [汎化データ型](src/Tutorial/DataTypes.md#generic-data-types)
   5. [データ定義の別の文法](src/Tutorial/DataTypes.md#alternative-syntax-for-data-definitions)
4. [インターフェース](src/Tutorial/Interfaces.md)
   1. [インターフェースの基本](src/Tutorial/Interfaces.md#interface-basics)
   2. [もっとインターフェース](src/Tutorial/Interfaces.md#more-about-interfaces)
   3. [Preludeにあるインターフェース](src/Tutorial/Interfaces.md#interfaces-in-the-prelude)
5. [関数 その2](src/Tutorial/Functions2.md)
   1. [let束縛と局所定義](src/Tutorial/Functions2.md#let-bindings-and-local-definitions)
   2. [関数引数の真実](src/Tutorial/Functions2.md#the-truth-about-function-arguments)
   3. [虫食いプログラミング](src/Tutorial/Functions2.md#programming-with-holes)
6. [依存型](src/Tutorial/Dependent.md)
   1. [長さ指標付きリスト](src/Tutorial/Dependent.md#length-indexed-lists)
   2. [Fin:
      ベクタから安全に指標で引く](src/Tutorial/Dependent.md#fin-safe-indexing-into-vectors)
   3. [コンパイル時計算](src/Tutorial/Dependent.md#compile-time-computations)
7. [IO: 副作用のあるプログラミング](src/Tutorial/IO.md)
   1. [純粋な副作用？](src/Tutorial/IO.md#pure-side-effects)
   2. [doブロックとその脱糖](src/Tutorial/IO.md#do-blocks-desugared)
   3. [ファイルを取り回す](src/Tutorial/IO.md#working-with-files)
   4. [どうIOが実装されているか](src/Tutorial/IO.md#how-io-is-implemented)
8. [関手と仲間達](src/Tutorial/Functor.md)
   1. [関手](src/Tutorial/Functor.md#functor)
   2. [アプリカティブ](src/Tutorial/Functor.md#applicative)
   3. [モナド](src/Tutorial/Functor.md#monad)
   4. [背景とその先へ](src/Tutorial/Functor.md#background-and-further-reading)
9. [再帰と畳み込み](src/Tutorial/Folds.md)
   1. [再帰](src/Tutorial/Folds.md#recursion)
   2. [全域性検査についての注意](src/Tutorial/Folds.md#a-few-notes-on-totality-checking)
   3. [Foldableインターフェース](src/Tutorial/Folds.md#interface-foldable)
10. [作用付き巡回](src/Tutorial/Traverse.md)
    1. [CSVの表を読む](src/Tutorial/Traverse.md#reading-csv-tables)
    2. [状態付きプログラミング](src/Tutorial/Traverse.md#programming-with-state)
    3. [組み立ての強力さ](src/Tutorial/Traverse.md#the-power-of-composition)
11. [シグマ型](src/Tutorial/DPair.md)
    1. [依存対](src/Tutorial/DPair.md#dependent-pairs)
    2. [用例：核酸](src/Tutorial/DPair.md#use-case-nucleic-acids)
    3. [用例：スキーマに基づくCSVファイル](src/Tutorial/DPair.md#use-case-csv-files-with-a-schema)
12. [命題の等値性](src/Tutorial/Eq.md)
    1. [型としての等値性](src/Tutorial/Eq.md#equality-as-a-type)
    2. [証明としてのプログラム](src/Tutorial/Eq.md#programs-as-proofs)
    3. [Voidへ](src/Tutorial/Eq.md#into-the-void)
    4. [規則を書き換える](src/Tutorial/Eq.md#rewrite-rules)
13. [前提と証明検索](src/Tutorial/Predicates.md)
    1. [前提条件](src/Tutorial/Predicates.md#preconditions)
    2. [値同士の契約](src/Tutorial/Predicates.md#contracts-between-values)
    3. [用例：柔軟なエラー制御](src/Tutorial/Predicates.md#use-case-flexible-error-handling)
    4. [インターフェースの真実](src/Tutorial/Predicates.md#the-truth-about-interfaces)
14. [原始型](src/Tutorial/Prim.md)
    1. [どのように原始型が実装されているか](src/Tutorial/Prim.md#how-primitives-are-implemented)
    2. [文字列を取り回す](src/Tutorial/Prim.md#working-with-strings)
    3. [整数](src/Tutorial/Prim.md#integers)
    4. [精錬後の原始型](src/Tutorial/Prim.md#refined-primitives)

### 第2部：補遺

補遺は身近な話題の参考情報として使えます。
最終的には、Idrisの文法、典型的なエラー文言、モジュールシステム、対話的編集などについての簡潔な参考情報にしようと模索しています。

1. [packとIdris2で始めよう](src/Appendices/Install.md)
2. [Neovimでの対話的編集](src/Appendices/Neovim.md)
3. [Idrisのプロジェクトを構築する](src/Appendices/Projects.md)

## 予め必要なもの

現時点でこのプロジェクトは活発に開発中で、Idris 2リポジトリのmainブランチとともに進展し続けています。
GitHubでnightlyにテストされており、[packのパッケージコレクション](https://github.com/stefan-hoeck/idris2-pack-db)の最新版に対してビルドされています。

この入門を読み進めるにあたっては[こちら](src/Appendices/Install.md)に記載されているようにpackパッケージ管理を介してIdrisをインストールすることを強くお勧めします。
