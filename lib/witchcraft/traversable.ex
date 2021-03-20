import TypeClass

defclass Witchcraft.Traversable do
  @moduledoc """
  Walk through a data structure from left to right,
  running some action on each element in turn.

  Similar to applicatives, it can be used to do things like collecting some effect
  while performing other actions.

  ## Type Class

  An instance of `Witchcraft.Traversable` must also implement `Witchcraft.Foldable`
  and `Witchcraft.Functor`, and define `Witchcraft.Foldable.right_fold/3`.

      [right_fold/3]  Foldable    Functor  [map/2]
                             ↓    ↓
                           Traversable
                         [right_fold/3]
  """

  alias __MODULE__
  alias Witchcraft.Foldable

  extend Witchcraft.Foldable
  extend Witchcraft.Functor

  use Witchcraft.Applicative
  use Witchcraft.Foldable, except: [equal?: 2]

  use Quark

  @type t :: any()
  @type link :: (any() -> Traversable.t())

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Foldable, unquote(opts)
      use Witchcraft.Functor, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    Convert elements to actions, and then evaluate the actions from left-to-right,
    and accumulate the results.

    For a version without accumulation, see `then_traverse/2`.

    ## Examples

        iex> traverse([1, 2, 3], fn x -> {x, x * 2, x * 10} end)
        {6, 12, [10, 20, 30]}

        iex> traverse({1, 2, 3}, fn x -> [x] end)
        [{1, 2, 3}]

        iex> traverse({1, 2, 3}, fn x -> [x, x * 5, x * 10] end)
        [
          {1, 2, 3},
          {1, 2, 15},
          {1, 2, 30}
        ]

        iex> traverse([1, 2, 3], fn x -> [x, x * 5, x * 10] end)
        [
          #
          [1, 2,  3], [1, 2,  15], [1, 2,  30],
          [1, 10, 3], [1, 10, 15], [1, 10, 30],
          [1, 20, 3], [1, 20, 15], [1, 20, 30],
          #
          [5, 2,  3], [5, 2,  15], [5, 2,  30],
          [5, 10, 3], [5, 10, 15], [5, 10, 30],
          [5, 20, 3], [5, 20, 15], [5, 20, 30],
          #
          [10, 2,  3], [10, 2,  15], [10, 2,  30],
          [10, 10, 3], [10, 10, 15], [10, 10, 30],
          [10, 20, 3], [10, 20, 15], [10, 20, 30]
        ]

        traverse([1, 2, 3], fn x -> %Algae.Maybe.Just{just: x} end)
        #=> %Algae.Maybe.Just{just: [1, 2, 3]}

        traverse(%Algae.Maybe.Just{just: 4}, fn x -> [x, x * 10] end)
        #=> [
        #     %Algae.Maybe.Just{just: 4},
        #     %Algae.Maybe.Just{just: 40}
        #   ]

        traverse([1, 2, 3], fn x ->
          if is_even(x) do
            %Algae.Maybe.Just{just: x}
          else
            %Algae.Maybe.Nothing{}
          end
        end)
        #=> %Algae.Maybe.Nothing{}

    """
    @spec traverse(Traversable.t(), Traversable.link()) :: Traversable.t()
    def traverse(data, link)
  end

  properties do
    def naturality(data) do
      a = generate(data)

      f = fn x -> [x] end
      g = &Quark.id/1

      a
      |> Traversable.traverse(f)
      |> g.()
      |> equal?(Traversable.traverse(a, fn x -> x |> f.() |> g.() end))
    end

    def identity(data) do
      a = generate(data)

      a
      |> Traversable.traverse(fn x -> {x} end)
      |> equal?({a})
    end

    def composition(_data) do
      # traverse (Compose . fmap g . f) = Compose . fmap (traverse g) . traverse f

      # MAINTAINER COMMENT
      # ==================
      #
      # I cannot get this working. After throwing 1.5 days at this *one* prop,
      # I'm walking away for now. If someone has an implementation that works,
      # it would be greatly appreciated.
      #
      # I've implemented %Endo{} and %Compose{}, but Compose's Foldable refused
      # to work because there is no Foldable instance for functions (AFAIK).
      #
      # I believe that the Hakell version works because of the lazy
      # recursive call to foldMap in `Foldable f, Foldable g => Compose (f g)`,
      # which in Elixir is trying to get dispatched on the partial function.
      #
      # It's very possible that there's a simple solution that I'm just not seeing
      # after staring at the problem for too long
      #
      # PRs gladly accepted here: https://github.com/expede/witchcraft/compare
      #
      # ~ Brooklyn Zelenka, @expede

      true
    end
  end

  @doc """
  `traverse/2` with arguments reversed.

  ## Examples

      iex> fn x -> {x, x * 2, x * 10} end |> through([1, 2, 3])
      {6, 12, [10, 20, 30]}

      iex> fn x -> [x] end |> through({1, 2, 3})
      [{1, 2, 3}]

      iex> fn x -> [x, x * 5, x * 10] end |> through({1, 2, 3})
      [
        {1, 2, 3},
        {1, 2, 15},
        {1, 2, 30}
      ]

      iex> fn x -> [x, x * 5, x * 10] end |> through([1, 2, 3])
      [
        #
        [1, 2,  3], [1, 2,  15], [1, 2,  30],
        [1, 10, 3], [1, 10, 15], [1, 10, 30],
        [1, 20, 3], [1, 20, 15], [1, 20, 30],
        #
        [5, 2,  3], [5, 2,  15], [5, 2,  30],
        [5, 10, 3], [5, 10, 15], [5, 10, 30],
        [5, 20, 3], [5, 20, 15], [5, 20, 30],
        #
        [10, 2,  3], [10, 2,  15], [10, 2,  30],
        [10, 10, 3], [10, 10, 15], [10, 10, 30],
        [10, 20, 3], [10, 20, 15], [10, 20, 30]
      ]

  """
  @spec through(Traversable.link(), Traversable.t()) :: Traversable.t()
  def through(link, traversable), do: traverse(traversable, link)

  @doc """
  Run each action/effect in sequence (from left to right),
  and accumulate values along the way.

  ## Examples

      iex> sequence([{1, 2, 3}, {4, 5, 6}])
      {5, 7, [3, 6]}

      iex> [
      ...>   [1, 2, 3],
      ...>   [4, 5, 6]
      ...> ]
      ...> |> sequence()
      [
        [1, 4],
        [1, 5],
        [1, 6],
        [2, 4],
        [2, 5],
        [2, 6],
        [3, 4],
        [3, 5],
        [3, 6]
      ]

  """
  @spec sequence(Traversable.t()) :: Foldable.t()
  def sequence(traversable), do: traverse(traversable, &Quark.id/1)
end

definst Witchcraft.Traversable, for: Tuple do
  use Witchcraft.Functor

  def traverse(tuple, link) do
    last_index = tuple_size(tuple) - 1

    tuple
    |> elem(last_index)
    |> link.()
    ~> fn last -> put_elem(tuple, last_index, last) end
  end
end

definst Witchcraft.Traversable, for: List do
  use Witchcraft.Applicative
  use Witchcraft.Foldable

  def traverse([], link), do: of(link.([]), [])

  def traverse(list = [head | _], link) do
    right_fold(list, of(link.(head), []), fn x, acc ->
      # credo:disable-for-lines:2 Credo.Check.Refactor.PipeChainStart
      fn link_head, link_tail -> [link_head | link_tail] end
      |> over(link.(x), acc)
    end)
  end
end
