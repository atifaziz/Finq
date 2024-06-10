// Copyright (c) 2024 Atif Aziz.
// Licensed under the Apache License, Version 2.0 (the "License").
// See "COPYING.txt" file in the project root for full license information.

namespace Finq.Tests;

public class FunqTests
{
    public class ArgOfTests
    {
        [Fact]
        public void Return_Returns_Function_Argument()
        {
            var f = Funq.ArgOf<int>.Return();
            var result = f(42);
            Assert.Equal(42, result);
        }

        [Fact]
        public void Return_Returns_Argument()
        {
            var f = Funq.ArgOf<int>.Return(42);
            var result = f(-42);
            Assert.Equal(42, result);
        }
    }

    [Fact]
    public void Return_Invoked_With_No_Argument_Returns_Given_Value()
    {
        var f = Funq.Return(42);
        var result = f.Invoke();
        Assert.Equal(42, result);
    }

    [Fact]
    public void Monad_Returns_Flattened_Projection()
    {
        var f = from x in Funq.Return(4)
                from y in Funq.Return(x / 2)
                select (x, y);

        var result = f.Invoke();

        Assert.Equal((4, 2), result);
    }

    [Theory]
    [InlineData(-1, 4242)]
    [InlineData(42, 42)]
    [InlineData(-42, -42)]
    [InlineData(-1, -4242)]
    public void Where(int expected, int arg)
    {
        var f = from n in Funq.Arg.Int32()
                where n is 42 or -42
                select n;

        var result = f.Default(-1).Invoke(arg);

        Assert.Equal(expected, result);
    }

    [Fact]
    public void Zip_Returns_Tuple_Of_Sources()
    {
        var arg = Funq.Arg.Int32();
        var a = from x in arg select $"=={x}==";
        var b = from x in arg select $"--{x}--";
        var f = a.Zip(b);

        var result = f(42);

        Assert.Equal(("==42==", "--42--"), result);
    }

    [Fact]
    public void Apply_Returns_Value_Without_Argument()
    {
        var f = Funq.Return(42).Apply();

        Assert.Equal(42, f());
    }

    [Fact]
    public void Apply_Captures_Argument()
    {
        var f = Funq.Arg.Int32().Apply(42);

        Assert.Equal(42, f());
    }

    [Fact]
    public void Cast_Casts_Argument()
    {
        var f = Funq.Arg.Object().Cast<int>();

        Assert.Equal(42, f(42));
    }

    [Fact]
    public void Cast_Throws_InvalidCastException_When_Casting_Fails()
    {
        var f = Funq.Arg.Object().Cast<int>();

        _ = Assert.Throws<InvalidCastException>(() => _ = f(42.0));
    }

    [Theory]
    [InlineData(false, -42)]
    [InlineData(false, 0)]
    [InlineData(true, 42)]
    public void TryInvoke(bool pass, int expected)
    {
        var positive =
            from x in Funq.Arg.Int32()
            where x > 0
            select x;

        var ok = positive.TryInvoke(expected, out var actual);

        Assert.Equal(pass, ok);
        Assert.Equal(pass ? expected : 0, actual);
    }

    [Fact]
    public void Invoke2()
    {
        var f = Funq.ArgOf<(int Int, string Str)>.Return();

        var result = f.Invoke(42, "42");

        Assert.Equal((42, "42"), result);
    }

    [Fact]
    public void Invoke3()
    {
        var f = Funq.ArgOf<(int Int, string Str, DateTime Time)>.Return();

        var time = DateTime.Now;
        var result = f.Invoke(42, "42", time);

        Assert.Equal((42, "42", time), result);
    }
}
