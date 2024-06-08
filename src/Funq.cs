using System;
using System.Diagnostics.CodeAnalysis;
using System.Threading.Tasks;
using Unit = System.ValueTuple;

namespace Finq;

#pragma warning disable CA1034 // Nested types should not be visible (by-design)

#pragma warning disable CA1040 // Avoid empty interfaces (by-design)
public interface IArg;
#pragma warning restore CA1040 // Avoid empty interfaces

public static class Arg
{
#pragma warning disable CA1720 // Identifier contains type name
    public static Func<object, object> Object(this IArg _) => Funq.ArgOf<object>.Return();
    public static Func<byte, byte> Byte(this IArg _) => Funq.ArgOf<byte>.Return();
    public static Func<short, short> Int16(this IArg _) => Funq.ArgOf<short>.Return();
    public static Func<int, int> Int32(this IArg _) => Funq.ArgOf<int>.Return();
    public static Func<long, long> Int64(this IArg _) => Funq.ArgOf<long>.Return();
    public static Func<float, float> Single(this IArg _) => Funq.ArgOf<float>.Return();
    public static Func<double, double> Double(this IArg _) => Funq.ArgOf<double>.Return();
    public static Func<Guid, Guid> Guid(this IArg _) => Funq.ArgOf<Guid>.Return();
    public static Func<DateTime, DateTime> DateTime(this IArg _) => Funq.ArgOf<DateTime>.Return();
    public static Func<DateTimeOffset, DateTimeOffset> DateTimeOffset(this IArg _) => Funq.ArgOf<DateTimeOffset>.Return();
    public static Func<TimeSpan, TimeSpan> TimeSpan(this IArg _) => Funq.ArgOf<TimeSpan>.Return();
    public static Func<string, string> String(this IArg _) => Funq.ArgOf<string>.Return();
    public static Func<Uri, Uri> Uri(this IArg _) => Funq.ArgOf<Uri>.Return();
#pragma warning restore CA1720 // Identifier contains type name
}

public static class Funq
{
    public static readonly IArg Arg = new Argument();

    sealed class Argument : IArg;

    public static class ArgOf<T>
    {
#pragma warning disable CA1000 // Do not declare static members on generic types (by-design)
        public static Func<T, T> Return() => static arg => arg;
        public static Func<T, TResult> Return<TResult>(TResult result) => _ => result;
#pragma warning restore CA1000 // Do not declare static members on generic types
    }

    public static Func<Unit, T> Return<T>(T value) => _ => value;

    public static T Invoke<TArg1, TArg2, T>(this Func<(TArg1, TArg2), T> function,
                                            TArg1 arg1, TArg2 arg2)
    {
        ArgumentNullException.ThrowIfNull(function);

        return function((arg1, arg2));
    }

    public static T Invoke<TArg1, TArg2, TArg3, T>(this Func<(TArg1, TArg2, TArg3), T> function,
                                                   TArg1 arg1, TArg2 arg2, TArg3 arg3)
    {
        ArgumentNullException.ThrowIfNull(function);

        return function((arg1, arg2, arg3));
    }

    public static T Invoke<T>(this Func<Unit, T> function)
    {
        ArgumentNullException.ThrowIfNull(function);

        return function(default);
    }

    public static (bool, T) Invoke<T>(this Func<Unit, (bool, T)> function)
    {
        ArgumentNullException.ThrowIfNull(function);

        return function(default);
    }

    public static T Invoke<T>(this Func<Unit, (bool, T)> function, T @default) =>
        function.Invoke(default, @default);

    public static T Invoke<TArg, T>(this Func<TArg, (bool, T)> function, TArg arg) =>
        function.GetResult()(arg);

    public static T Invoke<TArg, T>(this Func<TArg, (bool, T)> function, TArg arg, T @default) =>
        function.Default(@default)(arg);

    public static bool TryInvoke<TArg, T>(this Func<TArg, (bool, T)> function, TArg arg,
                                          [NotNullWhen(true)] out T? result)
    {
        ArgumentNullException.ThrowIfNull(function);

        (var hasValue, result) = function(arg);
        return hasValue;
    }

    public static Func<TArg, T> Default<TArg, T>(this Func<TArg, (bool, T)> function, T value) =>
        function.Match(some => some, value);

    public static Func<TArg, T> GetResult<TArg, T>(this Func<TArg, (bool, T)> function) =>
        function.Match(some => some, () => throw new InvalidOperationException());

    public static Func<TArg, TResult> Match<TArg, T, TResult>(this Func<TArg, (bool, T)> function,
                                                              Func<T, TResult> whenSome,
                                                              TResult none) =>
        function.Match(whenSome, () => none);

    public static Func<TArg, TResult> Match<TArg, T, TResult>(this Func<TArg, (bool, T)> function,
                                                              Func<T, TResult> whenSome,
                                                              Func<TResult> whenNone)
    {
        ArgumentNullException.ThrowIfNull(function);

        return arg => function(arg) is (true, var some) ? whenSome(some) : whenNone();
    }

    public static Func<TArg, TResult> Select<TArg, T, TResult>(this Func<TArg, T> func, Func<T, TResult> selector)
    {
        ArgumentNullException.ThrowIfNull(func);
        ArgumentNullException.ThrowIfNull(selector);

        return arg => selector(func(arg));
    }

    public static Func<TArg, Task<TResult>> Select<TArg, T, TResult>(this Func<TArg, Task<T>> func, Func<T, TResult> selector)
    {
        ArgumentNullException.ThrowIfNull(func);
        ArgumentNullException.ThrowIfNull(selector);

        return async arg => selector(await func(arg).ConfigureAwait(false));
    }

    public static Func<T> Apply<T>(this Func<Unit, T> func)
    {
        ArgumentNullException.ThrowIfNull(func);

        return () => func(default);
    }

    public static Func<T> Apply<TArg, T>(this Func<TArg, T> func, TArg arg)
    {
        ArgumentNullException.ThrowIfNull(func);

        return () => func(arg);
    }

    public static Action Ignore<T>(this Func<T> func)
    {
        ArgumentNullException.ThrowIfNull(func);

        return () => _ = func();
    }

    public static Func<TArg, object?> AsObject<TArg, T>(this Func<TArg, T> func)
    {
        ArgumentNullException.ThrowIfNull(func);

        return arg => func(arg);
    }

    public static Func<object, T> Cast<T>(this Func<object, object> func) where T : notnull
    {
        ArgumentNullException.ThrowIfNull(func);

        return arg => (T)func(arg);
    }

    public static Func<TArg, (bool, TResult)>
        Select<TArg, T, TResult>(this Func<TArg, (bool, T)> func, Func<T, TResult> selector)
    {
        ArgumentNullException.ThrowIfNull(func);
        ArgumentNullException.ThrowIfNull(selector);

        return arg => func(arg) is (true, var some) ? (true, selector(some)) : default;
    }

    public static Func<TArg, (bool, T)> Where<TArg, T>(this Func<TArg, T> func, Func<T, bool> predicate)
    {
        ArgumentNullException.ThrowIfNull(func);
        ArgumentNullException.ThrowIfNull(predicate);

        return arg => func(arg) is var some && predicate(some) ? (true, some) : default;
    }

    public static Func<TArg, TResult>
        SelectMany<TArg, TFirst, TSecond, TResult>(this Func<TArg, TFirst> first,
                                                   Func<TFirst, Func<TArg, TSecond>> second,
                                                   Func<TFirst, TSecond, TResult> resultSelector)
    {
        ArgumentNullException.ThrowIfNull(first);
        ArgumentNullException.ThrowIfNull(second);
        ArgumentNullException.ThrowIfNull(resultSelector);

        return arg =>
        {
            var a = first(arg);
            return resultSelector(a, second(a)(arg));
        };
    }

    public static Func<TArg, (TFirst First, TSecond Second)>
        Zip<TArg, TFirst, TSecond>(this Func<TArg, TFirst> first, Func<TArg, TSecond> second)
    {
        ArgumentNullException.ThrowIfNull(first);
        ArgumentNullException.ThrowIfNull(second);

        return arg => (first(arg), second(arg));
    }
}
