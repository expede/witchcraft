import TypeClass

defclass Witchcraft.Apply do
  @moduledoc """
  An extension of `Witchcraft.Functor`, `Apply` provides a way to _apply_ arguments
  to functions when both are wrapped in the same kind of container. This can be
  seen as running function application "in a context".

  For a nice, illustrated introduction,
  see [Functors, Applicatives, And Monads In Pictures](http://adit.io/posts/2013-04-17-functors,_applicatives,_and_monads_in_pictures.html).

  ## Graphically

  If function application looks like this

      data |> function == result

  and a functor looks like this

      %Container<data> ~> function == %Container<result>

  then an apply looks like

      %Container<data> ~>> %Container<function> == %Container<result>

  which is similar to function application inside containers, plus the ability to
  attach special effects to applications.

                 data --------------- function ---------------> result
      %Container<data> --- %Container<function> ---> %Container<result>

  This lets us do functorial things like

  * continue applying values to a curried function resulting from a `Witchcraft.Functor.lift/2`
  * apply multiple functions to multiple arguments (with lists)
  * propogate some state (like [`Nothing`](https://hexdocs.pm/algae/Algae.Maybe.Nothing.html#content)
  in [`Algae.Maybe`](https://hexdocs.pm/algae/Algae.Maybe.html#content))

  but now with a much larger number of arguments, reuse partially applied functions,
  and run effects with the function container as well as the data container.

  ## Examples

      iex> ap([fn x -> x + 1 end, fn y -> y * 10 end], [1, 2, 3])
      [2, 3, 4, 10, 20, 30]

      iex> [100, 200]
      ...> |> Witchcraft.Functor.lift(fn(x, y, z) -> x * y / z end)
      ...> |> provide([5, 2])
      ...> |> provide([100, 50])
      [5.0, 10.0, 2.0, 4.0, 10.0, 20.0, 4.0, 8.0]
      # ↓                          ↓
      # 100 * 5 / 100          200 * 5 / 50

      iex> import Witchcraft.Functor
      ...>
      ...> [100, 200]
      ...> ~> fn(x, y, z) ->
      ...>   x * y / z
      ...> end <<~ [5, 2]
      ...>     <<~ [100, 50]
      [5.0, 10.0, 2.0, 4.0, 10.0, 20.0, 4.0, 8.0]
      # ↓                          ↓
      # 100 * 5 / 100          200 * 5 / 50

      %Algae.Maybe.Just{just: 42}
      ~> fn(x, y, z) ->
        x * y / z
      end <<~ %Algae.Maybe.Nothing{}
          <<~ %Algae.Maybe.Just{just: 99}
      #=> %Algae.Maybe.Nothing{}

  ## `convey` vs `ap`

  `convey` and `ap` essentially associate in opposite directions. For example,
  large data is _usually_ more efficient with `ap`, and large numbers of
  functions are _usually_ more efficient with `convey`.

  It's also more consistent consistency. In Elixir, we like to think of a "subject"
  being piped through a series of transformations. This places the function argument
  as the second argument. In `Witchcraft.Functor`, this was of little consequence.
  However, in `Apply`, we're essentially running superpowered function application.
  `ap` is short for `apply`, as to not conflict with `Kernel.apply/2`, and is meant
  to respect a similar API, with the function as the first argument. This also reads
  nicely when piped, as it becomes `[funs] |> ap([args1]) |> ap([args2])`,
  which is similar in structure to `fun.(arg2).(arg1)`.

  With potentially multiple functions being applied over potentially
  many arguments, we need to worry about ordering. `convey` not only flips
  the order of arguments, but also who is in control of ordering.
  `convey` typically runs each function over all arguments (`first_fun ⬸ all_args`),
  and `ap` runs all functions for each element (`first_arg ⬸ all_funs`).
  This may change the order of results, and is a feature, not a bug.

      iex> [1, 2, 3]
      ...> |> convey([&(&1 + 1), &(&1 * 10)])
      [
        2, 10, # [(1 + 1), (1 * 10)]
        3, 20, # [(2 + 1), (2 * 10)]
        4, 30  # [(3 + 1), (3 * 10)]
      ]

      iex> [&(&1 + 1), &(&1 * 10)]
      ...> |> ap([1, 2, 3])
      [
        2,  3,  4, # [(1 + 1),  (2 + 1),  (3 + 1)]
        10, 20, 30 # [(1 * 10), (2 * 10), (3 * 10)]
      ]

  ## Type Class

  An instance of `Witchcraft.Apply` must also implement `Witchcraft.Functor`,
  and define `Witchcraft.Apply.convey/2`.

      Functor  [map/2]
         ↓
       Apply   [convey/2]
  """

  alias __MODULE__
  use Quark

  alias Witchcraft.Functor
  extend Witchcraft.Functor
  use Witchcraft.Functor

  @type t :: any()
  @type fun :: any()

  defmacro __using__(opts \\ []) do
    quote do
      use Witchcraft.Functor, unquote(opts)
      import unquote(__MODULE__), unquote(opts)
    end
  end

  where do
    @doc """
    Pipe arguments to functions, when both are wrapped in the same
    type of data structure.

    ## Examples

        iex> [1, 2, 3]
        ...> |> convey([fn x -> x + 1 end, fn y -> y * 10 end])
        [2, 10, 3, 20, 4, 30]

    """
    @spec convey(Apply.t(), Apply.fun()) :: Apply.t()
    def convey(wrapped_args, wrapped_funs)
  end

  properties do
    def composition(data) do
      alias Witchcraft.Functor
      use Quark

      as = data |> generate() |> Functor.map(&inspect/1)
      fs = data |> generate() |> Functor.replace(fn x -> x <> x end)
      gs = data |> generate() |> Functor.replace(fn y -> y <> "foo" end)

      left = Apply.convey(Apply.convey(as, gs), fs)

      right =
        fs
        |> Functor.lift(&compose/2)
        |> (fn x -> Apply.convey(gs, x) end).()
        |> (fn y -> Apply.convey(as, y) end).()

      equal?(left, right)
    end
  end

  @doc """
  Alias for `convey/2`.

  Why "hose"?

  * Pipes (`|>`) are application with arguments flipped
  * `ap/2` is like function application "in a context"
  * The opposite of `ap` is a contextual pipe
  * `hose`s are a kind of flexible pipe

  Q.E.D.

  ![](http://s2.quickmeme.com/img/fd/fd0baf5ada879021c32129fc7dea679bd7666e708df8ca8ca536da601ea3d29e.jpg)

  ## Examples

      iex> [1, 2, 3]
      ...> |> hose([fn x -> x + 1 end, fn y -> y * 10 end])
      [2, 10, 3, 20, 4, 30]

  """
  @spec hose(Apply.t(), Apply.fun()) :: Apply.t()
  def hose(wrapped_args, wrapped_funs), do: convey(wrapped_args, wrapped_funs)

  @doc """
  Reverse arguments and sequencing of `convey/2`.

  Conceptually this makes operations happen in
  a different order than `convey/2`, with the left-side arguments (functions) being
  run on all right-side arguments, in that order. We're altering the _sequencing_
  of function applications.

  ## Examples

      iex> ap([fn x -> x + 1 end, fn y -> y * 10 end], [1, 2, 3])
      [2, 3, 4, 10, 20, 30]

      # For comparison
      iex> convey([1, 2, 3], [fn x -> x + 1 end, fn y -> y * 10 end])
      [2, 10, 3, 20, 4, 30]

      iex> [100, 200]
      ...> |> Witchcraft.Functor.lift(fn(x, y, z) -> x * y / z end)
      ...> |> ap([5, 2])
      ...> |> ap([100, 50])
      [5.0, 10.0, 2.0, 4.0, 10.0, 20.0, 4.0, 8.0]
      # ↓                          ↓
      # 100 * 5 / 100          200 * 5 / 50

  """
  @spec ap(Apply.fun(), Apply.t()) :: Apply.t()
  def ap(wrapped_funs, wrapped) do
    lift(wrapped, wrapped_funs, fn arg, fun -> fun.(arg) end)
  end

  @doc """
  Async version of `convey/2`

  ## Examples

      iex> [1, 2, 3]
      ...> |> async_convey([fn x -> x + 1 end, fn y -> y * 10 end])
      [2, 10, 3, 20, 4, 30]

      0..10_000
      |> Enum.to_list()
      |> async_convey([
        fn x ->
          Process.sleep(500)
          x + 1
        end,
        fn y ->
          Process.sleep(500)
          y * 10
        end
      ])
      #=> [1, 0, 2, 10, 3, 30, ...] in around a second

  """
  @spec async_convey(Apply.t(), Apply.fun()) :: Apply.t()
  def async_convey(wrapped_args, wrapped_funs) do
    wrapped_args
    |> convey(
      lift(wrapped_funs, fn fun, arg ->
        Task.async(fn ->
          fun.(arg)
        end)
      end)
    )
    |> map(&Task.await/1)
  end

  @doc """
  Async version of `ap/2`

  ## Examples

      iex> [fn x -> x + 1 end, fn y -> y * 10 end]
      ...> |> async_ap([1, 2, 3])
      [2, 3, 4, 10, 20, 30]

      [
        fn x ->
          Process.sleep(500)
          x + 1
        end,
        fn y ->
          Process.sleep(500)
          y * 10
        end
      ]
      |> async_ap(Enum.to_list(0..10_000))
      #=> [1, 2, 3, 4, ...] in around a second

  """
  @spec async_ap(Apply.fun(), Apply.t()) :: Apply.t()
  def async_ap(wrapped_funs, wrapped_args) do
    wrapped_funs
    |> lift(fn fun, arg ->
      Task.async(fn ->
        fun.(arg)
      end)
    end)
    |> ap(wrapped_args)
    |> map(&Task.await/1)
  end

  @doc """
  Operator alias for `ap/2`

  Moves against the pipe direction, but in the order of normal function application

  ## Examples

      iex> [fn x -> x + 1 end, fn y -> y * 10 end] <<~ [1, 2, 3]
      [2, 3, 4, 10, 20, 30]

      iex> import Witchcraft.Functor
      ...>
      ...> [100, 200]
      ...> ~> fn(x, y, z) -> x * y / z
      ...> end <<~ [5, 2]
      ...>     <<~ [100, 50]
      ...> ~> fn x -> x + 1 end
      [6.0, 11.0, 3.0, 5.0, 11.0, 21.0, 5.0, 9.0]

      iex> import Witchcraft.Functor, only: [<~: 2]
      ...> fn(a, b, c, d) -> a * b - c + d end <~ [1, 2] <<~ [3, 4] <<~ [5, 6] <<~ [7, 8]
      [5, 6, 4, 5, 6, 7, 5, 6, 8, 9, 7, 8, 10, 11, 9, 10]

  """
  defalias wrapped_funs <<~ wrapped, as: :provide

  @doc """
  Operator alias for `reverse_ap/2`, moving in the pipe direction

  ## Examples

      iex> [1, 2, 3] ~>> [fn x -> x + 1 end, fn y -> y * 10 end]
      [2, 10, 3, 20, 4, 30]

      iex> import Witchcraft.Functor
      ...>
      ...> [100, 50]
      ...> ~>> ([5, 2]     # Note the bracket
      ...> ~>> ([100, 200] # on both `Apply` lines
      ...> ~> fn(x, y, z) -> x * y / z end))
      [5.0, 10.0, 2.0, 4.0, 10.0, 20.0, 4.0, 8.0]

  """
  defalias wrapped ~>> wrapped_funs, as: :supply

  @doc """
  Same as `convey/2`, but with all functions curried.

  ## Examples

      iex> [1, 2, 3]
      ...> |> supply([fn x -> x + 1 end, fn y -> y * 10 end])
      [2, 10, 3, 20, 4, 30]

  """
  @spec supply(Apply.t(), Apply.fun()) :: Apply.t()
  def supply(args, funs), do: convey(args, Functor.map(funs, &curry/1))

  @doc """
  Same as `ap/2`, but with all functions curried.

  ## Examples

      iex> [&+/2, &*/2]
      ...> |> provide([1, 2, 3])
      ...> |> ap([4, 5, 6])
      [5, 6, 7, 6, 7, 8, 7, 8, 9, 4, 5, 6, 8, 10, 12, 12, 15, 18]

  """
  @spec provide(Apply.fun(), Apply.t()) :: Apply.t()
  def provide(funs, args), do: funs |> Functor.map(&curry/1) |> ap(args)

  @doc """
  Sequence actions, replacing the first/previous values with the last argument

  This is essentially a sequence of actions forgetting the first argument

  ## Examples

      iex> [1, 2, 3]
      ...> |> Witchcraft.Apply.then([4, 5, 6])
      ...> |> Witchcraft.Apply.then([7, 8, 9])
      [
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9,
        7, 8, 9
      ]

      iex> {1, 2, 3} |> Witchcraft.Apply.then({4, 5, 6}) |> Witchcraft.Apply.then({7, 8, 9})
      {12, 15, 9}

  """
  @spec then(Apply.t(), Apply.t()) :: Apply.t()
  def then(wrapped_a, wrapped_b), do: over(&Quark.constant(&2, &1), wrapped_a, wrapped_b)

  @doc """
  Sequence actions, replacing the last argument with the first argument's values

  This is essentially a sequence of actions forgetting the second argument

  ## Examples

      iex> [1, 2, 3]
      ...> |> following([3, 4, 5])
      ...> |> following([5, 6, 7])
      [
        1, 1, 1, 1, 1, 1, 1, 1, 1,
        2, 2, 2, 2, 2, 2, 2, 2, 2,
        3, 3, 3, 3, 3, 3, 3, 3, 3
      ]

      iex> {1, 2, 3} |> following({4, 5, 6}) |> following({7, 8, 9})
      {12, 15, 3}

  """
  @spec following(Apply.t(), Apply.t()) :: Apply.t()
  def following(wrapped_a, wrapped_b), do: lift(wrapped_b, wrapped_a, &Quark.constant(&2, &1))

  @doc """
  Extends `Functor.lift/2` to apply arguments to a binary function

  ## Examples

      iex> lift([1, 2], [3, 4], &+/2)
      [4, 5, 5, 6]

      iex> [1, 2]
      ...> |> lift([3, 4], &*/2)
      [3, 6, 4, 8]

  """
  @spec lift(Apply.t(), Apply.t(), fun()) :: Apply.t()
  def lift(a, b, fun) do
    a
    |> lift(fun)
    |> (fn f -> convey(b, f) end).()
  end

  @doc """
  Extends `lift` to apply arguments to a ternary function

  ## Examples

      iex> lift([1, 2], [3, 4], [5, 6], fn(a, b, c) -> a * b - c end)
      [-2, -3, 1, 0, -1, -2, 3, 2]

  """
  @spec lift(Apply.t(), Apply.t(), Apply.t(), fun()) :: Apply.t()
  def lift(a, b, c, fun), do: a |> lift(b, fun) |> ap(c)

  @doc """
  Extends `lift` to apply arguments to a quaternary function

  ## Examples

      iex> lift([1, 2], [3, 4], [5, 6], [7, 8], fn(a, b, c, d) -> a * b - c + d end)
      [5, 6, 4, 5, 8, 9, 7, 8, 6, 7, 5, 6, 10, 11, 9, 10]

  """
  @spec lift(Apply.t(), Apply.t(), Apply.t(), Apply.t(), fun()) :: Apply.t()
  def lift(a, b, c, d, fun), do: a |> lift(b, c, fun) |> ap(d)

  @doc """
  Extends `Functor.async_lift/2` to apply arguments to a binary function

  ## Examples

      iex> async_lift([1, 2], [3, 4], &+/2)
      [4, 5, 5, 6]

      iex> [1, 2]
      ...> |> async_lift([3, 4], &*/2)
      [3, 6, 4, 8]

  """
  @spec async_lift(Apply.t(), Apply.t(), fun()) :: Apply.t()
  def async_lift(a, b, fun) do
    a
    |> async_lift(fun)
    |> (fn f -> async_convey(b, f) end).()
  end

  @doc """
  Extends `async_lift` to apply arguments to a ternary function

  ## Examples

      iex> async_lift([1, 2], [3, 4], [5, 6], fn(a, b, c) -> a * b - c end)
      [-2, -3, 1, 0, -1, -2, 3, 2]

  """
  @spec async_lift(Apply.t(), Apply.t(), Apply.t(), fun()) :: Apply.t()
  def async_lift(a, b, c, fun), do: a |> async_lift(b, fun) |> async_ap(c)

  @doc """
  Extends `async_lift` to apply arguments to a quaternary function

  ## Examples

      iex> async_lift([1, 2], [3, 4], [5, 6], [7, 8], fn(a, b, c, d) -> a * b - c + d end)
      [5, 6, 4, 5, 8, 9, 7, 8, 6, 7, 5, 6, 10, 11, 9, 10]

  """
  @spec async_lift(Apply.t(), Apply.t(), Apply.t(), Apply.t(), fun()) :: Apply.t()
  def async_lift(a, b, c, d, fun), do: a |> async_lift(b, c, fun) |> async_ap(d)

  @doc """
  Extends `over` to apply arguments to a binary function

  ## Examples

      iex> over(&+/2, [1, 2], [3, 4])
      [4, 5, 5, 6]

      iex> (&*/2)
      ...> |> over([1, 2], [3, 4])
      [3, 4, 6, 8]

  """
  @spec over(fun(), Apply.t(), Apply.t()) :: Apply.t()
  def over(fun, a, b), do: a |> lift(fun) |> ap(b)

  @doc """
  Extends `over` to apply arguments to a ternary function

  ## Examples

      iex> fn(a, b, c) -> a * b - c end
      iex> |> over([1, 2], [3, 4], [5, 6])
      [-2, -3, -1, -2, 1, 0, 3, 2]

  """
  @spec over(fun(), Apply.t(), Apply.t(), Apply.t()) :: Apply.t()
  def over(fun, a, b, c), do: fun |> over(a, b) |> ap(c)

  @doc """
  Extends `over` to apply arguments to a ternary function

  ## Examples

      iex> fn(a, b, c) -> a * b - c end
      ...> |> over([1, 2], [3, 4], [5, 6])
      [-2, -3, -1, -2, 1, 0, 3, 2]

  """
  @spec over(fun(), Apply.t(), Apply.t(), Apply.t()) :: Apply.t()
  def over(fun, a, b, c, d), do: fun |> over(a, b, c) |> ap(d)

  @doc """
  Extends `async_over` to apply arguments to a binary function

  ## Examples

      iex> async_over(&+/2, [1, 2], [3, 4])
      [4, 5, 5, 6]

      iex> (&*/2)
      ...> |> async_over([1, 2], [3, 4])
      [3, 4, 6, 8]

  """
  @spec async_over(fun(), Apply.t(), Apply.t()) :: Apply.t()
  def async_over(fun, a, b), do: a |> lift(fun) |> async_ap(b)

  @doc """
  Extends `async_over` to apply arguments to a ternary function

  ## Examples

      iex> fn(a, b, c) -> a * b - c end
      iex> |> async_over([1, 2], [3, 4], [5, 6])
      [-2, -3, -1, -2, 1, 0, 3, 2]

  """
  @spec async_over(fun(), Apply.t(), Apply.t(), Apply.t()) :: Apply.t()
  def async_over(fun, a, b, c), do: fun |> async_over(a, b) |> async_ap(c)

  @doc """
  Extends `async_over` to apply arguments to a ternary function

  ## Examples

      iex> fn(a, b, c) -> a * b - c end
      ...> |> async_over([1, 2], [3, 4], [5, 6])
      [-2, -3, -1, -2, 1, 0, 3, 2]

  """
  @spec async_over(fun(), Apply.t(), Apply.t(), Apply.t()) :: Apply.t()
  def async_over(fun, a, b, c, d), do: fun |> async_over(a, b, c) |> async_ap(d)
end

definst Witchcraft.Apply, for: Function do
  use Quark
  def convey(g, f), do: fn x -> curry(f).(x).(curry(g).(x)) end
end

definst Witchcraft.Apply, for: List do
  def convey(val_list, fun_list) when is_list(fun_list) do
    Enum.flat_map(val_list, fn val ->
      Enum.map(fun_list, fn fun -> fun.(val) end)
    end)
  end
end

# Contents must be semigroups
definst Witchcraft.Apply, for: Tuple do
  import TypeClass.Property.Generator, only: [generate: 1]
  use Witchcraft.Semigroup

  custom_generator(_) do
    {generate(""), generate(1), generate(0), generate(""), generate(""), generate("")}
  end

  def convey({v, w}, {a, fun}), do: {v <> a, fun.(w)}
  def convey({v, w, x}, {a, b, fun}), do: {v <> a, w <> b, fun.(x)}
  def convey({v, w, x, y}, {a, b, c, fun}), do: {v <> a, w <> b, x <> c, fun.(y)}

  def convey({v, w, x, y, z}, {a, b, c, d, fun}) do
    {
      a <> v,
      b <> w,
      c <> x,
      d <> y,
      fun.(z)
    }
  end

  def convey(tuple_a, tuple_b) when tuple_size(tuple_a) == tuple_size(tuple_b) do
    last_index = tuple_size(tuple_a) - 1

    tuple_a
    |> Tuple.to_list()
    |> Enum.zip(Tuple.to_list(tuple_b))
    |> Enum.with_index()
    |> Enum.map(fn
      {{arg, fun}, ^last_index} -> fun.(arg)
      {{left, right}, _} -> left <> right
    end)
    |> List.to_tuple()
  end
end
