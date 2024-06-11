# Finq

:warning: **This is a work in progress.** _The API for Finq is not yet stable
and is subject to change. Use at your own risk. It is nonetheless being
published to gather feedback and allow for experimentation, both of which should
help shape the final API._

Finq is a library that allows functions to be written using LINQ, as if you
never had [lambda] (`=>`) in C#:

```c#
var f = // : Func<int, int>
    from x in Funq.Arg.Int32()
    select x * 2;

var g = // : Func<int, string>
    from x in f
    select $"{x + 2}";

Console.WriteLine(g(20)); // prints: "42"
```

Note that the function types resulting from using Finq are still the ones you
are familiar with; this is, the type of `f` in the above example is still
`Func<int, int>`, and the type of `g` is `Func<int, string>`. `f` and `g` are
still instantiations of the generic `Fun<,>` and you can therefore think of Finq
as a way to write functions in a more declarative style, using LINQ.

With Finq, you can also use LINQ where a regular function is expected:

```c#
static string Join<T>(string delimiter, IEnumerable<T> xs, Func<T, string> fs) =>
    string.Join(delimiter, from x in xs select fs(x));

var s = Join(Environment.NewLine,
             [1, 2, 3, 4, 5],
             from x in Funq.Arg.Int32()
             select $"{x} => {x * Math.PI:0.0000}");

Console.WriteLine(s);
```

Prints:

    1 => 3.1416
    2 => 6.2832
    3 => 9.4248
    4 => 12.5664
    5 => 15.7080

The LINQ in the above example is equivalent to writing `x => $"{x} => {x *
Math.PI:0.0000}"`, but it reads longer and can run considerably slower so the
goal of Finq is not to offer a replacement. However, it can be useful in some
situations. For example, suppose you have the following function, that takes as
an argument, a [curried] function:

```c#
static T Foo<T>(Func<int, Func<int, T>> f) => f(20)(2);
```

In C# (up to and including version 13 at the time of writing), this function
cannot be called without explicitly specifying the type of `T`. Doing so:

```c#
Console.WriteLine(Foo(x => y => $"{x * 2 + y}")); // compilation error (CS0411)
```

results in compilation error [CS0411]:

> The type arguments for method 'method' cannot be inferred from the usage. Try
> specifying the type arguments explicitly.

The C# compiler is unable to infer that the type of `T` is `int` from the lambda
expression. Instead, you have to write:

```c#
Console.WriteLine(Foo<string>(x => y => $"{x * 2 + y}")); // prints: 42
```

However, with Finq, you can write:

```c#
var f = // : Func<int, Func<int, int>>
    from x in Funq.Arg.Int32()
    select
        from y in Funq.Arg.Int32()
        select x * 2 + y;

Console.WriteLine(Foo(f)); // prints: 42
```

It's also impossible to explicitly specify the type of `T` when the type is
anonymous, but

```c#
var f = // : Func<int, Func<int, ?>>
    from x in Funq.Arg.Int32()
    select
        from y in Funq.Arg.Int32()
        select new
        {
            X = x,
            Y = y,
            Calc = x * 2 + y
        };

Console.WriteLine(Foo(f)); // prints: { X = 20, Y = 2, Calc = 42 }
```

Finq can also come in handy when you want to model functions as a _reader
functor_ and more. For more on this, see the “[The Reader functor]” blog post
by [Mark Seemann] (_aka_ [@ploeh]), and specifically the section “[Raw
functions]”.

Finq's `Funq.Arg` ships with a number of common argument types, such as `Int32`,
`String`, `Double`, `Boolean`, etc. You can add your own to the mix by writing
an extension method for `IArg`.

For ad-hoc specification of the argument type, use `Funq.ArgOf<T>.Return()`:

```c#
var f = // : Func<int, int>
    from x in Funq.ArgOf<int>().Return()
    select x * 2;
```

Finq sticks to functions that take a single argument. If multiple arguments are
needed then use a tuple or, preferably the _[parameter object]_ pattern.

Finq also supports fallible functions via LINQ's `where` clause:

```c#
var positive = // : Func<int, (bool, int)>
    from x in Funq.Arg.Int32()
    where x > 0
    select x; // evaluated only if positive

foreach (var input in new[] { -1, 0, 1 })
{
    var ok = positive.TryInvoke(input, out var result);
    Console.WriteLine($"{nameof(ok)} = {ok}; {nameof(result)} = {result}");
}
```

Prints:

    ok = False; result = 0
    ok = False; result = 0
    ok = True; result = 1

Using `where` changes the function return type from some `T` to the tuple
`(bool, T)`, where the first (Boolean) element of the tuple is `true` if the
second element is valid and `false` otherwise. See [Optuple] for more background
on this pattern.


[lambda]: https://learn.microsoft.com/en-us/dotnet/c#/language-reference/operators/lambda-expressions
[curried]: https://en.wikipedia.org/wiki/Currying
[The Reader functor]: https://blog.ploeh.dk/2021/08/30/the-reader-functor/
[Raw functions]: https://blog.ploeh.dk/2021/08/30/the-reader-functor/#ad9b3abef16c4ec8a70a1263c17eecd6
[Mark Seemann]: https://blog.ploeh.dk/
[@ploeh]: https://github.com/ploeh
[CS0411]: https://learn.microsoft.com/en-us/dotnet/c#/misc/cs0411
[Parameter Object]: https://wiki.c2.com/?ParameterObject
[Optuple]: https://github.com/atifaziz/Optuple
