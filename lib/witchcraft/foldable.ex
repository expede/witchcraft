import TypeClass

defclass Witchcraft.Foldable do
  @moduledoc """
  Data that can be folded over to change its structure by altering or combining elements.

  Unlike `Witchcraft.Functors`s, the end result will not respect the original structure
  unless you build it back up manually.

  ## Examples

      iex> right_fold([1, 2, 3], 0, &+/2) # sum
      6

  ## Properties

  People are working on Foldable properties. This is one of the exceptions to
  there needing to conform to properties. In the meantime, we are testing that
  naturality is preserved, which is be a free theorm.

  If that fails, something is very wrong with the instance.

  ## Type Class

  An instance of `Witchcraft.Foldable` define `Witchcraft.Foldable.right_fold/3`.

      Foldable   [right_fold/3]
  """

  alias __MODULE__
  alias Witchcraft.{Apply, Ord, Monad, Monoid, Semigroup, Unit}

  import Kernel, except: [length: 1, max: 2, min: 2, then: 2]
  import Exceptional.Safe, only: [safe: 1]

  require Foldable.EmptyError

  use Witchcraft.Applicative
  use Quark

  @type t :: any()

  defmacro __using__(opts \\ []) do
    {:ok, new_opts} =
      Keyword.get_and_update(opts, :except, fn except ->
        {:ok, [length: 1, max: 2, min: 2] ++ (except || [])}
      end)

    if Access.get(opts, :override_kernel, true) do
      quote do
        use Witchcraft.Semigroup, unquote(opts)
        use Witchcraft.Ord, unquote(opts)

        import Kernel, unquote(new_opts)
        import unquote(__MODULE__), unquote(opts)
      end
    else
      quote do
        use Witchcraft.Semigroup, unquote(opts)
        use Witchcraft.Ord, unquote(opts)

        import unquote(__MODULE__), unquote(new_opts)
      end
    end
  end

  where do
    @doc ~S"""
    Right-associative fold over a structure to alter the structure and/or reduce
    it to a single summary value. The right-association makes it possible to
    cease computation on infinite streams of data.

    The folder must be a binary function, with the second argument being the
    accumulated value thus far.

    ## Examples

        iex> sum = fn xs -> right_fold(xs, 0, &+/2) end
        ...> sum.([1, 2, 3])
        6
        ...> sum.([4, 5, 6])
        15

    """
    @spec right_fold(Foldable.t(), any(), (any(), any() -> any())) :: any()
    def right_fold(foldable, seed, folder)
  end

  properties do
    # Free theorm
    def naturality(data) do
      foldable = generate(data)
      seed = "seed"

      f = &Quark.constant/2
      g = &Quark.id/1

      left =
        foldable
        |> Witchcraft.Foldable.right_fold(seed, f)
        |> g.()

      right =
        foldable
        |> g.()
        |> Witchcraft.Foldable.right_fold(seed, fn x, acc -> f.(g.(x), acc) end)

      equal?(left, right)
    end
  end

  @doc ~S"""
  The same as `right_fold/3`, but uses the first element as the seed

  ## Examples

      iex> right_fold([1, 2, 3], &+/2)
      6

      iex> right_fold([100, 2, 5], &//2)
      40.0 # (2 / (5 / 100))

      iex> right_fold([[], 1, 2, 3], fn(x, acc) -> [x | acc] end)
      [1, 2, 3]

  """
  @spec right_fold(Foldable.t(), fun()) :: any()
  def right_fold(foldable, folder) do
    case to_list(foldable) do
      [] -> []
      [a | as] -> right_fold(as, a, folder)
    end
  end

  @doc ~S"""
  Left-associative fold over a structure to alter the structure and/or reduce
  it to a single summary value.

  The folder must be a binary function, with the second argument being the
  accumulated value thus far.

  ## Examples

      iex> sum = fn xs -> right_fold(xs, 0, &+/2) end
      ...> sum.([1, 2, 3])
      6
      ...> sum.([4, 5, 6])
      15

      iex> left_fold([1, 2, 3], [], fn(acc, x) -> [x | acc] end)
      [3, 2, 1]

      iex> left_fold({1, 2, 3}, [], fn(acc, x) -> [x | acc] end)
      [3]

      iex> left_fold([1, 2, 3], [4, 5, 6], fn(acc, x) -> [x | acc] end)
      [3, 2, 1, 4, 5, 6]

  Note the reducer argument order versus `right_fold/3`

      iex> right_fold([1, 2, 3], [], fn(acc, x) -> [acc | x] end)
      [1, 2, 3]

      iex> left_fold([1, 2, 3], [], fn(acc, x) -> [acc | x] end)
      [[[[] | 1] | 2] | 3]

  """
  @spec left_fold(Foldable.t(), any(), (any(), any() -> any())) :: any()
  def left_fold(foldable, seed, folder) do
    right_fold(foldable, &Quark.id/1, fn b, g ->
      fn x ->
        x
        |> folder.(b)
        |> g.()
      end
    end).(seed)
  end

  @doc ~S"""
  The same as `left_fold/3`, but uses the first element as the seed

  ## Examples

      iex> left_fold([1, 2, 3], &+/2)
      6

      iex> left_fold([100, 2, 5], &//2)
      10.0 # ((100 / 2) / 5)

      iex> left_fold([1, 2, 3], [], fn(acc, x) -> [x | acc] end)
      [3, 2, 1]

  Note the reducer argument order versus `right_fold/2`

      iex> right_fold([100, 20, 10], &//2)
      200.0

      iex> left_fold([100, 20, 10], &//2)
      0.5

  """
  @spec left_fold(Foldable.t(), (any(), any() -> any())) :: any()
  def left_fold(foldable, folder) do
    [x | xs] = to_list(foldable)
    left_fold(xs, x, folder)
  end

  @doc """
  Combine all elements using monoidal append

  ## Examples

      iex> fold([1, 2, 3])
      6

      iex> fold([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      [1, 2, 3, 4, 5, 6, 7, 8, 9]

  """
  @spec fold(Foldable.t()) :: any()
  def fold(foldable), do: left_fold(foldable, &Semigroup.append/2)

  @doc """
  Map a functional over all elements and `fold` them together

  ## Examples

      iex> fold_map([1, 2, 3], fn x -> [x, x * 10] end)
      [1, 10, 2, 20, 3, 30]

      iex> fold_map([[1, 2, 3], [4, 5, 6], [7, 8, 9]], fn x -> [x, x] end)
      [
        [1, 2, 3], [1, 2, 3],
        [4, 5, 6], [4, 5, 6],
        [7, 8, 9], [7, 8, 9]
      ]

  """
  @spec fold_map(Foldable.t(), fun()) :: any()
  def fold_map(foldable, fun) do
    right_fold(foldable, Monoid.empty(foldable), fn element, acc ->
      element
      |> fun.()
      |> Semigroup.append(acc)
    end)
  end

  @doc """
  Turn any `Foldable` into a `List`

  ## Example

      iex> to_list({1, 2, 3})
      [1, 2, 3]

      iex> to_list(%{a: 1, b: 2, c: 3})
      [1, 2, 3]

  """
  @spec to_list(Foldable.t()) :: [any()]
  def to_list(list) when is_list(list), do: list
  def to_list(tuple) when is_tuple(tuple), do: Tuple.to_list(tuple)
  def to_list(string) when is_bitstring(string), do: String.to_charlist(string)
  def to_list(foldable), do: right_fold(foldable, [], fn x, acc -> [x | acc] end)

  @doc """
  Check if a foldable data structure is empty

  ## Examples

      iex> empty?("")
      true

      iex> empty?("hi")
      false

      iex> empty?(%{})
      true

  """
  @spec empty?(Foldable.t()) :: boolean
  def empty?(foldable), do: right_fold(foldable, true, fn _focus, _acc -> false end)

  @doc """
  Count the number of elements in a foldable structure

  ## Examples

      iex> use Witchcraft.Foldable
      ...> length(%{})
      0
      iex> length(%{a: 1, b: 2})
      2
      iex> length("ࠀabc")
      4

  """
  @spec length(Foldable.t()) :: non_neg_integer()
  def length(list) when is_list(list), do: Kernel.length(list)
  def length(foldable), do: right_fold(foldable, 0, fn _, acc -> 1 + acc end)

  defalias count(foldable), as: :length
  defalias size(foldable), as: :length

  @doc """
  Check if a foldable structure contains a particular element

  ## Examples

      iex> member?([1, 2, 3], 2)
      true

      iex> member?([1, 2, 3], 99)
      false

      iex> member?(%{a: 1, b: 2}, 2)
      true

      iex> member?(%{a: 1, b: 2}, 99)
      false

  """
  @spec member?(Foldable.t(), any()) :: boolean()
  def member?(list, target) when is_list(list), do: Enum.member?(list, target)
  def member?(map, target) when is_map(map), do: map |> Map.values() |> Enum.member?(target)

  def member?(tuple, target) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.member?(target)
  end

  def member?(string, target) when is_bitstring(string) do
    string
    |> String.to_charlist()
    |> Enum.member?(target)
  end

  def member?(foldable, target) do
    right_fold(foldable, false, fn focus, acc -> acc or focus == target end)
  end

  @doc """
  Find the maximum element in a foldable structure using a custom comparitor

  Elements must implement `Witchcraft.Ord`.

  Comes in both a safe and unsafe(`!`) version

  ## Examples

      iex> use Witchcraft.Foldable
      ...> [1, 2, 7]
      ...> |> max(by: fn(x, y) ->
      ...>   x
      ...>   |> Integer.mod(3)
      ...>   |> Witchcraft.Ord.compare(Integer.mod(y, 3))
      ...> end)
      2

  """
  @spec max(Foldable.t(), by: (any, any -> Order.ordering())) :: Ord.t()
  def max(foldable, by: comparator) do
    Witchcraft.Foldable.right_fold(foldable, fn focus, acc ->
      case comparator.(focus, acc) do
        :greater -> focus
        _ -> acc
      end
    end)
  end

  @doc """
  Find the maximum element in a foldable structure using the default ordering
  from `Witchcraft.Ord`.

  Elements must implement `Witchcraft.Ord`.

  ## Examples

      iex> use Witchcraft.Foldable
      ...> max([2, 3, 1])
      3
      ...> max([[4], [1, 2, 3, 4]])
      [4]

      %BinaryTree{
        node: 1,
        left: %BinaryTree{
          node: 3
          left: 4
        },
        right: 2
      }
      |> max()
      #=> 4

  """
  @spec max(Foldable.t()) :: Ord.t()
  def max(foldable_comparable), do: max(foldable_comparable, by: &Ord.compare/2)

  @doc """
  Find the maximum element in a foldable structure using a custom comparitor

  Elements must implement `Witchcraft.Ord`.

  Comes in both a safe and unsafe(`!`) version

  ## Examples

      iex> use Witchcraft.Foldable
      ...> [8, 2, 1]
      ...> |> min(by: fn(x, y) ->
      ...>   x
      ...>   |> Integer.mod(4)
      ...>   |> Witchcraft.Ord.compare(Integer.mod(y, 4))
      ...> end)
      8

  """
  @spec min(Foldable.t(), by: (any(), any() -> Order.t())) :: any() | Maybe.t()
  def min(foldable, by: comparitor) do
    right_fold(foldable, fn focus, acc ->
      case comparitor.(focus, acc) do
        :lesser -> focus
        _ -> acc
      end
    end)
  end

  @doc """
  Find the minimum element in a foldable structure using the default ordering
  from `Witchcraft.Ord`.

  Elements must implement `Witchcraft.Ord`.

  ## Examples

      iex> use Witchcraft.Foldable
      ...> min([2, 3, 1])
      1
      ...> min([[4], [1, 2, 3, 4]])
      [1, 2, 3, 4]

      %BinaryTree{
        node: 4,
        left: %BinaryTree{
          node: 3
          left: 1
        },
        right: 2
      }
      |> min()
      #=> 1

  """
  def min(foldable), do: min(foldable, by: &Ord.compare/2)

  @doc """
  Get a random element from a foldable structure.

  ## Examples

      random([1, 2, 3])
      #=> 1

      random([1, 2, 3])
      #=> 3

      random(%BinaryTree{left: %Empty{}, node: 2, right: %BinaryTree{node: 1}})
      1

  """
  @spec random(Foldable.t()) :: any() | Foldable.EmptyError.t()
  def random(foldable) do
    foldable
    |> to_list
    |> safe(&Enum.random/1).()
    |> case do
      %Enum.EmptyError{} -> Foldable.EmptyError.new(foldable)
      value -> value
    end
  end

  @doc ~S"""
  Sum all numbers in a foldable

  ## Examples

      iex> sum([1, 2, 3])
      6

      iex> sum({1, 2, 3})
      3

      %BinaryTree{
        left:  4,
        right: %BinaryTree{
          left: 2,
          right: 10
        }
      } |> sum()
      #=> 16

  """
  @spec sum(Foldable.t()) :: number()
  def sum(foldable), do: right_fold(foldable, 0, &+/2)

  @doc ~S"""
  Product of all numbers in a foldable

  ## Examples

      iex> product([1, 2, 3])
      6

      iex> product({1, 2, 3})
      6

      %BinaryTree{
        left:  4,
        right: %BinaryTree{
          left: 2,
          right: 10
        }
      }
      |> product()
      #=> 80

  """
  @spec product(Foldable.t()) :: number()
  def product(foldable), do: right_fold(foldable, &*/2)

  @doc ~S"""
  Concatenate all lists in a foldable structure

  ## Examples

      iex> flatten([[1, 2, 3], [4, 5, 6], [7, 8, 9]])
      [1, 2, 3, 4, 5, 6, 7, 8, 9]

      iex> flatten({[1, 2, 3], [4, 5, 6], [7, 8, 9]})
      [7, 8, 9]

      %BinaryTree{
        left:  [1, 2, 3],
        right: %BinaryTree{
          left:  [4, 5],
          right: [6]
        }
      }
      |> flatten()
      #=> [1, 2, 3, 4, 5, 6]

  """
  @spec flatten(Foldable.t()) :: [any()]
  def flatten(contained_lists) do
    right_fold(contained_lists, [], &Semigroup.append/2)
  end

  @doc ~S"""
  Lift a function over a foldable structure generating lists of results,
  and then concatenate the resulting lists

  ## Examples

      iex> flat_map([1, 2, 3, 4, 5, 6], fn x -> [x, x] end)
      [1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6]

      iex> flat_map({1, 2, 3, 4, 5, 6}, fn x -> [x, x] end)
      [6, 6]

      %BinaryTree{
        left:  1,
        right: %BinaryTree{
          left:  2,
          right: 3
        }
      }
      |> flat_map(fn x -> [x, x] end)
      #=> [1, 1, 2, 2, 3, 3]

  """
  @spec flat_map(Foldable.t(), (any() -> [any()])) :: [any()]
  def flat_map(foldable, mapper) do
    foldable
    |> right_fold([], fn inner_focus, acc ->
      [mapper.(inner_focus) | acc]
    end)
    |> flatten()
  end

  @doc """
  Test whether the structure is empty. The default implementation is
  optimized for structures that are similar to lists, because there
  is no general way to do better.

  ## Examples

      iex> null?([])
      true

      iex> null?([1, 2, 3])
      false

  """
  @spec null?(Foldable.t()) :: boolean()
  def null?(foldable), do: right_fold(foldable, true, fn _, _ -> false end)

  @doc ~S"""
  Check if a foldable is full of only `true`s

  ## Examples

      iex> all?([true, true, false])
      false

      iex> all?({true, true, false})
      false

      %BinaryTree{
        left:  true,
        right: %BinaryTree{
          left:  true,
          right: false
        }
      } |> all?()
      #=> false

  """
  @spec all?(Foldable.t()) :: boolean()
  def all?(foldable_bools), do: right_fold(foldable_bools, true, &and/2)

  @doc ~S"""
  The same as `all?/1`, but with a custom predicate matcher

  ## Examples

      iex> import Integer
      ...> all?([1, 2, 3], &is_odd/1)
      false

      %BinaryTree{
        left:  1,
        right: %BinaryTree{
          left:  2,
          right: 3
        }
      }
      |> all?(&Integer.is_odd?/1)
      #=> false

  """
  @spec all?(Foldable.t(), (any() -> boolean())) :: boolean()
  def all?(foldable, predicate) do
    right_fold(foldable, true, fn focus, acc -> predicate.(focus) and acc end)
  end

  @doc ~S"""
  Check if a foldable contains any `true`s

  ## Examples

      iex> any? [true, true, false]
      true

      %BinaryTree{
        left:  true,
        right: %BinaryTree{
          left:  true,
          right: false
        }
      } |> any?()
      #=> true

  Not that the `Tuple` instance behaves somewhat conterintuitively

      iex> any? {true, true, false}
      false

      iex> any? {true, false, true}
      true

  """
  @spec any?(Foldable.t()) :: boolean()
  def any?(foldable_bools), do: right_fold(foldable_bools, false, &or/2)

  @doc ~S"""
  The same as `all?/1`, but with a custom predicate matcher

  ## Examples

      iex> require Integer
      ...> any?([1, 2, 3], &Integer.is_odd/1)
      true

      %BinaryTree{
        left:  1,
        right: %BinaryTree{
          left:  2,
          right: 3
        }
      }
      |> any(&Integer.is_odd?/1)
      #=> true

  """
  @spec any?(Foldable.t(), (any() -> boolean())) :: boolean()
  def any?(foldable, predicate) do
    right_fold(foldable, false, fn focus, acc -> predicate.(focus) or acc end)
  end

  @doc """
  Run each action from left to right, discarding all values.

  Always returns `%Witchcraft.Unit{}` in the same foldbale structure that you started with.

  ## Examples

      iex> then_sequence([[1, 2, 3], [4, 5, 6]])
      [
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{}
      ]

      iex> then_sequence({{1, 2, 3}, {4, 5, 6}})
      {4, 5, %Witchcraft.Unit{}}

      iex> then_sequence({[1, 2, 3], [4, 5, 6]})
      [
        %Witchcraft.Unit{},
        %Witchcraft.Unit{},
        %Witchcraft.Unit{}
      ]

  """
  @spec then_sequence(Foldable.t()) :: Monad.t()
  def then_sequence(foldable_monad) do
    seed =
      foldable_monad
      |> to_list()
      |> hd()
      |> of(%Unit{})

    right_fold(foldable_monad, seed, &then/2)
  end

  @doc """
  `traverse` actions over data, but ignore the results.

  Not a typo: this is in the correct module, since it doens't depend directly
  on `Witchcraft.Traversable`, but behaves in a similar manner.

  ## Examples

      iex> [1, 2, 3]
      ...> |> then_traverse(fn x -> [x, x * 5, x * 10] end)
      [
          #
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          #
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          #
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{}
      ]

  """
  @spec then_traverse(Foldable.t(), Apply.fun()) :: Apply.t()
  def then_traverse(foldable, fun) do
    right_fold(foldable, of(foldable, %Unit{}), fn step, acc ->
      step
      |> fun.()
      |> then(acc)
    end)
  end

  @doc """
  The same as `then_traverse`, but with the arguments flipped.

  ## Examples

      iex> fn x -> [x, x * 5, x * 10] end
      ...> |> then_through([1, 2, 3])
      [
          #
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          #
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          #
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{},
          %Witchcraft.Unit{}, %Witchcraft.Unit{}, %Witchcraft.Unit{}
      ]

  """
  @spec then_traverse(Apply.fun(), Foldable.t()) :: Apply.t()
  def then_through(fun, traversable), do: then_traverse(traversable, fun)
end
